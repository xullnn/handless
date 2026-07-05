# Requirements - Output Audio Ducking During Recording

## Problem

When the Mac is playing music, video, meetings, or other audio while the user starts dictation, that playback can be picked up by the microphone and reduce ASR quality. The app should reduce local system playback while microphone recording is active, then restore it after recording ends.

## Scope

### IN

- Add a configurable recording-time output audio ducking policy.
- Reduce or mute the current default macOS output device while real microphone recording is active.
- Restore the previous output volume/mute state when recording stops, is cancelled, is replaced by a new session, or errors.
- Preserve safe behavior when restore is called more than once.
- Keep the feature local-only and independent of ASR backend.
- Add automated coverage through dependency-injected fakes.

### OUT

- Do not pause or resume individual media apps such as Music, Spotify, Chrome, Safari, or video players.
- Do not implement acoustic echo cancellation or voice-processing capture modes in this feature.
- Do not build the future visual settings panel in this feature.
- Do not change microphone capture chunking, ASR service behavior, paste routing, or correction behavior.

## Requirements

- R1: `AppConfig` must expose an `audioDucking` configuration block with defaults that are safe for distribution.
- R2: Ducking must be disabled by default in code/config examples unless explicitly enabled by config or command line.
- R3: When enabled and a real microphone session starts, the app must store the current default output device id, output volume, and mute state before changing volume.
- R4: When enabled, the app must either lower output volume to a configured target level or mute output, depending on config.
- R5: Ducking must begin for short input and long input sessions, but not for mock ASR sessions.
- R6: Output must be restored when microphone recording ends after user stop, before waiting for slow ASR finalization.
- R7: Output must be restored on Esc cancellation, session replacement, ASR/audio error, and app shutdown best-effort paths.
- R8: Restore must be idempotent and session-safe; stale restore calls from an old session must not damage a newer ducking session.
- R9: If CoreAudio volume access fails, the app must continue recording and surface no blocking failure to the user.
- R10: The status script and config docs must report the configured ducking behavior.

## Constraints

- This feature must operate through macOS CoreAudio default output device volume/mute controls, not AppleScript.
- The app is a menu-bar utility and should not take focus to manage audio state.
- The feature must not require network access or upload audio/text.
- The first implementation should favor reducing crash/restore risk over aggressive media control.

## Dependencies

- `2026-07-05-session-coordinator-integration-tests` provides AppController dependency seams for fake-driven lifecycle tests.

## Related PMB context

- `project_memory_bank/core/project_brief.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
