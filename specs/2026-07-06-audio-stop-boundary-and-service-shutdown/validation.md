# Validation — Audio Stop Boundary And Service Shutdown Hardening

## Completion rule

This feature can be marked `passes=true` only when required automated checks pass, the app and closed-alpha package rebuild successfully, and validation evidence is recorded in `specs/progress.md`. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: After the user stops recording, late live PCM using the stopped session token is rejected.
- A2: Stop-time flushed PCM is still sent to ASR and `finish()` is still called.
- A3: A new session does not receive late PCM from a previous session.
- A4: Cancel and replacement behavior remains stale-safe and does not route output.
- A5: `AudioCapture` no longer prepends idle pre-roll to a new recording session.
- A6: Stopping or cancelling a real capture tears down the audio engine and clears buffers.
- A7: The Qwen3 segmented service supports `/shutdown` and exits its serve loop cleanly in the self-test path.
- A8: The app-managed bundled service attempts graceful shutdown before forced process termination.
- A9: Qwen3 segmented service scripts do not pass unsupported runtime arguments to the service parser.
- A10: Existing automated macOS app tests, Swift build, app build, and alpha package checks still pass.

## Automated checks

```bash
python3 -m json.tool specs/2026-07-06-audio-stop-boundary-and-service-shutdown/feature.json >/dev/null
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m py_compile eval/asr_streaming/qwen3_mlx_segmented_cache_service.py eval/asr_streaming/qwen3_mlx_service_common.py
python3 eval/asr_streaming/qwen3_mlx_segmented_cache_service.py self-test
bash -n scripts/run_qwen3_mlx_segmented_app_smoke.sh scripts/run_qwen3_mlx_segmented_regression_gate.sh
bash scripts/test.sh
swift build
bash scripts/build_macos_app.sh
bash scripts/package_macos_alpha.sh --closed-alpha
bash scripts/package_macos_alpha.sh --verify-staged-runtime
hdiutil verify dist/LocalVoiceInput-0.1.0-alpha-closed-alpha-unnotarized.dmg
```

## Manual smoke checks

- Launch the rebuilt app and confirm normal short dictation still works.
- Start and stop two short recordings back to back; confirm the second result does not begin with the previous recording's tail.
- Confirm Esc cancellation still produces no copy/paste output.
- Confirm long-to-short and short-to-long replacement still work.
- Quit the app and check the Qwen service log for clean shutdown behavior. `resource_tracker` warnings should not newly appear during a normal app-managed quit.

## Optional / not-applicable checks

- Friend-machine reinstall is optional for this feature unless the user requests a new remote smoke.
- VM reinstall is optional because the core bug is covered by AppController regression tests and host package validation.
- Physical hotkey dictation smoke is recommended after the rebuilt app is in daily use, but it is not required for this closeout because the stop-boundary regression is covered by fake-driven session tests and Codex cannot produce reliable live microphone speech input.

## Evidence required in `specs/progress.md`

- Commands run and results.
- New or updated tests added.
- Built app and DMG path.
- Any skipped optional checks and reason.
- Manual smoke outcome if performed in this session.
