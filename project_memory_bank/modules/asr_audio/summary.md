# ASR And Audio Module

The ASR/audio path is local-first and supports mock validation, real FunASR WebSocket 2-pass transcription, and an optional localhost HTTP ASR client for Qwen3-ASR MLX wrapper services.

Stable responsibilities:

- `AudioCapture` records microphone input with `AVAudioEngine`, converts to 16 kHz mono int16 PCM, batches chunks, and flushes pending PCM before ASR finish. Closed-alpha capture is session-bound: it does not run the microphone engine while idle for pre-roll, and stop/cancel tears the engine down to prevent post-release audio from leaking into the next input.
- `FunASRClient` connects to a local WebSocket endpoint, sends a 2-pass start message, streams PCM data, and sends `is_speaking=false` after audio flush.
- `LocalHTTPASRClient` connects to an explicitly selected loopback HTTP service, posts `/start`, `/chunk`, `/finish`, and `/cancel`, transfers PCM as base64 JSON, and filters backend events by session token before emitting `ASREvent` values.
- `MockASRClient` provides deterministic partial and final events for interaction testing without a server.
- `ASRClientProtocol` keeps the app controller independent of the concrete ASR source.
- The local FunASR websocket runtime can run against cached smoke-test model directories under `.external/models/` for offline ASR, online ASR, and VAD.
- `eval/asr_streaming/` is the independent backend evaluation harness for replaying 16 kHz mono int16 WAV files before changing the macOS app runtime.
- `project_memory_bank/modules/asr_audio/eval_assets.md` is the durable PMB pointer map for ASR evaluation assets: runnable manifests, ignored local audio, the video subtitle pilot corpus, and current decision-bearing report entrypoints.
- `eval/asr_streaming/realtime_gate.py` is the stricter realtime backend gate: it sends timed PCM chunks, requires partials before simulated user stop, requires final/offline output after stop, and rejects late partials after final.
- `scripts/record_asr_cases.sh` starts the guided local recording flow for ASR eval cases and saves case-aligned WAV files under `eval/asr_streaming/audio/`.
- `scripts/run_full_asr_model_benchmark.sh`, `scripts/run_qwen3_06b_prompt_ab_benchmark.sh`, and `scripts/run_numeric_itn_report.sh` are the repeatable report entrypoints for current model comparison, prompt A/B, and NumericITN evidence.
- `eval/asr_streaming/run_eval.py` also supports a local Fun-ASR-Nano file-level adapter for model comparison on the same WAV cases without touching macOS hotkey, focus, paste, or floating-panel code.
- `eval/asr_streaming/qwen3_mlx_realtime_probe.py` checks whether Qwen3-ASR MLX exposes true session streaming or only file/token streaming.
- Qwen3-ASR MLX 0.6B and 1.7B expose `generate`, `stream_transcribe`, and `stream_generate`, but not `create_streaming_session`; they are not realtime-gate eligible without a custom session wrapper.
- `eval/asr_streaming/qwen3_mlx_segmented_cache_service.py` is the active Qwen3-ASR MLX local HTTP service route. It accepts timed PCM chunks, emits user-visible partial/final events, writes durable local audio cache files, commits bounded segments so long dictation does not require whole-session final recompute, and exposes a local `/shutdown` endpoint for app-managed graceful teardown. Its validated boundary policy prefers continuous low-energy cut points near the segment limit, then falls back to the hard duration cap plus bounded overlap and exact overlap de-duplication.
- `eval/asr_streaming/qwen3_mlx_service_common.py` owns shared active Qwen3 service helpers such as MLX backend calls, system prompt metadata/filtering, the fixed 16 kHz sample rate, and service-gate evaluation.
- The older Qwen3 cumulative-recompute probe/service/HTTP route has been retired from active code/config. Historical specs and result artifacts remain as evidence, but new runtime work should use the segmented service route.
- `eval/asr_streaming/monitor_pid_resources.py` and `scripts/run_qwen3_mlx_segmented_regression_gate.sh` provide repeatable RSS/CPU sampling while the segmented Qwen3 HTTP gate runs.
- The active Qwen3 segmented service route keeps its runtime argument surface narrow; runner scripts should not pass an app-level `--max-tokens` option to this service.
- `eval/asr_streaming/cleanup_localvoiceinput_cache.py` and `scripts/cleanup_localvoiceinput_cache.sh` safely inspect/delete generated ASR runtime artifacts while protecting model caches; eval audio cleanup is opt-in.
- `eval/asr_streaming/segment_cache_eval.py` prepares bounded segment WAVs and analyzes segment-final results as source-case plus strategy reports. Its first validated runs support using hybrid segmented caching for long dictation instead of whole-session cumulative final recompute.
- Qwen3-ASR MLX 0.6B has validated segmented-route evidence across base and numeric regression suites, plus a validated optional Swift local HTTP client path and ongoing manual actual-use evidence. It is still opt-in rather than the default replacement for the existing FunASR app backend until service supervision is formalized.
- The Qwen3 MLX HTTP service currently uses single-threaded `HTTPServer` because MLX inference failed when model load and request handling ran on different Python threads.
- Segmented Qwen3 resource runs currently show roughly 1.2-1.4 GB peak RSS with bursty CPU peaks; these are sizing signals, not final acceptance thresholds.
- Nemotron 3.5 ASR Streaming 0.6B MLX exposes cache-aware `stream_generate(audio)` in the local MLX implementation, but the local runtime surface does not expose a session-style incremental PCM API; current local Chinese/technical-term quality is weak.
- MiMo-V2.5-ASR MLX remains the offline-quality reference unless a chunked or streaming API is proven.
- The local ASR model cache is intentionally lean after cleanup: keep Qwen3-ASR MLX 0.6B/1.7B for the current wrapper path, MiMo-V2.5-ASR MLX plus tokenizer for offline reference, and FunASR Paraformer/VAD for baseline/runtime fallback. Detailed cache paths and removed historical models live in `eval/asr_streaming/model_inventory.md`.
- AMD model acquisition can be used as a cache/transfer path for large Hugging Face snapshots, but Mac-local inference remains the authoritative product evidence.
- `scripts/download_fun_asr_nano.sh` and `scripts/run_fun_asr_nano_smoke.sh` provide the repeatable acquisition and smoke path for Fun-ASR-Nano-2512.

