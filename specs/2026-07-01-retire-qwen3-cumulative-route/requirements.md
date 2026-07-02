# Requirements - Retire Qwen3 Cumulative Recompute Runtime Route

## Problem

The project previously used a Qwen3-ASR MLX cumulative-recompute wrapper as the local HTTP ASR route. Real daily use and segmented regression results now show that this route is structurally worse for long dictation: it repeatedly recognizes growing audio prefixes, gets slower as speech grows, and did not reliably solve Arabic-number formatting even with a system prompt.

The active code and configuration should therefore stop presenting cumulative recompute as a usable runtime route. Historical specs and validation artifacts should remain as evidence, but runtime scripts, defaults, and current PMB guidance should converge on the segmented route.

## Scope

### IN

- Remove active cumulative Qwen3 service/probe code from `eval/asr_streaming/`.
- Remove active shell scripts that start or benchmark the cumulative HTTP service.
- Refactor the segmented service so it no longer imports cumulative-service or cumulative-probe modules.
- Update default local HTTP URL/configuration to the segmented service port.
- Update status and validation scripts to check the segmented service.
- Update README/current docs so users are directed to segmented Qwen3 service commands only.
- Update PMB durable guidance after validation so cumulative recompute is recorded as retired historical evidence, not current direction.

### OUT

- Do not delete historical SDD feature folders or validation evidence for cumulative experiments.
- Do not delete historical result directories solely because they mention cumulative recompute.
- Do not remove the generic Swift `LocalHTTPASRClient`; the App still uses local HTTP for the segmented Qwen3 backend.
- Do not solve Arabic-number formatting in this feature.
- Do not change focus detection, paste safety, clipboard behavior, hotkey behavior, or floating-panel behavior.
- Do not introduce cloud ASR, LLM correction, auto-send, or InputMethodKit.

## Requirements

- R1: No active script should start `qwen3_mlx_http_service.py` or `qwen3_mlx_cumulative_service.py`.
- R2: `qwen3_mlx_segmented_cache_service.py` must own its runtime dependencies through neutral shared helpers, not cumulative modules.
- R3: Default local HTTP config and status checks must point to the segmented service route.
- R4: Automated validation must compile and self-test only active Qwen3 segmented service tooling.
- R5: Historical specs/results may still mention cumulative recompute, but current README/PMB operational guidance must say it is retired.
- R6: Swift build/tests must continue to pass.

## Constraints

- Keep changes local-only and privacy-preserving.
- Keep historical evidence intact for traceability.
- Prefer small, obvious file moves/deletions over broad refactors.

## Dependencies

- `2026-06-26-qwen3-mlx-segmented-cache-service`
- `2026-06-26-qwen3-mlx-segmented-app-smoke`
- `2026-07-01-qwen3-segmented-regression-suite`

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
