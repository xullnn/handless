#!/usr/bin/env python3
"""Shared helpers for active Qwen3-ASR MLX local service routes.

This module intentionally does not implement a cumulative-recompute route. It
holds neutral helpers used by the segmented service: model invocation,
system-prompt handling, and service-gate analysis.
"""

from __future__ import annotations

import difflib
import hashlib
import re
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np

from qwen3_mlx_realtime_probe import extract_text  # noqa: E402
from run_eval import (  # noqa: E402
    cer,
    char_length_ratio,
    merge_partial_texts,
    normalize_for_cer,
    wer,
)


SAMPLE_RATE = 16000


@dataclass
class ServiceResult:
    text: str
    wall_ms: float
    mode: str


class MLXBackend:
    def __init__(
        self,
        model: Any,
        *,
        language: str | None,
        system_prompt: str | None = None,
    ) -> None:
        self.model = model
        self.language = language
        self.system_prompt = (system_prompt or "").strip() or None

    def partial(self, audio: np.ndarray) -> ServiceResult:
        result = call_stream_or_generate(
            model=self.model,
            audio=audio,
            language=self.language,
            system_prompt=self.system_prompt,
        )
        return ServiceResult(
            text=str(result["text"]).strip(),
            wall_ms=float(result["wall_ms"]),
            mode=str(result["mode"]),
        )

    def final(self, audio: np.ndarray) -> ServiceResult:
        result = call_final_generate(
            model=self.model,
            audio=audio,
            language=self.language,
            system_prompt=self.system_prompt,
        )
        return ServiceResult(
            text=str(result["text"]).strip(),
            wall_ms=float(result["wall_ms"]),
            mode=str(result["mode"]),
        )


def has_meaningful_text(text: str) -> bool:
    return bool(normalize_for_cer(text))


def resolve_system_prompt(
    *,
    system_prompt: str | None = None,
    system_prompt_file: str | None = None,
) -> str | None:
    parts: list[str] = []
    prompt_file = (system_prompt_file or "").strip()
    if prompt_file:
        path = Path(prompt_file)
        if not path.is_file():
            raise FileNotFoundError(f"system prompt file not found: {prompt_file}")
        file_text = path.read_text(encoding="utf-8").strip()
        if file_text:
            parts.append(file_text)

    inline_prompt = (system_prompt or "").strip()
    if inline_prompt:
        parts.append(inline_prompt)

    merged = "\n".join(parts).strip()
    return merged or None


def system_prompt_metadata(system_prompt: str | None) -> dict[str, Any]:
    text = (system_prompt or "").strip()
    return {
        "system_prompt_enabled": bool(text),
        "system_prompt_chars": len(text),
        "system_prompt_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest() if text else None,
    }


def normalize_prompt_leak_text(text: str) -> str:
    return re.sub(r"[\W_]+", "", text, flags=re.UNICODE).lower()


def is_system_prompt_leak(text: str, system_prompt: str | None) -> bool:
    normalized_text = normalize_prompt_leak_text(text)
    normalized_prompt = normalize_prompt_leak_text(system_prompt or "")
    if not normalized_text or not normalized_prompt:
        return False

    marker_phrases = [
        "转写输出规则",
        "只输出音频中的原始转写文本",
        "不解释不总结不补充用户没有说出的内容",
        "在不改变原话语义的前提下",
        "优先使用阿拉伯数字写法",
        "常见技术词优先写作",
        "不要机械改成",
    ]
    if any(normalize_prompt_leak_text(marker) in normalized_text for marker in marker_phrases):
        return True

    if len(normalized_text) >= 18 and normalized_text in normalized_prompt:
        return True

    prompt_lines = [
        normalize_prompt_leak_text(line)
        for line in (system_prompt or "").splitlines()
        if normalize_prompt_leak_text(line)
    ]
    return any(
        len(normalized_text) >= 24
        and difflib.SequenceMatcher(None, normalized_text, line).ratio() >= 0.72
        for line in prompt_lines
    )


def filter_system_prompt_leak(text: str, system_prompt: str | None) -> str:
    return "" if is_system_prompt_leak(text, system_prompt) else text


def call_stream_or_generate(
    *,
    model: Any,
    audio: np.ndarray,
    language: str | None,
    system_prompt: str | None = None,
) -> dict[str, Any]:
    started = time.perf_counter()
    first_token_ms: float | None = None
    events: list[dict[str, Any]] = []
    text_parts: list[str] = []
    mode = "stream_transcribe" if hasattr(model, "stream_transcribe") else "generate"

    if mode == "stream_transcribe":
        for item in model.stream_transcribe(
            audio,
            language=language,
            system_prompt=system_prompt,
        ):
            text = extract_text(item)
            if not text:
                continue
            offset_ms = (time.perf_counter() - started) * 1000.0
            if first_token_ms is None:
                first_token_ms = offset_ms
            text_parts.append(text)
            events.append(
                {
                    "kind": "prefix_token",
                    "recv_offset_ms": offset_ms,
                    "text": text,
                    "is_final": bool(getattr(item, "is_final", False)),
                }
            )
        text = filter_system_prompt_leak(merge_partial_texts(text_parts), system_prompt)
    else:
        result = model.generate(
            audio,
            language=language,
            system_prompt=system_prompt,
        )
        text = filter_system_prompt_leak(extract_text(result).strip(), system_prompt)
        if text:
            first_token_ms = (time.perf_counter() - started) * 1000.0
            events.append(
                {
                    "kind": "prefix_generate_result",
                    "recv_offset_ms": first_token_ms,
                    "text": text,
                    "is_final": True,
                }
            )

    finished = time.perf_counter()
    return {
        "mode": mode,
        "text": text.strip(),
        "first_token_ms": first_token_ms,
        "wall_ms": (finished - started) * 1000.0,
        "events": events,
    }


