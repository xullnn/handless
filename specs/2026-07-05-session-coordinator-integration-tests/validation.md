# Validation — Session Coordinator Integration Tests

## Completion rule

This feature can be marked `passes=true` only when the required automated checks pass and validation evidence is recorded in `specs/progress.md`. Manual macOS smoke is recommended but not required for this testability-only change if no production behavior changes are intended beyond dependency injection.

## Acceptance criteria

- A1: `AppController(config:)` still wires the real production collaborators by default.
- A2: Tests can drive short and long session lifecycle without real microphone, AX, CGEvent, or ASR service.
- A3: A delayed paste completion from an abandoned session cannot update the active session panel or history.
- A4: A stale ASR final from an abandoned session cannot update the active session panel or history.
- A5: Stale audio chunks from an abandoned session cannot be sent to the new ASR client.
- A6: Short-to-long, long-to-short, and finalizing-to-new-session replacement paths are covered.
- A7: Esc cancellation remains no-copy/no-paste/no-history.
- A8: Focus change during recording is covered and downgrades output away from cursor paste.
- A9: Too-short real-audio sessions are covered and do not route output.

## Automated checks

```bash
swift test
swift build
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-05-session-coordinator-integration-tests/feature.json >/dev/null
git diff --check
```

## Manual smoke checks

- Optional for this feature unless production behavior is changed beyond test seams.
- Existing high-priority physical smoke remains in `eval/focus_cases.md`.

## Optional / not-applicable checks

- Real ASR service smoke is not required because this feature does not change ASR transport behavior.
- Real global keyboard-event automation is not required because hotkey interpretation is already covered separately and this feature targets coordinator lifecycle logic.

## Evidence required in `specs/progress.md`

- Commands run.
- Test results.
- Manual smoke status or not-applicable rationale.
- Residual risks or follow-ups.
