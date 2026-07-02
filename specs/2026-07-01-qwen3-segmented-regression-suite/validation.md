# Validation - Qwen3-ASR Segmented Route Regression Suite

## Completion Rule

This feature can be marked `passes=true` only after the automated checks run, result directories are recorded, and the recommendation is written in `specs/progress.md`.

## Automated Checks

```bash
bash -n scripts/run_qwen3_mlx_segmented_regression_gate.sh
python3 -m py_compile eval/asr_streaming/analyze_numeric_format_results.py eval/asr_streaming/compare_asr_summaries.py eval/asr_streaming/qwen3_mlx_segmented_cache_service.py
python3 eval/asr_streaming/qwen3_mlx_segmented_cache_service.py self-test
DRY_RUN=1 bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-01-qwen3-segmented-regression-suite/feature.json >/dev/null
git diff --check
```

## Required Segmented Runs

Numeric prompt suite:

```bash
CASES=eval/asr_streaming/cases.numeric.local.jsonl \
SYSTEM_PROMPT_FILE=configs/asr/qwen3_system_prompt.numeric_style.zh.txt \
OUT_DIR=eval/asr_streaming/results/segmented-numeric-prompt-v1-$(date +%Y%m%d-%H%M%S) \
bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
```

Numeric format analysis:

```bash
python3 eval/asr_streaming/analyze_numeric_format_results.py \
  --cases eval/asr_streaming/cases.numeric.local.jsonl \
  --summary <numeric-out-dir>/summary.json \
  --out <numeric-out-dir>/numeric_format_analysis.json
```

Base prompt suite:

```bash
CASES=eval/asr_streaming/cases.local.jsonl \
SYSTEM_PROMPT_FILE=configs/asr/qwen3_system_prompt.numeric_style.zh.txt \
OUT_DIR=eval/asr_streaming/results/segmented-base-prompt-v1-$(date +%Y%m%d-%H%M%S) \
bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
```

Base comparison:

```bash
python3 eval/asr_streaming/compare_asr_summaries.py \
  --baseline eval/asr_streaming/results/base-regression-prompt-v2-http-20260630-224848/summary.json \
  --candidate <base-out-dir>/summary.json \
  --out <base-out-dir>/comparison_vs_cumulative_prompt.json
```

## Acceptance Criteria

- A1: Runner starts the segmented service and does not use `qwen3_mlx_http_service.py`.
- A2: Both suites produce `summary.json`, per-case `events.jsonl`, `service.log`, `resource_summary.json`, and `run_metadata.json`.
- A3: Numeric analysis reports pass/fail counts and failed case details.
- A4: Base comparison reports aggregate and per-case deltas.
- A5: No accepted output after cancel, no partial after final, and no accepted stale events appear in required runs.
- A6: Any CER/WER/coverage regression is listed with case IDs and final texts.
- A7: The final recommendation states whether segmented route should replace cumulative route, needs tuning, or remains experimental.

## Manual Checks

- Manual App smoke is not required for this feature because the user has already reported successful Codex auto-paste on the segmented route during daily use. That observation should be recorded as context, not as automated evidence.
- A later runtime-promotion feature must still repeat manual App smoke before switching defaults.

## Evidence Required In `specs/progress.md`

- Commands run.
- Result directories.
- Numeric format pass/fail count.
- Base aggregate metrics.
- Comparison summary.
- Recommendation and remaining blockers.
