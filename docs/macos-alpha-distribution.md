# LocalVoiceInput macOS Closed Alpha Distribution

This document tracks the first friend/colleague alpha path. It is not the Mac App Store path and it is not the formal Developer ID/notarized path.

## Current Phase

Phase 1 target:

- unnotarized closed-alpha DMG;
- drag-installable `LocalVoiceInput.app`;
- bundled Qwen3-ASR MLX 0.6B 8-bit model;
- bundled Python/MLX runtime and `mlx-audio` source;
- app-managed local Qwen3 segmented service;
- no terminal setup for testers;
- Dock-visible app entry for closed-alpha launch and quit;
- expected first-launch Gatekeeper friction handled through macOS Privacy & Security "Open Anyway" by trusted testers.

Future Phase 2:

- Developer ID Application / Installer certificates;
- hardened runtime;
- notarization and stapling;
- possibly `.pkg` installer;
- broader external distribution.

## Build And Package Checks

Use preflight first:

```bash
bash scripts/package_macos_alpha.sh --preflight
```

Inspect the closed-alpha sequence:

```bash
bash scripts/package_macos_alpha.sh --dry-run
```

Stage the allowlisted runtime/model/service assets:

```bash
bash scripts/package_macos_alpha.sh --stage-runtime
```

Verify the staged runtime can start outside the repo:

```bash
bash scripts/package_macos_alpha.sh --verify-staged-runtime
```

Build the unnotarized closed-alpha DMG:

```bash
bash scripts/package_macos_alpha.sh --closed-alpha
```

The generated artifact name includes `closed-alpha-unnotarized` intentionally. Do not describe this build as Apple-notarized or public-ready.

## Bundled Alpha Runtime

The closed-alpha package should include only:

- `dist/LocalVoiceInput.app`;
- `.external/models/mlx-community__Qwen3-ASR-0.6B-8bit`;
- `.venv-mimo`;
- `.external/repos/mlx-audio`;
- allowlisted service files from `eval/asr_streaming/`;
- `configs/alpha.local-qwen3.json`;
- manifest, checksums, README, and notices.

It must not include:

- full `.external/models`;
- Qwen3 1.7B;
- MiMo reference models;
- FunASR baseline caches unless separately scoped;
- `asr_logs`;
- generated eval results.

## Tester First Run

Expected first launch:

1. Drag `LocalVoiceInput.app` to Applications.
2. Open it from Applications or Spotlight by searching `LocalVoiceInput`.
3. macOS may block it because it is not notarized.
4. Open System Settings > Privacy & Security and choose Open Anyway / Still Open.
5. Grant Microphone, Accessibility, and Input Monitoring when prompted.
6. After launch, LocalVoiceInput appears as a normal running app in the Dock. It also has a menu-bar control when macOS displays it.
7. Use Right Option for short dictation or Right Command + `.` for long dictation.

The yellow/orange microphone icon shown by macOS is only a system privacy and microphone-mode panel. It is not the LocalVoiceInput menu or quit button.

## Launch, Find, And Quit

- Launch: open `LocalVoiceInput.app` from Applications or use Spotlight search for `LocalVoiceInput`.
- Find the running app: look for the LocalVoiceInput Dock icon first. If the app-owned menu-bar item is visible, it shows `LVI`, `REC`, or `LVI!`.
- Quit: use the Dock icon's Quit action, press Command-Q while LocalVoiceInput is active, or click the app-owned menu-bar item and choose `退出 LocalVoiceInput` when that item is visible.
- Reopen: launch it again from Applications or Spotlight.

The closed-alpha build intentionally keeps a normal Dock-visible app entry because menu-bar-only utilities can be hard for non-technical testers to find and quit.

## Menu Diagnostics

When visible, the app-owned menu-bar menu includes tester-facing support actions:

- `检查/申请权限`: opens or requests the macOS permission prompts where possible.
- `打开日志文件夹`: opens `~/Library/Logs/LocalVoiceInput`.
- `复制诊断摘要`: copies safe runtime metadata, including app path, config path, backend, ASR URL, NumericITN, and audio ducking settings.

The diagnostics summary does not include recorded audio, transcript history, or dictated content.

The app should start or reuse the local Qwen3 service on `127.0.0.1:18096` without asking the tester to run shell commands.

## Alpha Defaults

The bundled alpha config selects:

- `asrBackend=local-http`
- `asrHTTPURL=http://127.0.0.1:18096`
- `numericITNEnabled=true`
- `audioDucking.enabled=true`
- `audioDucking.targetVolume=0.08`

User config under `~/Library/Application Support/LocalVoiceInput/config.json` still takes precedence when present. Fresh testers should use the bundled alpha config.

## Tester Permissions

The tester must grant these macOS permissions manually:

- Microphone
- Accessibility
- Input Monitoring

Scripts and the app can guide the user, but they cannot silently grant these TCC permissions.

## Local-Only Boundary

The alpha path is local-first:

- no cloud ASR fallback by default;
- no audio upload by default;
- no text upload by default;
- no automatic model download in this feature.

## Diagnostics

Development diagnostics also remain:

```bash
bash scripts/status_localvoiceinput.sh
```

Tester-facing diagnostics should be gathered from:

- the `LVI` menu's `复制诊断摘要` output;
- `~/Library/Logs/LocalVoiceInput/qwen3-service.log`
- `~/Library/Application Support/LocalVoiceInput/`
- screenshots of macOS permission/Gatekeeper prompts when launch fails.

## Not In This Phase

- App Store submission
- TestFlight external beta
- Developer ID notarization
- Stapled DMG
- `.pkg` installer
- Payments or licensing
- Automatic model download
- Bundling the full `.external/models` cache
