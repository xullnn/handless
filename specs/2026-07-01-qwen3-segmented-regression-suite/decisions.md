# Decisions - Qwen3-ASR Segmented Route Regression Suite

## Confirmed Decisions

- D1: Treat segmented-cache Qwen3 as the main route to evaluate next.
- D2: Keep cumulative recompute available as reference/rollback until segmented route passes enough evidence.
- D3: Run numeric-format and base-recognition suites on the segmented route before promoting it.
- D4: Use realtime-paced replay by default because the product goal is user-perceived live dictation.
- D5: Keep the current numeric-style system prompt enabled for the first segmented comparison.
- D6: Do not change Swift App paste/focus/clipboard safety behavior in this feature.

## Current Observations

- The user observed that Codex auto-paste works after switching to the segmented route, while the old cumulative route often fell back to clipboard in the same surface. This is useful manual context, but the technical cause still needs isolated validation before it becomes a product claim.
- A later status check on 2026-07-01 showed the daily App process was still pointed at `http://127.0.0.1:18105`, served by `qwen3_mlx_http_service.py` rather than `qwen3_mlx_segmented_cache_service.py`. The segmented evidence in this feature came from temporary test service runs on port `18113`.

## Open Questions / Unresolved Choices

- What segment policy should become the daily default after numeric/base regression results are available?
- Should long-draft mode insert committed segments incrementally in the future, or continue final-only insertion?
- When should cumulative-recompute scripts be moved from active path to legacy/reference tooling?

## Rejected For This Feature

- Deleting cumulative code immediately.
- Making segmented route the default without regression evidence.
- Using post-ASR LLM correction to mask numeric formatting failures.
