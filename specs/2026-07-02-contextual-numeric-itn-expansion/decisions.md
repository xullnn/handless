# Decisions - Contextual Numeric ITN Expansion

## Confirmed decisions

- D1: Keep `十六` alone unchanged. The risk is not parsing difficulty; the risk is style and semantic overreach in ordinary dictation.
- D2: Allow `九百六十四 MB` because `MB` is a strong technical-unit suffix and the rule only rewrites the bounded numeric span.
- D3: Percent expressions must be handled before the generic decimal rule so `百分之三点五` becomes `3.5%`, not `百分之3.5`.
- D4: Ordinal/document-style conversion uses a whitelist instead of broad classifier conversion.
- D5: `万/亿`, dates, times, money, and broad natural-language quantities remain out of scope.
- D6: Candidate cases that need broad semantic interpretation should be recorded as deferred or abandoned rather than forcing a risky rule.

## Open questions / unresolved choices

- None at implementation start. Rule boundaries can be tightened during validation if tests expose false positives.

## Deferred / abandoned candidates

- `十六` alone remains no-op. Converting it globally is easy technically, but too broad for ordinary dictation style.
- `十六个样本`, `十六条建议`, `一百个理由`, and `九百六十四个样本` remain no-op because they are ordinary prose quantities rather than strong technical/document contexts.
- `百分之十几`, `百分之几`, and `百分之三点五个百分点` remain no-op because they are approximate or require choosing between `%` and `百分点` semantics.
- `一万 MB` and other `万/亿` magnitude forms remain no-op to avoid large-number parsing and half conversion.
- `一百八 MB` and omitted-zero thousands such as `两千四十八MB` are deferred. They are often understandable, but the first expansion keeps the parser strict to avoid colloquial-place ambiguity.
- `十六K` remains no-op because converting it to `16KB` would add a unit that ASR did not output.
