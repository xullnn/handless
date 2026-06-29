# System Overview

The repository is a Swift Package with two main targets:

- `LocalVoiceInputCore`: platform-independent logic for session state, hotkey state, focus snapshots, output routing, transcript merging, correction, and history models.
- `LocalVoiceInputMac`: macOS app implementation using AppKit, Accessibility, AVFoundation, pasteboard, CGEvent, URLSession WebSocket, and optional localhost HTTP ASR transport.

High-level runtime flow:

1. `HotkeyController` observes global keyboard events.
2. `AppController` starts a voice session and captures the initial `FocusSnapshot`.
3. `OutputModeRouter` selects cursor paste, clipboard draft, fallback copy, or floating draft.
4. `FloatingPanelController` shows rounded realtime partial text without becoming key window or activating the app.
5. `AudioCapture` streams 16 kHz mono int16 PCM to the active ASR client.
6. The configured ASR client (`FunASRClient`, `LocalHTTPASRClient`, or `MockASRClient`) emits `ASREvent` values into `TranscriptBuffer`.
7. `ASREventRouter` updates partials while recording and only allows finalization after user stop.
8. `CorrectionPipeline` applies local rule-based cleanup, hotword fixes, and homophone fixes.
9. `PasteEngine` routes final text through `ClipboardManager` and `KeyboardSimulator`.
10. `HistoryStore` persists recent final results.

Important safety properties:

- Active ASR callbacks are guarded by session id and ASR client identity; the local HTTP ASR client also filters backend events by session token.
- Focus is tracked during recording; any meaningful App/window/element/security change is sticky and downgrades output to clipboard draft.
- Secure text fields never auto-paste by default.
- Confirmed paste keeps the dictated result on the clipboard by default. If `restoreClipboardAfterPaste` is enabled, restoration happens only after paste verification confirms insertion.
- Failed or uncertain paste keeps the dictated text on the clipboard.
- Esc cancellation stops audio/ASR/session state and performs no copy or paste.
- Local ASR runtime artifacts are governed by explicit cleanup tooling; model caches are protected from the cleanup path.
