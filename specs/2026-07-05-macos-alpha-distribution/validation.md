# Validation - macOS Closed Alpha Distribution Package

## Completion rule

This feature can be marked `passes=true` only when the required automated checks pass, a closed-alpha DMG is produced, the bundled/staged Qwen3 runtime is proven to start outside the repo, the app can start or reuse the Qwen3 service without terminal setup, and a real macOS alpha smoke confirms core dictation workflows.

Gatekeeper acceptance is not required for Phase 1. An unnotarized/Gatekeeper warning or rejection is expected and should be recorded as informational evidence. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: Development builds remain possible for local daily use.
- A2: The closed-alpha package can be built without Developer ID, notary credentials, App Store Connect, or Apple Developer Program membership.
- A3: The packaging workflow produces a DMG under `dist/` with a clear unnotarized closed-alpha name.
- A4: The DMG does not include `.external/models` wholesale or generated ASR logs.
- A5: The DMG includes the production Qwen3 0.6B 8-bit model, runtime assets, `mlx-audio`, active segmented service source, alpha config, README, manifest, checksums, and notices.
- A6: Repo-external staged runtime validation starts the Qwen3 segmented service using only staged paths and confirms `/metadata` or `/health`.
- A7: The app-managed service path starts or reuses the local Qwen3 service when `asrBackend=local-http`.
- A8: The service uses user-writable spool/cache/log directories and does not write mutable files into the app bundle.
- A9: The app bundle still has the intended `LSUIElement` menu-bar shape and required microphone/input-monitoring usage strings.
- A10: Alpha double-click configuration makes local HTTP ASR, NumericITN, and audio ducking behavior explicit and inspectable.
- A11: Permission guidance explains Microphone, Accessibility, and Input Monitoring, and does not imply scripts can grant them automatically.
- A12: Short input produces text through Qwen3 local HTTP ASR.
- A13: Long input start/stop works.
- A14: Esc cancellation does not copy or paste.
- A15: Audio ducking lowers playback during recording and restores afterward.
- A16: The distribution docs explain that no cloud ASR fallback or audio/text upload is enabled by default.
- A17: Future Developer ID/notarized distribution constraints are recorded but not treated as part of the Phase 1 acceptance gate.

## Automated checks

```bash
bash scripts/test.sh
swift build
bash scripts/build_macos_app.sh
bash scripts/show_codesign_status.sh
bash scripts/status_localvoiceinput.sh
python3 -m json.tool configs/alpha.local-qwen3.json >/dev/null
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-05-macos-alpha-distribution/feature.json >/dev/null
bash -n scripts/build_macos_app.sh scripts/package_macos_alpha.sh scripts/write_alpha_config.sh
git diff --check
```

When closed-alpha packaging support exists, also run:

```bash
bash scripts/package_macos_alpha.sh --preflight
bash scripts/package_macos_alpha.sh --dry-run
bash scripts/package_macos_alpha.sh --stage-runtime
bash scripts/package_macos_alpha.sh --verify-staged-runtime
bash scripts/package_macos_alpha.sh --closed-alpha
```

Optional informational Gatekeeper check:

```bash
spctl --assess --type open --verbose=4 dist/LocalVoiceInput*-closed-alpha*.dmg
```

For Phase 1, `spctl` rejection is expected unless the artifact happens to be signed/notarized outside this feature's requirements.

## Manual smoke checks

- Install or copy the generated app from the DMG on a clean or clean-ish macOS account.
- If macOS blocks first launch, use the Apple-supported Privacy & Security "Open Anyway" override.
- Launch the app from the installed location.
- Grant Microphone, Accessibility, and Input Monitoring permissions when prompted.
- Confirm the app starts or reuses the Qwen3 segmented local HTTP service on `127.0.0.1:18096` without terminal setup.
- Run diagnostics and confirm expected alpha status or record exact expected deviations.
- Use short Right Option dictation and confirm final text is inserted or safely copied according to focus policy.
- Use Right Command + `.` long input and confirm final text is available.
- Press Esc during recording and confirm no copy/paste occurs.
- Play local audio during recording and confirm output lowers and restores.

## Optional / not-applicable checks

- Developer ID signing is not applicable to Phase 1 closed alpha.
- Notarization and stapling are not applicable to Phase 1 closed alpha.
- `.pkg` installer validation is not applicable to Phase 1 closed alpha.
- Mac App Store sandbox submission is not applicable.
- TestFlight external review is not applicable.
- Intel Mac validation is optional for the first alpha unless the user explicitly expands hardware support.
- Automatic model download is not applicable in this feature.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Signing identity used and whether it is Apple Development, ad-hoc, local identity, or Developer ID.
- Staged runtime path and `/metadata` or `/health` result.
- DMG path and approximate size.
- Manifest/checksum path.
- Model/runtime packaging decision and resulting disk/package size observations.
- Gatekeeper assessment result if run, explicitly labeled informational.
- Manual smoke results or skipped smoke rationale.
- Whether feature matrix status is `in_progress`, `implemented`, `blocked`, or `validated`.
