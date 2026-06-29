# Decisions - Input trigger abstraction for mouse and external devices

## Confirmed decisions

- D1: This contract creation pass does not implement runtime changes.
- D2: Existing keyboard shortcuts remain the default and must not regress.
- D3: Non-keyboard triggers are opt-in and disabled by default.
- D4: Trigger sources dispatch into the same existing dictation actions instead of creating a separate mouse-only session path.
- D5: Simultaneous left+right click is not a safe default because it may conflict with ordinary app interaction. It can only be treated as an experimental opt-in gesture.

## Open questions / unresolved choices

- Which mouse gesture should become the first recommended default after hardware testing: middle-button hold, side-button hold/double-click, or another low-conflict gesture?
- Should trigger configuration ship first as JSON/config only, or should it include an app menu/settings UI in the same implementation feature?
- Should configured mouse trigger events be consumed, passed through, or handled per gesture type?
- How should source health be surfaced to the user: floating-panel diagnostic, menu item, notification, or logs only?
- Which additional external devices should be considered first after mouse support is validated?

## PMB promotion candidates

- Promote the trigger-source architecture to PMB only after implementation and validation.
