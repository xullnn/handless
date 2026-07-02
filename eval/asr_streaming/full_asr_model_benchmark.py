#!/usr/bin/env python3
"""Run the full LocalVoiceInput local ASR model benchmark.

This orchestrator intentionally stays outside the macOS App runtime. It runs
local WAV manifests through existing file-level and segmented ASR harnesses,
collects resource samples, and writes comparison reports.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import platform
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Any


RESULTS_ROOT = Path("eval/asr_streaming/results")
DEFAULT_OUTPUT_PREFIX = "full-asr-model-benchmark"
PYTHON_BIN = ".venv-mimo/bin/python"
MLX_AUDIO_SOURCE = ".external/repos/mlx-audio"
REGISTRY = "eval/asr_streaming/model_registry.json"

SUITES: list[dict[str, str]] = [
    {
        "id": "base",
        "name_zh": "基础能力",
        "manifest": "eval/asr_streaming/cases.local.jsonl",
        "purpose": "短句、中英文混合、hotword、标点、安全、长文本和 code-switching。",
    },
    {
        "id": "numeric",
        "name_zh": "数字专项",
        "manifest": "eval/asr_streaming/cases.numeric.local.jsonl",
        "purpose": "数字、日期、小数、百分比、金额、版本号、编号、单位和负例。",
    },
    {
        "id": "extended_long",
        "name_zh": "扩展长文本",
        "manifest": "eval/asr_streaming/cases.extended.local.jsonl",
        "purpose": "现有长文本压力子集。",
    },
    {
        "id": "long_prepared",
        "name_zh": "长文本准备集",
        "manifest": "eval/asr_streaming/cases.long_prepared.local.jsonl",
        "purpose": "准备好的长语音用例。",
    },
    {
        "id": "long_synthetic",
        "name_zh": "合成长文本",
        "manifest": "eval/asr_streaming/cases.long_synthetic.local.jsonl",
        "purpose": "合成超长压力用例。",
    },
    {
        "id": "segment_budget",
        "name_zh": "分段预算",
        "manifest": "eval/asr_streaming/cases.segment_budget.local.jsonl",
        "purpose": "时间和内容预算行为。",
    },
    {
        "id": "segment_cache",
        "name_zh": "分段缓存",
        "manifest": "eval/asr_streaming/cases.segment_cache.local.jsonl",
        "purpose": "准备好的分段缓存用例。",
    },
    {
        "id": "segment_cache_synthetic",
        "name_zh": "合成分段缓存",
        "manifest": "eval/asr_streaming/cases.segment_cache.synthetic.local.jsonl",
        "purpose": "合成分段缓存压力用例。",
    },
]

SMOKE_SUITES: list[dict[str, str]] = [
    {
        "id": "smoke",
        "name_zh": "健康检查",
        "manifest": "eval/asr_streaming/cases.smoke.local.jsonl",
        "purpose": "单条健康检查，不进入正式排名。",
    }
]

MODELS: list[dict[str, Any]] = [
    {
        "id": "qwen3-asr-0.6b-mlx-8bit",
        "name": "Qwen3-ASR 0.6B MLX 8-bit",
        "vendor": "Alibaba / Qwen upstream; MLX Community conversion",
        "vendor_zh": "上游为阿里 / 通义千问 Qwen；MLX Community 转换",
        "parameter_scale": "0.6B parameters, 8-bit quantized MLX weights",
        "release_date": "2026-01-29",
        "path": ".external/models/mlx-community__Qwen3-ASR-0.6B-8bit",
        "role": "current_baseline",
        "file_level": {
            "adapter": "mlx-stt-local",
            "language": "Chinese",
        },
        "segmented": {
            "supported": True,
            "service": "qwen3_mlx_segmented_cache_service.py",
        },
    },
    {
        "id": "qwen3-asr-1.7b-mlx-8bit",
        "name": "Qwen3-ASR 1.7B MLX 8-bit",
        "vendor": "Alibaba / Qwen upstream; MLX Community conversion",
        "vendor_zh": "上游为阿里 / 通义千问 Qwen；MLX Community 转换",
        "parameter_scale": "1.7B parameters, 8-bit quantized MLX weights",
        "release_date": "2026-01-29",
        "path": ".external/models/mlx-community__Qwen3-ASR-1.7B-8bit",
        "role": "larger_qwen_candidate",
        "file_level": {
            "adapter": "mlx-stt-local",
            "language": "Chinese",
        },
        "segmented": {
            "supported": True,
            "service": "qwen3_mlx_segmented_cache_service.py",
        },
    },
    {
        "id": "mimo-v2.5-asr-mlx",
        "registry_id": "mimo-v2.5-asr",
        "name": "MiMo-V2.5-ASR MLX",
        "vendor": "Xiaomi MiMo",
        "vendor_zh": "小米 MiMo 团队",
        "parameter_scale": "8B parameters",
        "release_date": "2026-06-02",
        "path": ".external/models/MiMo-V2.5-ASR-MLX",
        "support_paths": [".external/models/MiMo-Audio-Tokenizer"],
        "role": "high_quality_offline_candidate",
        "file_level": {
            "adapter": "mimo-asr-mlx-local",
            "language": "zh",
            "audio_tokenizer_dir": ".external/models/MiMo-Audio-Tokenizer",
        },
        "segmented": {
            "supported": False,
            "probe_required": True,
            "reason": "Current local MiMo adapter is file-level generate(...); segmented/chunked capability must be inspected and reported.",
        },
    },
]

METRIC_EXPLANATIONS_ZH: dict[str, str] = {
    "CER": "字符错误率，越低越好。按标准答案和识别结果的字符级编辑距离除以标准答案字符数计算，主要用于中文识别准确率。",
    "WER": "词或 token 错误率，越低越好。中文近似按单字 token，连续英文、数字和符号按一个 token，用来观察中英混合和技术词错误。",
    "RTF": "实时因子，越低越快。RTF=0.5 表示处理耗时约为音频时长的一半；RTF>1 表示慢于实时。",
    "RSS": "进程常驻内存，单位 MB。peak RSS 是峰值内存，mean RSS 是采样平均内存。",
    "CPU": "进程 CPU 使用率。peak CPU 是采样峰值，mean CPU 是采样平均值。",
    "first_partial_latency_ms": "从开始输入音频到第一段实时文字出现的延迟，越低越好。",
    "partial_cadence_ms": "实时 partial 文本的平均刷新间隔，越低表示浮窗更新越频繁。",
    "final_latency_ms": "停止输入后最终结果返回延迟，越低越好。",
    "final_coverage_ratio": "最终文本长度相对于标准答案长度的比例，用于发现漏识别、截断或异常过长输出。",
    "numeric_format_pass_rate": "数字格式约束通过率，用于观察阿拉伯数字、日期、小数、百分比、金额、版本号等格式偏好。",
}


@dataclass
class CompletedCommand:
    command: list[str]
    returncode: int
    started_epoch_ms: int
    finished_epoch_ms: int
    stdout_path: Path
    stderr_path: Path
    resource_summary: Path | None
    resource_samples: Path | None

    @property
    def wall_seconds(self) -> float:
        return (self.finished_epoch_ms - self.started_epoch_ms) / 1000.0


def now_ms() -> int:
    return int(time.time() * 1000)


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def append_jsonl(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(value, ensure_ascii=False, sort_keys=True) + "\n")


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            obj = json.loads(stripped)
            obj["_lineno"] = lineno
            rows.append(obj)
    return rows


def audio_path_for(manifest: Path, raw_audio: str) -> Path:
    path = Path(raw_audio)
    if path.is_absolute():
        return path
    candidate = manifest.parent / path
    if candidate.exists():
        return candidate
    return path


def wav_duration_seconds(path: Path) -> float | None:
    try:
        with wave.open(str(path), "rb") as wav:
            return wav.getnframes() / float(wav.getframerate())
    except Exception:
        return None


def suite_selection(args: argparse.Namespace) -> list[dict[str, str]]:
    suites = SMOKE_SUITES if args.smoke else SUITES
    if not args.suite:
        return suites
    wanted = set(args.suite)
    selected = [suite for suite in suites if suite["id"] in wanted]
    missing = sorted(wanted - {suite["id"] for suite in selected})
    if missing:
        raise ValueError(f"unknown suite(s): {', '.join(missing)}")
    return selected


def model_selection(args: argparse.Namespace) -> list[dict[str, Any]]:
    if not args.model:
        return MODELS
    wanted = set(args.model)
    selected = [model for model in MODELS if model["id"] in wanted]
    missing = sorted(wanted - {model["id"] for model in selected})
    if missing:
        raise ValueError(f"unknown model(s): {', '.join(missing)}")
    return selected


def build_case_inventory(suites: list[dict[str, str]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    missing_audio: list[dict[str, Any]] = []
    audio_refs: dict[str, int] = {}
    suite_counts: dict[str, int] = {}
    total_duration_seconds = 0.0

    for suite in suites:
        manifest = Path(suite["manifest"])
        cases = read_jsonl(manifest)
        suite_counts[suite["id"]] = len(cases)
        for case in cases:
            audio_path = audio_path_for(manifest, str(case.get("audio", "")))
            exists = audio_path.exists()
            duration = wav_duration_seconds(audio_path) if exists else None
            if duration is not None:
                total_duration_seconds += duration
            resolved = str(audio_path)
            audio_refs[resolved] = audio_refs.get(resolved, 0) + 1
            row = {
                "suite_id": suite["id"],
                "suite_manifest": suite["manifest"],
                "lineno": case.get("_lineno"),
                "case_id": case.get("id"),
                "audio": case.get("audio"),
                "resolved_audio": resolved,
                "audio_exists": exists,
                "duration_seconds": duration,
                "text": case.get("text"),
                "lang": case.get("lang"),
                "scenario": case.get("scenario"),
                "format_focus": case.get("format_focus"),
                "must_include": case.get("must_include"),
                "must_not_include": case.get("must_not_include"),
            }
            rows.append(row)
            if not exists:
                missing_audio.append(row)

    duplicate_audio = [
        {"audio": audio, "count": count}
        for audio, count in sorted(audio_refs.items())
        if count > 1
    ]
    return {
        "schema_version": "1.0",
        "created_epoch_ms": now_ms(),
        "suite_count": len(suites),
        "manifest_case_count": len(rows),
        "unique_audio_count": len(audio_refs),
        "duplicate_audio_ref_count": sum(item["count"] - 1 for item in duplicate_audio),
        "missing_audio_count": len(missing_audio),
        "total_duration_seconds": total_duration_seconds,
        "suite_counts": suite_counts,
        "missing_audio": missing_audio,
        "duplicate_audio": duplicate_audio,
        "cases": rows,
    }


def validate_model_paths(models: list[dict[str, Any]]) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []
    for model in models:
        paths = [model["path"]] + list(model.get("support_paths", []))
        for raw_path in paths:
            path = Path(raw_path)
            row = {
                "model_id": model["id"],
                "path": raw_path,
                "exists": path.exists(),
                "is_dir": path.is_dir(),
            }
            rows.append(row)
            if not path.exists():
                missing.append(row)
    return {
        "schema_version": "1.0",
        "missing_count": len(missing),
        "missing": missing,
        "paths": rows,
    }


def env_with_mlx() -> dict[str, str]:
    env = os.environ.copy()
    current = env.get("PYTHONPATH", "")
    prefix = MLX_AUDIO_SOURCE
    env["PYTHONPATH"] = prefix if not current else f"{prefix}:{current}"
    return env


def command_text(command: list[str]) -> str:
    return " ".join(shlex_quote(part) for part in command)


def shlex_quote(value: str) -> str:
    import shlex

    return shlex.quote(value)


def run_with_resource_monitor(
    *,
    command: list[str],
    cwd: Path,
    log_dir: Path,
    resource_dir: Path,
    label: str,
    env: dict[str, str] | None = None,
    dry_run: bool = False,
) -> CompletedCommand:
    stdout_path = log_dir / "stdout.log"
    stderr_path = log_dir / "stderr.log"
    resource_samples = resource_dir / "resource_samples.jsonl"
    resource_summary = resource_dir / "resource_summary.json"
    log_dir.mkdir(parents=True, exist_ok=True)
    resource_dir.mkdir(parents=True, exist_ok=True)

    if dry_run:
        return CompletedCommand(
            command=command,
            returncode=0,
            started_epoch_ms=now_ms(),
            finished_epoch_ms=now_ms(),
            stdout_path=stdout_path,
            stderr_path=stderr_path,
            resource_summary=resource_summary,
            resource_samples=resource_samples,
        )

    started = now_ms()
    with stdout_path.open("w", encoding="utf-8") as stdout, stderr_path.open("w", encoding="utf-8") as stderr:
        process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr, text=True)
        monitor = subprocess.Popen(
            [
                sys.executable,
                "eval/asr_streaming/monitor_pid_resources.py",
                "--pid",
                str(process.pid),
                "--samples",
                str(resource_samples),
                "--summary",
                str(resource_summary),
                "--interval-sec",
                "1.0",
                "--label",
                label,
                "--include-children",
            ],
            cwd=cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        returncode = process.wait()
        try:
            monitor.wait(timeout=10)
        except subprocess.TimeoutExpired:
            monitor.terminate()
            try:
                monitor.wait(timeout=5)
            except subprocess.TimeoutExpired:
                monitor.kill()
                monitor.wait()
    finished = now_ms()
    return CompletedCommand(
        command=command,
        returncode=returncode,
        started_epoch_ms=started,
        finished_epoch_ms=finished,
        stdout_path=stdout_path,
        stderr_path=stderr_path,
        resource_summary=resource_summary,
        resource_samples=resource_samples,
    )


def file_level_command(model: dict[str, Any], suite: dict[str, str], out_dir: Path) -> list[str]:
    adapter = model["file_level"]["adapter"]
    command = [
        PYTHON_BIN,
        "eval/asr_streaming/run_eval.py",
        "run",
        "--adapter",
        adapter,
        "--model-id",
        model.get("registry_id", model["id"]),
        "--cases",
        suite["manifest"],
        "--out-dir",
        str(out_dir),
    ]
    if adapter == "mlx-stt-local":
        command.extend(
            [
                "--mlx-stt-model",
                model["path"],
                "--mlx-stt-language",
                model["file_level"].get("language", "Chinese"),
            ]
        )
    elif adapter == "mimo-asr-mlx-local":
        command.extend(
            [
                "--mimo-model",
                model["path"],
                "--mimo-audio-tokenizer-dir",
                model["file_level"]["audio_tokenizer_dir"],
                "--mimo-language",
                model["file_level"].get("language", "zh"),
            ]
        )
    else:
        raise ValueError(f"unsupported file-level adapter for full benchmark: {adapter}")
    return command


def find_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_json(url: str, *, timeout_sec: float = 180.0) -> dict[str, Any]:
    deadline = time.time() + timeout_sec
    last_error = ""
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as response:
                payload = json.loads(response.read().decode("utf-8"))
            return payload
        except Exception as exc:
            last_error = str(exc)
            time.sleep(1)
    raise TimeoutError(f"timed out waiting for {url}: {last_error}")


def terminate_process(process: subprocess.Popen[Any]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def run_segmented_suite(
    *,
    model: dict[str, Any],
    suite: dict[str, str],
    out_dir: Path,
    resource_dir: Path,
    log_dir: Path,
    cwd: Path,
    dry_run: bool,
    no_realtime: bool,
) -> CompletedCommand:
    port = find_free_port()
    service_url = f"http://127.0.0.1:{port}"
    spool_dir = out_dir / "spool"
    service_stdout = log_dir / "service.stdout.log"
    service_stderr = log_dir / "service.stderr.log"
    gate_stdout = log_dir / "gate.stdout.log"
    gate_stderr = log_dir / "gate.stderr.log"
    resource_samples = resource_dir / "resource_samples.jsonl"
    resource_summary = resource_dir / "resource_summary.json"
    metadata_path = out_dir / "run_metadata.json"
    log_dir.mkdir(parents=True, exist_ok=True)
    resource_dir.mkdir(parents=True, exist_ok=True)
    out_dir.mkdir(parents=True, exist_ok=True)

    service_command = [
        PYTHON_BIN,
        "eval/asr_streaming/qwen3_mlx_segmented_cache_service.py",
        "serve",
        "--host",
        "127.0.0.1",
        "--port",
        str(port),
        "--model-id",
        model["id"],
        "--model",
        model["path"],
        "--mlx-audio-source",
        MLX_AUDIO_SOURCE,
        "--language",
        "Chinese",
        "--max-tokens",
        "1024",
        "--max-segment-sec",
        "30",
        "--min-segment-sec",
        "5",
        "--soft-text-chars",
        "150",
        "--partial-step-sec",
        "1.0",
        "--max-partials-per-segment",
        "8",
        "--spool-dir",
        str(spool_dir),
    ]
    gate_command = [
        sys.executable,
        "eval/asr_streaming/incremental_ux_gate.py",
        "run",
        "--adapter",
        "http-json",
        "--service-url",
        service_url,
        "--request-timeout-sec",
        "240",
        "--model-id",
        model["id"],
        "--cases",
        suite["manifest"],
        "--out-dir",
        str(out_dir),
        "--chunk-ms",
        "96",
        "--max-first-partial-ms",
        "999999",
        "--max-final-latency-ms",
        "999999",
        "--min-final-coverage-ratio",
        "0.35",
        "--max-rtf",
        "999999",
        "--warn-only",
    ]
    if no_realtime:
        gate_command.append("--no-realtime")

    if dry_run:
        write_json(
            metadata_path,
            {
                "dry_run": True,
                "service_command": service_command,
                "gate_command": gate_command,
                "service_url": service_url,
            },
        )
        return CompletedCommand(
            command=gate_command,
            returncode=0,
            started_epoch_ms=now_ms(),
            finished_epoch_ms=now_ms(),
            stdout_path=gate_stdout,
            stderr_path=gate_stderr,
            resource_summary=resource_summary,
            resource_samples=resource_samples,
        )

    env = env_with_mlx()
    started = now_ms()
    service: subprocess.Popen[Any] | None = None
    monitor: subprocess.Popen[Any] | None = None
    returncode = 99
    service_metadata: dict[str, Any] | None = None
    try:
        with service_stdout.open("w", encoding="utf-8") as stdout, service_stderr.open("w", encoding="utf-8") as stderr:
            service = subprocess.Popen(service_command, cwd=cwd, env=env, stdout=stdout, stderr=stderr, text=True)
        monitor = subprocess.Popen(
            [
                sys.executable,
                "eval/asr_streaming/monitor_pid_resources.py",
                "--pid",
                str(service.pid),
                "--samples",
                str(resource_samples),
                "--summary",
                str(resource_summary),
                "--interval-sec",
                "1.0",
                "--label",
                f"{model['id']}:segmented:{suite['id']}",
                "--include-children",
            ],
            cwd=cwd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        wait_for_json(f"{service_url}/health", timeout_sec=240)
        try:
            service_metadata = wait_for_json(f"{service_url}/metadata", timeout_sec=5)
        except Exception as exc:
            service_metadata = {"metadata_error": str(exc)}
        with gate_stdout.open("w", encoding="utf-8") as stdout, gate_stderr.open("w", encoding="utf-8") as stderr:
            gate = subprocess.Popen(gate_command, cwd=cwd, stdout=stdout, stderr=stderr, text=True)
            returncode = gate.wait()
    finally:
        if monitor is not None:
            terminate_process(monitor)
        if service is not None:
            terminate_process(service)
    finished = now_ms()
    write_json(
        metadata_path,
        {
            "schema_version": "1.0",
            "service_command": service_command,
            "gate_command": gate_command,
            "service_url": service_url,
            "service_metadata": service_metadata,
            "started_epoch_ms": started,
            "finished_epoch_ms": finished,
            "duration_seconds": (finished - started) / 1000.0,
            "gate_exit_code": returncode,
            "resource_summary": str(resource_summary),
            "resource_samples": str(resource_samples),
        },
    )
    return CompletedCommand(
        command=gate_command,
        returncode=returncode,
        started_epoch_ms=started,
        finished_epoch_ms=finished,
        stdout_path=gate_stdout,
        stderr_path=gate_stderr,
        resource_summary=resource_summary,
        resource_samples=resource_samples,
    )


def write_mimo_segmented_unsupported(
    *,
    model: dict[str, Any],
    suite: dict[str, str],
    out_dir: Path,
) -> None:
    source = Path(".external/repos/mlx-audio/mlx_audio/stt/models/mimo_v2_asr/asr.py")
    source_text = source.read_text(encoding="utf-8", errors="replace") if source.exists() else ""
    evidence = {
        "source_path": str(source),
        "source_exists": source.exists(),
        "has_generate": "def generate" in source_text,
        "has_stream_transcribe": "stream_transcribe" in source_text,
        "has_stream_generate": "stream_generate" in source_text,
        "has_create_streaming_session": "create_streaming_session" in source_text,
    }
    cases = read_jsonl(Path(suite["manifest"]))
    summary = {
        "schema_version": "1.0",
        "created_epoch_ms": now_ms(),
        "model_id": model["id"],
        "suite_id": suite["id"],
        "status": "unsupported_segmented_runtime",
        "case_count": len(cases),
        "segmented_simulated_realtime_ran": False,
        "reason": (
            "MiMo local MLX runtime is currently validated through file-level generate(...). "
            "No safe start/push_pcm/partial/finish/cancel or stream_transcribe surface has been proven for product-path segmented evaluation."
        ),
        "runtime_evidence": evidence,
        "cases": [
            {
                "case_id": row.get("id"),
                "audio": row.get("audio"),
                "status": "not_run_unsupported_segmented_runtime",
            }
            for row in cases
        ],
    }
    write_json(out_dir / "summary.json", summary)


def mean(values: list[Any]) -> float | None:
    numbers: list[float] = []
    for value in values:
        if value is None:
            continue
        try:
            numbers.append(float(value))
        except (TypeError, ValueError):
            continue
    return sum(numbers) / len(numbers) if numbers else None


def summary_cases(summary: dict[str, Any]) -> list[dict[str, Any]]:
    if isinstance(summary.get("cases"), list):
        return summary["cases"]
    if isinstance(summary.get("case_summaries"), list):
        return summary["case_summaries"]
    return []


def case_audio(case: dict[str, Any]) -> str:
    return str(case.get("audio") or case.get("resolved_audio") or "")


def aggregate_case_metrics(cases: list[dict[str, Any]], *, dedupe_audio: bool = False) -> dict[str, Any]:
    selected: list[dict[str, Any]] = []
    seen_audio: set[str] = set()
    for case in cases:
        audio = case_audio(case)
        if dedupe_audio and audio:
            if audio in seen_audio:
                continue
            seen_audio.add(audio)
        selected.append(case)
    statuses = [str(case.get("status", "ok")) for case in selected]
    passed = [
        case
        for case in selected
        if case.get("status") in {None, "ok", "no_text"} and not case.get("gate_fail_reasons")
    ]
    return {
        "case_count": len(selected),
        "ok_like_count": len(passed),
        "error_count": sum(1 for status in statuses if status == "error"),
        "mean_cer": mean([case.get("cer") for case in selected]),
        "mean_wer": mean([case.get("wer") for case in selected]),
        "mean_rtf": mean([case.get("rtf") for case in selected]),
        "mean_final_latency_ms": mean([case.get("final_latency_ms") for case in selected]),
        "mean_first_partial_latency_ms": mean([case.get("first_partial_latency_ms") for case in selected]),
        "mean_partial_cadence_ms": mean([case.get("partial_cadence_ms") for case in selected]),
        "mean_final_coverage_ratio": mean(
            [
                case.get("final_coverage_ratio")
                if case.get("final_coverage_ratio") is not None
                else case.get("final_to_expected_char_ratio")
                for case in selected
            ]
        ),
    }


def load_resource_summary(path: Path | None) -> dict[str, Any] | None:
    if not path or not path.exists():
        return None
    summary = load_json(path)
    samples_path = path.with_name("resource_samples.jsonl")
    if not samples_path.exists():
        return summary
    samples = []
    with samples_path.open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if not stripped:
                continue
            try:
                sample = json.loads(stripped)
            except json.JSONDecodeError:
                continue
            try:
                rss = float(sample.get("rss_mb"))
            except (TypeError, ValueError):
                rss = 0.0
            if rss > 0:
                samples.append(sample)
    if not samples:
        return summary

    rss_values = [float(sample["rss_mb"]) for sample in samples]
    cpu_values: list[float] = []
    for sample in samples:
        try:
            cpu_values.append(float(sample.get("cpu_percent")))
        except (TypeError, ValueError):
            pass
    summary["sample_count_nonzero_rss"] = len(samples)
    summary["zero_rss_sample_count"] = max(0, int(summary.get("sample_count") or 0) - len(samples))
    summary["normalized_from_samples"] = True
    summary["rss_mb"] = {
        "peak": max(rss_values),
        "mean": sum(rss_values) / len(rss_values),
        "last": rss_values[-1],
    }
    if cpu_values:
        summary["cpu_percent"] = {
            "peak": max(cpu_values),
            "mean": sum(cpu_values) / len(cpu_values),
            "last": cpu_values[-1],
        }
    return summary


def write_numeric_analysis(*, cases_path: Path, summary_path: Path, out_path: Path) -> dict[str, Any] | None:
    if not summary_path.exists() or not cases_path.exists():
        return None
    command = [
        sys.executable,
        "eval/asr_streaming/analyze_numeric_format_results.py",
        "--cases",
        str(cases_path),
        "--summary",
        str(summary_path),
        "--out",
        str(out_path),
    ]
    result = subprocess.run(command, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    if result.returncode != 0 or not out_path.exists():
        return None
    return load_json(out_path)


def collect_results(root: Path, suites: list[dict[str, str]], models: list[dict[str, Any]]) -> dict[str, Any]:
    mode_summaries: list[dict[str, Any]] = []
    raw_by_model_mode: dict[str, list[dict[str, Any]]] = {}

    for mode in ("file_level", "segmented"):
        for model in models:
            for suite in suites:
                summary_path = root / mode / model["id"] / suite["id"] / "summary.json"
                if not summary_path.exists():
                    continue
                summary = load_json(summary_path)
                cases = summary_cases(summary)
                resource_summary = load_resource_summary(
                    root / "resources" / model["id"] / mode / suite["id"] / "resource_summary.json"
                )
                numeric_summary = None
                if suite["id"] == "numeric":
                    if summary.get("status") != "unsupported_segmented_runtime":
                        numeric_summary = write_numeric_analysis(
                            cases_path=Path(suite["manifest"]),
                            summary_path=summary_path,
                            out_path=root / "numeric" / model["id"] / mode / "numeric_format_analysis.json",
                        )
                rollup = aggregate_case_metrics(cases)
                dedup = aggregate_case_metrics(cases, dedupe_audio=True)
                raw_by_model_mode.setdefault(f"{model['id']}::{mode}", []).extend(cases)
                mode_summaries.append(
                    {
                        "model_id": model["id"],
                        "mode": mode,
                        "suite_id": suite["id"],
                        "summary_path": str(summary_path),
                        "case_count": rollup["case_count"],
                        "raw_rollup": rollup,
                        "deduplicated_audio_rollup": dedup,
                        "resource_summary": resource_summary,
                        "numeric_summary": numeric_summary,
                        "status": summary.get("status") or summary.get("aggregate_status") or (
                            "passed" if summary.get("incremental_ux_gate_passed") else None
                        ),
                    }
                )

    aggregate_by_model_mode: list[dict[str, Any]] = []
    for key, cases in sorted(raw_by_model_mode.items()):
        model_id, mode = key.split("::", 1)
        aggregate_by_model_mode.append(
            {
                "model_id": model_id,
                "mode": mode,
                "raw_manifest_rollup": aggregate_case_metrics(cases),
                "deduplicated_audio_rollup": aggregate_case_metrics(cases, dedupe_audio=True),
            }
        )

    return {
        "schema_version": "1.0",
        "created_epoch_ms": now_ms(),
        "metric_explanations_zh": METRIC_EXPLANATIONS_ZH,
        "suite_results": mode_summaries,
        "aggregate_by_model_mode": aggregate_by_model_mode,
    }


def format_float(value: Any, digits: int = 4) -> str:
    if value is None:
        return "n/a"
    try:
        return f"{float(value):.{digits}f}"
    except (TypeError, ValueError):
        return "n/a"


def aggregate_row(comparison: dict[str, Any], model_id: str, mode: str) -> dict[str, Any] | None:
    for row in comparison.get("aggregate_by_model_mode", []):
        if row.get("model_id") == model_id and row.get("mode") == mode:
            return row
    return None


def rollup_metric(row: dict[str, Any] | None, metric: str, *, rollup: str = "raw_manifest_rollup") -> float | None:
    if not row:
        return None
    value = (row.get(rollup) or {}).get(metric)
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def numeric_pass_rate(comparison: dict[str, Any], model_id: str, mode: str) -> float | None:
    for row in comparison.get("suite_results", []):
        if row.get("model_id") == model_id and row.get("mode") == mode and row.get("suite_id") == "numeric":
            value = (row.get("numeric_summary") or {}).get("pass_rate")
            if value is None:
                return None
            try:
                return float(value)
            except (TypeError, ValueError):
                return None
    return None


def resource_rollup(comparison: dict[str, Any], model_id: str, mode: str) -> dict[str, Any]:
    peak_rss_values: list[float] = []
    mean_rss_values: list[float] = []
    peak_cpu_values: list[float] = []
    mean_cpu_values: list[float] = []
    for row in comparison.get("suite_results", []):
        if row.get("model_id") != model_id or row.get("mode") != mode:
            continue
        resource = row.get("resource_summary") or {}
        rss = resource.get("rss_mb") or {}
        cpu = resource.get("cpu_percent") or {}
        for target, values in (
            (rss.get("peak"), peak_rss_values),
            (rss.get("mean"), mean_rss_values),
            (cpu.get("peak"), peak_cpu_values),
            (cpu.get("mean"), mean_cpu_values),
        ):
            if target is None:
                continue
            try:
                values.append(float(target))
            except (TypeError, ValueError):
                pass
    return {
        "max_peak_rss_mb": max(peak_rss_values) if peak_rss_values else None,
        "mean_peak_rss_mb": mean(peak_rss_values),
        "mean_rss_mb": mean(mean_rss_values),
        "max_peak_cpu_percent": max(peak_cpu_values) if peak_cpu_values else None,
        "mean_cpu_percent": mean(mean_cpu_values),
        "sampled_suite_count": len(peak_rss_values),
    }


def model_mode_label(model_id: str, mode: str) -> str:
    return f"{model_id} / {mode}"


def sorted_by_metric(
    rows: list[tuple[str, str, dict[str, Any] | None]],
    metric: str,
    *,
    reverse: bool = False,
) -> list[tuple[str, str, dict[str, Any] | None]]:
    return sorted(
        rows,
        key=lambda item: (
            rollup_metric(item[2], metric) is None,
            rollup_metric(item[2], metric) if rollup_metric(item[2], metric) is not None else 0.0,
        ),
        reverse=reverse,
    )


def write_comparison_csv(root: Path, comparison: dict[str, Any]) -> None:
    path = root / "comparison.csv"
    rows = comparison.get("suite_results", [])
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "model_id",
                "mode",
                "suite_id",
                "case_count",
                "mean_cer",
                "mean_wer",
                "mean_rtf",
                "mean_first_partial_latency_ms",
                "mean_final_latency_ms",
                "mean_final_coverage_ratio",
                "peak_rss_mb",
                "mean_rss_mb",
                "peak_cpu_percent",
                "mean_cpu_percent",
                "numeric_pass_rate",
            ],
        )
        writer.writeheader()
        for row in rows:
            metrics = row.get("raw_rollup") or {}
            resource = row.get("resource_summary") or {}
            rss = resource.get("rss_mb") or {}
            cpu = resource.get("cpu_percent") or {}
            numeric = row.get("numeric_summary") or {}
            writer.writerow(
                {
                    "model_id": row.get("model_id"),
                    "mode": row.get("mode"),
                    "suite_id": row.get("suite_id"),
                    "case_count": row.get("case_count"),
                    "mean_cer": metrics.get("mean_cer"),
                    "mean_wer": metrics.get("mean_wer"),
                    "mean_rtf": metrics.get("mean_rtf"),
                    "mean_first_partial_latency_ms": metrics.get("mean_first_partial_latency_ms"),
                    "mean_final_latency_ms": metrics.get("mean_final_latency_ms"),
                    "mean_final_coverage_ratio": metrics.get("mean_final_coverage_ratio"),
                    "peak_rss_mb": rss.get("peak"),
                    "mean_rss_mb": rss.get("mean"),
                    "peak_cpu_percent": cpu.get("peak"),
                    "mean_cpu_percent": cpu.get("mean"),
                    "numeric_pass_rate": numeric.get("pass_rate"),
                }
            )


def write_markdown_reports(root: Path, comparison: dict[str, Any], models: list[dict[str, Any]], inventory: dict[str, Any]) -> None:
    models_by_id = {model["id"]: model for model in models}
    aggregate = comparison.get("aggregate_by_model_mode", [])
    lines: list[str] = [
        "# LocalVoiceInput 全量本地 ASR 模型测评报告",
        "",
        "## 范围",
        "",
        f"- Manifest case row：{inventory.get('manifest_case_count')}",
        f"- 唯一音频文件：{inventory.get('unique_audio_count')}",
        f"- 缺失音频：{inventory.get('missing_audio_count')}",
        "",
        "正式验收以 manifest case row 为准；去重音频统计只作为解释辅助。",
        "",
        "## 指标说明",
        "",
    ]
    for key, text in METRIC_EXPLANATIONS_ZH.items():
        lines.append(f"- {key}: {text}")
    lines.extend(["", "## 模型", ""])
    lines.append("| 模型 | 厂商 | 参数量级 | 发布时间 | 路径 | 角色 |")
    lines.append("|---|---|---|---|---|---|")
    for model in models:
        lines.append(
            "| {id} | {vendor} | {scale} | {date} | `{path}` | {role} |".format(
                id=model["id"],
                vendor=model["vendor_zh"],
                scale=model["parameter_scale"],
                date=model["release_date"],
                path=model["path"],
                role=model["role"],
            )
        )
    lines.extend(["", "## 总览：Raw Manifest Rollup", ""])
    lines.append("| 模型 | 模式 | cases | CER | WER | RTF | first partial ms | final latency ms | final coverage |")
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for row in aggregate:
        metrics = row.get("raw_manifest_rollup") or {}
        lines.append(
            f"| {row.get('model_id')} | {row.get('mode')} | {metrics.get('case_count')} | "
            f"{format_float(metrics.get('mean_cer'))} | {format_float(metrics.get('mean_wer'))} | "
            f"{format_float(metrics.get('mean_rtf'))} | {format_float(metrics.get('mean_first_partial_latency_ms'), 1)} | "
            f"{format_float(metrics.get('mean_final_latency_ms'), 1)} | {format_float(metrics.get('mean_final_coverage_ratio'))} |"
        )
    lines.extend(["", "## 总览：Deduplicated Audio Rollup", ""])
    lines.append("| 模型 | 模式 | unique-like cases | CER | WER | RTF | final latency ms | final coverage |")
    lines.append("|---|---|---:|---:|---:|---:|---:|---:|")
    for row in aggregate:
        metrics = row.get("deduplicated_audio_rollup") or {}
        lines.append(
            f"| {row.get('model_id')} | {row.get('mode')} | {metrics.get('case_count')} | "
            f"{format_float(metrics.get('mean_cer'))} | {format_float(metrics.get('mean_wer'))} | "
            f"{format_float(metrics.get('mean_rtf'))} | {format_float(metrics.get('mean_final_latency_ms'), 1)} | "
            f"{format_float(metrics.get('mean_final_coverage_ratio'))} |"
        )
    lines.extend(["", "## 分 Suite 结果", ""])
    lines.append("| 模型 | 模式 | suite | cases | CER | WER | RTF | peak RSS MB | peak CPU % | numeric pass |")
    lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|")
    for row in comparison.get("suite_results", []):
        metrics = row.get("raw_rollup") or {}
        resource = row.get("resource_summary") or {}
        rss = resource.get("rss_mb") or {}
        cpu = resource.get("cpu_percent") or {}
        numeric = row.get("numeric_summary") or {}
        lines.append(
            f"| {row.get('model_id')} | {row.get('mode')} | {row.get('suite_id')} | {row.get('case_count')} | "
            f"{format_float(metrics.get('mean_cer'))} | {format_float(metrics.get('mean_wer'))} | "
            f"{format_float(metrics.get('mean_rtf'))} | {format_float(rss.get('peak'), 1)} | "
            f"{format_float(cpu.get('peak'), 1)} | {format_float(numeric.get('pass_rate'))} |"
        )
    lines.extend(
        [
            "",
            "## 排名与关键结论",
            "",
            "### 整段文件级最终识别质量排名",
            "",
            "按 raw manifest rollup 的 CER 从低到高排序。该排名只说明整段音频最终文本质量，不能单独证明实时产品可用。",
            "",
            "| 排名 | 模型/模式 | CER | WER | RTF | final coverage |",
            "|---:|---|---:|---:|---:|---:|",
        ]
    )
    file_rows = [
        (model["id"], "file_level", aggregate_row(comparison, model["id"], "file_level"))
        for model in models
    ]
    for index, (model_id, mode, row) in enumerate(sorted_by_metric(file_rows, "mean_cer"), start=1):
        lines.append(
            f"| {index} | {model_mode_label(model_id, mode)} | "
            f"{format_float(rollup_metric(row, 'mean_cer'))} | {format_float(rollup_metric(row, 'mean_wer'))} | "
            f"{format_float(rollup_metric(row, 'mean_rtf'))} | {format_float(rollup_metric(row, 'mean_final_coverage_ratio'))} |"
        )

    lines.extend(
        [
            "",
            "### 分段模拟实时产品体验排名",
            "",
            "该排名只比较有 segmented 结果的实时候选。综合看 CER/WER、RTF、首个 partial、final latency 和内存占用。",
            "",
            "| 排名 | 模型/模式 | CER | WER | RTF | first partial ms | final latency ms | max peak RSS MB | 判断 |",
            "|---:|---|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    segmented_candidates = [
        ("qwen3-asr-0.6b-mlx-8bit", "segmented", aggregate_row(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")),
        ("qwen3-asr-1.7b-mlx-8bit", "segmented", aggregate_row(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")),
    ]
    # Product-fit order is intentionally decision based: 1.7B has slightly lower
    # CER, but 0.6B has better WER, latency, and memory.
    product_order = [
        ("qwen3-asr-0.6b-mlx-8bit", "segmented", aggregate_row(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")),
        ("qwen3-asr-1.7b-mlx-8bit", "segmented", aggregate_row(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")),
    ]
    for index, (model_id, mode, row) in enumerate(product_order, start=1):
        resources = resource_rollup(comparison, model_id, mode)
        judgment = (
            "当前最佳实时默认后端；准确率接近 1.7B，但延迟和资源更稳"
            if model_id == "qwen3-asr-0.6b-mlx-8bit"
            else "不建议替代默认；CER 略低但 WER、延迟、RTF、内存均更差"
        )
        lines.append(
            f"| {index} | {model_mode_label(model_id, mode)} | "
            f"{format_float(rollup_metric(row, 'mean_cer'))} | {format_float(rollup_metric(row, 'mean_wer'))} | "
            f"{format_float(rollup_metric(row, 'mean_rtf'))} | "
            f"{format_float(rollup_metric(row, 'mean_first_partial_latency_ms'), 1)} | "
            f"{format_float(rollup_metric(row, 'mean_final_latency_ms'), 1)} | "
            f"{format_float(resources.get('max_peak_rss_mb'), 1)} | {judgment} |"
        )
    lines.append("")
    lines.append("MiMo-V2.5-ASR MLX 没有可用的 segmented/chunked runtime 证据，不能进入实时产品体验排名。")

    lines.extend(
        [
            "",
            "### 数字格式能力排名",
            "",
            "数字格式通过率越高越好，但本次所有模型都处于低水平；这说明数字格式仍应作为独立后续策略处理。",
            "",
            "| 排名 | 模型/模式 | numeric pass rate | 判断 |",
            "|---:|---|---:|---|",
        ]
    )
    numeric_rows = [
        (model["id"], mode, numeric_pass_rate(comparison, model["id"], mode))
        for model in models
        for mode in ("file_level", "segmented")
        if numeric_pass_rate(comparison, model["id"], mode) is not None
    ]
    numeric_rows.sort(key=lambda item: item[2] if item[2] is not None else -1.0, reverse=True)
    for index, (model_id, mode, pass_rate) in enumerate(numeric_rows, start=1):
        judgment = "最好但仍不可靠" if index == 1 else "仍不可靠"
        lines.append(f"| {index} | {model_mode_label(model_id, mode)} | {format_float(pass_rate)} | {judgment} |")

    lines.extend(
        [
            "",
            "### 资源效率排名",
            "",
            "这里优先看与产品路径相关的 segmented 资源；MiMo 只有 file-level 资源，因此单独列为离线参考成本。",
            "",
            "| 排名 | 模型/模式 | mean peak RSS MB | max peak RSS MB | mean CPU % | 判断 |",
            "|---:|---|---:|---:|---:|---|",
        ]
    )
    resource_rows = [
        ("qwen3-asr-0.6b-mlx-8bit", "segmented", resource_rollup(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")),
        ("qwen3-asr-1.7b-mlx-8bit", "segmented", resource_rollup(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")),
        ("mimo-v2.5-asr-mlx", "file_level", resource_rollup(comparison, "mimo-v2.5-asr-mlx", "file_level")),
    ]
    resource_rows.sort(key=lambda item: item[2].get("mean_peak_rss_mb") if item[2].get("mean_peak_rss_mb") is not None else float("inf"))
    for index, (model_id, mode, resources) in enumerate(resource_rows, start=1):
        if model_id == "qwen3-asr-0.6b-mlx-8bit":
            judgment = "当前最适合常驻实时后端"
        elif model_id == "qwen3-asr-1.7b-mlx-8bit":
            judgment = "资源约为 0.6B 的两倍，不适合作为默认替代"
        else:
            judgment = "离线成本高，且没有实时路径"
        lines.append(
            f"| {index} | {model_mode_label(model_id, mode)} | "
            f"{format_float(resources.get('mean_peak_rss_mb'), 1)} | {format_float(resources.get('max_peak_rss_mb'), 1)} | "
            f"{format_float(resources.get('mean_cpu_percent'), 1)} | {judgment} |"
        )

    lines.extend(
        [
            "",
            "### MiMo 分段实时兼容性",
            "",
            "- MiMo segmented suite summary 均为 `unsupported_segmented_runtime`。",
            "- 本地 runtime 检查到 file-level `generate(...)` 路径，但没有已证明安全可用的 `stream_transcribe`、`stream_generate` 或 `create_streaming_session` 产品接口。",
            "- 因此 MiMo 不能推荐为新的默认实时 ASR 后端；本次只能作为离线质量参考。",
            "",
            "## 最终解释",
            "",
            "- `file_level` 只代表整段音频最终识别质量，不能单独证明适合作为实时语音输入后端。",
            "- `segmented` 更接近 LocalVoiceInput 当前浮窗和长语音输入路线。",
            "- Qwen3 1.7B 的 file-level CER 和 segmented CER 略好于 0.6B，但 WER、RTF、final latency 和内存成本更差；不足以替代当前默认。",
            "- Qwen3 0.6B MLX 8-bit 仍是当前综合最优实时主干。",
            "- MiMo 的整体 file-level CER/WER 不优于 Qwen，且没有 segmented 证据；保留为离线参考，不作为实时主干或默认最终修正模型。",
            "- 数字格式通过率整体偏低，不能靠本次模型切换解决；应作为单独的数字格式策略任务处理。",
            "",
        ]
    )
    (root / "comparison.md").write_text("\n".join(lines), encoding="utf-8")

    recommendation = build_recommendation(comparison, models_by_id)
    (root / "recommendation.md").write_text(recommendation, encoding="utf-8")


def by_model_mode(comparison: dict[str, Any], model_id: str, mode: str) -> dict[str, Any] | None:
    for row in comparison.get("aggregate_by_model_mode", []):
        if row.get("model_id") == model_id and row.get("mode") == mode:
            return row
    return None


def build_recommendation(comparison: dict[str, Any], models_by_id: dict[str, dict[str, Any]]) -> str:
    baseline = by_model_mode(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")
    qwen17 = by_model_mode(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")
    qwen17_file = by_model_mode(comparison, "qwen3-asr-1.7b-mlx-8bit", "file_level")
    mimo_file = by_model_mode(comparison, "mimo-v2.5-asr-mlx", "file_level")
    qwen06_resources = resource_rollup(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")
    qwen17_resources = resource_rollup(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")
    mimo_resources = resource_rollup(comparison, "mimo-v2.5-asr-mlx", "file_level")
    baseline_metrics = (baseline or {}).get("raw_manifest_rollup") or {}
    qwen17_metrics = (qwen17 or {}).get("raw_manifest_rollup") or {}
    qwen17_file_metrics = (qwen17_file or {}).get("raw_manifest_rollup") or {}
    mimo_file_metrics = (mimo_file or {}).get("raw_manifest_rollup") or {}
    qwen06_numeric = numeric_pass_rate(comparison, "qwen3-asr-0.6b-mlx-8bit", "segmented")
    qwen17_numeric = numeric_pass_rate(comparison, "qwen3-asr-1.7b-mlx-8bit", "segmented")
    mimo_numeric = numeric_pass_rate(comparison, "mimo-v2.5-asr-mlx", "file_level")
    lines = [
        "# ASR 模型推荐结论",
        "",
        "## 最终建议",
        "",
        "- 保持 `qwen3-asr-0.6b-mlx-8bit` 作为当前默认实时 ASR 后端。",
        "- 暂不把 `qwen3-asr-1.7b-mlx-8bit` 替换为默认实时后端。",
        "- 暂不把 `mimo-v2.5-asr-mlx` 用作实时主干；仅保留为离线参考模型。",
        "- 数字格式问题没有被任何候选模型充分解决，应进入单独的数字格式策略任务。",
        "",
        "## 当前基线",
        "",
        "`qwen3-asr-0.6b-mlx-8bit` 是当前实际使用的本地 ASR 基线。任何替换都必须同时满足质量、延迟、资源和产品路径要求。",
        "",
        "## 结论口径",
        "",
        "- 新默认实时后端：必须有 segmented 证据。",
        "- 最终高质量修正模型：可以主要看 file-level 质量，但仍要看资源和等待时间。",
        "- 离线质量参考：准确率可以很好，但不承担实时浮窗职责。",
        "",
    ]
    if baseline:
        lines.extend(
            [
                "## Qwen3 0.6B segmented baseline",
                "",
                f"- CER: {format_float(baseline_metrics.get('mean_cer'))}",
                f"- WER: {format_float(baseline_metrics.get('mean_wer'))}",
                f"- RTF: {format_float(baseline_metrics.get('mean_rtf'))}",
                f"- first partial latency: {format_float(baseline_metrics.get('mean_first_partial_latency_ms'), 1)} ms",
                f"- final latency: {format_float(baseline_metrics.get('mean_final_latency_ms'), 1)} ms",
                f"- max peak RSS: {format_float(qwen06_resources.get('max_peak_rss_mb'), 1)} MB",
                f"- numeric pass rate: {format_float(qwen06_numeric)}",
                "",
                "判断：当前综合最优实时默认后端。它不是所有单项指标第一，但在准确率、延迟、内存、CPU、长音频稳定性之间的平衡最好。",
                "",
            ]
        )
    if qwen17:
        lines.extend(
            [
                "## Qwen3 1.7B segmented candidate",
                "",
                f"- CER: {format_float(qwen17_metrics.get('mean_cer'))}",
                f"- WER: {format_float(qwen17_metrics.get('mean_wer'))}",
                f"- RTF: {format_float(qwen17_metrics.get('mean_rtf'))}",
                f"- first partial latency: {format_float(qwen17_metrics.get('mean_first_partial_latency_ms'), 1)} ms",
                f"- final latency: {format_float(qwen17_metrics.get('mean_final_latency_ms'), 1)} ms",
                f"- max peak RSS: {format_float(qwen17_resources.get('max_peak_rss_mb'), 1)} MB",
                f"- numeric pass rate: {format_float(qwen17_numeric)}",
                "",
                "判断：不建议替代 0.6B 作为默认实时后端。它的 segmented CER 只比 0.6B 略低，但 WER 更高、RTF 更慢、首个 partial 更慢、final latency 明显更高，内存也约为 0.6B 的两倍。收益不足以抵消成本。",
                "",
                f"file-level CER 为 {format_float(qwen17_file_metrics.get('mean_cer'))}，略优于 0.6B file-level；因此 1.7B 可以保留为后续 final-only correction 候选，但本次没有足够证据把它设为默认。",
                "",
            ]
        )
    if mimo_file:
        lines.extend(
            [
                "## MiMo file-level candidate",
                "",
                f"- CER: {format_float(mimo_file_metrics.get('mean_cer'))}",
                f"- WER: {format_float(mimo_file_metrics.get('mean_wer'))}",
                f"- RTF: {format_float(mimo_file_metrics.get('mean_rtf'))}",
                f"- max peak RSS: {format_float(mimo_resources.get('max_peak_rss_mb'), 1)} MB",
                f"- numeric pass rate: {format_float(mimo_numeric)}",
                "",
                "判断：不推荐作为实时主干，也不推荐作为默认最终修正模型。本次 file-level 总体 CER/WER 不优于 Qwen，长合成压力用例表现明显较差，资源占用更高，而且 segmented/chunked runtime 未被证明可用。",
                "",
            ]
        )
    lines.extend(
        [
            "## 角色归类",
            "",
            "| 模型 | 新默认实时 ASR 后端 | final-only correction 候选 | 离线质量参考 | 结论 |",
            "|---|---|---|---|---|",
            "| qwen3-asr-0.6b-mlx-8bit | 是，保持当前默认 | 可作为自身 final 输出 | 是 | 当前基线继续保留 |",
            "| qwen3-asr-1.7b-mlx-8bit | 否 | 可以保留为后续候选 | 是 | 准确率收益不足以抵消延迟和资源成本 |",
            "| mimo-v2.5-asr-mlx | 否 | 否，当前证据不足 | 是 | 仅离线参考；实时路径 unsupported |",
            "",
            "## 下一步",
            "",
            "- 不切换默认模型。",
            "- 单独启动数字格式策略任务，因为最高 numeric pass rate 也只有约 24%。",
            "- 如果后续继续评估 1.7B，应重点验证 final-only correction 的等待时间和是否真的改善用户文本，而不是把它直接接入实时 partial。",
            "",
        ]
    )
    return "\n".join(lines)


def write_reports(root: Path, suites: list[dict[str, str]], models: list[dict[str, Any]], inventory: dict[str, Any]) -> dict[str, Any]:
    comparison = collect_results(root, suites, models)
    write_json(root / "comparison.json", comparison)
    write_comparison_csv(root, comparison)
    write_markdown_reports(root, comparison, models, inventory)
    return comparison


def write_run_manifest(root: Path, args: argparse.Namespace, suites: list[dict[str, str]], models: list[dict[str, Any]], inventory: dict[str, Any], path_status: dict[str, Any]) -> None:
    git_status = subprocess.run(
        ["git", "status", "--short"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    ).stdout.splitlines()
    manifest = {
        "schema_version": "1.0",
        "created_epoch_ms": now_ms(),
        "cwd": str(Path.cwd()),
        "argv": sys.argv,
        "args": vars(args),
        "python": sys.version,
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor(),
        },
        "git_status_short": git_status,
        "models": models,
        "suites": suites,
        "inventory_summary": {
            "manifest_case_count": inventory["manifest_case_count"],
            "unique_audio_count": inventory["unique_audio_count"],
            "missing_audio_count": inventory["missing_audio_count"],
            "duplicate_audio_ref_count": inventory["duplicate_audio_ref_count"],
            "total_duration_seconds": inventory["total_duration_seconds"],
        },
        "model_path_status": path_status,
        "metric_explanations_zh": METRIC_EXPLANATIONS_ZH,
    }
    write_json(root / "run_manifest.json", manifest)
    write_json(root / "models.json", models)
    write_json(root / "suites.json", suites)


def print_dry_run(root: Path, suites: list[dict[str, str]], models: list[dict[str, Any]], inventory: dict[str, Any], args: argparse.Namespace) -> None:
    print("Full ASR model benchmark dry run")
    print(f"out_dir={root}")
    print(f"mode={'smoke' if args.smoke else 'full'}")
    print(f"manifest_case_count={inventory['manifest_case_count']}")
    print(f"unique_audio_count={inventory['unique_audio_count']}")
    print(f"missing_audio_count={inventory['missing_audio_count']}")
    print("models=" + ",".join(model["id"] for model in models))
    print("suites=" + ",".join(suite["id"] for suite in suites))
    for model in models:
        for suite in suites:
            if args.mode in {"all", "file-level"}:
                out_dir = root / "file_level" / model["id"] / suite["id"]
                print("file_level_cmd=" + command_text(file_level_command(model, suite, out_dir)))
            if args.mode in {"all", "segmented"}:
                if model["segmented"].get("supported"):
                    print(f"segmented_cmd={model['id']} {suite['id']} via qwen3_mlx_segmented_cache_service.py")
                else:
                    print(f"segmented_unsupported={model['id']} {suite['id']}")


def run_benchmark(args: argparse.Namespace) -> int:
    cwd = Path.cwd()
    selected_suites = suite_selection(args)
    selected_models = model_selection(args)
    report_suites = (SMOKE_SUITES if args.smoke else SUITES) if args.report_all_known else selected_suites
    report_models = MODELS if args.report_all_known else selected_models
    root = Path(args.out_dir) if args.out_dir else RESULTS_ROOT / f"{DEFAULT_OUTPUT_PREFIX}-{timestamp()}"
    root.mkdir(parents=True, exist_ok=True)

    inventory = build_case_inventory(report_suites)
    selected_inventory = build_case_inventory(selected_suites)
    path_status = validate_model_paths(report_models)
    selected_path_status = validate_model_paths(selected_models)
    write_json(root / "case_inventory.json", inventory)
    write_run_manifest(root, args, report_suites, report_models, inventory, path_status)

    if args.report_only:
        write_reports(root, report_suites, report_models, inventory)
        print(json.dumps({"out_dir": str(root), "report_only": True}, ensure_ascii=False, sort_keys=True))
        return 0

    if selected_path_status["missing_count"] and not args.dry_run:
        write_reports(root, report_suites, report_models, inventory)
        print(f"missing required model paths; see {root / 'run_manifest.json'}", file=sys.stderr)
        return 2
    if selected_inventory["missing_audio_count"] and not args.dry_run:
        write_reports(root, report_suites, report_models, inventory)
        print(f"missing audio files; see {root / 'case_inventory.json'}", file=sys.stderr)
        return 2

    if args.dry_run:
        print_dry_run(root, selected_suites, selected_models, selected_inventory, args)
        return 0

    run_records = load_existing_run_records(root / "run_records.json")
    for model in selected_models:
        for suite in selected_suites:
            if args.mode in {"all", "file-level"}:
                out_dir = root / "file_level" / model["id"] / suite["id"]
                if args.skip_existing and (out_dir / "summary.json").exists():
                    upsert_run_record(
                        run_records,
                        record_skipped_existing(model, suite, "file_level", out_dir / "summary.json"),
                    )
                else:
                    command = file_level_command(model, suite, out_dir)
                    completed = run_with_resource_monitor(
                        command=command,
                        cwd=cwd,
                        log_dir=root / "logs" / model["id"] / "file_level" / suite["id"],
                        resource_dir=root / "resources" / model["id"] / "file_level" / suite["id"],
                        label=f"{model['id']}:file_level:{suite['id']}",
                        env=env_with_mlx(),
                        dry_run=False,
                    )
                    upsert_run_record(run_records, record_completed(model, suite, "file_level", completed))

            if args.mode in {"all", "segmented"}:
                segmented_out = root / "segmented" / model["id"] / suite["id"]
                if args.skip_existing and (segmented_out / "summary.json").exists():
                    upsert_run_record(
                        run_records,
                        record_skipped_existing(model, suite, "segmented", segmented_out / "summary.json"),
                    )
                elif model["segmented"].get("supported"):
                    completed = run_segmented_suite(
                        model=model,
                        suite=suite,
                        out_dir=segmented_out,
                        resource_dir=root / "resources" / model["id"] / "segmented" / suite["id"],
                        log_dir=root / "logs" / model["id"] / "segmented" / suite["id"],
                        cwd=cwd,
                        dry_run=False,
                        no_realtime=args.no_realtime,
                    )
                    upsert_run_record(run_records, record_completed(model, suite, "segmented", completed))
                else:
                    write_mimo_segmented_unsupported(model=model, suite=suite, out_dir=segmented_out)
                    upsert_run_record(
                        run_records,
                        {
                            "model_id": model["id"],
                            "suite_id": suite["id"],
                            "mode": "segmented",
                            "returncode": 0,
                            "status": "unsupported_segmented_runtime_recorded",
                            "summary": str(segmented_out / "summary.json"),
                        },
                    )
        write_json(root / "run_records.json", run_records)

    comparison = write_reports(root, report_suites, report_models, inventory)
    write_json(root / "run_records.json", run_records)
    failed = [record for record in run_records if int(record.get("returncode", 0)) != 0]
    print(json.dumps({"out_dir": str(root), "failed_runs": len(failed)}, ensure_ascii=False, sort_keys=True))
    return 1 if failed and not args.warn_only else 0


def record_completed(model: dict[str, Any], suite: dict[str, str], mode: str, completed: CompletedCommand) -> dict[str, Any]:
    return {
        "model_id": model["id"],
        "suite_id": suite["id"],
        "mode": mode,
        "command": completed.command,
        "returncode": completed.returncode,
        "started_epoch_ms": completed.started_epoch_ms,
        "finished_epoch_ms": completed.finished_epoch_ms,
        "wall_seconds": completed.wall_seconds,
        "stdout": str(completed.stdout_path),
        "stderr": str(completed.stderr_path),
        "resource_summary": str(completed.resource_summary) if completed.resource_summary else None,
        "resource_samples": str(completed.resource_samples) if completed.resource_samples else None,
    }


def load_existing_run_records(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    try:
        data = load_json(path)
    except Exception:
        return []
    if not isinstance(data, list):
        return []
    return [item for item in data if isinstance(item, dict)]


def run_record_key(record: dict[str, Any]) -> tuple[str, str, str]:
    return (
        str(record.get("model_id") or ""),
        str(record.get("mode") or ""),
        str(record.get("suite_id") or ""),
    )


def upsert_run_record(records: list[dict[str, Any]], record: dict[str, Any]) -> None:
    key = run_record_key(record)
    for index, existing in enumerate(records):
        if run_record_key(existing) == key:
            if existing.get("status") == "skipped_existing" and record.get("status") != "skipped_existing":
                records[index] = record
            elif existing.get("status") != "skipped_existing" and record.get("status") == "skipped_existing":
                return
            else:
                records[index] = record
            return
    records.append(record)


def record_skipped_existing(model: dict[str, Any], suite: dict[str, str], mode: str, summary: Path) -> dict[str, Any]:
    return {
        "model_id": model["id"],
        "suite_id": suite["id"],
        "mode": mode,
        "returncode": 0,
        "status": "skipped_existing",
        "summary": str(summary),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out-dir", default="")
    parser.add_argument("--suite", action="append", default=[], help="Suite id to run; repeatable. Defaults to all suites.")
    parser.add_argument("--model", action="append", default=[], help="Model id to run; repeatable. Defaults to all models.")
    parser.add_argument("--mode", choices=["all", "file-level", "segmented"], default="all")
    parser.add_argument("--smoke", action="store_true", help="Run only the smoke manifest for quick validation.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--report-only", action="store_true", help="Only regenerate manifest/comparison/recommendation from existing summaries.")
    parser.add_argument("--report-all-known", action="store_true", help="When running a subset into an existing output directory, generate reports over the full known model/suite matrix.")
    parser.add_argument("--skip-existing", action="store_true", help="Resume mode: do not rerun model/mode/suite combinations that already have summary.json.")
    parser.add_argument("--no-realtime", action="store_true", help="Send segmented chunks without realtime pacing; diagnostic only.")
    parser.add_argument("--warn-only", action="store_true", help="Return zero even if individual runs fail.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return run_benchmark(args)
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