def call_final_generate(
    *,
    model: Any,
    audio: np.ndarray,
    language: str | None,
    system_prompt: str | None = None,
) -> dict[str, Any]:
    started = time.perf_counter()
    result = model.generate(
        audio,
        language=language,
        system_prompt=system_prompt,
    )
    finished = time.perf_counter()
    return {
        "text": filter_system_prompt_leak(extract_text(result).strip(), system_prompt),
        "wall_ms": (finished - started) * 1000.0,
        "mode": "generate",
    }


def partial_cadence_ms(partials: list[dict[str, Any]]) -> float | None:
    offsets = [
        float(p["recv_offset_ms"])
        for p in partials
        if isinstance(p.get("recv_offset_ms"), (int, float))
    ]
    if len(offsets) < 2:
        return None
    return sum(b - a for a, b in zip(offsets, offsets[1:])) / float(len(offsets) - 1)


def evaluate_service_gate(
    *,
    events: list[dict[str, Any]],
    expected_text: str,
    input_finished_offset_ms: float,
    max_first_usable_partial_ms: float,
    max_final_latency_ms: float,
    max_final_cer: float,
) -> dict[str, Any]:
    partials = [e for e in events if e.get("kind") == "partial" and e.get("text")]
    meaningful_partials = [e for e in partials if bool(e.get("meaningful_text"))]
    finals = [e for e in events if e.get("kind") == "final" and e.get("text")]
    ignored = [e for e in events if str(e.get("kind", "")).startswith("ignored")]
    partials_before_stop = [
        e
        for e in partials
        if isinstance(e.get("recv_offset_ms"), (int, float))
        and float(e["recv_offset_ms"]) <= input_finished_offset_ms
    ]
    finals_after_stop = [
        e
        for e in finals
        if isinstance(e.get("recv_offset_ms"), (int, float))
        and float(e["recv_offset_ms"]) >= input_finished_offset_ms
    ]
    final_text = str(finals[-1]["text"]) if finals else ""
    final_offset = float(finals[-1]["recv_offset_ms"]) if finals else None
    final_latency = None if final_offset is None else final_offset - input_finished_offset_ms
    first_usable = (
        float(meaningful_partials[0]["recv_offset_ms"])
        if meaningful_partials and isinstance(meaningful_partials[0].get("recv_offset_ms"), (int, float))
        else None
    )
    partial_after_final = bool(
        final_offset is not None
        and any(float(p.get("recv_offset_ms", 0.0)) > final_offset for p in partials)
    )
    final_cer = cer(expected_text, final_text)
    fail_reasons: list[str] = []

    if not partials_before_stop:
        fail_reasons.append("no_partial_before_user_stop")
    if first_usable is None:
        fail_reasons.append("missing_first_usable_partial")
    elif first_usable > max_first_usable_partial_ms:
        fail_reasons.append("first_usable_partial_too_slow")
    if not final_text:
        fail_reasons.append("missing_final_text")
    if not finals_after_stop:
        fail_reasons.append("no_final_after_user_stop")
    if final_latency is None:
        fail_reasons.append("missing_final_latency")
    elif final_latency > max_final_latency_ms:
        fail_reasons.append("final_latency_too_slow")
    if final_cer is None:
        fail_reasons.append("missing_final_cer")
    elif final_cer > max_final_cer:
        fail_reasons.append("final_cer_too_high")
    if partial_after_final:
        fail_reasons.append("partial_after_final")

    return {
        "service_gate_passed": not fail_reasons,
        "service_gate_fail_reasons": fail_reasons,
        "native_realtime_gate_eligible": False,
        "wrapper_service_candidate": not fail_reasons,
        "thresholds": {
            "max_first_usable_partial_ms": max_first_usable_partial_ms,
            "max_final_latency_ms": max_final_latency_ms,
            "max_final_cer": max_final_cer,
        },
        "partial_before_stop_count": len(partials_before_stop),
        "final_after_stop_count": len(finals_after_stop),
        "first_usable_partial_ms": first_usable,
        "final_latency_ms": final_latency,
        "partial_cadence_ms": partial_cadence_ms(partials),
        "ignored_stale_event_count": len(ignored),
        "partial_after_final": partial_after_final,
        "final_text": final_text,
        "final_cer": final_cer,
        "final_wer": wer(expected_text, final_text),
        "final_to_expected_char_ratio": char_length_ratio(final_text, expected_text),
        "reason_not_native_realtime": (
            "This service uses bounded segmented recognition over local audio chunks. "
            "It validates wrapper service behavior, not native model feed/step/close semantics."
        ),
    }
