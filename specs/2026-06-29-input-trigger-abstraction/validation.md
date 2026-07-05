# Validation - Input trigger abstraction for mouse and external devices

## Completion rule

This feature can be marked `passes=true` only when all required automated checks pass and the manual mouse-trigger smoke checks are recorded in `specs/progress.md`. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: Existing keyboard behavior is unchanged for Right Option push-to-talk, Right Command + `.` long draft, Option+Space pass-through, and Esc cancel.
- A2: Non-keyboard triggers are disabled by default.
- A3: A configured mouse push-to-talk gesture can start and stop a normal dictation session without changing output safety behavior.
- A4: A configured mouse long-draft gesture can start and stop long-draft mode without requiring the user to hold a keyboard key.
- A5: Push-to-talk and long draft remain mutually exclusive across trigger sources.
- A6: Esc cancel still stops audio, ASR, session state, and floating UI without copy or paste.
- A7: Trigger-source failure does not disable existing keyboard triggers or start recording unexpectedly.
- A8: Output routing remains governed by focus, secure-field, focus-change, paste verification, and clipboard policy.

## Automated checks

```bash
swift build
swift test
```

Required test coverage:

- Keyboard push-to-talk lifecycle remains unchanged.
- Right Command + `.` long-draft lifecycle remains unchanged.
- Option+Space remains non-default/pass-through for long draft.
- Esc cancellation remains unchanged.
- Mouse source disabled by default.
- Mouse push-to-talk start/stop lifecycle through a fake event source.
- Mouse long-draft toggle lifecycle through a fake event source.
- Cross-source conflict behavior: push-to-talk stop does not stop long draft.
- Duplicate event debouncing.
- Trigger-source install failure is reported without starting a session.

## Manual smoke checks

- Enable a mouse push-to-talk gesture in local config.
- Confirm the same gesture works in Apple Notes and writes final text through the existing output path.
- Confirm a browser page with no focused input still routes to clipboard draft.
- Confirm secure/password fields still route to clipboard draft.
- Confirm Right Command + `.` keyboard long draft still works after mouse triggers are enabled.
- Confirm Option+Space does not become the default long-draft shortcut after mouse triggers are enabled.
- Confirm Esc cancels both keyboard-started and mouse-started sessions.
- Confirm the app shows clear diagnostics if Input Monitoring or Accessibility permission is missing.

## Optional / not-applicable checks

- Real hardware testing for every mouse vendor is not required for this MVP contract.
- External device plugin support is not required for this feature; it is a follow-up candidate.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Tests added or updated.
- Manual hardware and app smoke results.
- Any skipped checks and the reason.
- Remaining risks or blocked devices.
