# Decisions - Qwen3 0.6B Prompt A/B Benchmark

## Confirmed Decisions

- D1: Test only `qwen3-asr-0.6b-mlx-8bit`; do not include 1.7B or MiMo in this A/B.
- D2: Use segmented simulated-realtime results because this is the current product path for user-facing Qwen3 experiments.
- D3: Use numeric 37 cases as the primary suite and base 10 cases as the regression guard.
- D4: Numeric-format pass rate is the primary numeric-suite metric; CER/WER on numeric cases are secondary because references are spoken-form text.
- D5: This feature is evaluation-only and must not enable the prompt by default.
- D6: The current numeric-style prompt should not be enabled by default. It improves numeric pass rate from `21.6%` to `35.1%`, but absolute pass rate remains low and first partial latency increases materially.
- D7: The prompt evidence should feed a future local numeric ITN/post-processing feature rather than becoming the product default.

## Open Questions / Unresolved Choices

- O1: Whether to create a separate numeric ITN/post-processing feature after this A/B result.
- O2: Whether a revised prompt should be tested later after reducing latency and prompt leakage/over-formatting risk.

## PMB Promotion Candidates

- P1: If validated, promote the durable lesson that the current numeric prompt improves some cases but is not default-ready.
