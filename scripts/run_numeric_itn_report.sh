#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CASES="${CASES:-eval/asr_streaming/cases.numeric.local.jsonl}"
BASE_SUMMARY="${BASE_SUMMARY:-eval/asr_streaming/results/full-asr-model-benchmark-20260702-004029/segmented/qwen3-asr-0.6b-mlx-8bit/numeric/summary.json}"
OUT_DIR="${OUT_DIR:-eval/asr_streaming/results/simple-numeric-itn-report-$(date +%Y%m%d-%H%M%S)}"
SWIFTC_BIN="${SWIFTC_BIN:-swiftc}"
TOOL_BIN="${TOOL_BIN:-.build/numeric-itn-tools/apply_numeric_itn_to_summary}"

mkdir -p "$OUT_DIR" "$(dirname "$TOOL_BIN")"

"$SWIFTC_BIN" \
  Sources/LocalVoiceInputCore/NumericITN.swift \
  eval/asr_streaming/apply_numeric_itn_to_summary.swift \
  -o "$TOOL_BIN"

"$TOOL_BIN" \
  --summary "$BASE_SUMMARY" \
  --out "$OUT_DIR/itn_summary.json" \
  > "$OUT_DIR/itn_summary.stdout.json"

python3 eval/asr_streaming/analyze_numeric_format_results.py \
  --cases "$CASES" \
  --summary "$BASE_SUMMARY" \
  --out "$OUT_DIR/raw_numeric_format_analysis.json" \
  > "$OUT_DIR/raw_numeric_format_analysis.stdout.json"

python3 eval/asr_streaming/analyze_numeric_format_results.py \
  --cases "$CASES" \
  --summary "$OUT_DIR/itn_summary.json" \
  --out "$OUT_DIR/itn_numeric_format_analysis.json" \
  > "$OUT_DIR/itn_numeric_format_analysis.stdout.json"

python3 eval/asr_streaming/numeric_itn_report.py \
  --raw-analysis "$OUT_DIR/raw_numeric_format_analysis.json" \
  --itn-analysis "$OUT_DIR/itn_numeric_format_analysis.json" \
  --out-json "$OUT_DIR/comparison.json" \
  --out-md "$OUT_DIR/comparison.md" \
  > "$OUT_DIR/comparison.stdout.json"

echo "Wrote $OUT_DIR"
echo "$OUT_DIR/comparison.md"
