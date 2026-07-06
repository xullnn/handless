# macOS TCC And Code Signing

macOS TCC permissions such as Accessibility, Input Monitoring, and Microphone are user-controlled and cannot be silently granted by the app, normal shell scripts, or automation. Computer automation can help navigate System Settings, but the user still controls final approval and may need to enter a password or use Touch ID.

Ad-hoc signing identifies each build by a changing `cdhash`. Rebuilding an ad-hoc signed app can make macOS treat it as a different binary for TCC purposes, causing repeated permission prompts or stale permission state.

Use a stable signing identity for regular testing:

- Keep `CFBundleIdentifier` stable: `dev.localvoiceinput.mvp`.
- Sign with the same Apple Development or local code-signing identity across rebuilds.
- Ensure the Apple WWDR G3 intermediate certificate is available when using Apple Development certificates.
- Use `scripts/show_codesign_status.sh` to inspect the active identity and designated requirement.

The desired designated requirement is certificate-based rather than pure `cdhash`-based. That lets macOS recognize rebuilds as the same app identity when the bundle id and signing identity remain stable.

For trusted closed-alpha distribution, an unnotarized DMG is usable only with explicit user action: macOS may block first launch, the tester must use Privacy & Security "Open Anyway" / "Still Open", and then grant Microphone, Accessibility, and Input Monitoring. Input Monitoring may require quitting and reopening the app before the global event tap works.

When testing inside a macOS VM on the same host, quit the host `LocalVoiceInput` app before testing VM hotkeys. Both apps can otherwise listen for Right Option, and the host event tap may consume the shortcut before VirtualBuddy passes it to the guest.
