#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PYTHON_BIN="${PYTHON_BIN:-.venv-mimo/bin/python}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-18113}"
MODEL_ID="${MODEL_ID:-qwen3-asr-0.6b-mlx-8bit}"
MODEL="${MODEL:-.external/models/mlx-community__Qwen3-ASR-0.6B-8bit}"
MLX_AUDIO_SOURCE="${MLX_AUDIO_SOURCE:-.external/repos/mlx-audio}"
CASES="${CASES:-eval/asr_streaming/cases.local.jsonl}"
OUT_DIR="${OUT_DIR:-eval/asr_streaming/results/qwen3-mlx-segmented-regression-$(date +%Y%m%d-%H%M%S)}"
LANGUAGE="${LANGUAGE:-Chinese}"
CHUNK_MS="${CHUNK_MS:-96}"
REQUEST_TIMEOUT_SEC="${REQUEST_TIMEOUT_SEC:-240}"
MAX_FIRST_PARTIAL_MS="${MAX_FIRST_PARTIAL_MS:-999999}"
MAX_FINAL_LATENCY_MS="${MAX_FINAL_LATENCY_MS:-999999}"
MIN_FINAL_COVERAGE_RATIO="${MIN_FINAL_COVERAGE_RATIO:-0.35}"
MAX_RTF="${MAX_RTF:-999999}"
WARN_ONLY="${WARN_ONLY:-1}"
NO_REALTIME="${NO_REALTIME:-0}"
RESOURCE_INTERVAL_SEC="${RESOURCE_INTERVAL_SEC:-1.0}"
SYSTEM_PROMPT="${SYSTEM_PROMPT:-}"
SYSTEM_PROMPT_FILE="${SYSTEM_PROMPT_FILE:-}"
MAX_SEGMENT_SEC="${MAX_SEGMENT_SEC:-30}"
MIN_SEGMENT_SEC="${MIN_SEGMENT_SEC:-5}"
SOFT_TEXT_CHARS="${SOFT_TEXT_CHARS:-150}"
PARTIAL_STEP_SEC="${PARTIAL_STEP_SEC:-1.0}"
MAX_PARTIALS_PER_SEGMENT="${MAX_PARTIALS_PER_SEGMENT:-8}"
DRY_RUN="${DRY_RUN:-0}"
export SYSTEM_PROMPT SYSTEM_PROMPT_FILE

SERVICE_PID=""
MONITOR_PID=""
GATE_EXIT=99

SERVICE_URL="http://$HOST:$PORT"
SERVICE_LOG="$OUT_DIR/service.log"
RESOURCE_SAMPLES="$OUT_DIR/resource_samples.jsonl"
RESOURCE_SUMMARY="$OUT_DIR/resource_summary.json"
RESOURCE_MONITOR_LOG="$OUT_DIR/resource_monitor.log"
RUN_METADATA="$OUT_DIR/run_metadata.json"
SPOOL_DIR="${SPOOL_DIR:-$OUT_DIR/spool}"
GATE_SUMMARY="$OUT_DIR/summary.json"

SERVICE_ARGS=(
  eval/asr_streaming/qwen3_mlx_segmented_cache_service.py
  serve
  --host "$HOST"
  --port "$PORT"
  --model-id "$MODEL_ID"
  --model "$MODEL"
  --mlx-audio-source "$MLX_AUDIO_SOURCE"
  --language "$LANGUAGE"
  --max-segment-sec "$MAX_SEGMENT_SEC"
  --min-segment-sec "$MIN_SEGMENT_SEC"
  --soft-text-chars "$SOFT_TEXT_CHARS"
  --partial-step-sec "$PARTIAL_STEP_SEC"
  --max-partials-per-segment "$MAX_PARTIALS_PER_SEGMENT"
  --spool-dir "$SPOOL_DIR"
)
if [ -n "$SYSTEM_PROMPT" ]; then
  SERVICE_ARGS+=(--system-prompt "$SYSTEM_PROMPT")
fi
if [ -n "$SYSTEM_PROMPT_FILE" ]; then
  SERVICE_ARGS+=(--system-prompt-file "$SYSTEM_PROMPT_FILE")
fi

GATE_ARGS=(
  eval/asr_streaming/incremental_ux_gate.py
  run
  --adapter http-json
  --service-url "$SERVICE_URL"
  --request-timeout-sec "$REQUEST_TIMEOUT_SEC"
  --model-id "$MODEL_ID"
  --cases "$CASES"
  --out-dir "$OUT_DIR"
  --chunk-ms "$CHUNK_MS"
  --max-first-partial-ms "$MAX_FIRST_PARTIAL_MS"
  --max-final-latency-ms "$MAX_FINAL_LATENCY_MS"
  --min-final-coverage-ratio "$MIN_FINAL_COVERAGE_RATIO"
  --max-rtf "$MAX_RTF"
)
if [ "$WARN_ONLY" = "1" ]; then
  GATE_ARGS+=(--warn-only)
