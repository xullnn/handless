# Plan — ASR resource and cache governance

## Implementation sequence

1. Update `CumulativeRecomputeService` to support configurable event retention and finalized/canceled session cleanup.
2. Update `qwen3_mlx_http_service.py` to expose `/status` and pass retention configuration into the service.
3. Add or extend Python self-tests for cleanup, event retention, stale-session safety, and HTTP status behavior in fake-backend mode.
4. Add `scripts/cleanup_localvoiceinput_cache.sh` as a safe CLI wrapper.
5. Add a Python cleanup helper under `eval/asr_streaming/` to enumerate and optionally delete eligible cache/result/audio files without touching models.
6. Run Swift and Python validation commands.
7. Record validation evidence in `specs/progress.md`.

## Touched areas

- `eval/asr_streaming/qwen3_mlx_cumulative_service.py`
- `eval/asr_streaming/qwen3_mlx_http_service.py`
- `eval/asr_streaming/cleanup_localvoiceinput_cache.py`
- `scripts/cleanup_localvoiceinput_cache.sh`
- `specs/2026-06-28-asr-resource-cache-governance/`
- `specs/feature_matrix.json`
- `specs/progress.md`

## Validation implementation notes

- Use fake backend self-tests for service logic so validation does not require loading Qwen3 MLX.
- Keep existing `swift build` and `swift test` as regression checks.
- Add cleanup tests using a temporary directory and `--dry-run` / `--apply`.

## PMB promotion candidates

- After validation, promote the durable fact that the Qwen3 HTTP service bounds session/event retention and that cache cleanup is explicit and model-safe.

## Risks and mitigations

- Risk: Cleaning sessions too early could hide final events from the HTTP response.
  Mitigation: Cleanup happens after final event creation and retained events remain available.
- Risk: Event retention could remove diagnostics needed by tests.
  Mitigation: Keep retention configurable and verify only recent bounded history is required for status.
- Risk: Cleanup script could delete user recordings unexpectedly.
  Mitigation: Dry-run default, explicit `--apply`, scoped roots, and no model cache deletion.
- Risk: App behavior regresses.
  Mitigation: Do not modify Swift interaction code in this feature and run the full Swift test suite.

## Notes

- This pass is intentionally narrower than segmented-cache product integration.
