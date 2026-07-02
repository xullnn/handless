# Requirements - Full ASR Model Benchmark

## Problem

LocalVoiceInput now treats `mlx-community__Qwen3-ASR-0.6B-8bit` as the practical local ASR baseline. Future model switches or ASR pipeline changes must not make accuracy, latency, resource use, or product safety worse. Existing evidence only partially compares Qwen3-ASR 0.6B, Qwen3-ASR 1.7B, and MiMo-V2.5-ASR across older file-level runs. The project needs one full, reproducible, apples-to-apples benchmark over all currently recorded local test cases, including the later numeric cases.

## Scope

### IN

- Define and implement a repeatable full benchmark over all current local ASR case manifests that have audio files.
- Compare these local models:
  - Baseline: `mlx-community__Qwen3-ASR-0.6B-8bit`
  - Candidate: `mlx-community__Qwen3-ASR-1.7B-8bit`
  - Candidate: `MiMo-V2.5-ASR-MLX` plus `MiMo-Audio-Tokenizer`
- Run file-level final-transcript evaluation for every compared model on every runnable suite.
- Run segmented, simulated-realtime evaluation for every model where a timed-PCM or chunked wrapper is technically available.
- Treat lack of segmented/realtime capability as a measured compatibility result, not as a silent skip.
- Measure quality, speed, resource usage, numeric-format behavior, and product-fit compatibility.
- Produce a human-readable comparison report and machine-readable raw result artifacts.
- Use the current Qwen3-ASR 0.6B MLX segmented route as the baseline for replacement decisions.

### OUT

- No macOS App runtime switch.
- No default model change.
- No cloud ASR service.
- No upload of audio or transcripts.
- No deletion of local model files.
- No InputMethodKit rewrite.
- No automatic numeric post-processing change in the App.
- No manual rerecording requirement unless the benchmark detects missing or corrupt audio and reports it as a blocker.

## Models

Required model metadata in every report:

| Model ID | Path | Vendor | Parameter scale | Release date | Role |
|---|---|---|---|---|---|
| `qwen3-asr-0.6b-mlx-8bit` | `.external/models/mlx-community__Qwen3-ASR-0.6B-8bit` | Alibaba / Qwen upstream; MLX Community conversion | 0.6B, 8-bit MLX | 2026-01-29 | Current baseline |
| `qwen3-asr-1.7b-mlx-8bit` | `.external/models/mlx-community__Qwen3-ASR-1.7B-8bit` | Alibaba / Qwen upstream; MLX Community conversion | 1.7B, 8-bit MLX | 2026-01-29 | Larger Qwen candidate |
| `mimo-v2.5-asr-mlx` | `.external/models/MiMo-V2.5-ASR-MLX` plus `.external/models/MiMo-Audio-Tokenizer` | Xiaomi MiMo | 8B MLX ASR plus audio tokenizer | 2026-06-02 | High-quality offline candidate |

## Test Suites

The benchmark must inventory current local manifests before running. The expected current set includes:

| Suite | Manifest | Current count | Purpose |
|---|---|---:|---|
| Base | `eval/asr_streaming/cases.local.jsonl` | 10 | Short Chinese, hotwords, punctuation, safety, long text, code-switching |
| Numeric | `eval/asr_streaming/cases.numeric.local.jsonl` | 37 | Digits, dates, decimals, percentages, money, versions, units, negative cases |
| Extended long | `eval/asr_streaming/cases.extended.local.jsonl` | 3 | Existing long stress subset |
| Long prepared | `eval/asr_streaming/cases.long_prepared.local.jsonl` | 3 | Prepared long audio cases |
| Long synthetic | `eval/asr_streaming/cases.long_synthetic.local.jsonl` | 2 | Synthetic long stress cases |
| Segment budget | `eval/asr_streaming/cases.segment_budget.local.jsonl` | 10 | Time/content-budget behavior |
| Segment cache | `eval/asr_streaming/cases.segment_cache.local.jsonl` | 18 | Prepared segment-cache cases |
| Segment cache synthetic | `eval/asr_streaming/cases.segment_cache.synthetic.local.jsonl` | 23 | Synthetic segment-cache stress cases |

