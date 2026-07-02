# Validation - Retire Qwen3 Cumulative Recompute Runtime Route

## Completion rule

This feature can be marked `passes=true` only after all required checks pass and validation evidence is recorded in `specs/progress.md`.

## Acceptance criteria

- A1: `qwen3_mlx_segmented_cache_service.py self-test` passes without importing deleted cumulative modules.
- A2: Active validation no longer compiles or self-tests cumulative Qwen3 service/probe modules.
- A3: Active scripts no longer start `qwen3_mlx_http_service.py` or `qwen3_mlx_cumulative_service.py`.
- A4: Default config/docs/status point to the segmented route.
- A5: Swift build and unit tests pass.
- A6: Historical cumulative specs/results remain available as evidence.

## Automated checks

```bash
bash eval/asr_streaming/validate.sh
DRY_RUN=1 bash scripts/run_qwen3_mlx_segmented_app_smoke.sh
DRY_RUN=1 bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
swift build
swift test
python3 -m json.tool specs/2026-07-01-retire-qwen3-cumulative-route/feature.json >/dev/null
python3 -m json.tool specs/feature_matrix.json >/dev/null
git diff --check
```

## Manual smoke checks

- After a separate runtime switch/restart, use the App with the segmented service and confirm short dictation and long-draft dictation still produce final text. This is recommended but not required for this code cleanup because it does not change Swift session/output logic.

## Optional / not-applicable checks

- Full real-model segmented regression is not required here because it already passed in `2026-07-01-qwen3-segmented-regression-suite`; this feature changes active route cleanup and shared imports.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Files removed or retained by design.
- Any skipped manual checks with rationale.
