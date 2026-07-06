# macOS App Module

`Sources/LocalVoiceInputMac` owns the AppKit application and macOS integrations.

Stable responsibilities:

- `AppController` coordinates session lifecycle, focus capture, ASR/audio ownership, correction, output routing, history, and panel state.
- `AppConfig` can explicitly select the ASR backend. FunASR WebSocket remains the default for development, while alpha config can select `LocalHTTPASRClient`, final-output numeric ITN, and output audio ducking for double-click closed-alpha use.
- `BundledQwenASRServiceManager` owns the alpha app-managed Qwen3 service path: it can reuse a compatible loopback service or start the bundled Python/service/model assets, while writing mutable spool/cache/log files to user-writable locations rather than the app bundle.
- `HotkeyController` uses a global event tap and requires Accessibility plus Input Monitoring permissions. Right Option controls short push-to-talk, while Right Command + `.` controls long draft start/stop.
- `FocusDetector` uses Accessibility APIs to identify editable targets, secure fields, and focus identity.
- `FloatingPanelController` shows rounded, non-key, non-activating realtime UI and includes controls to copy, restore clipboard, cancel, and quit the app. New recording sessions clear stale final text and show a non-word listening indicator. Completed output holds briefly, fades out over time, and pauses dismissal while the pointer is over the panel.
- `MenuBarController` provides a status-item menu and quit path.
- `PermissionManager` prompts for microphone, Accessibility, and Input Monitoring permissions.
- `AppController` has internal dependency seams for coordinator integration tests, allowing fake hotkey, audio, ASR, focus, paste, panel, and history collaborators without changing production wiring.

The app is intentionally an LSUIElement menu-bar utility rather than a normal foreground app or InputMethodKit input method.

Go Deeper:

- See `../../integration/output_safety_flow.md` for cross-module output behavior.
- See `../../insights/macos_tcc_codesigning.md` for signing and permission stability.
