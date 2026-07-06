# Packaging And Operations Module

Packaging and local operations are script-driven.

Stable responsibilities:

- `scripts/build_macos_app.sh` builds `LocalVoiceInputMac`, creates `dist/LocalVoiceInput.app`, copies `Resources/AppIcon.icns`, writes `Info.plist` including `CFBundleIconFile=AppIcon`, omits `LSUIElement` by default for a Dock-visible closed-alpha app, and signs the app. `LOCALVOICEINPUT_MENU_BAR_ONLY=1` writes `LSUIElement=true` for developer-only menu-bar-agent builds.
- `scripts/package_macos_alpha.sh` builds the Phase 1 unnotarized closed-alpha DMG for trusted Apple Silicon testers. It stages allowlisted runtime assets, verifies the staged Qwen3 segmented service outside the repo, embeds `AlphaRuntime` into the app, re-signs the bundle, and creates the DMG under `dist/`.
- `configs/alpha.local-qwen3.json` is the closed-alpha config path for double-click use: local HTTP ASR on `127.0.0.1:18096`, NumericITN enabled, and output audio ducking enabled.
- `scripts/write_alpha_config.sh` writes the alpha config into the user config location when an alpha tester or local smoke needs that explicit runtime state.
- The build script uses `LOCALVOICEINPUT_CODESIGN_IDENTITY` when set. If it is not set and exactly one valid code-signing identity exists, the script uses that identity automatically. Otherwise it falls back to ad-hoc signing.
- `scripts/show_codesign_status.sh` reports available code-signing identities and the app's code-signing details/designated requirement.
- `scripts/write_default_config.sh` writes the default config under `~/Library/Application Support/LocalVoiceInput/config.json`.
- `scripts/status_localvoiceinput.sh` reports the current App process, Qwen3 segmented ASR service process, config, local runtime paths, and local service diagnostics without starting or stopping anything. It prefers `/metadata` and falls back to `/health`.
- `scripts/cleanup_localvoiceinput_cache.sh` inspects and cleans generated ASR runtime artifacts with dry-run defaults and model-cache protection.
- `scripts/setup_qwen3_mlx_runtime.sh` prepares the project-local `.venv-mimo` runtime for the active Qwen3 MLX service path and verifies the local model and `mlx-audio` source paths.
- `scripts/run_qwen3_mlx_segmented_app_smoke.sh` starts the active segmented Qwen3 HTTP service and launches the macOS app against it for manual smoke testing.
- `scripts/run_qwen3_mlx_segmented_regression_gate.sh` starts the segmented service, runs the HTTP adapter regression gate, and records resource samples and run metadata.
- `scripts/setup_funasr_venv.sh` and `scripts/run_funasr_python_server.sh` prepare and run the local FunASR server path.
- `scripts/download_funasr_smoke_models.sh` downloads repeatable local smoke-test models into `.external/models/`.
- `scripts/run_funasr_python_server.sh` prefers cached local model directories when present, defaults to CPU, and keeps punctuation and speaker verification disabled unless explicitly requested with environment variables.

Operational preference:

- Use a stable Apple Development or local code-signing identity for regular testing. Ad-hoc signatures change `cdhash` on rebuild and can force repeated macOS TCC permission prompts.
- Phase 1 closed-alpha distribution intentionally accepts Gatekeeper first-launch friction and relies on the tester using Privacy & Security "Open Anyway". It must not be described as notarized or public-ready.
- The closed-alpha package bundles only the active production Qwen3 0.6B runtime path, not the full `.external/models` cache or generated ASR logs.
- Existing user config takes precedence over the app-bundled alpha config. If an old dev/test install double-clicks into the FunASR default path or reports ASR connection failure, inspect with `scripts/status_localvoiceinput.sh` and write the alpha config with `scripts/write_alpha_config.sh`.

Go Deeper:

- See `../../insights/macos_tcc_codesigning.md` for the TCC/signing lesson.
