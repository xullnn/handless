# macOS App Module

`Sources/LocalVoiceInputMac` owns the AppKit application and macOS integrations.

Stable responsibilities:

- `AppController` coordinates session lifecycle, focus capture, ASR/audio ownership, correction, output routing, history, and panel state.
- `AppConfig` can explicitly select the ASR backend. FunASR WebSocket remains the default for development, while alpha config can select `LocalHTTPASRClient`, final-output numeric ITN, and output audio ducking for double-click closed-alpha use.
- `BundledQwenASRServiceManager` owns the alpha app-managed Qwen3 service path: it can reuse a compatible loopback service or start the bundled Python/service/model assets, writes mutable spool/cache/log files to user-writable locations rather than the app bundle, and requests graceful `/shutdown` for app-owned service processes before forced termination.
- `HotkeyController` uses a global event tap and requires Accessibility plus Input Monitoring permissions. Right Option controls short push-to-talk, while Right Command + `.` controls long draft start/stop.
- `FocusDetector` uses Accessibility APIs to identify editable targets, secure fields, and focus identity.
- `FloatingPanelController` shows rounded, non-key, non-activating realtime UI and includes controls to copy, restore clipboard, cancel, and quit the app. New recording sessions clear stale final text and show a non-word listening indicator. Completed output holds briefly, fades out over time, and pauses dismissal while the pointer is over the panel.
- `main.swift` launches the closed-alpha app as a normal Dock-visible app by default so testers can find and quit it. `--menu-bar-only` preserves the older accessory-style developer launch path.
- `MenuBarController` provides an auxiliary app-owned `LVI` menu-bar control. It shows `LVI` when ready, `REC` while recording, and `LVI!` when attention is needed, and exposes permissions, logs, diagnostics, history, mock-session, stop/copy, and explicit quit actions when the item is visible.
- `PermissionManager` prompts for microphone, Accessibility, and Input Monitoring permissions.
- `AppController` has internal dependency seams for coordinator integration tests, allowing fake hotkey, audio, ASR, focus, paste, panel, and history collaborators without changing production wiring.

The app is intentionally not an InputMethodKit input method. The closed-alpha build is Dock-visible by default; pure menu-bar-agent behavior is a developer override, not the tester default.

Go Deeper:

- See `../../integration/output_safety_flow.md` for cross-module output behavior.
- See `../../insights/macos_tcc_codesigning.md` for signing and permission stability.
