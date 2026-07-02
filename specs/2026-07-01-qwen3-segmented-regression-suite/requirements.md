# Requirements - Qwen3-ASR Segmented Route Regression Suite

## Problem

The project now needs to evaluate the segmented-cache Qwen3 route as the main ASR direction, rather than continuing to optimize the older cumulative-recompute path. Previous numeric-format and base-recognition regressions were mostly run through the cumulative HTTP service, so they do not prove that the segmented route is ready to become the daily path.

## Scope

### IN

- Add a repeatable runner that starts `qwen3_mlx_segmented_cache_service.py serve` and runs `incremental_ux_gate.py --adapter http-json`.
- Run the dedicated numeric-format suite: `eval/asr_streaming/cases.numeric.local.jsonl`.
- Run the existing base suite: `eval/asr_streaming/cases.local.jsonl`.
- Use the same Qwen3-ASR 0.6B MLX 8-bit model and the current numeric-style system prompt when prompt-enabled validation is requested.
- Record service logs, resource samples, run metadata, gate summaries, and per-case events under `eval/asr_streaming/results/`.
- Add analysis for numeric-format constraints using `must_include` and `must_not_include`.
- Compare segmented-route results against the latest cumulative-route reference summaries where available.
- Preserve local-only execution and current App safety boundaries.

### OUT

- No InputMethodKit migration.
- No cloud ASR, no upload of audio or text.
- No default LLM correction or auto-send behavior.
- No weakening of focus detection, paste fallback, clipboard safety, or cancel behavior.
- No immediate deletion of cumulative-recompute code before segmented results are reviewed.
- No claim that Qwen3 is native streaming; this remains a local wrapper route.

## Requirements

- R1: The runner must be explicit that it is testing the segmented route, not the cumulative route.
- R2: The runner must support dry-run mode, custom case file, custom output directory, custom port, system prompt file, and segment-policy parameters.
- R3: The runner must default to realtime-paced PCM replay because the target is user-perceived live dictation, while still allowing `NO_REALTIME=1` for diagnostic parity runs.
- R4: Numeric analysis must report:
  - total cases;
  - cases passing all `must_include` and `must_not_include` constraints;
  - failures grouped by scenario and format focus;
  - final text per failed case.
- R5: Base comparison must report CER, WER, RTF, coverage, latency, and gate pass deltas with Chinese metric descriptions available in the underlying summaries.
- R6: A segmented-route result can be considered acceptable only if no safety event ordering problems appear: no accepted output after cancel, no partial after final, and no stale accepted event.
- R7: Accuracy regressions against the cumulative reference must be explicitly listed, not hidden by aggregate means.
- R8: The final recommendation must distinguish:
  - ready for more manual App smoke;
  - ready to promote as daily route;
  - needs segment policy tuning;
  - keep cumulative route only as rollback/reference.

## Dependencies

- `2026-06-22-incremental-ux-asr-gate`
- `2026-06-23-qwen3-mlx-http-service-boundary`
- `2026-06-26-qwen3-mlx-segmented-cache-service`
- `2026-06-26-qwen3-mlx-segmented-app-smoke`
- `2026-06-28-asr-resource-cache-governance`

## Related PMB context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `project_memory_bank/modules/macos_app/summary.md`
