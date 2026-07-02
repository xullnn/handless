# Current Focus

Current phase: daily-use hardening of the local-first macOS dictation MVP and the optional Qwen3-ASR MLX loopback HTTP backend.

Stable status:

- Build and automated Swift tests pass on the local Mac with full Xcode selected.
- The packaged app is signed with a stable Apple Development identity so macOS TCC permissions can survive rebuilds when bundle id and signing identity stay stable.
- The app is being used through the packaged `dist/LocalVoiceInput.app` path with an explicit local HTTP ASR URL when Qwen3 is needed. FunASR WebSocket remains the default config path; Qwen3-ASR MLX is opt-in.
- Mock ASR mode remains the fast shell validation path for hotkeys, focus routing, floating panel, clipboard, paste verification, and cancel behavior.
- Qwen3-ASR MLX 0.6B behind the segmented-cache local HTTP wrapper is the current first-choice ASR candidate for actual-use experiments. It is still a local wrapper around file-level model calls, not a native streaming session API.
- The older Qwen3 cumulative-recompute route is retired from active code/config. It remains historical evidence only because daily use showed worse long-dictation responsiveness and unreliable numeric-format prompting.
- Simple deterministic numeric ITN is the validated first-line approach for simple final-output numeric formatting. It covers decimals, version-like expressions, strong digit-sequence contexts, bounded technical-unit integers, complete percent expressions, and narrow ordinal/document contexts. It still avoids bare integer rewriting, dates, times, money, `万/亿`, broad quantities, and partial-display normalization unless separate validation proves a narrower safe rule.
- Long dictation should use bounded segment finalization with durable local audio cache, merge/dedup rules, and backlog pressure controls instead of whole-session final recompute.
- The floating panel is non-key and non-activating, has rounded visual chrome, keeps text readable for long partials, and fades after final output with hover pause.
- Confirmed auto-paste now keeps the dictated result as the newest clipboard item by default. Restoring the previous clipboard is an optional policy and must only happen after paste verification.
- Qwen3 segmented HTTP service resource governance exists: terminal sessions release audio state, segmented spool files are governed by cleanup tooling, `/metadata` and `/health` report service state, and cleanup tooling targets generated ASR artifacts while protecting model caches.
- Local model cache is intentionally lean: keep Qwen3-ASR MLX 0.6B/1.7B, MiMo-V2.5-ASR MLX plus tokenizer for offline reference, and FunASR Paraformer/VAD baseline assets. Detailed cache paths live in `eval/asr_streaming/model_inventory.md`.

Immediate next focus:

- Continue small-step hardening around daily-use issues rather than broad rewrites.
- Define production service supervision for the segmented local ASR path: startup, health checks, restart/fallback, memory/CPU ceilings, and user-facing failure handling.
- Keep mouse/other-device trigger abstraction and model profile management as SDD-planned future features until the core runtime path is more stable.

Current operational caution:

- Qwen3 actual-use launch requires both the App and local HTTP service to be healthy; use `scripts/status_localvoiceinput.sh` for read-only inspection.
- When numeric ITN is enabled by command-line override, status inspection must check the running App process flags as well as the config file because the default config can still show `numericITNEnabled=false`.
- A running older Qwen3 service process may still exist until restarted, but new Qwen3 work should use `qwen3_mlx_segmented_cache_service.py` and the segmented smoke/regression scripts.
- File-level model output and token streaming over an already materialized audio buffer do not prove realtime floating-panel behavior. App integration must be validated with timed PCM chunks and manual macOS smoke.
- Whole-session cumulative recompute gets slower as speech grows longer and is no longer an active runtime path; long dictation uses segment budgets and local audio cache for reliability.
- Real ASR setup may download packages or models on first setup; after local caches are present, operation should remain local/offline.
- AMD or other machines can help acquire model snapshots, but Mac-local inference and App behavior remain the authoritative product evidence.
