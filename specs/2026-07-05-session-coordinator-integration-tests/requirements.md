# Requirements — Session Coordinator Integration Tests

## Problem

The previous input-session replacement work fixed a real daily-use issue where a new hotkey intent could be blocked while the previous result panel or paste verification was still settling. The highest-risk behavior now lives in `AppController`, where hotkeys, audio capture, ASR callbacks, focus snapshots, paste routing, floating-panel state, and history writes meet. Much of that lifecycle is still only verifiable through manual macOS smoke testing.

## Scope

### IN

- Add test seams around the macOS app session coordinator so tests can drive session lifecycle without real microphone input, real Accessibility focus inspection, real CGEvent paste, or a real ASR service.
- Preserve the existing production `AppController(config:)` behavior and object wiring.
- Add automated integration-style Swift tests for cross-session lifecycle behavior, stale callback isolation, cancellation, focus-change downgrade, short-audio suppression, and replacement during asynchronous paste completion.
- Keep real macOS smoke testing as a separate manual validation layer.

### OUT

- Do not change the user-facing shortcut semantics from the validated hotkey feature.
- Do not introduce a new production session coordinator type unless it is required to make tests practical.
- Do not automate real global keyboard events, real Accessibility permissions, real microphone input, or real app focus changes in CI.
- Do not change ASR model selection, ASR service behavior, or local model caches.

## Requirements

- R1: Production app initialization must continue to use the real menu, panel, focus detector, hotkeys, audio capture, paste engine, history store, and ASR clients by default.
- R2: Tests must be able to inject fake ASR clients and emit partial/final/error callbacks on demand.
- R3: Tests must be able to inject fake audio capture and emit PCM chunks with session tokens on demand.
- R4: Tests must be able to inject fake focus snapshots and simulate focus changes during recording.
- R5: Tests must be able to inject fake paste routing and deliberately delay completion.
- R6: Tests must be able to observe floating-panel state transitions and history writes without creating real windows.
- R7: Automated coverage must include replacement across short/long modes and late callback isolation for ASR, audio, timeout, and paste completion paths where practical.
- R8: Esc cancellation must remain no-copy, no-paste, and no-history.

## Constraints

- Test seams should remain internal to the Swift module and should not create a public API promise.
- Production code should stay close to existing control flow; this is a testability hardening pass, not a broad architecture rewrite.
- Tests must run with `swift test` on the local Mac without requiring TCC prompts.

## Dependencies

- Depends on the validated `2026-07-05-input-session-replacement-hotkeys` behavior.

## Related PMB context

- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/modules/macos_app/summary.md`
- `project_memory_bank/modules/output_safety/summary.md`
- `project_memory_bank/modules/asr_audio/summary.md`
