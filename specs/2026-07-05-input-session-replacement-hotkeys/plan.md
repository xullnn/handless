# Plan — Input Session Replacement Hotkeys

## Implementation sequence

1. Update `HotkeyStateMachine` so it models `Right Option` short input and `Right Command + .` long input without `Option + Space` conversion semantics.
2. Update `HotkeyController` event detection for right Command and period, and route replacement intents to the app controller.
3. Update `AppController` with a replacement-aware session start path that can abandon an existing session without copying, pasting, writing history, or showing a cancelled result.
4. Add a floating-panel listening indicator API and use it at new session start so stale final text is immediately replaced.
5. Adjust keyboard simulation to release right-side modifier keys before synthetic paste.
6. Update tests for the new state-machine behavior and replacement scenarios where practical.
7. Update README/manual smoke docs for the new shortcuts.

## Touched areas

- `Sources/LocalVoiceInputCore/HotkeyStateMachine.swift`
- `Sources/LocalVoiceInputMac/HotkeyController.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/FloatingPanelController.swift`
- `Sources/LocalVoiceInputMac/KeyboardSimulator.swift`
- `Tests/LocalVoiceInputCoreTests/HotkeyStateMachineTests.swift`
- `README.md`
- `eval/focus_cases.md`

## Validation implementation notes

- Add or update pure Swift tests for the hotkey state machine.
- Run `swift test`.
- Run `swift build`.
- Run `scripts/status_localvoiceinput.sh` as a read-only runtime sanity check if the app is running.

## PMB promotion candidates

- `project_memory_bank/core/project_brief.md`: default long input shortcut changes from `Option+Space` to `Right Command + .`.
- `project_memory_bank/modules/core_logic/summary.md`: hotkey state machine behavior changes.
- `project_memory_bank/modules/macos_app/summary.md`: floating panel listening behavior and shortcut behavior changes.
- `project_memory_bank/integration/output_safety_flow.md`: session start trigger and replacement behavior changes.

## Risks and mitigations

- Risk: `Command + .` may conflict with some app-level cancel commands if LocalVoiceInput is not running or lacks permissions.
  Mitigation: consume the shortcut when event tap is healthy and record configurable hotkeys as a follow-up.
- Risk: Replacing a session while paste verification is already in progress cannot undo a paste.
  Mitigation: do not attempt undo; ensure stale completions cannot update current session UI or history.
- Risk: Hotkey state and app session state can diverge during replacement.
  Mitigation: centralize replacement through AppController and keep stale ASR callback guards.

## Notes

- First implementation pass keeps shortcuts hard-coded.
- `Option + Space` may remain unhandled or pass through; it should not be the default long input shortcut.
