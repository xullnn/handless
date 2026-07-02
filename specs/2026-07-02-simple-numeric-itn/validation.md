# Validation — Simple Numeric ITN

## Completion rule

This feature can be marked `passes=true` only when all required checks pass. A skipped check is acceptable only if this file marks it optional/not applicable or the user explicitly approves the skip.

## Acceptance criteria

- A1: Simple decimal expressions are converted without requiring a unit suffix, such as `零点六` -> `0.6` and `三点一四` -> `3.14`.
- A2: The same decimal expressions keep adjacent ASR output intact, such as `零点六B` -> `0.6B`.
- A3: Simple unit-context integers convert when the context is strong, such as `十六KB` -> `16KB`.
- A4: Digit-by-digit sequences convert only when explicit or strongly contextual, such as verification codes, ports, and IDs.
- A5: Ambiguous phrases and idioms remain unchanged.
- A6: ITN is configurable and can be disabled.
- A7: The first App integration applies to final output only by default.
- A8: Existing paste, clipboard, focus downgrade, secure-field, and cancel behavior is unchanged.
- A9: Numeric-format reporting separates numeric pass rate from CER/WER.

## Automated checks

```bash
swift test
```

Planned focused checks after implementation:

```bash
swift test --filter NumericITN
bash scripts/run_qwen3_mlx_segmented_regression_gate.sh
```

If an eval/reporting script is added, its shell syntax and Python syntax must also be checked:

```bash
bash -n scripts/<numeric-itn-script>.sh
python3 -m py_compile eval/asr_streaming/<numeric-itn-script>.py
```

## Manual smoke checks

- Dictate short decimal examples in a normal text editor and confirm final pasted/copied text uses Arabic digits.
- Dictate a phrase containing an ambiguous expression such as `一会儿` or `一点也不` and confirm it is not rewritten.
- Confirm disabling ITN restores raw ASR output.

## Optional / not-applicable checks

- Partial/floating-panel ITN validation is not required for this feature because partial normalization is explicitly out of default scope.
- Complex large-number normalization is not required for this feature.

## Evidence required in `specs/progress.md`

- Commands run.
- Test and eval result paths.
- Numeric pass rate before and after ITN.
- Base regression result before and after ITN.
- Any skipped checks with rationale.
- Manual smoke notes if App integration is enabled.
