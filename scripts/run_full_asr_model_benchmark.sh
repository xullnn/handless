#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

PYTHON_BIN="${PYTHON_BIN:-.venv-mimo/bin/python}"
DRY_RUN="${DRY_RUN:-0}"
SMOKE="${SMOKE:-0}"
MODE="${MODE:-all}"
OUT_DIR="${OUT_DIR:-}"
WARN_ONLY="${WARN_ONLY:-0}"
NO_REALTIME="${NO_REALTIME:-0}"
SKIP_EXISTING="${SKIP_EXISTING:-0}"
REPORT_ONLY="${REPORT_ONLY:-0}"
REPORT_ALL_KNOWN="${REPORT_ALL_KNOWN:-0}"

ARGS=(
  eval/asr_streaming/full_asr_model_benchmark.py
  --mode "$MODE"
)

if [ -n "$OUT_DIR" ]; then
  ARGS+=(--out-dir "$OUT_DIR")
fi
if [ "$DRY_RUN" = "1" ]; then
  ARGS+=(--dry-run)
fi
if [ "$SMOKE" = "1" ]; then
  ARGS+=(--smoke)
fi
if [ "$WARN_ONLY" = "1" ]; then
  ARGS+=(--warn-only)
fi
if [ "$NO_REALTIME" = "1" ]; then
  ARGS+=(--no-realtime)
fi
if [ "$SKIP_EXISTING" = "1" ]; then
  ARGS+=(--skip-existing)
fi
if [ "$REPORT_ONLY" = "1" ]; then
  ARGS+=(--report-only)
fi
if [ "$REPORT_ALL_KNOWN" = "1" ]; then
  ARGS+=(--report-all-known)
fi

if [ -n "${MODEL:-}" ]; then
  # Comma-separated model ids.
  IFS=',' read -r -a MODEL_IDS <<< "$MODEL"
  for model_id in "${MODEL_IDS[@]}"; do
    if [ -n "$model_id" ]; then
      ARGS+=(--model "$model_id")
    fi
  done
fi

if [ -n "${SUITE:-}" ]; then
  # Comma-separated suite ids.
  IFS=',' read -r -a SUITE_IDS <<< "$SUITE"
  for suite_id in "${SUITE_IDS[@]}"; do
    if [ -n "$suite_id" ]; then
      ARGS+=(--suite "$suite_id")
    fi
  done
fi

exec "$PYTHON_BIN" "${ARGS[@]}"