As of contract creation, this scope contains `106` manifest case rows, `100` unique audio files, and `0` missing audio files. The benchmark runner must recompute these counts at runtime rather than hard-coding them, because future recording work may add or replace cases.

`cases.smoke.local.jsonl` and `cases.long120.local.jsonl` may be used for health checks and warmup, but aggregate comparison must distinguish health subsets from the full benchmark suites so duplicate cases do not hide regressions.

Template manifests such as `cases.local.template.jsonl` and `cases.numeric.template.jsonl` are not benchmark inputs unless corresponding audio files exist and they are converted into local runnable manifests.

## Requirements

- R1: The benchmark must build a run manifest containing model list, suite list, command line, git status summary, Python runtime, host hardware, and timestamp.
- R2: The benchmark must fail early or mark the run blocked if any required model path is missing.
- R3: The benchmark must inventory every case in every selected manifest and report missing audio files before running inference.
- R4: The benchmark must run file-level final evaluation for all three required models across all selected suites, covering every runnable manifest row.
- R5: The benchmark must run segmented simulated-realtime evaluation for Qwen3-ASR 0.6B and Qwen3-ASR 1.7B through the active segmented service path or an equivalent timed-PCM local HTTP service, covering every runnable manifest row unless a suite-specific timeout/blocker is recorded.
- R6: The benchmark must evaluate whether MiMo can run a practical segmented/chunked route. If it cannot, the report must show the inspected API/runtime reason and still include full file-level results.
- R7: The benchmark must record quality metrics per model, suite, and case: CER, WER, final coverage ratio, final text, expected text, and failure reason.
- R8: The benchmark must record numeric-format metrics for the numeric suite: must-include pass rate, must-not-include violation rate, Arabic-number preference pass rate, and per-category pass rate.
- R9: The benchmark must record speed metrics: wall time, model load time, RTF, first partial latency where applicable, partial cadence where applicable, final latency, and timeout count.
- R10: The benchmark must record resource metrics: peak RSS, approximate steady RSS when service mode exists, mean CPU, peak CPU, and sample count.
- R11: The benchmark must identify whether each model is eligible for product replacement, final-only correction, offline quality reference, or reject/hold.
- R12: The report must explain every metric abbreviation in Chinese, including CER, WER, RTF, RSS, CPU, first partial latency, final latency, and final coverage ratio.
- R13: The report must include model vendor, parameter scale, release date, local model path, and current product role.
- R14: No model can be recommended as the new default unless it is at least as good as the Qwen3-ASR 0.6B baseline on accuracy and materially acceptable on runtime/resource behavior.
- R15: No App-level behavior conclusion may be made solely from file-level results. Segmented simulated-realtime evidence is required for any realtime backend recommendation.

## Constraints

- The benchmark must remain local-only and offline after local model files are present.
- Results must not depend on network access.
- Existing App hotkey, focus, paste, clipboard, and floating-panel code must not be modified by this feature.
- The older cumulative recompute route must not be revived as a product path.
- Runtime comparisons must label whether the run is file-level, segmented simulated realtime, or health/warmup.
- Resource measurements must be comparable enough for ranking, but the report must call out if a model is measured in file-level command mode while another is measured in service mode.

## Dependencies

- `2026-06-20-asr-backend-eval-harness`
- `2026-06-22-mimo-v25-asr-mlx-local-eval`
- `2026-06-22-mlx-asr-model-download-and-eval`
- `2026-06-23-incremental-ux-real-backend-adapters`
- `2026-06-26-qwen3-mlx-segmented-cache-service`
- `2026-07-01-qwen3-segmented-regression-suite`
- `2026-07-01-retire-qwen3-cumulative-route`

## Related PMB Context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/asr_audio/summary.md`
- `eval/asr_streaming/model_inventory.md`
