# Decisions - Retire Qwen3 Cumulative Recompute Runtime Route

## Confirmed decisions

- D1: The segmented-cache route is the active Qwen3 HTTP ASR route going forward.
- D2: Cumulative recompute is retired from active code/config because daily-use experience showed worse responsiveness and unreliable numeric-format behavior.
- D3: Historical cumulative specs and result artifacts remain as evidence and should not be rewritten or deleted as part of runtime cleanup.
- D4: The generic Swift local HTTP ASR client remains because the segmented route uses the same local HTTP boundary.
- D5: Arabic-number formatting remains a separate follow-up and must be evaluated on segmented long/mixed cases.
- D6: The default local HTTP URL is now the segmented smoke port `http://127.0.0.1:18096`; `asrBackend` still defaults to FunASR WebSocket unless a launch script or CLI flag selects local HTTP.

## Open questions / unresolved choices

- Whether the old cumulative historical result directories should be archived outside the active repo in a later cleanup pass.
- Whether segmented route should become the default `asrBackend` in config later, after service supervision is implemented.

## PMB promotion candidates

- Promote D1-D3 after validation.
