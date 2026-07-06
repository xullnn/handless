# Requirements — Audio Stop Boundary And Service Shutdown Hardening

## Problem

Closed-alpha testing found two hardening issues in the current distributable app path:

- After releasing the recording hotkey, a short tail from the previous utterance can appear at the start of the next input.
- The bundled Qwen3 service log can show `resource_tracker: There appear to be 1 leaked semaphore objects to clean up at shutdown`, which suggests the app is terminating the Python/MLX service abruptly.

The first issue affects dictated text correctness and must be fixed before broader friend/colleague testing. The second issue is currently a cleanup warning rather than a functional failure, but the app-managed closed-alpha runtime should try a graceful service shutdown before force termination.

## Scope

### IN

- Stop accepting live microphone PCM immediately when the user releases the hotkey or stops long-draft input.
- Remove idle microphone pre-roll from the closed-alpha runtime path so post-release room audio cannot be prepended to the next session.
- Keep the final flushed PCM that was captured before stop, so normal final recognition does not lose the last legitimate syllable.
- Preserve stale-session isolation for replacement, cancel, and late audio callbacks.
- Add regression tests for late live PCM after stop and next-session isolation.
- Add a local HTTP shutdown endpoint to the Qwen3 segmented service.
- Make the app-managed bundled Qwen3 service request graceful shutdown before terminating the process.
- Align the Qwen3 segmented service and runner scripts so they no longer expose or pass the removed `--max-tokens` runtime argument.
- Add automated tests or self-tests for the shutdown contract where practical.

### OUT

- Full service auto-restart policy.
- Public notarized distribution.
- New settings UI for audio latency or pre-roll preferences.
- Model quality changes, ASR prompt changes, or segment-boundary policy changes.
- VM or friend-machine reinstall unless separately requested after a new package is built.

## Requirements

- R1: Releasing the recording hotkey must close the live audio session gate before any later tap callback can send PCM to ASR.
- R2: `AudioCapture` must not keep recording while idle merely to maintain a pre-roll buffer.
- R3: `AudioCapture.stopAndFlush` must drain already buffered PCM captured before stop, then stop the audio engine and clear capture buffers.
- R4: `AudioCapture.cancel` must stop the audio engine and clear capture buffers without sending output.
- R5: Late audio chunks carrying an old `AudioSessionToken` must not reach the active or next ASR client.
- R6: Flushed stop-time chunks must still be sent to the active ASR client and counted for the minimum-audio guard.
- R7: The Qwen3 segmented HTTP service must expose a local `/shutdown` request that returns successfully and exits the `serve_forever` loop.
- R8: `BundledQwenASRServiceManager.stopManagedService()` must try the service shutdown request for app-owned processes before falling back to `terminate()` / `interrupt()`.
- R9: Qwen3 segmented service entrypoints and runner scripts must agree on supported runtime arguments.
- R10: Existing closed-alpha app behavior, output routing, audio ducking, cancellation, and replacement behavior must remain intact.

## Constraints

- The app remains local-only; no audio or text upload is introduced.
- macOS microphone permissions remain user-controlled.
- The Qwen3 service uses single-threaded `HTTPServer` for request handling because MLX inference has shown thread-affinity sensitivity. The shutdown request may use a small helper thread only to unblock `serve_forever`.
- The app must not shut down a compatible service it did not launch itself.

## Dependencies

- `2026-07-05-session-coordinator-integration-tests`
- `2026-07-05-output-audio-ducking`
- `2026-07-05-macos-alpha-distribution`
- `2026-07-06-closed-alpha-lifecycle-ergonomics`

## Related PMB context

- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/packaging_ops/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
