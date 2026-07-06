# Plan — Audio Stop Boundary And Service Shutdown Hardening

## Implementation sequence

1. Update `AudioCapture` so idle pre-roll is disabled, session stop/cancel stops the audio engine, and post-stop tap callbacks are discarded.
2. Update `AppController.finishSession()` so the live audio session gate closes as soon as the user stops, while stop-flush chunks are still delivered through a separate trusted flush path.
3. Add AppController regression tests for late live PCM after stop, flushed PCM preservation, and next-session isolation.
4. Add `/shutdown` to `qwen3_mlx_segmented_cache_service.py`, advertise it in metadata, and cover it with a lightweight self-test.
5. Align the Qwen3 segmented service common runtime and runner scripts around the supported service arguments.
6. Update `BundledQwenASRServiceManager` to remember the app-owned service URL and request graceful shutdown before process termination.
7. Add or update service-manager tests for shutdown request behavior that can be verified without loading the model.
8. Run the validation commands and rebuild the distributable app/package if tests pass.

## Touched areas

- `Sources/LocalVoiceInputMac/AudioCapture.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/BundledQwenASRServiceManager.swift`
- `Tests/LocalVoiceInputMacTests/AppControllerSessionTests.swift`
- `Tests/LocalVoiceInputMacTests/BundledQwenASRServiceManagerTests.swift`
- `eval/asr_streaming/qwen3_mlx_segmented_cache_service.py`
- `eval/asr_streaming/qwen3_mlx_service_common.py`
- `scripts/run_qwen3_mlx_segmented_app_smoke.sh`
- `scripts/run_qwen3_mlx_segmented_regression_gate.sh`

## Validation implementation notes

- Add fake-driven Swift tests for audio-session token behavior rather than trying to drive real AVAudioEngine in XCTest.
- Use the existing Python segmented-service `self-test` entrypoint for the handler-level shutdown contract.
- Keep package validation after unit tests so broken app logic does not produce a new closed-alpha artifact.

## PMB promotion candidates

- If validated, promote the durable policy that the closed-alpha runtime disables idle microphone pre-roll and stops the audio engine between sessions.
- If validated, promote the app-managed Qwen service shutdown contract.

## Risks and mitigations

- Risk: Removing pre-roll can slightly cut off speech if the user starts talking before the hotkey down event is processed.
  Mitigation: Closed-alpha correctness and privacy are higher priority than pre-roll convenience; the UI already requires holding Right Option before speaking.
- Risk: Closing the gate on stop might drop legitimate PCM still queued by the audio tap.
  Mitigation: Use `stopAndFlush` as the trusted final-drain path and send those chunks even after the live gate is closed.
- Risk: Calling `HTTPServer.shutdown()` from the request handler can deadlock.
  Mitigation: Schedule shutdown on a daemon helper thread after writing the response.
- Risk: Shutdown requests could affect a non-app-owned service.
  Mitigation: The Swift manager only sends `/shutdown` when it has a `managedProcess`, meaning the current app launched that process.

## Notes

- This pass does not change ASR model selection, numeric ITN, output audio ducking policy, or installer UX.
