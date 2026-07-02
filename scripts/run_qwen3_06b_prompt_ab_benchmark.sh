#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

OUT_DIR="${OUT_DIR:-eval/asr_streaming/results/qwen3-06b-prompt-ab-$(date +%Y%m%d-%H%M%S)}"
PROMPT_FILE="${PROMPT_FILE:-configs/asr/qwen3_system_prompt.numeric_style.zh.txt}"
PYTHON_BIN="${PYTHON_BIN:-.venv-mimo/bin/python}"
RUN_FRESH="${RUN_FRESH:-0}"
DRY_RUN="${DRY_RUN:-0}"

NO_PROMPT_NUMERIC_SUMMARY="${NO_PROMPT_NUMERIC_SUMMARY:-eval/asr_streaming/results/full-asr-model-benchmark-20260702-004029/segmented/qwen3-asr-0.6b-mlx-8bit/numeric/summary.json}"
NO_PROMPT_BASE_SUMMARY="${NO_PROMPT_BASE_SUMMARY:-eval/asr_streaming/results/full-asr-model-benchmark-20260702-004029/segmented/qwen3-asr-0.6b-mlx-8bit/base/summary.json}"
PROMPT_NUMERIC_SUMMARY="${PROMPT_NUMERIC_SUMMARY:-eval/asr_streaming/results/segmented-numeric-prompt-v1-20260701-230142/summary.json}"
PROMPT_BASE_SUMMARY="${PROMPT_BASE_SUMMARY:-eval/asr_streaming/results/segmented-base-prompt-v1-20260701-230709/summary.json}"

mkdir -p "$OUT_DIR"

if [ "$DRY_RUN" = "1" ]; then
  echo "Qwen3 0.6B prompt A/B dry run"
  echo "out_dir=$OUT_DIR"
  echo "prompt_file=$PROMPT_FILE"
  echo "run_fresh=$RUN_FRESH"
  echo "no_prompt_numeric_summary=$NO_PROMPT_NUMERIC_SUMMARY"
  echo "prompt_numeric_summary=$PROMPT_NUMERIC_SUMMARY"
  echo "no_prompt_base_summary=$NO_PROMPT_BASE_SUMMARY"
  echo "prompt_base_summary=$PROMPT_BASE_SUMMARY"
  exit 0
fi

if [ ! -f "$PROMPT_FILE" ]; then
  echo "Missing prompt file: $PROMPT_FILE" >&2
  exit 2
fi

if [ "$RUN_FRESH" = "1" ]; then
  NO_PROMPT_NUMERIC_DIR="$OUT_DIR/no_prompt/numeric"
  PROMPT_NUMERIC_DIR="$OUT_DIR/prompt/numeric"
  NO_PROMPT_BASE_DIR="$OUT_DIR/no_prompt/base"
  PROMPT_BASE_DIR="$OUT_DIR/prompt/base"

  PORT=18131 CASES=eval/asr_streaming/cases.numeric.local.jsonl OUT_DIR="$NO_PROMPT_NUMERIC_DIR" \
    PYTHON_BIN="$PYTHON_BIN" bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
  PORT=18132 CASES=eval/asr_streaming/cases.numeric.local.jsonl OUT_DIR="$PROMPT_NUMERIC_DIR" \
    PYTHON_BIN="$PYTHON_BIN" SYSTEM_PROMPT_FILE="$PROMPT_FILE" bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
  PORT=18133 CASES=eval/asr_streaming/cases.local.jsonl OUT_DIR="$NO_PROMPT_BASE_DIR" \
    PYTHON_BIN="$PYTHON_BIN" bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
  PORT=18134 CASES=eval/asr_streaming/cases.local.jsonl OUT_DIR="$PROMPT_BASE_DIR" \
    PYTHON_BIN="$PYTHON_BIN" SYSTEM_PROMPT_FILE="$PROMPT_FILE" bash scripts/run_qwen3_mlx_segmented_regression_gate.sh

  NO_PROMPT_NUMERIC_SUMMARY="$NO_PROMPT_NUMERIC_DIR/summary.json"
  PROMPT_NUMERIC_SUMMARY="$PROMPT_NUMERIC_DIR/summary.json"
  NO_PROMPT_BASE_SUMMARY="$NO_PROMPT_BASE_DIR/summary.json"
  PROMPT_BASE_SUMMARY="$PROMPT_BASE_DIR/summary.json"
fi

for path in "$NO_PROMPT_NUMERIC_SUMMARY" "$PROMPT_NUMERIC_SUMMARY" "$NO_PROMPT_BASE_SUMMARY" "$PROMPT_BASE_SUMMARY"; do
  if [ ! -f "$path" ]; then
    echo "Missing summary: $path" >&2
    exit 2
  fi
done

NO_PROMPT_NUMERIC_ANALYSIS="$OUT_DIR/no_prompt_numeric_format_analysis.json"
PROMPT_NUMERIC_ANALYSIS="$OUT_DIR/prompt_numeric_format_analysis.json"
NUMERIC_COMPARISON="$OUT_DIR/numeric_prompt_vs_no_prompt_comparison.json"
BASE_COMPARISON="$OUT_DIR/base_prompt_vs_no_prompt_comparison.json"

python3 eval/asr_streaming/analyze_numeric_format_results.py \
  --cases eval/asr_streaming/cases.numeric.local.jsonl \
  --summary "$NO_PROMPT_NUMERIC_SUMMARY" \
  --out "$NO_PROMPT_NUMERIC_ANALYSIS" >/dev/null
python3 eval/asr_streaming/analyze_numeric_format_results.py \
  --cases eval/asr_streaming/cases.numeric.local.jsonl \
  --summary "$PROMPT_NUMERIC_SUMMARY" \
  --out "$PROMPT_NUMERIC_ANALYSIS" >/dev/null

python3 eval/asr_streaming/compare_asr_summaries.py \
  --baseline "$NO_PROMPT_NUMERIC_SUMMARY" \
  --candidate "$PROMPT_NUMERIC_SUMMARY" \
  --out "$NUMERIC_COMPARISON" >/dev/null
python3 eval/asr_streaming/compare_asr_summaries.py \
  --baseline "$NO_PROMPT_BASE_SUMMARY" \
  --candidate "$PROMPT_BASE_SUMMARY" \
  --out "$BASE_COMPARISON" >/dev/null

python3 eval/asr_streaming/qwen3_prompt_ab_report.py \
  --out-dir "$OUT_DIR" \
  --prompt-file "$PROMPT_FILE" \
  --no-prompt-numeric-summary "$NO_PROMPT_NUMERIC_SUMMARY" \
  --prompt-numeric-summary "$PROMPT_NUMERIC_SUMMARY" \
  --no-prompt-base-summary "$NO_PROMPT_BASE_SUMMARY" \
  --prompt-base-summary "$PROMPT_BASE_SUMMARY" \
  --no-prompt-numeric-analysis "$NO_PROMPT_NUMERIC_ANALYSIS" \
  --prompt-numeric-analysis "$PROMPT_NUMERIC_ANALYSIS" \
  --numeric-comparison "$NUMERIC_COMPARISON" \
  --base-comparison "$BASE_COMPARISON" >/dev/null

echo "Qwen3 0.6B prompt A/B report: $OUT_DIR"
