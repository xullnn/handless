# Decisions - Silence-Aware Segmented ASR Boundaries

## Confirmed decisions

- D1: Prefer backward silence/low-energy search from the maximum boundary over waiting past the maximum duration.
- D2: Keep committed segment duration within the configured hard limit whenever the hard limit triggers.
- D3: Use hard-cut plus overlap only when no acceptable low-energy window is found.
- D4: Final merge de-duplication must be conservative and limited to exact adjacent suffix/prefix repeats.
- D5: This feature changes only the Qwen3 segmented-cache service internals; the App HTTP contract remains unchanged.
- D6: Initial automated self-test validation must not restart the user-facing service; live runtime validation may restart the service/App after explicit user approval.
- D7: Synthetic live-runtime requests are sufficient to validate boundary mechanics, but natural long-dictation quality still needs a separate focused regression.

## Open questions / unresolved choices

- Exact production thresholds for low-energy detection may need tuning after real recordings. The first pass uses deterministic defaults and diagnostics.
- Real natural long-dictation regression should cover boundary-near speech, natural pauses, and no-pause continuous speech before changing thresholds.

## PMB promotion candidates

- Promoted the durable boundary policy for long-dictation segmented-cache ASR into PMB after validation.
