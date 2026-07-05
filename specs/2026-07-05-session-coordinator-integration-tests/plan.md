# Plan — Session Coordinator Integration Tests

## Implementation sequence

1. Add internal protocols for the app coordinator dependencies that need fakes in tests: menu, panel, hotkeys, focus detector, audio capture, paste routing, history recording, ASR client creation, and scheduling where needed.
2. Add an `AppController.Dependencies` initializer path for tests while preserving the existing production `init(config:)`.
3. Make existing production collaborators conform to the new internal protocols with minimal code movement.
4. Add fake test collaborators under `Tests/LocalVoiceInputMacTests`.
5. Add integration-style tests for the highest-risk session lifecycle scenarios.
6. Update manual focus/smoke documentation for the split between automated coordinator tests and physical macOS smoke.
7. Run required validation and record SDD evidence.

## Touched areas

- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/ASRClientProtocol.swift`
- `Sources/LocalVoiceInputMac/AudioCapture.swift`
- `Sources/LocalVoiceInputMac/FocusDetector.swift`
- `Sources/LocalVoiceInputMac/FloatingPanelController.swift`
- `Sources/LocalVoiceInputMac/HotkeyController.swift`
- `Sources/LocalVoiceInputMac/MenuBarController.swift`
- `Sources/LocalVoiceInputMac/PasteEngine.swift`
- `Sources/LocalVoiceInputMac/HistoryStore.swift`
- `Tests/LocalVoiceInputMacTests/AppControllerSessionTests.swift`
- `eval/focus_cases.md`

## Validation implementation notes

- Add tests that drive sessions through fake hotkey callbacks instead of real global events.
- Use fake ASR clients to emit stale and current events deterministically.
- Use fake paste router with held completions to reproduce the final-panel re-record window.
- Use fake focus detector snapshots to verify focus-change downgrade.
- Keep real CGEvent/AX/microphone checks as manual smoke only.

## PMB promotion candidates

- `project_memory_bank/modules/macos_app/summary.md`: mention that `AppController` has internal test seams for coordinator integration tests if validated.
- `project_memory_bank/modules/output_safety/summary.md`: mention automated coverage for stale paste completion and cancellation invariants if validated.

## Risks and mitigations

- Risk: Protocol extraction could accidentally change production initialization.
  Mitigation: preserve `AppController(config:)` and instantiate the same real objects through a production dependency factory.
- Risk: Tests could overfit fake behavior and miss macOS integration problems.
  Mitigation: keep the manual smoke checklist for CGEvent, AX, permissions, focus, and real paste.
- Risk: Adding too many protocols could make the code harder to read.
  Mitigation: keep protocols narrow and only cover AppController-facing methods.

## Notes

- This feature is a testability and regression-coverage feature. It should not change end-user behavior.