fi
if [ "$NO_REALTIME" = "1" ]; then
  GATE_ARGS+=(--no-realtime)
fi

runtime_status_json() {
  python3 - "$PYTHON_BIN" "$MODEL" "$MLX_AUDIO_SOURCE" "$CASES" "$SYSTEM_PROMPT_FILE" <<'PY'
import json
import os
import sys
from pathlib import Path

python_bin, model, mlx_audio, cases, prompt_file = sys.argv[1:]
status = {
    "python_bin": python_bin,
    "python_bin_executable": os.access(python_bin, os.X_OK),
    "model": model,
    "model_exists": Path(model).is_dir(),
    "mlx_audio_source": mlx_audio,
    "mlx_audio_source_exists": Path(mlx_audio).is_dir(),
    "cases": cases,
    "cases_exists": Path(cases).is_file(),
    "system_prompt_file": prompt_file,
    "system_prompt_file_exists": (not prompt_file) or Path(prompt_file).is_file(),
}
print(json.dumps(status, ensure_ascii=False, sort_keys=True))
PY
}

require_runtime_paths() {
  if [ ! -x "$PYTHON_BIN" ]; then
    echo "Missing Python runtime: $PYTHON_BIN" >&2
    echo "Run: bash scripts/setup_qwen3_mlx_runtime.sh" >&2
    exit 2
  fi
  if [ ! -d "$MODEL" ]; then
    echo "Missing Qwen3 MLX model directory: $MODEL" >&2
    exit 2
  fi
  if [ ! -d "$MLX_AUDIO_SOURCE" ]; then
    echo "Missing mlx-audio source directory: $MLX_AUDIO_SOURCE" >&2
    exit 2
  fi
  if [ ! -f "$CASES" ]; then
    echo "Missing cases file: $CASES" >&2
    exit 2
  fi
  if [ -n "$SYSTEM_PROMPT_FILE" ] && [ ! -f "$SYSTEM_PROMPT_FILE" ]; then
    echo "Missing system prompt file: $SYSTEM_PROMPT_FILE" >&2
    exit 2
  fi
}

cleanup() {
  if [ -n "${MONITOR_PID:-}" ] && kill -0 "$MONITOR_PID" >/dev/null 2>&1; then
    kill -TERM "$MONITOR_PID" >/dev/null 2>&1 || true
    wait "$MONITOR_PID" >/dev/null 2>&1 || true
  fi
  if [ -n "${SERVICE_PID:-}" ] && kill -0 "$SERVICE_PID" >/dev/null 2>&1; then
    kill "$SERVICE_PID" >/dev/null 2>&1 || true
    wait "$SERVICE_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

mkdir -p "$OUT_DIR"

if [ "$DRY_RUN" = "1" ]; then
  echo "Qwen3 segmented regression gate dry run"
  echo "runtime_status=$(runtime_status_json)"
  printf 'service_cmd='
  printf '%q ' env "PYTHONPATH=$MLX_AUDIO_SOURCE\${PYTHONPATH:+:\$PYTHONPATH}" "$PYTHON_BIN" "${SERVICE_ARGS[@]}"
  printf '\n'
  printf 'gate_cmd='
  printf '%q ' python3 "${GATE_ARGS[@]}"
  printf '\n'
  echo "service_url=$SERVICE_URL"
  echo "out_dir=$OUT_DIR"
  echo "spool_dir=$SPOOL_DIR"
  echo "warn_only=$WARN_ONLY"
  echo "no_realtime=$NO_REALTIME"
  exit 0
fi

require_runtime_paths

RUN_STARTED_EPOCH_MS="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

PYTHONPATH="$MLX_AUDIO_SOURCE${PYTHONPATH:+:$PYTHONPATH}" "$PYTHON_BIN" "${SERVICE_ARGS[@]}" \
  >"$SERVICE_LOG" 2>&1 &
SERVICE_PID=$!

python3 eval/asr_streaming/monitor_pid_resources.py \
  --pid "$SERVICE_PID" \
  --samples "$RESOURCE_SAMPLES" \
  --summary "$RESOURCE_SUMMARY" \
  --interval-sec "$RESOURCE_INTERVAL_SEC" \
  --label "qwen3_mlx_segmented_cache_service" \
  >"$RESOURCE_MONITOR_LOG" 2>&1 &
MONITOR_PID=$!

python3 - "$SERVICE_URL" "$SERVICE_LOG" <<'PY'
import json
import sys
import time
import urllib.request
from pathlib import Path

url = sys.argv[1].rstrip("/") + "/health"
log_path = Path(sys.argv[2])
deadline = time.time() + 180
last_error = ""
while time.time() < deadline:
    try:
        with urllib.request.urlopen(url, timeout=2) as response:
            payload = json.loads(response.read().decode("utf-8"))
        if payload.get("ok"):
            print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
            raise SystemExit(0)
    except Exception as exc:
        last_error = str(exc)
        if log_path.exists():
            text = log_path.read_text(encoding="utf-8", errors="replace")
            if "Traceback" in text:
                print(text[-4000:], file=sys.stderr)
                raise SystemExit(1)
    time.sleep(1)
print(f"service did not become healthy: {last_error}", file=sys.stderr)
if log_path.exists():
    print(log_path.read_text(encoding="utf-8", errors="replace")[-4000:], file=sys.stderr)
raise SystemExit(1)
PY

set +e
python3 "${GATE_ARGS[@]}"
GATE_EXIT=$?
set -e

if [ -n "${MONITOR_PID:-}" ] && kill -0 "$MONITOR_PID" >/dev/null 2>&1; then
  kill -TERM "$MONITOR_PID" >/dev/null 2>&1 || true
  wait "$MONITOR_PID" >/dev/null 2>&1 || true
fi

if [ -n "${SERVICE_PID:-}" ] && kill -0 "$SERVICE_PID" >/dev/null 2>&1; then
  kill "$SERVICE_PID" >/dev/null 2>&1 || true
  wait "$SERVICE_PID" >/dev/null 2>&1 || true
fi

RUN_FINISHED_EPOCH_MS="$(python3 - <<'PY'
import time
print(int(time.time() * 1000))
PY
)"

