# ASR Evaluation Assets

This file is the durable PMB entrypoint for LocalVoiceInput ASR test assets. It is a pointer map and usage guide, not a raw run log. Detailed execution evidence remains in `specs/progress.md`, `eval/asr_streaming/results/`, and local `.external/` reports. Counts below reflect the current local Mac snapshot on 2026-07-05.

## Asset Posture

- The tracked `eval/asr_streaming/cases*.jsonl` files are the canonical manifest entrypoints for repeatable local ASR evaluation.
- The WAV files under `eval/asr_streaming/audio/` are local/private and ignored by Git. A manifest can exist in Git while the matching audio file is only present on this Mac.
- The video subtitle pilot corpus under `.external/corpora/video_subtitle_pilot/` is also local-only and ignored by Git. It contains derived audio, local subtitle copies, manual-review notes, and pilot gold drafts from the user's own video material.
- Do not upload audio or transcripts by default. These assets are for local evaluation, model selection, app-fit validation, and competitor/UX comparison.

## Core Runnable Manifests

The current full benchmark set is the eight manifest group below. It contains 106 manifest rows, 100 unique local WAV files, no missing audio on the current Mac, and about 62.3 minutes of unique audio. It intentionally excludes smoke, long120 health subsets, templates, and examples from formal aggregate acceptance.

| Suite | Manifest | Rows | Unique audio | Duration | Purpose |
|---|---|---:|---:|---:|---|
| Base regression | `eval/asr_streaming/cases.local.jsonl` | 10 | 10 | 4.5 min | Short Chinese, app/project hotwords, punctuation/fillers, safety, and code-switching baseline coverage. |
| Numeric | `eval/asr_streaming/cases.numeric.local.jsonl` | 37 | 37 | 3.7 min | Digits, decimals, dates, percentages, money, versions, units, indexes, and negative numeric-format controls. |
| Extended long | `eval/asr_streaming/cases.extended.local.jsonl` | 3 | 3 | 3.1 min | Existing longer natural/local cases, including code-switch long-form stress. |
| Long prepared | `eval/asr_streaming/cases.long_prepared.local.jsonl` | 3 | 3 | 2.6 min | Prepared 120/200/400 second-class long cases used for long-dictation evaluation. |
| Long synthetic | `eval/asr_streaming/cases.long_synthetic.local.jsonl` | 2 | 2 | 14.9 min | Synthetic repeated long stress material for backlog, truncation, and over-generation detection; not natural speech UX proof by itself. |
| Segment budget | `eval/asr_streaming/cases.segment_budget.local.jsonl` | 10 | 10 | 12.6 min | Time/content budget behavior: silence-only, repeated content, padded same text, and warmup cases. |
| Segment cache | `eval/asr_streaming/cases.segment_cache.local.jsonl` | 18 | 18 | 10.4 min | Prepared segment-cache cases for bounded finalization and aggregate merge behavior. |
| Segment cache synthetic | `eval/asr_streaming/cases.segment_cache.synthetic.local.jsonl` | 23 | 23 | 16.3 min | Synthetic segment-cache stress cases for boundary and merge robustness. |

## Supplemental Manifests

| Manifest | Role | Current use |
|---|---|---|
| `eval/asr_streaming/cases.smoke.local.jsonl` | Health subset | Fast model/service smoke only; do not include in full aggregate decisions unless explicitly labeled as a health check. |
| `eval/asr_streaming/cases.long120.local.jsonl` | Health/supplemental long subset | Useful for quick long-path probes and some quantization comparisons; not part of the current 106-row full benchmark aggregate. |
| `eval/asr_streaming/cases.example.jsonl` | Example/template aid | Contains missing placeholder audio on this Mac; do not treat as a runnable benchmark suite. |
| `eval/asr_streaming/cases.local.template.jsonl` | Template/source planning aid | Not a formal benchmark input unless matching local audio exists and it is converted into a runnable local manifest. |
| `eval/asr_streaming/cases.numeric.template.jsonl` | Numeric template mirror | Mirrors numeric case intent; the runnable numeric suite is `cases.numeric.local.jsonl`. |