Important constraints:

- FunASR offline segment results can update transcript state while recording but must not finalize the whole user session until user stop.
- The websocket server must flush remaining PCM to offline ASR when `is_speaking=false` arrives, because the macOS app sends that control message after all PCM has been flushed.
- Old ASR sessions must not affect the active session.
- Audio captured after user stop must not affect the stopped or next session; only chunks returned by the stop-flush path are trusted after the live session gate closes.
- Real ASR setup should remain local; no audio or text is uploaded by default.
- Public ASR benchmark results are shortlist evidence only; final backend selection must be validated with local harness runs and project/user-specific recordings.
- Fun-ASR-Nano local file-level results are backend-selection evidence only. They do not validate realtime partial display, WebSocket session behavior, or macOS app insertion behavior.
- Qwen3-ASR MLX file/token streaming probes are backend-selection evidence only; current loaded MLX snapshots do not provide a native session API for timed microphone PCM chunks, partial stability, cancellation, and repeated-session model reuse.
- Qwen3-ASR MLX segmented-cache service gates are wrapper-feasibility and product-UX evidence only. They are not native model streaming, but they are the active Qwen3 local HTTP route for App smoke and future hardening.
- The validated Swift `LocalHTTPASRClient` proves the App can consume local HTTP ASR events safely; production still needs app-managed service supervision and formal memory/CPU thresholds.
- Segmented-service timing must be session-relative. A new recording session must not inherit previous-session worker delay.
- Long-dictation finalization should be bounded by segment budgets rather than a single whole-session final recompute. The active segmented service uses a hard audio-duration cap, soft recognized-text budget, silence-aware boundary preference, hard-overlap fallback, and conservative exact overlap de-duplication; backlog pressure controls remain future hardening.
- Long code-switch technical terms remain a quality risk even when the incremental UX gate passes; model prompting, hotword correction, final correction, or a larger final model may still be needed.
- Model names or cards that say `streaming` are not enough. The local runtime must expose or be wrapped into a tested `start/push_pcm/partial/finish/final/cancel` contract before app integration.
- Complete-audio `generate(...)` output, even when token-streamed after loading the whole file, is not enough to qualify a backend for the realtime floating-panel MVP.
- On FunASR 1.3.1, Fun-ASR-Nano should run without VAD by default until the Nano plus VAD merge failure is resolved.

Go Deeper:

- See `../../core/system_overview.md` for end-to-end flow.
- See `../../core/current_focus.md` for current real-ASR setup status.
- See `eval_assets.md` for ASR test-case categories, local audio retention posture, video-subtitle pilot rules, and current evaluation evidence pointers.
- See `../../insights/funasr_local_runtime.md` for local FunASR and Fun-ASR-Nano operating notes.
