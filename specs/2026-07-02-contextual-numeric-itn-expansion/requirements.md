# Requirements - Contextual Numeric ITN Expansion

## Problem

The validated first NumericITN pass intentionally avoided several common numeric forms because broad Chinese number rewriting is risky. Some excluded forms are still high-confidence when the surrounding text supplies a narrow context, such as a technical unit, a percent marker, or a document/ordinal suffix.

This feature expands the local deterministic ITN rule set without changing the core product boundary: local-only, final-output first, no LLM correction, no ASR model changes, and no return to cumulative recompute.

## Scope

### IN

- Convert bounded Chinese integer expressions in strong technical-unit context:
  - `九百六十四 MB` -> `964MB`
  - `一百二十八GB` -> `128GB`
  - `一千零二十四 KB` -> `1024KB`
  - `两千零四十八MB` -> `2048MB`
- Convert complete percent expressions as a whole:
  - `百分之三点五` -> `3.5%`
  - `百分之十六` -> `16%`
  - `百分之零点六` -> `0.6%`
- Convert narrow ordinal/document-style integer contexts:
  - `第十六页` -> `第16页`
  - `第十六个` -> `第16个`
  - `十六号` -> `16号`
  - `十六页` -> `16页`
- Keep first-version behavior for decimals, version-like expressions, digit sequences, and small technical-unit integers.
- Add positive and negative unit tests before broad validation.
- Keep rules deterministic, local, and easy to disable through the existing `numericITNEnabled` flag.
- Record cases that remain unsafe or unstable as deferred/abandoned rather than forcing broad conversion.

### OUT

- Do not convert bare integers such as `十六` with no strong context.
- Do not convert broad natural-language quantities such as `一百个理由` or `九百六十四个样本`.
- Do not handle `万` or `亿` magnitude numbers.
- Do not handle date, time, money, phone numbers, addresses, or full grammar-level Chinese numeral parsing.
- Do not change realtime partial/floating-panel behavior.
- Do not change ASR model selection, prompts, segmented-cache service behavior, or local/cloud boundaries.

## Requirements

- R1: Technical-unit integer conversion must support `十/百/千` forms up to a bounded small range and must fail closed on unsupported magnitudes.
- R2: Percent conversion must rewrite the complete `百分之...` phrase or leave it unchanged; half-normalized output such as `百分之3.5` is not acceptable.
- R3: Narrow ordinal/document-style conversion must require an explicit prefix/suffix whitelist.
- R4: Bare `十六` must remain unchanged.
- R5: Ambiguous approximate, idiomatic, or ordinary prose phrases must remain unchanged.
- R6: Existing validated NumericITN behavior must not regress.
- R7: Validation must include focused Swift unit tests and an offline numeric-format report against recorded summaries.
- R8: If a candidate rule creates unstable or overly broad behavior during testing, it should be abandoned and recorded rather than widened.

## Dependencies

- `2026-07-02-simple-numeric-itn`

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/core_logic/summary.md`
