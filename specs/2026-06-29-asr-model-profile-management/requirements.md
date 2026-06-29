# Requirements - ASR model profile management

## Problem

The current app can talk to local ASR backends, but practical deployment still assumes a small working set and manual backend selection. Users with lower-end machines may need a smaller or more conservative model. Users with high-memory Apple Silicon machines may want a larger or higher-quality model. The app needs a local-only model profile layer that describes available ASR backends, chooses compatible profiles safely, and reports the active model clearly.

## Scope

### IN

- Define local ASR model profile metadata.
- Define startup and idle-time profile selection behavior.
- Define compatibility checks for RAM, disk, runtime, model assets, and backend type.
- Preserve the existing App/service/model separation.
- Keep Qwen3-ASR MLX 0.6B as the current first integration candidate unless later validation changes that decision.
- Preserve FunASR as a local baseline/fallback path.
- Treat MiMo-V2.5-ASR MLX as an offline-quality reference unless streaming or chunked behavior is proven.
- Define health/status reporting for active profile, loaded model, runtime, and resource state.

### OUT

- No cloud ASR fallback.
- No automatic audio/text upload.
- No default LLM correction.
- No model switch while an active dictation session is recording or finalizing.
- No implementation in this contract creation pass.
- No model training or fine-tuning.
- No forced download of large models during normal app startup.

## Requirements

- R1: A model profile must include at least: profile id, display name, vendor, model family, parameter scale, release/source notes, backend type, local model path, required assets, runtime, supported hardware, minimum memory, recommended memory, approximate disk footprint, realtime capability label, and intended product role.
- R2: Product roles must distinguish realtime partial candidate, final-refinement candidate, baseline fallback, and offline-quality reference.
- R3: Manual user selection must win when the selected profile is locally available and compatible with the current machine.
- R4: Auto selection must choose only local profiles whose assets exist and whose requirements are compatible with the current machine.
- R5: Failed profile startup must fail closed: the app can fall back only to another configured local profile, and it must not upload audio/text or silently switch to cloud.
- R6: Profile switching is allowed only before a session starts or after all active session cleanup is complete.
- R7: The app or service must expose a health/status surface showing the selected profile, loaded model, backend URL or transport type, local-only status, and current resource diagnostics where available.
- R8: Model profile selection must not weaken existing focus, paste, clipboard, floating-panel, ASR session-token, or stale-event isolation behavior.
- R9: Missing model files must produce actionable diagnostics instead of a confusing transcription failure.
- R10: The profile layer must allow future smaller and larger local models without hard-coding Qwen3-specific paths into app-level control flow.

## Constraints

- Keep the Swift app lightweight. Heavy model loading remains in local ASR service processes or existing local backend runtimes.
- Preserve local-only privacy guarantees.
- Do not auto-download or auto-run a model that exceeds conservative resource thresholds.
- Do not make the optional Qwen3 HTTP path the default without separate real app validation and supervision work.
- Keep model inventory and cleanup policy aligned with the existing resource/cache governance work.

## Dependencies

- `2026-06-23-qwen3-mlx-http-service-boundary`
- `2026-06-23-qwen3-mlx-swift-http-adapter`
- `2026-06-28-asr-resource-cache-governance`
- Existing `ASRClientProtocol`, `LocalHTTPASRClient`, `FunASRClient`, and app config paths.

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