## Video Subtitle Pilot Corpus

The video subtitle pilot is the local corpus built from the user's processed spoken-video material on the MacBook Pro 2015 source machine. Its local entrypoint is `.external/corpora/video_subtitle_pilot/`.

Current local state:

- 10 source video cases.
- About 43.3 minutes of source audio.
- 10 whole-file `audio.wav` files under `.external/corpora/video_subtitle_pilot/cases/<case_id>/`.
- 97 production-style boundary segments under `.external/corpora/video_subtitle_pilot/boundary_segments/`.
- Manual listening review is recorded in `.external/corpora/video_subtitle_pilot/manual_review/final_listening_review.md`.
- Pilot gold entrypoint is `.external/corpora/video_subtitle_pilot/gold_cases/gold_manifest.jsonl`.

Usage rules:

- Use `gold_audio_aligned_draft.txt` as the preferred reference text for pilot evaluation, not the raw source subtitle.
- Treat the `gold_audio_aligned_draft.txt` files as manually reviewed pilot gold drafts, not final immutable benchmark gold.
- Confirmed opening highlight repeats are not errors; those cases should either use the aligned gold with the prefix included or a scorer that explicitly ignores the annotated opening prefix.
- `vs_20250910_long_handoff` has non-spoken trailing hashtag metadata removed in the pilot gold.
- `vs_20250830_ai_replace_work` has a local order fix and should receive another quick full-text read before promotion into a strict frozen benchmark.
- Do not modify or write back to the original MacBook Pro 2015 video/subtitle sources.

Current pilot role:

- Competitor/UX comparison: play the stable `audio.wav` files through a virtual microphone path and compare product output against `gold_audio_aligned_draft.txt`.
- Natural long-form ASR evaluation: reuse the 97 boundary segments for file-level models and aggregate back to the 10 source videos.
- Corpus graduation trigger: create a dedicated dataset card or frozen benchmark contract before using this corpus as release-gating evidence.

## Current Evidence Pointers

These are current decision-bearing summaries. Raw run directories should be consulted only when reproducing or auditing a specific result.

| Evidence | Scope | Current durable conclusion |
|---|---|---|
| `eval/asr_streaming/results/mlx_candidate_comparison_20260622.md` | Early 10-case Mac-local candidate comparison | MiMo had the strongest early file-level accuracy, Qwen3 MLX was the practical realtime-integration direction, and Nemotron/Fun-ASR-Nano MLX were not suitable primary backends. Superseded by the full benchmark for default-model decisions. |
| `eval/asr_streaming/results/full-asr-model-benchmark-20260702-004029/recommendation.md` | 106 manifest rows, 100 unique audios; Qwen3 0.6B, Qwen3 1.7B, MiMo | Keep `qwen3-asr-0.6b-mlx-8bit` as the default realtime ASR backend. Do not promote Qwen3 1.7B to default; it has small quality gains but worse WER/latency/RTF/memory. Keep MiMo as offline reference only. Numeric formatting is not solved by model choice. |
| `eval/asr_streaming/results/qwen3-06b-prompt-ab-20260702-155144/recommendation.md` | Qwen3 0.6B segmented prompt vs no-prompt on numeric plus base guard | Do not enable the numeric-style system prompt by default. It improves numeric format pass rate from 8/37 to 13/37 but increases first partial latency and remains too weak. |
| `eval/asr_streaming/results/simple-numeric-itn-report-fresh-20260702-1730/comparison.md` | 37 numeric cases | Simple deterministic NumericITN improves numeric-format pass rate from 8/37 to 20/37 with no worsened cases in that report. |
| `eval/asr_streaming/results/contextual-numeric-itn-report-20260702-181133/comparison.md` | 37 numeric cases | Contextual NumericITN improves numeric-format pass rate from 8/37 to 23/37 with no worsened cases in that report; numeric ITN remains a separate guarded strategy, not a model-selection outcome. |
| `.external/corpora/video_subtitle_pilot/boundary_segments/boundary_segment_run_report.md` | 10 video cases, 97 boundary segments | Whole-file MiMo under-covered long videos, but production-style silence-aware segmentation made all 10 video cases `likely_aligned`. |
| `.external/corpora/video_subtitle_pilot/qwen3_model_runs/model_selection_report.md` | 10 video cases aggregated from 97 segments | Qwen3 1.7B is slightly closer to pilot gold on this natural video corpus, but Qwen3 0.6B remains the safer production default because it is already validated on the segmented service path and is roughly 2x faster on these segments. |
| `eval/asr_streaming/qwen3_0_6b_quant_comparison_20260705.md` | 107 local rows plus 97 video boundary segments; Qwen3 0.6B 4/5/6/8-bit | Keep Qwen3 0.6B 8-bit as the default. 4-bit had catastrophic over-generation outliers, 5-bit/6-bit did not justify replacing 8-bit, and lower-bit caches were intentionally removed after summarization. |

