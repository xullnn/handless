# Decisions - ASR model profile management

## Confirmed decisions

- D1: This contract creation pass does not implement runtime changes.
- D2: ASR remains local-only; no cloud fallback or upload is allowed by default.
- D3: The Swift app should stay lightweight. Heavy model execution belongs in local ASR services or existing local runtimes.
- D4: Model switching is not allowed during an active dictation session.
- D5: Qwen3-ASR MLX 0.6B remains the current first local HTTP integration candidate unless later validation changes the default.
- D6: FunASR remains a local baseline/fallback path.
- D7: MiMo-V2.5-ASR MLX remains an offline-quality reference unless chunked or streaming behavior is proven.

## Open questions / unresolved choices

- Where should the canonical profile registry live: `configs/`, `eval/asr_streaming/`, or a new runtime resource directory?
- Should the first implementation expose profile selection only through config/CLI, or also through a menu/settings UI?
- What exact memory, disk, and latency thresholds should define compatible versus override-required profiles?
- Should Qwen3-ASR MLX 1.7B become a selectable final-quality profile, a future final-refinement profile, or remain evaluation-only until more tests are run?
- Should model acquisition be handled by scripts only, or should the app eventually guide local model installation?

## PMB promotion candidates

- Promote durable profile architecture and default-profile policy only after implementation and validation.
