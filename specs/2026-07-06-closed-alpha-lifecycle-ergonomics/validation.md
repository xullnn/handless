# Validation — Closed-Alpha Launch And Lifecycle Ergonomics

## Completion rule

This feature can be marked `passes=true` only when required automated checks pass, the built app contains the icon resource and updated `Info.plist`, the closed-alpha package rebuilds successfully, and a local manual smoke confirms the app is findable/quittable through Dock/Application-menu paths even if the menu-bar item is not obvious on a crowded host menu bar.

## Acceptance criteria

- A1: The menu-bar item visibly shows a LocalVoiceInput-owned marker in idle, recording, and warning states.
- A2: The menu contains explicit controls for permissions, logs, diagnostics, and `Quit LocalVoiceInput`.
- A3: Copying diagnostics does not start or stop the ASR service and does not include transcript or audio content.
- A4: The built app bundle includes a `CFBundleIconFile` entry and the corresponding `.icns` resource.
- A5: The closed-alpha docs explain launch, menu-bar location, quit, logs, diagnostics, and the distinction between the app item and macOS microphone privacy dot.
- A6: Existing dictation session behavior, output routing, cancel behavior, and audio ducking are unchanged.
- A7: The closed-alpha DMG can be rebuilt with the updated app resources.
- A8: The default built app is Dock-visible and does not include `LSUIElement=true`.
- A9: A developer can still produce/launch a menu-bar-only build when explicitly requested.

## Automated checks

```bash
python3 -m json.tool specs/2026-07-06-closed-alpha-lifecycle-ergonomics/feature.json >/dev/null
python3 -m json.tool specs/feature_matrix.json >/dev/null
bash scripts/test.sh
swift build
bash scripts/build_macos_app.sh
/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' dist/LocalVoiceInput.app/Contents/Info.plist
test -f dist/LocalVoiceInput.app/Contents/Resources/AppIcon.icns
if /usr/libexec/PlistBuddy -c 'Print :LSUIElement' dist/LocalVoiceInput.app/Contents/Info.plist >/tmp/localvoiceinput-lsuielement.txt 2>&1; then
  cat /tmp/localvoiceinput-lsuielement.txt
  exit 1
fi
codesign --verify --deep --strict --verbose=2 dist/LocalVoiceInput.app
bash scripts/package_macos_alpha.sh --closed-alpha
bash scripts/package_macos_alpha.sh --verify-staged-runtime
hdiutil verify dist/LocalVoiceInput-0.1.0-alpha-closed-alpha-unnotarized.dmg
```

## Manual smoke checks

- Launch the rebuilt app.
- Confirm the app appears as a normal running app in the Dock after launch.
- Confirm Command-Q or the Dock Quit action exits the app.
- If the menu-bar item is visible, confirm it shows a LocalVoiceInput-owned marker and opens the lifecycle menu.
- Open the menu and confirm the permission, logs, diagnostics, and quit actions are present.
- Use `Copy Diagnostics Summary` and confirm the clipboard contains safe app/runtime metadata, not dictated text.
- Use `Open Logs Folder` and confirm Finder opens the LocalVoiceInput log directory.
- Quit via `Quit LocalVoiceInput` and confirm the app process exits.
- Relaunch and confirm existing short/long dictation shortcuts still work, including cancel.

## Optional / not-applicable checks

- Start-at-login validation is not applicable to this feature.
- First-run onboarding validation is not applicable to this feature.
- Developer ID notarization, stapling, and App Store validation remain not applicable to the Phase 1 closed alpha.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Built app icon/Info.plist verification.
- DMG path and verification result.
- Manual smoke outcome or reason for deferral.
- Feature matrix status and `passes` state.