## Repeatable Runner Entrypoints

| Runner | Main use |
|---|---|
| `scripts/run_full_asr_model_benchmark.sh` | Rebuild or report the multi-model benchmark across the current manifest suites. |
| `scripts/run_qwen3_mlx_segmented_regression_gate.sh` | Start the segmented Qwen3 HTTP service, replay timed PCM through the HTTP adapter gate, and capture resource samples. |
| `scripts/run_qwen3_mlx_segmented_app_smoke.sh` | Launch the segmented Qwen3 HTTP service and the macOS app for manual actual-use smoke. |
| `scripts/run_qwen3_06b_prompt_ab_benchmark.sh` | Reproduce the Qwen3 0.6B prompt-vs-no-prompt comparison using existing summaries or fresh segmented runs. |
| `scripts/run_numeric_itn_report.sh` | Re-run final-output NumericITN analysis against the numeric suite and produce comparison JSON/Markdown. |
| `scripts/record_asr_cases.sh` and `scripts/record_numeric_asr_cases.sh` | Record or extend local/private WAV cases for the manifest suites. |

## Artifact Classification

| Path or pattern | Role | Disposition | Notes |
|---|---|---|---|
| `eval/asr_streaming/cases*.jsonl` | `dataset_or_ground_truth` pointer manifests | `keep_formal_core` for runnable local manifests; templates/examples are planning aids | Tracked in Git; they may reference ignored local audio. |
| `eval/asr_streaming/audio/` | `dataset_or_ground_truth` local audio | `keep_formal_core` while the manifests cite it | Ignored/private; do not delete just because it is untracked. |
| `.external/corpora/video_subtitle_pilot/cases/` | `dataset_or_ground_truth` local derived audio/subtitles | `keep_current_evidence` / pilot corpus | Local-only; source videos remain on MacBook Pro 2015. |
| `.external/corpora/video_subtitle_pilot/gold_cases/` | `dataset_or_ground_truth` pilot gold drafts | `keep_current_evidence` | Not final immutable benchmark gold. |
| `.external/corpora/video_subtitle_pilot/manual_review/` | `report_or_summary` and human review record | `keep_current_evidence` | Authoritative manual-review summary for the video pilot. |
| `eval/asr_streaming/results/` | `run_output` plus reports | Keep decision-bearing reports; raw run outputs are evidence-specific | Preserve referenced reports. Reclassify exploratory or invalid raw outputs before deletion. |
| `.external/models/` | model/runtime cache | Not an eval dataset | Govern through `eval/asr_streaming/model_inventory.md`; do not infer model-cache value from test-case manifests. |

## Cautions For Future Work

- File-level `generate(audio)` results do not prove realtime app readiness.
- Segmented simulated-realtime results are stronger product-fit evidence, but still require App smoke when changing runtime defaults.
- Synthetic long/repeated cases are useful for stress and over-generation detection; do not cite them as natural long-speech UX evidence.
- Video-subtitle pilot cases are realistic and useful, but still pilot-level until frozen with a dataset card and explicit acceptance contract.
- Competitor tests using virtual microphone playback should report the playback path, audio file, app settings, and output capture method so UX findings remain reproducible.
