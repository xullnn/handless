# Requirements — Simple Numeric ITN

## Problem

The current Qwen3-ASR 0.6B segmented route is the default local ASR baseline, but numeric expressions are often emitted as spoken Chinese text, such as `零点六` or `十六KB`, instead of the more useful written forms `0.6` or `16KB`.

Prompt-based numeric formatting improves a few cases but increases latency and is not reliable enough to enable by default. The safer next step is a local deterministic inverse text normalization (ITN) pass for simple, high-confidence numeric patterns.

## Scope

### IN

- Add a local numeric ITN path for simple, high-confidence numeric expressions.
- Start with conservative rules that are easy to reason about and easy to disable.
- Treat strong numeric shapes as sufficient conversion signals without requiring a trailing unit:
  - `零点六` -> `0.6`
  - `三点一四` -> `3.14`
  - `一点二点三` -> `1.2.3`
- Treat unit or label context as an additional confidence signal, not as the only trigger:
  - `零点六B` -> `0.6B`
  - `十六KB` -> `16KB`
  - `一八一零五端口` -> `18105端口`
  - `验证码是八零六二一九` -> `验证码是806219`
- Preserve all non-numeric words and units exactly as ASR produced them unless the rule explicitly converts the numeric span.
- Apply to final output first. Partial/floating-panel normalization is out of default scope until final-output behavior is validated.
- Record enough debug information to inspect what changed when testing the ITN path.

### OUT

- Do not use cloud services or LLM correction.
- Do not change the ASR model choice or Qwen3 segmented service contract.
- Do not add semantic correction beyond numeric text formatting.
- Do not add units or meaning that ASR did not output.
- Do not attempt broad natural-language number rewriting.
- Do not attempt complex or large-number normalization in the first version, including examples such as `九千九百九十九万点一零三四` or mixed spoken forms like `9999万.1034`.
- Do not convert ambiguous approximate phrases such as `十几个`, `几十个`, `一两天`, `三四次`.
- Do not convert idioms or non-numeric phrases such as `千万不要`, `一点也不`, `一二三木头人`.

## Requirements

- R1: The ITN implementation must be fully local, deterministic, and testable without microphone input.
- R2: The default rule set must prioritize low false positives over maximum numeric coverage.
- R3: Decimal expressions using `点` with Chinese digit characters must be converted even when no unit follows the number.
- R4: Version-like expressions with repeated `点` between numeric parts may be converted when all parts are simple numeric spans.
- R5: Digit-by-digit sequences may be converted when the form is explicit or the surrounding context is strong, such as verification code, ID, port, model version, or sample number.
- R6: Integer expressions such as `十六` should require context in the first version unless they appear inside an explicitly numeric construction.
- R7: The ITN path must be configurable and easy to disable.
- R8: The first production integration must apply to final text only by default.
- R9: The existing safety rules for password fields, focus downgrade, clipboard retention, paste fallback, and cancel must not be weakened.
- R10: Numeric benchmark reporting must distinguish ASR accuracy from numeric-format pass rate, because converting spoken-form references to Arabic digits can worsen CER/WER while improving product usefulness.

## Constraints

- Keep the app local-first. Do not upload audio or text.
- Do not enable the numeric-style ASR system prompt by default as a substitute for ITN.
- Do not reintroduce cumulative recompute routing.
- Keep the first implementation small enough to review and manually reason about.

## Dependencies

- `2026-07-01-qwen3-segmented-regression-suite`
- `2026-07-02-full-asr-model-benchmark`
- `2026-07-02-qwen3-06b-prompt-ab-benchmark`

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/core/system_overview.md`
- `project_memory_bank/modules/asr_audio/summary.md`
