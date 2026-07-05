# Validation - Output Audio Ducking During Recording

## Completion rule

This feature can be marked `passes=true` only when all required automated checks pass and manual smoke confirms real macOS playback is reduced and restored. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: Existing config files without `audioDucking` still decode successfully with ducking disabled.
- A2: Config can enable ducking and set target volume or mute behavior.
- A3: Starting real short input invokes ducking exactly once for the active session.
- A4: Starting real long input invokes ducking exactly once for the active session.
- A5: Stopping recording restores output before ASR finalization timeout waits.
- A6: Esc cancel restores output.
- A7: Replacing an active session restores the old ducking state before starting the new ducking state.
- A8: ASR/audio errors restore output even when the session is cleaned up through fallback/error handling.
- A9: Mock ASR sessions do not touch output audio.
- A10: Repeated restore paths are idempotent in tests.
- A11: The packaged app builds and launches.
- A12: Manual smoke confirms real playback volume lowers during recording and restores after recording.

## Automated checks

```bash
bash scripts/test.sh
swift build
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-05-output-audio-ducking/feature.json >/dev/null
git diff --check
```

## Manual smoke checks

- Play local audio, start short input with ducking enabled, confirm playback becomes quiet/muted, then release and confirm volume restores.
- Play local audio, start long input with ducking enabled, confirm playback becomes quiet/muted, then stop and confirm volume restores.
- Start recording with playback active, press Esc, confirm volume restores.
- Start long recording with playback active, replace it with short recording, confirm output does not get stuck low.
- If possible, disconnect or change the microphone during recording and confirm the app does not crash and output restores.

## Optional / not-applicable checks

- Per-app pause/resume checks are not applicable for this feature.
- Acoustic echo cancellation checks are not applicable for this feature.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Manual smoke results or skipped smoke rationale.
- Any restore edge cases observed.
- Whether feature matrix status is `implemented` or `validated`.
