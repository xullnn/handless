# Qwen3-ASR 0.6B MLX Quantization Comparison - 2026-07-05

## Decision

Keep `qwen3-asr-0.6b-mlx-8bit` as the LocalVoiceInput production/default Qwen3 model.

Do not promote `qwen3-asr-0.6b-mlx-4bit`. It saves the most disk space, but it produced catastrophic over-generation on long/synthetic cases.

Keep the `5bit` result as a historical low-footprint candidate only. It was close enough to be informative, but not better than `8bit` on aggregate local accuracy.

Do not keep the downloaded `4bit`, `5bit`, or `6bit` model caches on this Mac after this experiment. Re-download only if a future packaging-size investigation needs to rerun the comparison.

## Tested Inputs

- Local ASR manifests: 107 case rows from base, numeric, extended long, long120 supplemental, long prepared/synthetic, segment budget/cache, and segment cache synthetic suites.
- Video/subtitle pilot: 97 production-style boundary segments aggregated back to 10 source videos.
- Runtime: local MLX `mlx-audio` path through `eval/asr_streaming/run_eval.py` with `mlx-stt-local`.
- No macOS App behavior was changed by this experiment.

## Model Size

| Model | Directory size | `model.safetensors` bytes | Weight saving vs 8-bit |
|---|---:|---:|---:|
| `qwen3-asr-0.6b-mlx-4bit` | 692M | 708,236,945 | 29.6% |
| `qwen3-asr-0.6b-mlx-5bit` | 751M | 782,735,089 | 22.2% |
| `qwen3-asr-0.6b-mlx-6bit` | 822M | 857,233,233 | 14.8% |
| `qwen3-asr-0.6b-mlx-8bit` | 964M | 1,006,229,426 | baseline |

## Local Suite Aggregate

| Model | Cases | Status | Mean CER | Median CER | Mean WER | Mean RTF | Numeric format pass | Peak RSS |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| `qwen3-asr-0.6b-mlx-4bit` | 107 | 107 ok | 0.9116 | 0.0242 | 0.8877 | 0.0283 | 9/37 | 2200.9 MB |
| `qwen3-asr-0.6b-mlx-5bit` | 107 | 107 ok | 0.0677 | 0.0247 | 0.0906 | 0.0183 | 9/37 | 2209.3 MB |
| `qwen3-asr-0.6b-mlx-6bit` | 107 | 107 ok | 0.0654 | 0.0247 | 0.0839 | 0.0188 | 8/37 | 2317.8 MB |
| `qwen3-asr-0.6b-mlx-8bit` | 107 | 106 ok, 1 no_text | 0.0616 | 0.0247 | 0.0806 | 0.0191 | 8/37 | 2472.7 MB |

## Video Boundary Aggregate

| Model | Segments | Videos | Mean similarity | Token similarity | Length ratio | Segment RTF | Verdict |
|---|---:|---:|---:|---:|---:|---:|---|
| `qwen3-asr-0.6b-mlx-4bit` | 97 | 10 | 0.9334 | 0.9339 | 1.0133 | 0.0210 | 10/10 likely_aligned |
| `qwen3-asr-0.6b-mlx-5bit` | 97 | 10 | 0.9336 | 0.9343 | 1.0140 | 0.0210 | 10/10 likely_aligned |
| `qwen3-asr-0.6b-mlx-6bit` | 97 | 10 | 0.9350 | 0.9353 | 1.0137 | 0.0208 | 10/10 likely_aligned |
| `qwen3-asr-0.6b-mlx-8bit` | 97 | 10 | 0.9341 | 0.9344 | 1.0137 | 0.0211 | 10/10 likely_aligned |

## Key Interpretation

The `4bit` model is not production-safe. Its median CER looked normal, but it had severe outliers:

- One 45-second synthetic segment expected about 200 characters and produced 16,359 output characters.
- One 650-second synthetic case expected 2,895 characters and produced 14,927 output characters.

These failures are unacceptable for a voice-input app because one bad turn can paste a very large hallucinated transcript.

The `5bit` model is the only lower-footprint variant worth remembering. It saved 22.2% on the weight file and was close on video boundary results, but its local mean CER was still worse than `8bit`.

The `6bit` model was also close to `8bit`, but its practical benefit was too small: only 14.8% weight saving and no aggregate accuracy win.

Numeric pass count did not justify switching models. `4bit` and `5bit` passed 9/37 numeric-format cases while `6bit` and `8bit` passed 8/37, but `8bit` still had the best numeric CER. Numeric formatting should continue to be handled by deterministic final-output ITN and focused prompt/normalization experiments rather than by choosing a worse ASR quantization.

## Cleanup Record

After preserving this summary, the following generated artifacts were intentionally removed:

- `.external/models/mlx-community__Qwen3-ASR-0.6B-4bit`
- `.external/models/mlx-community__Qwen3-ASR-0.6B-5bit`
- `.external/models/mlx-community__Qwen3-ASR-0.6B-6bit`
- `eval/asr_streaming/results/qwen3-0.6b-quant-comparison-20260705-135018`

The retained durable conclusion is that `mlx-community__Qwen3-ASR-0.6B-8bit` remains the default local Qwen3 model.
