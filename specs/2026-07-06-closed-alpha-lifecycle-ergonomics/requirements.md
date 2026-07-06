# Requirements — Closed-Alpha Launch And Lifecycle Ergonomics

## Problem

The closed-alpha app is technically usable, but VM and host smoke testing exposed a distribution problem: a menu-bar-only utility can be hard for non-technical testers to identify, quit, reopen, and diagnose. The visible status item can be confused with, hidden by, or visually dominated by macOS microphone/privacy indicators, so closed-alpha builds need a more reliable app-owned control point.

## Scope

### IN

- Make the running app visibly identifiable as LocalVoiceInput from the macOS menu bar.
- Make the closed-alpha app visible as a normal Dock app by default so testers can find and quit it even when the menu-bar item is unclear.
- Keep a menu-bar control as an auxiliary lifecycle/diagnostics entry.
- Keep an explicit menu-bar-only launch/build override for developer use.
- Provide a clear `Quit LocalVoiceInput` menu action.
- Provide tester-facing menu entries for permissions, logs, and copying a short diagnostics summary.
- Add an app icon to the built `.app` so Finder, Applications, Spotlight, and Gatekeeper prompts have a recognizable identity.
- Update closed-alpha docs so testers know how to launch, find, diagnose, and quit the app.
- Preserve existing hotkey, ASR, output safety, audio ducking, packaging, and local-only behavior.

### OUT

- InputMethodKit conversion.
- Notarization, Developer ID, TestFlight, App Store, or `.pkg` installer work.
- Start-at-login preference.
- Full first-run onboarding window.
- Settings window or user-editable hotkey UI.
- Rebranding or final marketing-grade icon design.

## Requirements

- R1: The status item must use a LocalVoiceInput-owned visible marker, not only the generic macOS microphone symbol.
- R2: Recording and warning states must remain visible from the menu bar.
- R3: The menu must expose an explicit `Quit LocalVoiceInput` action.
- R4: The menu must keep a permission prompt action for Microphone, Accessibility, and Input Monitoring.
- R5: The menu must provide an `Open Logs Folder` action for tester diagnostics.
- R6: The menu must provide a `Copy Diagnostics Summary` action that does not start, stop, or mutate the ASR service.
- R7: The built app bundle must contain a `CFBundleIconFile` and icon resource.
- R8: Closed-alpha docs must tell testers that the yellow/orange macOS microphone privacy dot is not the LocalVoiceInput control; the app control is the LocalVoiceInput menu-bar item.
- R9: The build and package scripts must continue to sign the app after resources are copied.
- R10: Automated tests must cover any new pure presentation or diagnostics logic that can be tested without driving macOS UI.
- R11: The default built app must be Dock-visible, with an escape hatch for menu-bar-only developer builds.
- R12: The app must provide a normal Command-Q quit path when launched as a Dock-visible app.

## Constraints

- macOS TCC permissions remain user-controlled and cannot be silently granted.
- Dictation UI must remain non-focus-stealing during recording; the app may have normal foreground/Dock identity for launch and quit.
- Diagnostics must avoid leaking audio contents or transcript history by default.
- The app icon and menu text can be alpha-quality but must be clear enough for friend/colleague testing.

## Dependencies

- `2026-07-05-macos-alpha-distribution`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
- `project_memory_bank/insights/macos_tcc_codesigning.md`

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
- `project_memory_bank/insights/macos_tcc_codesigning.md`
