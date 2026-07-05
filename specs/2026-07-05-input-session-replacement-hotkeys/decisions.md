# Decisions — Input Session Replacement Hotkeys

## Confirmed decisions

- D1: New input intent should replace any unfinished prior input instead of being silently ignored.
- D2: Long input default shortcut changes to `Right Command + .`.
- D3: `Option + Space` is no longer the default long input shortcut and short-to-long conversion is removed from default behavior.
- D4: If a paste has already been issued, the app does not attempt to undo it; replacement only prevents stale session state from continuing to drive UI/history/output.
- D5: New session start should show a non-text listening indicator rather than "正在等待语音".
- D6: Asynchronous paste verification is now part of this feature because manual testing showed synchronous verification could block the main event loop during the final-panel re-record window.

## Open questions / unresolved choices

- Configurable shortcuts are deferred to a separate future feature.
- The remaining deeper test architecture question is whether to extract an AppController session coordinator for fake-driven integration tests.

## PMB promotion candidates

- Promote the new default shortcut and replacement interaction after validation.
