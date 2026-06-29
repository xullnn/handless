# Validation - ASR model profile management

## Completion rule

This feature can be marked `passes=true` only when all required checks pass and profile behavior is recorded in `specs/progress.md`. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: The profile registry can describe current local ASR candidates without hard-coding them into app control flow.
- A2: Auto selection chooses only available and compatible local profiles.
- A3: Manual selection wins when compatible and locally available.
- A4: Missing assets or incompatible hardware produce actionable diagnostics.
- A5: Fallback never uses cloud and never uploads audio or text.
- A6: No profile switch can occur while a dictation session is active or finalizing.
- A7: Health/status reports include active profile id, backend type, local-only status, model path or model id, and resource diagnostics where available.
- A8: Existing hotkey, focus, paste, clipboard, ASR session isolation, and floating-panel behavior still pass tests.

## Automated checks

```bash
swift build
swift test
python3 -m json.tool specs/feature_matrix.json >/dev/null
```

Required test coverage:

- Valid profile registry parsing.
- Missing model path diagnostics.
- Manual profile selection.
- Auto profile selection.
- Unsupported hardware/resource threshold diagnostics.
- Local-only fallback.
- No mid-session switching.
- Existing `LocalHTTPASRClient` session-token filtering remains intact.
- Existing FunASR/mock backend selection still works.

## Manual smoke checks

- Start the app with the current Qwen3-ASR MLX 0.6B local HTTP profile and confirm dictated text reaches the expected output route.
- Start the app with mock ASR and confirm profile changes do not break manual interaction tests.
- Start with a deliberately missing model path and confirm the app reports an actionable local error.
- Confirm no cloud endpoint is contacted during profile selection or fallback.
- Confirm status output identifies the active local profile.

## Optional / not-applicable checks

- Full benchmark reruns for every candidate model are not required for this profile-management feature.
- User-facing model selection UI is not required unless explicitly moved into scope.
- Automatic model download is not required and should remain out of scope for this feature.

## Evidence required in `specs/progress.md`

- Commands run and results.
- Profile fixtures tested.
- Manual smoke results.
- Local-only/fallback evidence.
- Skipped checks and rationale.
- Remaining model-selection risks.
