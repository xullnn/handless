# Plan - ASR model profile management

## Implementation sequence

1. Define the local model profile schema and a small registry format.
2. Add a profile resolver that can load the registry, check local asset presence, check basic hardware/resource compatibility, and return an explicit selected profile or diagnostic failure.
3. Connect existing config/CLI selection to profile ids while preserving the current explicit backend flags.
4. Add service startup/status integration so the active local HTTP ASR service can report the loaded profile and resource state.
5. Add fallback behavior for missing or incompatible profiles, limited to local configured profiles only.
6. Add tests for profile parsing, compatibility checks, missing assets, fallback behavior, and no mid-session switching.
7. Update operational docs with profile examples for Qwen3-ASR MLX 0.6B, Qwen3-ASR MLX 1.7B, FunASR baseline, and MiMo offline-reference status.
8. Run smoke checks against the current Qwen3 local HTTP path and existing FunASR/mock paths before marking validated.

## Touched areas

- `Sources/LocalVoiceInputCore/` if a platform-independent profile model is added.
- `Sources/LocalVoiceInputMac/AppConfig.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/LocalHTTPASRClient.swift`
- `eval/asr_streaming/`
- `configs/`
- `scripts/`
- `Tests/LocalVoiceInputCoreTests/`
- `Tests/LocalVoiceInputMacTests/`
- `eval/asr_streaming/README.md`
- `eval/asr_streaming/model_inventory.md`

## Validation implementation notes

- Profile selection logic should be unit-tested without loading real models.
- Real model smoke tests should remain explicit and local.
- Resource compatibility checks should be conservative and visible, not silent.
- The current app safety tests remain required because this feature changes backend selection but must not change output safety.

## PMB promotion candidates

- Promote the profile architecture to `project_memory_bank/modules/asr_audio/summary.md` only after validation.
- Promote any durable default profile policy to `project_memory_bank/core/current_focus.md` only after the default path is validated.

## Risks and mitigations

- Risk: Profile abstraction makes backend selection look safer than it is.
  Mitigation: Record realtime capability and product role separately, and require validation per role.
- Risk: App startup becomes slow because model checks load large assets.
  Mitigation: Compatibility checks must inspect metadata and paths without loading models unless explicitly starting the service.
- Risk: Fallback hides a failed selected model.
  Mitigation: Report selected, failed, and fallback profiles in diagnostics.
- Risk: Users select a model too large for their machine.
  Mitigation: Add conservative thresholds and require explicit override for unsupported profiles.
- Risk: Model profile work destabilizes existing paste/hotkey behavior.
  Mitigation: Keep selection below `ASRClientProtocol` and rerun existing Swift tests.

## Notes

- This feature defines model choice and resource compatibility, not the segmented-cache long-dictation policy itself.
- The profile layer should make model replacement possible without forcing a single model into app-level code.
