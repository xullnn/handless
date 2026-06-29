# Decisions — ASR resource and cache governance

## Confirmed decisions

- D1: Keep this pass scoped to service-side resource cleanup, status observability, and explicit cleanup tooling.
- D2: Do not change App hotkeys, focus routing, paste behavior, floating panel behavior, or default backend selection.
- D3: Do not delete model caches through the cleanup script.
- D4: Cleanup tooling defaults to dry-run and requires an explicit apply flag for deletion.

## Open questions / unresolved choices

- O1: Product defaults for segmented-cache retention after real App integration remain open.
- O2: User-facing recovery UX for crash-retained audio remains open.
- O3: Product RSS/CPU acceptance thresholds require longer soak testing before they become deployment gates.

## PMB promotion candidates

- Promote validated service cleanup/status behavior after closeout.
