# Validation - Contextual Numeric ITN Expansion

## Completion rule

This feature can be marked `passes=true` only after required checks pass and evidence is recorded in `specs/progress.md`.

## Acceptance criteria

- A1: Technical-unit integers with `十/百/千` forms convert in strong unit context.
- A2: Complete percent expressions convert without leaving `百分之` half-normalized.
- A3: Narrow ordinal/document contexts convert only when a whitelisted prefix/suffix is present.
- A4: Bare integers such as `十六` remain unchanged.
- A5: Ambiguous prose, approximate quantities, idioms, and unsupported magnitudes remain unchanged.
- A6: Existing NumericITN tests for decimals, versions, simple units, and strong digit sequences still pass.
- A7: Offline numeric-format reporting shows no worsened numeric-format cases.

## Required automated checks

```bash
swift test --filter NumericITN
swift test --filter CorrectionPipelineTests
swift test
```

```bash
BASE_SUMMARY=eval/asr_streaming/results/simple-numeric-itn-segmented-numeric-20260702-1724/summary.json \
OUT_DIR=eval/asr_streaming/results/contextual-numeric-itn-report-$(date +%Y%m%d-%H%M%S) \
bash scripts/run_numeric_itn_report.sh
```

## Optional checks

- Re-run the report on the base segmented summary if the numeric summary improves and there is concern about broad text rewrites.
- App smoke is optional for this expansion because the App integration point and enable/disable flag were already validated by `2026-07-02-simple-numeric-itn`; this feature changes only the pure Core rule inventory.

## Evidence required in `specs/progress.md`

- Commands run and pass/fail result.
- Report output path.
- Numeric pass-rate before/after and worsened-case count.
- Any abandoned/deferred examples with rationale.
