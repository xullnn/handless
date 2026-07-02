# Decisions — Simple Numeric ITN

## Confirmed decisions

- D1: Start with the simplest high-confidence numeric scenarios. Complex large-number handling is not part of the first version and may never be product scope unless real usage proves it is needed.
- D2: Strong decimal structure such as `零点六` is enough to convert to `0.6`; a trailing unit such as `B` is not required.
- D3: Unit and label context should increase confidence for integer or digit-sequence conversion, but ITN must only rewrite the numeric span and must not invent new units or semantics.
- D4: The first App integration should apply to final output only by default. Partial/floating-panel ITN is a later optional feature.
- D5: Prompt-based ASR numeric formatting is not the default solution because the validated prompt A/B result improved only a subset of numeric cases and added latency.
- D6: The first implementation is Swift Core-only. A Python eval/reporting prototype is deferred until before/after numeric pass-rate reporting needs it.
- D7: The App/Core config flag is `numericITNEnabled`, defaulting to `false` for this implementation pass so the current running App behavior does not change until explicitly enabled. Temporary App launches can override only this setting with `--numeric-itn` or `--no-numeric-itn` without rewriting the user config file.
- D8: Percent, date/time, money, and broader large-integer normalization are not included in the first rule inventory. The decimal rule intentionally skips `百分之...` phrases to avoid half-normalized output such as `百分之3.5`.

## Open questions / unresolved choices

- None for the implemented conservative rule pass. Full validation and default enablement remain pending.

## PMB promotion candidates

- If validated, promote the durable decision that simple deterministic final-output numeric ITN is the preferred first-line solution for numeric formatting.
