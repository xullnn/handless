# Requirements — Input Session Replacement Hotkeys

## Problem

Daily use exposed a weak interaction boundary: if a user finishes a short dictation and immediately presses the shortcut again while the previous session is still finalizing, the hotkey can be consumed without starting a new recording. This is especially painful when the previous result was not pasted or was recognized incorrectly and the user wants to immediately re-record.

## Scope

### IN

- Make new input intent replace any previous unfinished session instead of being silently ignored.
- Change long input from `Option + Space` to `Right Command + .`.
- Remove the default short-to-long conversion behavior tied to `Option + Space`.
- Keep short input as hold-to-talk on `Right Option`.
- Clear stale final text from the floating panel when a new session starts and show a non-text listening indicator.
- Preserve stale ASR callback isolation by session id / client identity.
- Update automated tests and user-facing docs for the new shortcut behavior.

### OUT

- Configurable shortcuts UI or preferences panel.
- InputMethodKit migration.
- ASR backend changes or model selection changes.
- Automatic undo of already-issued paste actions.
- Deleting text already inserted into the target application.

## Requirements

- R1: Pressing `Right Option` when no active recording is running starts a short push-to-talk session.
- R2: Pressing `Right Command + .` when no active recording is running starts a long input session.
- R3: Pressing `Right Command + .` while long input is recording stops that long session and enters finalization.
- R4: Pressing `Right Option` while long input is recording abandons the long session and immediately starts a short session.
- R5: Pressing `Right Command + .` while short input is recording abandons the short session and immediately starts a long session.
- R6: Pressing either input-start shortcut while a previous session is finalizing, correcting, routing output, or still showing the final floating panel abandons the previous session and starts the requested new session.
- R7: Abandoned sessions must not write history, update the current floating panel with stale text, or route output after replacement.
- R8: New session UI must immediately replace stale final text with a non-text listening indicator until the first partial text arrives.
- R9: `Option + Space` must no longer be the documented or default long input shortcut.
- R10: Esc cancellation remains available for the active session and does not copy or paste.

## Constraints

- Keep local-first behavior; no network or cloud dependency changes.
- Preserve focus routing and output safety rules.
- Treat already-issued paste operations as non-reversible.
- Avoid broad refactors outside the hotkey/session/panel boundary.

## Dependencies

- Existing `HotkeyController`, `HotkeyStateMachine`, `AppController`, `FloatingPanelController`, and paste safety components.
- Existing Swift/XCTest test infrastructure.

## Related PMB context

- `project_memory_bank/core/project_brief.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/core_logic/summary.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
- `project_memory_bank/integration/output_safety_flow.md`
