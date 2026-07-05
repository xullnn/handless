# Plan - Output Audio Ducking During Recording

## Implementation sequence

1. Add `AudioDuckingConfig` to `AppConfig` with JSON decoding defaults.
2. Add a `SystemAudioDuckingControlling` dependency seam and production wiring.
3. Implement `CoreAudioOutputDucker` to capture default output device state, apply volume reduction or mute, and restore idempotently.
4. Wire `AppController` session lifecycle:
   - start ducking after a real session is accepted;
   - restore before final ASR wait after user stop;
   - restore on cancel, replacement, cleanup, error, and shutdown best effort.
5. Add fake-driven `AppControllerSessionTests` for lifecycle behavior.
6. Add `AppConfigTests` for JSON/default behavior.
7. Update `configs/config.example.json`, `scripts/write_default_config.sh`, `scripts/status_localvoiceinput.sh`, and `README.md`.
8. Run automated checks and rebuild the packaged app.

## Touched areas

- `Sources/LocalVoiceInputMac/AppConfig.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/AppControllerDependencies.swift`
- `Sources/LocalVoiceInputMac/CoreAudioOutputDucker.swift`
- `Tests/LocalVoiceInputMacTests/AppConfigTests.swift`
- `Tests/LocalVoiceInputMacTests/AppControllerSessionTests.swift`
- `configs/config.example.json`
- `scripts/write_default_config.sh`
- `scripts/status_localvoiceinput.sh`
- `README.md`
- `specs/feature_matrix.json`

## Validation implementation notes

- AppController tests should use a fake output ducker and should not depend on real CoreAudio.
- CoreAudio production behavior needs manual smoke because mutating the real default output device is a system side effect.
- Config validation should verify missing config remains backward-compatible.

## PMB promotion candidates

- `project_memory_bank/modules/macos_app/summary.md` after validated closeout if ducking becomes stable product behavior.
- `project_memory_bank/modules/asr_audio/summary.md` after validated closeout if the audio path summary should mention output-ducking around capture.

## Risks and mitigations

- Risk: The app crashes or is killed before restore.
  Mitigation: Keep target volume nonzero by default for personal config; make restore best-effort on shutdown; keep production defaults disabled.
- Risk: User manually changes volume while recording, and restore overwrites that manual change.
  Mitigation: First implementation restores the saved pre-duck state; record manual-change-sensitive restore as a future refinement if needed.
- Risk: Output device changes while recording.
  Mitigation: Restore only the saved device state when possible; do not block recording if restore fails.
- Risk: CoreAudio calls fail on unsupported devices.
  Mitigation: Treat duck/restore errors as non-fatal and continue recording.

## Notes

- The first product behavior is "lower local playback while the mic is active", not per-app media control.
