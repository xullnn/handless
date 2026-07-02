# Plan - Contextual Numeric ITN Expansion

## Execution plan

1. Add a follow-up SDD contract so the validated conservative ITN baseline remains distinct from this broader rule pass.
2. Add focused unit fixtures first:
   - technical units with `百/千` integers
   - complete percent expressions
   - narrow ordinal/document suffixes
   - no-op cases for bare integers, ordinary quantities, idioms, and unsupported magnitudes
3. Extend `NumericITN` in small rule groups:
   - percent expressions before decimal rewriting
   - bounded `十/百/千` integer parsing for technical-unit context
   - suffix/prefix whitelist for ordinal/document contexts
4. Run focused tests and tighten any rule that produces false positives.
5. Run broader Swift validation and offline numeric-format reporting.
6. Record validation evidence and any abandoned cases in SDD.

## Touched areas

- `Sources/LocalVoiceInputCore/NumericITN.swift`
- `Tests/LocalVoiceInputCoreTests/NumericITNTests.swift`
- `specs/2026-07-02-contextual-numeric-itn-expansion/`
- `specs/feature_matrix.json`
- `specs/progress.md`

## Candidate abandon criteria

- A rule needs broad semantic interpretation rather than local syntax/context.
- A rule rewrites common prose in plausible daily dictation.
- A rule interacts poorly with the already validated decimal/version/digit-sequence rules.
- A rule cannot be explained with a simple whitelist or bounded parser.

## PMB promotion candidates

- Promote only if validation confirms a durable rule-boundary decision. Do not promote raw validation evidence or active fixture lists.
