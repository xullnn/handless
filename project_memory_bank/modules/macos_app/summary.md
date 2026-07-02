# macOS App Module

`Sources/LocalVoiceInputMac` owns the AppKit application and macOS integrations.

Stable responsibilities:

- `AppController` coordinates session lifecycle, focus capture, ASR/audio ownership, correction, output routing, history, and panel state.
- `AppConfig` can explicitly select the ASR backend. FunASR WebSocket remains the default; `LocalHTTPASRClient` and final-output numeric ITN are available only when selected through config or CLI flags.
- `HotkeyController` uses a global event tap and requires Accessibility plus Input Monitoring permissions.
- `FocusDetector` uses Accessibility APIs to identify editable targets, secure fields, and focus identity.
- `FloatingPanelController` shows rounded, non-key, non-activating realtime UI and includes controls to copy, restore clipboard, cancel, and quit the app. Completed output holds briefly, fades out over time, and pauses dismissal while the pointer is over the panel.
- `MenuBarController` provides a status-item menu and quit path.
- `PermissionManager` prompts for microphone, Accessibility, and Input Monitoring permissions.

The app is intentionally an LSUIElement menu-bar utility rather than a normal foreground app or InputMethodKit input method.

Go Deeper:

- See `../../integration/output_safety_flow.md` for cross-module output behavior.
- See `../../insights/macos_tcc_codesigning.md` for signing and permission stability.
