# Plan - Qwen3-ASR Segmented Route Regression Suite

## Implementation

1. Add `scripts/run_qwen3_mlx_segmented_regression_gate.sh`.
2. Add `eval/asr_streaming/analyze_numeric_format_results.py`.
3. Add `eval/asr_streaming/compare_asr_summaries.py`.
4. Register this feature in `specs/feature_matrix.json`.

## Validation Run Order

1. Static checks:
   - shell syntax;
   - Python compile;
   - JSON validation;
   - segmented service self-test.
2. Dry-run the segmented regression runner.
3. Run numeric-format suite on segmented route with the current system prompt.
4. Analyze numeric `must_include` / `must_not_include` constraints.
5. Run base suite on segmented route with the current system prompt.
6. Compare base suite against the latest cumulative prompt reference.
7. Compare numeric suite against the latest cumulative prompt reference where useful.
8. Record results and recommendation in `specs/progress.md`.

## Initial References

- Numeric cumulative reference: `eval/asr_streaming/results/numeric-prompt-v3-http-integrity-20260630-223057/summary.json`
- Base cumulative prompt reference: `eval/asr_streaming/results/base-regression-prompt-v2-http-20260630-224848/summary.json`
- Base cumulative no-prompt reference: `eval/asr_streaming/results/base-regression-no-prompt-http-20260630-224639/summary.json`

## Interpretation Rules

- CER means character error rate. Lower is better.
- WER means word/token error rate. Lower is better.
- RTF means real-time factor: processing time divided by audio duration. Lower is better; below 1 means faster than realtime.
- Final coverage ratio compares final output length to expected text length. Very low values suggest missing text.
- Numeric-format pass is separate from CER/WER because a transcript can be phonetically correct while still using the wrong numeric style.
- Realtime-paced replay is the product-facing evidence. `NO_REALTIME=1` is only a speed/parity diagnostic mode.

## Rollout Decision

- If segmented numeric and base results are acceptable, keep cumulative recompute as rollback/reference and move runtime supervision toward the segmented service.
- If segmented route regresses only on segment-boundary artifacts, tune segment policy before changing defaults.
- If segmented route regresses broadly on final accuracy, keep cumulative route active while investigating merge/dedup and finalization strategy.
