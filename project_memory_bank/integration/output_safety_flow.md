# Output Safety Flow

This integration flow is the central product safety contract.

Start:

1. User starts a short push-to-talk session with Right Option, or starts/stops long-draft mode with Right Command + `.`.
2. `AppController` captures the initial `FocusSnapshot`.
3. `OutputModeRouter` selects the initial output mode.
4. `FocusChangeTracker` samples focus during recording.

Final routing:

- Cursor paste: allowed only for non-secure, editable, pasteable, high/medium-confidence initial focus with no sticky focus change, plus explicit low-confidence app allowlist exceptions.
- Clipboard draft: used for no input focus, low confidence without allowlist, secure fields, focus changes, and disabled auto-paste.
- Floating draft: used for long-draft output; final text is shown in the panel, copied to the clipboard, and saved to history instead of auto-pasted.
- Fallback copy: used when paste was attempted but insertion could not be confirmed.
- Cancelled: used for Esc cancellation; no copy and no paste.

Clipboard policy:

- Cursor paste temporarily writes final text to the pasteboard, sends Cmd+V, and verifies insertion.
- Confirmed cursor paste keeps the dictated result as the newest clipboard item by default. If `restoreClipboardAfterPaste` is enabled, the original clipboard is restored only after confirmation.
- Clipboard draft intentionally keeps the dictated text on the clipboard for the user's next manual Cmd+V.
- Floating draft also keeps the dictated text on the clipboard for the user's next manual Cmd+V.
- Fallback copy keeps the dictated text on the clipboard because paste failed or could not be proven.
- Secure fields never auto-paste by default.

Focus-change policy:

- App, process, window title, focused element identity, role/subrole, editability, secure-field state, or pasteability changes during recording are sticky.
- A sticky change downgrades the final output to clipboard draft when the policy enables downgrade.

ASR session policy:

- ASR/audio callbacks must match the active session id and active ASR client identity.
- A replacement input intent cancels the active ASR/audio session and starts the new requested mode; stale callbacks from the replaced session must not route output or history.
- Offline FunASR segments before user stop update transcript state but do not finalize output.
- User stop triggers audio flush first, then `is_speaking=false`.
