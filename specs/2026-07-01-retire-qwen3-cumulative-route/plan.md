# Plan - Retire Qwen3 Cumulative Recompute Runtime Route

## Implementation sequence

1. Add a neutral shared Qwen3 service helper module for common MLX backend, service result, sample rate, service-gate evaluation, and system-prompt helpers.
2. Update `qwen3_mlx_segmented_cache_service.py` to import from the shared helper module.
3. Remove active cumulative Python entrypoints and cumulative runner scripts.
4. Update eval validation to compile/self-test the segmented route and shared helper only.
5. Update default config, README, and status script to use the segmented Qwen3 service port and process name.
6. Update PMB current durable guidance after validation.
7. Run required validation and record evidence in `specs/progress.md`.

## Touched areas

- `eval/asr_streaming/qwen3_mlx_segmented_cache_service.py`
- `eval/asr_streaming/qwen3_mlx_service_common.py`
- `eval/asr_streaming/validate.sh`
- `scripts/status_localvoiceinput.sh`
- `scripts/run_qwen3_mlx_segmented_app_smoke.sh`
- `scripts/run_qwen3_mlx_segmented_regression_gate.sh`
- `scripts/write_default_config.sh`
- `configs/config.example.json`
- `Sources/LocalVoiceInputMac/AppConfig.swift`
- `Tests/LocalVoiceInputMacTests/LocalHTTPASRClientTests.swift`
- `README.md`
- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
- `specs/feature_matrix.json`
- `specs/progress.md`

## Validation implementation notes

- Keep Swift HTTP client tests but update their example loopback URL to the segmented default port.
- Keep segmented regression tooling available for future model tests.
- Run `eval/asr_streaming/validate.sh`, `swift build`, and `swift test`.
- Run dry-run segmented app and regression scripts.

## PMB promotion candidates

- Current Qwen3 local HTTP runtime direction: segmented-cache service only.
- Cumulative recompute is retired from active code/config and retained only as historical evidence.

## Risks and mitigations

- Risk: deleting cumulative modules breaks segmented imports.
  Mitigation: move shared helpers first, then delete cumulative files.
- Risk: historical docs become misleading.
  Mitigation: do not rewrite old specs; update current README/PMB guidance explicitly.
- Risk: deleting active scripts removes useful comparisons.
  Mitigation: keep historical result summaries and specs, and keep comparison tools that read summaries.
