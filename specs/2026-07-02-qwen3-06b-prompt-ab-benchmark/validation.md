# Validation - Qwen3 0.6B Prompt A/B Benchmark

## Completion Rule

This feature can be marked `passes=true` only after the A/B report is generated, validation commands pass, and concrete evidence is recorded in `specs/progress.md`.

## Acceptance Criteria

- A1: The report compares only `qwen3-asr-0.6b-mlx-8bit`.
- A2: The report compares no-prompt vs `configs/asr/qwen3_system_prompt.numeric_style.zh.txt`.
- A3: Numeric suite coverage is `37` cases.
- A4: Base suite regression guard coverage is `10` cases.
- A5: Numeric-format pass rate, improved cases, and worsened cases are reported.
- A6: Base-suite CER/WER/coverage/first-partial latency comparison is reported.
- A7: The recommendation states whether to enable the prompt by default.
- A8: The report explains the spoken-reference CER/WER caveat for numeric cases.
- A9: No Swift App runtime behavior is modified by this feature.

## Automated Checks

```bash
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-02-qwen3-06b-prompt-ab-benchmark/feature.json >/dev/null
bash -n scripts/run_qwen3_06b_prompt_ab_benchmark.sh
python3 -m py_compile eval/asr_streaming/qwen3_prompt_ab_report.py eval/asr_streaming/analyze_numeric_format_results.py eval/asr_streaming/compare_asr_summaries.py
DRY_RUN=1 bash scripts/run_qwen3_06b_prompt_ab_benchmark.sh
bash scripts/run_qwen3_06b_prompt_ab_benchmark.sh
```

## Result Validation

```bash
python3 -m json.tool eval/asr_streaming/results/<prompt-ab-run>/comparison.json >/dev/null
test -s eval/asr_streaming/results/<prompt-ab-run>/comparison.md
test -s eval/asr_streaming/results/<prompt-ab-run>/recommendation.md
git diff --check
```

## Optional / Not Applicable Checks

- `RUN_FRESH=1 bash scripts/run_qwen3_06b_prompt_ab_benchmark.sh` is optional for this closeout because existing prompt and no-prompt segmented summaries already cover the same 0.6B model and target suites.
- Manual macOS App smoke is not required because this feature is evaluation-only and does not change App runtime defaults.

## Evidence Required In `specs/progress.md`

- Commands run.
- Output directory.
- Source summary paths.
- Numeric pass-rate delta.
- Base regression-guard result.
- Recommendation.