python3 - "$RUN_METADATA" <<PY
import json
import os
import sys
from pathlib import Path

metadata = {
    "schema_version": "1.0",
    "runner": "run_qwen3_mlx_segmented_regression_gate.sh",
    "started_epoch_ms": int("$RUN_STARTED_EPOCH_MS"),
    "finished_epoch_ms": int("$RUN_FINISHED_EPOCH_MS"),
    "duration_seconds": (int("$RUN_FINISHED_EPOCH_MS") - int("$RUN_STARTED_EPOCH_MS")) / 1000.0,
    "gate_exit_code": int("$GATE_EXIT"),
    "service_pid": int("$SERVICE_PID"),
    "service_url": "$SERVICE_URL",
    "model_id": "$MODEL_ID",
    "model": "$MODEL",
    "mlx_audio_source": "$MLX_AUDIO_SOURCE",
    "cases": "$CASES",
    "out_dir": "$OUT_DIR",
    "system_prompt_enabled": bool(os.environ.get("SYSTEM_PROMPT", "") or os.environ.get("SYSTEM_PROMPT_FILE", "")),
    "system_prompt_file": os.environ.get("SYSTEM_PROMPT_FILE", ""),
    "chunk_ms": int("$CHUNK_MS"),
    "request_timeout_sec": float("$REQUEST_TIMEOUT_SEC"),
    "warn_only": "$WARN_ONLY" == "1",
    "input_realtime_pacing": "$NO_REALTIME" != "1",
    "segment_policy": {
        "max_segment_sec": float("$MAX_SEGMENT_SEC"),
        "min_segment_sec": float("$MIN_SEGMENT_SEC"),
        "soft_text_chars": int("$SOFT_TEXT_CHARS"),
        "partial_step_sec": float("$PARTIAL_STEP_SEC"),
        "max_partials_per_segment": int("$MAX_PARTIALS_PER_SEGMENT"),
    },
    "paths": {
        "gate_summary": "$GATE_SUMMARY",
        "resource_samples": "$RESOURCE_SAMPLES",
        "resource_summary": "$RESOURCE_SUMMARY",
        "service_log": "$SERVICE_LOG",
        "resource_monitor_log": "$RESOURCE_MONITOR_LOG",
        "spool_dir": "$SPOOL_DIR",
    },
}
path = Path(sys.argv[1])
path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
print(json.dumps(metadata, ensure_ascii=False, sort_keys=True))
PY

echo "Qwen3 segmented regression gate wrote: $OUT_DIR"
exit "$GATE_EXIT"
