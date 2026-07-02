# Requirements - Silence-Aware Segmented ASR Boundaries

## Problem

The current Qwen3 segmented-cache service prevents whole-session cumulative recompute by committing bounded audio segments. However, a hard time boundary can cut through a word or technical term when no segment has been committed before the maximum segment duration. This can create recognition errors around segment boundaries.

The next step is to make segment commits boundary-aware without changing the App-facing local HTTP contract or using a cloud/LLM repair path.

## Scope

### IN

- Add a service-side boundary selector for the active segment.
- When a hard segment limit is reached, search backward from the limit for a nearby continuous low-energy/silence window.
- If a safe low-energy boundary is found, commit audio before that boundary and carry the remaining audio into the next active segment.
- If no safe low-energy boundary is found, hard-cut at the configured maximum segment duration and carry a short overlap into the next active segment.
- Preserve local durable audio cache behavior.
- Record boundary diagnostics in segment metadata and events.
- Add self-test/fake-backend coverage for:
  - silence-boundary cut
  - hard cut with overlap carry
  - final merge with conservative boundary de-duplication
  - existing stale/cancel behavior

### OUT

- Do not change the Swift App HTTP contract.
- Do not change ASR model selection.
- Do not claim native model realtime streaming.
- Do not restore cumulative whole-session recompute.
- Do not add LLM or cloud correction.
- Do not do broad fuzzy text rewriting or semantic merge.
- Do not restart or replace the current user-facing service until validation is reviewed.

## Requirements

- R1: The hard boundary path must keep committed segment duration within the configured maximum segment duration.
- R2: Silence-aware cutting must use a continuous low-energy window, not a single low-energy sample.
- R3: Audio after a silence cut must be preserved as carry audio for the next segment.
- R4: If no low-energy window is found, the service must hard-cut and preserve a configurable overlap into the next segment.
- R5: Final text merge may only de-duplicate clear suffix/prefix repeats at adjacent segment boundaries.
- R6: Existing local HTTP `/start`, `/chunk`, `/finish`, and `/cancel` behavior must remain compatible.
- R7: Stale-token and cancel protections must not regress.
- R8: Validation must not disturb the currently running user App/service.

## Constraints

- Keep processing local-only.
- Keep the first implementation simple enough to reason about and test with fake audio.
- Prefer deterministic logic and diagnostics over opaque heuristics.

## Dependencies

- `2026-06-26-qwen3-mlx-segmented-cache-service`
- `2026-07-01-qwen3-segmented-regression-suite`

## Related PMB context

- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/core/current_focus.md`
