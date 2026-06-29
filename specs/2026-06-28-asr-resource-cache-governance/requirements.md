# Requirements — ASR resource and cache governance

## Problem

The local Qwen3-ASR HTTP path is useful for real app smoke testing, but the current cumulative service keeps session audio and event history in memory after final/cancel. The segmented-cache prototype also writes local audio spool files without a product retention policy. Long-running local use needs bounded resource behavior without weakening the existing dictation safety contract.

## Scope

### IN

- Release cumulative Qwen3 HTTP service session audio after final or cancel.
- Bound service-side event retention so long-running service processes do not grow unbounded event lists.
- Add a local `/status` endpoint for resource diagnostics.
- Add a safe cleanup script for local ASR cache/spool/eval runtime artifacts with `--dry-run` default behavior.
- Add focused automated tests around memory/session cleanup, event retention, status shape, and cleanup dry-run/apply behavior.
- Preserve the current app interaction model, output routing, clipboard behavior, and local/offline-only boundary.

### OUT

- No changes to Right Option, Option+Space, Esc, focus routing, paste verification, or floating panel UX.
- No change to default ASR backend selection.
- No product integration of segmented-cache as the default App runtime.
- No deletion of model caches by default.
- No cloud dependency or upload path.
- No user-facing cache/recovery UI in this pass.

## Requirements

- R1: The cumulative Qwen3 service must remove finalized or canceled session audio from its active session store.
- R2: The service must keep event retention bounded by a configurable limit while preserving enough recent events for HTTP responses and diagnostics.
- R3: The HTTP service must expose `/status` with active session count, retained event count, uptime, model metadata, native realtime eligibility, and process RSS when available.
- R4: Cache cleanup must be explicit and safe: dry-run by default, no model cache deletion, and clear reporting of candidate paths and byte counts.
- R5: Cache cleanup must support age-based deletion and max-byte budget enforcement for segmented-cache spool and manual ASR audio/eval artifacts.
- R6: Existing Swift App tests must continue to pass; no App safety rules may be weakened to satisfy resource tests.

## Constraints

- Local-only operation remains mandatory.
- Audio/text must not be uploaded.
- Cleanup must not touch `.external/models` unless a future explicit feature adds model cleanup.
- Cleanup must not delete current config, history, packaged app, or source files.
- Resource governance must be testable without loading the real MLX model.

## Dependencies

- `2026-06-23-qwen3-mlx-http-service-boundary`
- `2026-06-23-qwen3-mlx-http-resource-validation`
- `2026-06-26-qwen3-mlx-segmented-cache-service`

## Related PMB context

- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/core/current_focus.md`
