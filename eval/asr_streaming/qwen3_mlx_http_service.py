#!/usr/bin/env python3
"""Local HTTP boundary for the Qwen3-ASR MLX cumulative service.

This service exposes the same localhost JSON contract consumed by
`incremental_ux_gate.py --adapter http-json`. It is an evaluation service, not a
Swift app integration. Cumulative recompute remains non-native realtime.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import threading
import time
import traceback
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))

from qwen3_mlx_cumulative_service import (  # noqa: E402
    CumulativeRecomputeService,
    FakeBackend,
    MLXBackend,
    SAMPLE_RATE,
)
from qwen3_mlx_cumulative_probe import (  # noqa: E402
    resolve_system_prompt,
    system_prompt_metadata,
)
from qwen3_mlx_realtime_probe import classify_model_surface, load_mlx_model  # noqa: E402
from run_eval import load_model_metadata, now_ms  # noqa: E402


SERVICE_SCHEMA_VERSION = "1.0"


class ExpectedTextFakeBackend(FakeBackend):
    """Fake backend for HTTP transport tests.

    The canonical gate validates final text coverage. Using the gate-provided
    expected text keeps this fake mode focused on transport/session behavior
    rather than model quality.
    """

    def __init__(self) -> None:
        super().__init__()
        self.expected_text = "你好世界"

    def set_expected_text(self, text: str) -> None:
        stripped = text.strip()
        if stripped:
            self.expected_text = stripped

    def partial(self, audio: np.ndarray) -> Any:
        seconds = len(audio) / float(SAMPLE_RATE)
        if seconds < 1.0:
            return super().partial(audio)
        split = max(1, len(self.expected_text) // 2)
        return type(super().partial(audio))(
            text=self.expected_text[:split],
            wall_ms=self.partial_wall_ms,
            mode="fake_partial",
        )

    def final(self, audio: np.ndarray) -> Any:
        return type(super().final(audio))(
            text=self.expected_text,
            wall_ms=self.final_wall_ms,
            mode="fake_final",
        )


def pcm16_base64_to_float32(payload: dict[str, Any]) -> np.ndarray:
    sample_rate = int(payload.get("sample_rate", SAMPLE_RATE))
    channels = int(payload.get("channels", 1))
    sample_width = int(payload.get("sample_width_bytes", 2))
    if sample_rate != SAMPLE_RATE or channels != 1 or sample_width != 2:
        raise ValueError("expected 16 kHz mono int16 PCM chunks")
    raw_b64 = str(payload.get("pcm_base64", ""))
    if not raw_b64:
        return np.zeros((0,), dtype=np.float32)
    raw = base64.b64decode(raw_b64.encode("ascii"), validate=True)
    if len(raw) % 2:
        raise ValueError("pcm_base64 decoded byte count must be divisible by 2 for int16 PCM")
    return np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0


def public_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    allowed = {"partial", "final"}
    result: list[dict[str, Any]] = []
    for event in events:
        kind = str(event.get("kind", ""))
        if kind in allowed or kind.startswith("ignored"):
            result.append(event)
    return result


class Qwen3HttpState:
    def __init__(
        self,
        *,
        backend: Any,
        model_info: dict[str, Any],
        model_surface: dict[str, Any],
        prefix_step_sec: float,
        min_prefix_sec: float,
        max_prefixes: int,
        event_retention: int,
        fake_backend: bool,
        model_load_wall_ms: float,
        asr_context: dict[str, Any],
    ):
        self.lock = threading.RLock()
        self.started_monotonic = time.monotonic()
        self.fake_expected_backend = backend if isinstance(backend, ExpectedTextFakeBackend) else None
        self.expected_text_by_session: dict[str, str] = {}
        self.service = CumulativeRecomputeService(
            backend=backend,
            prefix_step_sec=prefix_step_sec,
            min_prefix_sec=min_prefix_sec,
            max_prefixes=max_prefixes,
            event_retention=event_retention,
        )
        self.model_info = model_info
        self.model_surface = model_surface
        self.fake_backend = fake_backend
        self.model_load_wall_ms = model_load_wall_ms
        self.asr_context = asr_context
        self.started_epoch_ms = now_ms()

    def metadata(self) -> dict[str, Any]:
        return {
            "schema_version": SERVICE_SCHEMA_VERSION,
            "service": "qwen3-mlx-http-service",
            "fake_backend": self.fake_backend,
            "native_realtime_gate_eligible": False,
            "model_info": self.model_info,
            "model_surface": self.model_surface,
            "asr_context": self.asr_context,
            "model_load_wall_ms": self.model_load_wall_ms,
            "started_epoch_ms": self.started_epoch_ms,
            "contract": ["start", "chunk", "finish", "cancel"],
        }

    def status(self) -> dict[str, Any]:
        with self.lock:
            return {
                "ok": True,
                **self.metadata(),
                "uptime_seconds": round(time.monotonic() - self.started_monotonic, 3),
                "process": {
                    "pid": os.getpid(),
                    "rss_mb": current_rss_mb(),
                },
                "service_state": self.service.status(),
            }

    def start(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        with self.lock:
            session_id = str(payload["session_id"])
            expected_text = str(payload.get("expected_text", "")).strip()
            if expected_text:
                self.expected_text_by_session[session_id] = expected_text
            self._select_fake_expected_text(session_id)
            before = self.service.event_cursor()
            self.service.start(
                session_id,
                simulated_now_ms=float(payload.get("recv_offset_ms", 0.0)),
                session_token=int(payload["session_token"]),
            )
            return public_events(self.service.events_after(before))

    def chunk(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        with self.lock:
            session_id = str(payload["session_id"])
            self._select_fake_expected_text(session_id)
            before = self.service.event_cursor()
            pcm = pcm16_base64_to_float32(payload)
            self.service.push_pcm(
                session_id,
                pcm,
                simulated_now_ms=float(payload.get("recv_offset_ms", payload.get("audio_end_ms", 0.0))),
                audio_start_ms=float(payload.get("audio_start_ms", 0.0)),
                audio_end_ms=float(payload.get("audio_end_ms", 0.0)),
                chunk_index=int(payload.get("chunk_index", 0)),
            )
            return public_events(self.service.events_after(before))

    def finish(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        with self.lock:
            session_id = str(payload["session_id"])
            self._select_fake_expected_text(session_id)
            before = self.service.event_cursor()
            self.service.finish(
                session_id,
                simulated_now_ms=float(payload.get("recv_offset_ms", 0.0)),
            )
            self.expected_text_by_session.pop(session_id, None)
            return public_events(self.service.events_after(before))

    def cancel(self, payload: dict[str, Any]) -> list[dict[str, Any]]:
        with self.lock:
            session_id = str(payload["session_id"])
            before = self.service.event_cursor()
            self.service.cancel(
                session_id,
                simulated_now_ms=float(payload.get("recv_offset_ms", 0.0)),
            )
            self.expected_text_by_session.pop(session_id, None)
            return public_events(self.service.events_after(before))

    def _select_fake_expected_text(self, session_id: str) -> None:
        if self.fake_expected_backend is None:
            return
        self.fake_expected_backend.set_expected_text(self.expected_text_by_session.get(session_id, ""))


class Handler(BaseHTTPRequestHandler):
    state: Qwen3HttpState

    def do_GET(self) -> None:  # noqa: N802
        if self.path in {"/health", "/metadata"}:
            self._write_json({"ok": True, **self.state.metadata()})
            return
        if self.path == "/status":
            self._write_json(self.state.status())
            return
        self._write_json({"error": f"unsupported path: {self.path}"}, status=404)

    def do_POST(self) -> None:  # noqa: N802
        try:
            payload = self._read_payload()
            if self.path == "/start":
                events = self.state.start(payload)
            elif self.path == "/chunk":
                events = self.state.chunk(payload)
            elif self.path == "/finish":
                events = self.state.finish(payload)
            elif self.path == "/cancel":
                events = self.state.cancel(payload)
            else:
                self._write_json({"error": f"unsupported path: {self.path}"}, status=404)
                return
            self._write_json({"events": events, "metadata": self.state.metadata()})
        except Exception as exc:
            traceback.print_exc(file=sys.stderr)
            self._write_json({"error": str(exc), "error_type": type(exc).__name__}, status=500)

    def log_message(self, format: str, *args: Any) -> None:
        return None

    def _read_payload(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        payload = json.loads(raw) if raw else {}
        if not isinstance(payload, dict):
            raise ValueError("request body must be a JSON object")
        return payload

    def _write_json(self, payload: dict[str, Any], *, status: int = 200) -> None:
        raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)


def build_state(args: argparse.Namespace) -> Qwen3HttpState:
    model_info = load_model_metadata(Path(args.registry), args.model_id)
    system_prompt = resolve_system_prompt(
        system_prompt=args.system_prompt,
        system_prompt_file=args.system_prompt_file,
    )
    load_started = time.perf_counter()
    if args.fake_backend:
        backend = ExpectedTextFakeBackend()
        model_surface: dict[str, Any] = {"fake_backend": True}
        load_wall_ms = 0.0
    else:
        model = load_mlx_model(args.model, args.mlx_audio_source)
        load_wall_ms = (time.perf_counter() - load_started) * 1000.0
        backend = MLXBackend(
            model,
            language=args.language.strip() or None,
            max_tokens=args.max_tokens,
            system_prompt=system_prompt,
        )
        model_surface = classify_model_surface(model)
    return Qwen3HttpState(
        backend=backend,
        model_info=model_info,
        model_surface=model_surface,
        prefix_step_sec=args.prefix_step_sec,
        min_prefix_sec=args.min_prefix_sec,
        max_prefixes=args.max_prefixes,
        event_retention=args.event_retention,
        fake_backend=args.fake_backend,
        model_load_wall_ms=load_wall_ms,
        asr_context=system_prompt_metadata(system_prompt),
    )


def current_rss_mb() -> float | None:
    try:
        raw = subprocess.check_output(
            ["ps", "-o", "rss=", "-p", str(os.getpid())],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        if not raw:
            return None
        return round(float(raw) / 1024.0, 3)
    except Exception:
        return None


def command_self_test() -> int:
    args = argparse.Namespace(
        fake_backend=True,
        registry="eval/asr_streaming/model_registry.json",
        model_id="qwen3-asr-0.6b-mlx-8bit",
        model=".external/models/mlx-community__Qwen3-ASR-0.6B-8bit",
        mlx_audio_source=".external/repos/mlx-audio",
        language="Chinese",
        min_prefix_sec=1.0,
        prefix_step_sec=1.0,
        max_prefixes=2,
        max_tokens=128,
        event_retention=6,
        system_prompt="数字优先使用阿拉伯数字。",
        system_prompt_file="",
    )
    state = build_state(args)
    metadata = state.metadata()
    if not metadata["asr_context"]["system_prompt_enabled"]:
        raise AssertionError(f"HTTP metadata did not record enabled system prompt: {metadata}")
    if metadata["asr_context"]["system_prompt_chars"] <= 0:
        raise AssertionError(f"HTTP metadata did not record prompt length: {metadata}")
    session_payload = {
        "session_id": "http-self-test",
        "session_token": 123,
        "expected_text": "你好世界",
        "recv_offset_ms": 0.0,
        "sample_rate": 16000,
        "sample_width_bytes": 2,
        "channels": 1,
    }
    state.start(session_payload)
    pcm = (np.zeros((SAMPLE_RATE,), dtype="<i2")).tobytes()
    chunk_events = state.chunk(
        {
            **session_payload,
            "chunk_index": 0,
            "audio_start_ms": 0.0,
            "audio_end_ms": 1000.0,
            "recv_offset_ms": 1000.0,
            "pcm_base64": base64.b64encode(pcm).decode("ascii"),
        }
    )
    if not any(event.get("kind") == "partial" for event in chunk_events):
        raise AssertionError(f"HTTP chunk did not emit partial: {chunk_events}")
    finish_events = state.finish({**session_payload, "recv_offset_ms": 1200.0})
    if not any(event.get("kind") == "final" for event in finish_events):
        raise AssertionError(f"HTTP finish did not emit final: {finish_events}")
    status = state.status()
    service_state = status["service_state"]
    if service_state["active_session_count"] != 0:
        raise AssertionError(f"finished HTTP session was not released: {status}")
    if service_state["retained_event_count"] > 6:
        raise AssertionError(f"event retention was not enforced: {status}")
    if "process" not in status or "uptime_seconds" not in status:
        raise AssertionError(f"status payload missing process/uptime: {status}")

    Handler.state = state
    server = HTTPServer(("127.0.0.1", 0), Handler)
    port = server.server_address[1]
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        import urllib.request

        with urllib.request.urlopen(f"http://127.0.0.1:{port}/status", timeout=2) as response:
            http_status = json.loads(response.read().decode("utf-8"))
        if http_status["service_state"]["active_session_count"] != 0:
            raise AssertionError(f"/status returned malformed service state: {http_status}")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)

    print("Qwen3 MLX HTTP service self-test passed.")
    return 0


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    if argv and argv[0] == "self-test":
        return command_self_test()

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18105)
    parser.add_argument("--fake-backend", action="store_true")
    parser.add_argument("--model", default=".external/models/mlx-community__Qwen3-ASR-0.6B-8bit")
    parser.add_argument("--model-id", default="qwen3-asr-0.6b-mlx-8bit")
    parser.add_argument("--mlx-audio-source", default=".external/repos/mlx-audio")
    parser.add_argument("--registry", default="eval/asr_streaming/model_registry.json")
    parser.add_argument("--language", default="Chinese")
    parser.add_argument("--system-prompt", default="")
    parser.add_argument("--system-prompt-file", default="")
    parser.add_argument("--min-prefix-sec", type=float, default=1.0)
    parser.add_argument("--prefix-step-sec", type=float, default=1.0)
    parser.add_argument("--max-prefixes", type=int, default=8)
    parser.add_argument("--max-tokens", type=int, default=256)
    parser.add_argument("--event-retention", type=int, default=5000)
    args = parser.parse_args(argv)

    Handler.state = build_state(args)
    server = HTTPServer((args.host, args.port), Handler)
    print(
        json.dumps(
            {
                "listening": f"http://{args.host}:{args.port}",
                "fake_backend": args.fake_backend,
                "model_id": args.model_id,
                "model_load_wall_ms": Handler.state.model_load_wall_ms,
                "asr_context": Handler.state.asr_context,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        return 0
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
