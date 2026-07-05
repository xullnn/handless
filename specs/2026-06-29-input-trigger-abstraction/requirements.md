# Requirements - Input trigger abstraction for mouse and external devices

## Problem

LocalVoiceInput currently depends on keyboard shortcuts for all dictation entry points. This works well at the desk, but it is awkward when the user is away from the keyboard and using a Bluetooth mouse or another external controller. The app needs a trigger layer that can accept non-keyboard input without weakening the existing hotkey, focus, paste, clipboard, and cancellation safety contracts.

## Scope

### IN

- Define a source-agnostic trigger action model for dictation actions.
- Preserve current keyboard behavior for Right Option push-to-talk, Right Command + `.` long draft, and Esc cancel.
- Allow future mouse trigger sources to map hardware events to the same dictation actions.
- Require non-keyboard triggers to be opt-in and configurable.
- Define safety, conflict, debounce, and permission expectations for global event sources.
- Keep trigger handling separate from ASR backend selection and output routing.

### OUT

- No InputMethodKit rewrite.
- No partial text insertion into the active app.
- No cloud service, remote trigger broker, or uploaded input telemetry.
- No implementation in this contract creation pass.
- No default hijacking of ordinary left-click or right-click behavior.
- No guarantee that every mouse vendor exposes all buttons consistently on macOS.

## Requirements

- R1: The current keyboard contracts must remain unchanged: Right Option hold starts and releases push-to-talk, Right Command + `.` toggles long draft, Option+Space is not the default long-draft shortcut, and Esc cancels an active session.
- R2: Trigger handling must normalize source-specific events into a small action set: `startPushToTalk`, `stopPushToTalk`, `toggleLongDraft`, and `cancel`.
- R3: The session state machine must remain the authority for conflict handling. A trigger source cannot directly bypass active-session checks in `AppController` or core session logic.
- R4: Push-to-talk and long draft remain mutually exclusive. A push-to-talk stop event from any source must not stop an active long-draft session.
- R5: Mouse and external-device triggers must be disabled by default until the user explicitly enables them.
- R6: The first mouse trigger candidates should prefer low-conflict gestures, such as middle-button hold for push-to-talk or side-button double-click for long draft. Simultaneous left+right click may be supported only as an experimental, opt-in gesture.
- R7: Trigger sources must debounce repeated hardware events so one physical gesture cannot create duplicate start/stop/toggle transitions.
- R8: Trigger sources must expose diagnostics for missing Accessibility/Input Monitoring permissions, event tap failure, and source startup failure.
- R9: Trigger sources must fail closed. If a source cannot be installed or loses its event tap, the app must keep existing keyboard triggers working and must not start recording unexpectedly.
- R10: Trigger configuration must be represented in local config only. No trigger history or raw input event stream should be uploaded or persisted by default.

## Constraints

- Preserve local-first privacy and safety.
- Do not weaken secure-field, focus-change, clipboard, paste-verification, or Esc-cancel behavior.
- Do not make non-keyboard triggers default-on in the MVP.
- Avoid consuming ordinary mouse events unless the configured gesture intentionally requires it and the risk is documented.
- Keep implementation testable with pure core state-machine tests plus macOS event-source seams.

## Dependencies

- Existing `LocalVoiceInputCore` hotkey/session state-machine behavior.
- Existing `LocalVoiceInputMac` global event tap permission path.
- Existing output safety contracts for focus detection, clipboard, and paste fallback.

## Related PMB context

- `project_memory_bank/core/project_brief.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/modules/core_logic/summary.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
- `specs/2026-07-05-input-session-replacement-hotkeys/`
