# Plan - Input trigger abstraction for mouse and external devices

## Implementation sequence

1. Introduce a small core trigger-action model that represents source-neutral actions and active-session conflict behavior.
2. Refactor the current keyboard event path behind a keyboard trigger source without changing observable Right Option, Option+Space, or Esc behavior.
3. Add a trigger coordinator in the macOS app that owns source registration, source health, and dispatch into existing `AppController` session methods.
4. Add local configuration for enabled sources and gesture mappings, with all non-keyboard sources disabled by default.
5. Add a mouse trigger source behind the configuration flag.
6. Add diagnostics for event tap install failures, missing permissions, unsupported button events, and source recovery.
7. Add automated tests for trigger lifecycle, conflict handling, disabled-by-default behavior, and regression coverage for existing keyboard hotkeys.
8. Run manual smoke tests with at least one Bluetooth mouse and one app input field path before considering the feature validated.

## Touched areas

- `Sources/LocalVoiceInputCore/`
- `Sources/LocalVoiceInputMac/HotkeyController.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/AppConfig.swift`
- `Sources/LocalVoiceInputMac/PermissionManager.swift`
- `Tests/LocalVoiceInputCoreTests/`
- `Tests/LocalVoiceInputMacTests/`
- `configs/`
- `scripts/` only if a manual smoke helper is useful

## Validation implementation notes

- Keep current keyboard tests as the first regression boundary.
- Add pure logic tests for source-neutral trigger actions and mutual exclusion.
- Add macOS seam tests with fake event sources instead of relying on real CGEvents in unit tests.
- Keep manual mouse tests separate from automated CI-style checks because hardware event delivery is environment-dependent.

## PMB promotion candidates

- Promote only after validation if the trigger abstraction becomes durable architecture.
- Candidate PMB areas: `project_memory_bank/core/system_overview.md`, `project_memory_bank/modules/core_logic/summary.md`, and `project_memory_bank/modules/macos_app/summary.md`.

## Risks and mitigations

- Risk: Mouse triggers conflict with ordinary app interactions.
  Mitigation: Keep non-keyboard triggers off by default and prefer low-conflict gestures.
- Risk: Event tap behavior differs across devices or macOS versions.
  Mitigation: Add diagnostics and manual hardware smoke checks.
- Risk: Trigger abstraction accidentally changes existing keyboard behavior.
  Mitigation: Refactor behind tests first and validate keyboard paths before enabling new sources.
- Risk: A trigger source starts or stops the wrong session mode.
  Mitigation: Keep the core session state machine authoritative for conflict handling.

## Notes

- This feature is a trigger-source architecture change only. It must not change ASR routing, paste behavior, clipboard policy, or floating-panel behavior except as observable consequences of starting or stopping the same existing session types.
