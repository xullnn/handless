# Validation — Input Session Replacement Hotkeys

## Completion rule

This feature can be marked `passes=true` only when required automated checks pass and manual smoke is either completed or explicitly recorded as not run with rationale.

## Acceptance criteria

- A1: `Right Option` still starts/stops short push-to-talk.
- A2: `Right Command + .` starts long input when idle and stops it when long input is actively recording.
- A3: `Option + Space` is no longer the default long input shortcut in code tests or docs.
- A4: A new input intent can replace an existing recording or finalizing session without the old session writing history or output.
- A5: New session start immediately clears stale final text and shows a non-text listening indicator.
- A6: Existing stale ASR callback guards remain in place.
- A7: Esc cancellation remains no-copy/no-paste behavior.

## Automated checks

```bash
swift test
swift build
```

Additional focused automated coverage should include:

- Audio session token/generation isolation so queued chunks from an abandoned session cannot enter the replacement session.
- Physical hotkey interpretation for `Right Option`, `Right Command + .`, left Command non-trigger behavior, repeat handling, and `Option + Space` pass-through.
- Paste key event planning that releases right-side trigger modifiers before synthetic `Cmd+V`.
- Non-word listening indicator frame generation.
- Asynchronous paste verification so cursor-paste confirmation does not block hotkey handling during the final-panel re-record window.

## Manual smoke checks

- Short input normal path: hold `Right Option`, speak, release, verify output.
- Short input replacement: release `Right Option`, immediately press `Right Option` again before final output fully settles; verify new recording starts.
- Short-to-long replacement: while short input is recording or finalizing, press `Right Command + .`; verify old session is abandoned and long input starts.
- Long input normal path: press `Right Command + .`, speak, press `Right Command + .` again, verify final output.
- Long-to-short replacement: while long input is recording or finalizing, press `Right Option`; verify old long session is abandoned and short input starts.
- Floating panel: verify stale final text is replaced by a non-text listening indicator on new session start.

## Optional / not-applicable checks

- Full manual smoke may be recorded as pending if automated checks pass but user needs immediate app availability; this must be noted in `specs/progress.md`.

## Evidence required in `specs/progress.md`

- Commands run.
- Test results.
- Manual smoke status.
- Any skipped checks with rationale.
- Residual risks or follow-ups.
