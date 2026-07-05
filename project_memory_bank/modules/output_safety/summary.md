# Output Safety Module

Output safety spans core routing, macOS focus detection, paste execution, clipboard handling, and UI diagnostics.

Stable responsibilities:

- Route to cursor paste only when the initial focus is editable, pasteable, not secure, and sufficiently confident.
- Route to clipboard draft when no text input is focused, the target is secure, confidence is low, auto-paste is disabled, or focus changes during recording. Low-confidence app-specific force-paste allowlists are explicit policy exceptions.
- Route to fallback copy when paste is attempted but cannot be confirmed.
- Keep dictated text as the newest clipboard item by default, including after confirmed paste.
- Restore the previous clipboard only when `restoreClipboardAfterPaste` is enabled and paste verification confirms insertion.
- Keep dictated text on the clipboard for no-input, secure-field, focus-change, and paste-failure cases.
- Never copy or paste on Esc cancellation.

Current paste behavior:

- `KeyboardSimulator` posts clean Right Option and Right Command key-up events before Cmd+V, then posts Cmd+V to the detected target process when available.
- `PasteEngine` verifies insertion asynchronously using AX text/value/count/range evidence so paste confirmation does not block the main event loop or hotkey handling during immediate re-record.
- `PasteRoutePlanner` decides whether a confirmed paste should keep the result or restore the previous clipboard from `OutputPolicy.restoreClipboardAfterPaste`.
- Fake-driven `AppController` session tests cover stale paste completion, stale ASR final, stale audio chunk, cancellation, focus-change downgrade, and short-audio no-output invariants without relying on real macOS event delivery.

Go Deeper:

- See `../../integration/output_safety_flow.md` for detailed routing flow.
