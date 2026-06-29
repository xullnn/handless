# Validation — ASR resource and cache governance

## Completion rule

This feature can be marked `passes=true` only when all required checks pass. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: Finalized and canceled cumulative-service sessions no longer retain audio chunks in active session state.
- A2: Service events are bounded by a configurable retention limit.
- A3: `/status` returns machine-readable resource state without loading the real model in tests.
- A4: Cache cleanup defaults to dry-run and does not delete model caches.
- A5: Cleanup `--apply` deletes only eligible scoped cache/artifact files in tests.
- A6: Existing Swift build and tests still pass.

## Automated checks

```bash
python3 eval/asr_streaming/qwen3_mlx_cumulative_service.py self-test
python3 eval/asr_streaming/qwen3_mlx_http_service.py self-test
python3 eval/asr_streaming/cleanup_localvoiceinput_cache.py self-test
bash scripts/cleanup_localvoiceinput_cache.sh --dry-run --max-bytes 1048576
swift build
swift test
```

## Manual smoke checks

- Optional: run the App against the existing Qwen3 HTTP service and verify previous dictation behavior remains unchanged.

## Optional / not-applicable checks

- Real MLX model load is optional for this feature because resource governance is covered by fake-backend service tests and Swift regression tests.

## Evidence required in `specs/progress.md`

- Commands run.
- Results.
- Any skipped checks with rationale.
- Whether any manual smoke was run.
