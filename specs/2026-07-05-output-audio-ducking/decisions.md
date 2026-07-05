# Decisions - Output Audio Ducking During Recording

## Confirmed decisions

- D1: Implement system output ducking first, not per-app playback pause/resume.
- D2: Keep the feature configurable with distribution-safe defaults.
- D3: Attach duck/restore to `AppController` session lifecycle rather than `AudioCapture`, because the behavior spans short input, long input, cancellation, replacement, and errors.
- D4: Restore when microphone recording stops rather than waiting for ASR finalization, because playback no longer affects capture after the mic has stopped.
- D5: Treat CoreAudio failures as non-fatal; dictation should continue even if output ducking cannot be applied.

## Open questions / unresolved choices

- Whether the user's personal config should use `targetVolume=0.05`, `0.08`, or full mute after manual smoke.
- Whether future restore should detect and preserve user manual volume changes made during recording.

## PMB promotion candidates

- Promote the stable session-level ducking behavior to PMB after validation.
