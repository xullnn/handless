# Requirements - macOS Closed Alpha Distribution Package

## Problem

LocalVoiceInput is useful as a local daily-use macOS menu-bar dictation app, but the current runnable path still assumes a developer machine: repo checkout, project-local Python runtime, local Qwen3 model cache, command-line overrides, and a manually started Qwen3 segmented HTTP service.

The next product milestone is a closed alpha package that a small number of trusted friends or colleagues can install and use without preparing Python, MLX, model files, or shell commands. This is not yet the formal Developer ID/notarized distribution path. The expected macOS Gatekeeper behavior for this phase is that the first launch may be blocked until the tester manually chooses "Open Anyway" / "Still Open" in Privacy & Security.

## Scope

### IN

- Define and implement the first closed-alpha macOS DMG path.
- Produce a repeatable DMG containing a drag-installable `LocalVoiceInput.app`.
- Bundle only the production alpha ASR assets needed for the current path:
  - Qwen3-ASR MLX 0.6B 8-bit model snapshot;
  - a Python/MLX runtime or staged runtime derived from `.venv-mimo`;
  - `mlx-audio` source required by the active Qwen3 service;
  - the active segmented Qwen3 HTTP service code.
- Exclude the full `.external/models` cache and generated ASR logs/artifacts.
- Make the app manage the bundled Qwen3 service for alpha use: health check, start when needed, use a user-writable spool/cache/log path, and surface clear failure diagnostics.
- Make alpha defaults match the current daily-use behavior without command-line overrides: local HTTP ASR on `127.0.0.1:18096`, NumericITN enabled, and audio ducking enabled at volume `0.08`.
- Keep the current app form as an `LSUIElement` menu-bar utility, not an InputMethodKit input method.
- Sign the app and nested executable code with the best available local stable identity when possible; ad-hoc signing remains a fallback for development/closed-alpha only.
- Produce checksum/manifest/license-notice artifacts with the DMG.
- Document the expected first-launch Gatekeeper override and the macOS permissions testers must grant: Microphone, Accessibility, and Input Monitoring.
- Preserve local-only behavior: no cloud ASR fallback and no audio/text upload by default.

### OUT

- No Mac App Store submission in this feature.
- No TestFlight build in this feature.
- No Developer ID requirement for Phase 1.
- No notarization or stapling requirement for Phase 1.
- No `.pkg` installer for Phase 1.
- No payments, licensing, account login, or paid-app commerce.
- No automatic network model download inside the app.
- No bundling of every cached model under `.external/models`.
- No bundling of generated runtime logs such as `asr_logs`.
- No installer or script that silently grants macOS TCC permissions.
- No privileged helper, system extension, kernel extension, or background daemon.
- No migration to InputMethodKit.
- No model profile selection UI; `2026-06-29-asr-model-profile-management` remains separate.

## Requirements

- R1: The closed-alpha workflow must build `dist/LocalVoiceInput.app` from the Swift Package release product with the stable bundle id unless a deliberate bundle-id decision is recorded.
- R2: The closed-alpha DMG must be producible without a paid Apple Developer Program account, Developer ID certificate, notarization profile, or App Store Connect access.
- R3: The closed-alpha DMG must make Gatekeeper override expectations explicit and must not claim to be an Apple-notarized or public distribution artifact.
- R4: The package must include the Qwen3 0.6B 8-bit model snapshot and must not include `.external/models` wholesale.
- R5: The package must include the local runtime assets required to start the Qwen3 segmented service without asking testers to install Python, MLX, or `mlx-audio`.
- R6: Runtime staging must be verified outside the repo before the package is treated as usable.
- R7: The app must start or reuse the local Qwen3 segmented service for alpha use when the selected backend is `local-http`.
- R8: The app-managed service must write mutable artifacts to user-writable Application Support, Caches, or Logs directories, not inside the `.app` bundle.
- R9: The service start path must use explicit bundled paths for model, runtime, service source, spool/cache, host, and port.
- R10: The app must surface actionable failures when the service cannot start, the port is occupied by an incompatible process, required bundled assets are missing, or health checks fail.
- R11: The alpha configuration used for double-click usage must be explicit and inspectable. It must cover local HTTP ASR URL, NumericITN, and audio ducking.
- R12: Permission guidance must tell testers which macOS settings are required and must not imply that scripts can grant TCC permissions automatically.
- R13: Runtime status tooling must remain read-only when used for diagnostics.
- R14: The closed-alpha package must preserve existing output safety behavior: no auto-send, secure fields do not auto-paste, failed paste keeps text recoverable, and cancel does not copy or paste.
- R15: The Phase 1 target is Apple Silicon macOS 13+. Intel support is not required unless separately validated.
- R16: The workflow must keep a future Developer ID/notarized path visible but must not block Phase 1 on those credentials.

## Constraints

- Current local evidence shows `dist/LocalVoiceInput.app` is about 1.1M, Qwen3 0.6B 8-bit is about 964M, `.venv-mimo` is about 583M, `mlx-audio` source is about 15M, `.external/models` totals about 10G, and `asr_logs` is about 1.2G.
- `.venv-mimo` contains executable files and dynamic libraries, so relocatability and nested signing need explicit validation.
- Current App process uses command-line overrides for Qwen3 local HTTP, NumericITN, and audio ducking; config defaults do not yet fully represent the actual daily-use launch state.
- Qwen3 segmented service is a local wrapper around file-level model calls, not a native model streaming API.
- The Qwen3 service currently uses single-threaded `HTTPServer` because MLX inference failed when model loading and request handling ran on different Python threads.
- macOS TCC permissions are user-controlled and cannot be silently granted by app scripts.
- Closed-alpha Gatekeeper override is acceptable only for a small trusted tester group; public distribution still requires a future Developer ID/notarized path.

## Dependencies

- `2026-06-23-qwen3-mlx-swift-http-adapter`
- `2026-06-26-qwen3-mlx-segmented-cache-service`
- `2026-06-28-asr-resource-cache-governance`
- `2026-07-02-contextual-numeric-itn-expansion`
- `2026-07-05-output-audio-ducking`
- Current scripts:
  - `scripts/build_macos_app.sh`
  - `scripts/show_codesign_status.sh`
  - `scripts/status_localvoiceinput.sh`
  - `scripts/setup_qwen3_mlx_runtime.sh`
  - `scripts/run_qwen3_mlx_segmented_app_smoke.sh`

## Related PMB context

- `project_memory_bank/core/project_brief.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
- `project_memory_bank/insights/macos_tcc_codesigning.md`
- `eval/asr_streaming/model_inventory.md`
