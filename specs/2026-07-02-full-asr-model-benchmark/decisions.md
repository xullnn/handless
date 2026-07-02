# Decisions - Full ASR Model Benchmark

## Confirmed Decisions

- D1: `mlx-community__Qwen3-ASR-0.6B-8bit` is the benchmark baseline because it is the current practical local ASR model behind the segmented service route.
- D2: The benchmark scope includes all current local runnable ASR case manifests with audio, not only the old 10-case base suite.
- D3: The benchmark must include numeric cases recorded after the initial base suite.
- D4: The benchmark must compare both recognition quality and runtime/resource behavior.
- D5: File-level final-transcript quality and segmented perceived-realtime product fit are separate dimensions and must be reported separately.
- D6: MiMo must be evaluated on all audio cases in file-level mode. If it lacks a segmented/chunked route, that limitation must be reported as compatibility evidence rather than hidden.
- D7: No local model files should be deleted for this benchmark.
- D8: The feature is evaluation-only and must not switch the App default model.
- D9: The current full benchmark acceptance surface is all selected manifest rows. At contract creation that is 106 rows and 100 unique audio files; duplicate-audio rollups are interpretation aids, not replacements for raw suite results.
- D10: The validated full benchmark keeps `qwen3-asr-0.6b-mlx-8bit` as the default realtime ASR baseline. `qwen3-asr-1.7b-mlx-8bit` has only a small CER advantage but worse WER, latency, RTF, and memory in segmented mode.
- D11: `mimo-v2.5-asr-mlx` is validated only as file-level/offline evidence in this benchmark. Its local runtime exposes file-level `generate(...)` evidence but no proven safe segmented/chunked product interface.
- D12: Numeric formatting remains unsolved by model choice. The numeric pass rates are low for all compared model/mode combinations and should be handled as a separate feature.

## Resolved Questions

- RQ1: MiMo segmented/chunked support is classified as unsupported for this product route. The benchmark records runtime evidence in every MiMo segmented suite summary.
- RQ2: Qwen3-ASR 1.7B can run through the same segmented service route for benchmark purposes, but the measured product-fit result does not justify replacing 0.6B.
- RQ3: The final recommendation uses a transparent decision matrix rather than a hidden weighted score. Rankings are separated into file-level accuracy, segmented product fit, numeric formatting, resource efficiency, and overall recommendation.
- RQ4: Synthetic long cases remain visible in per-suite and raw rollups. The report also provides deduplicated-audio rollups so repeated/synthetic evidence does not hide human-use interpretation.

## Open Questions / Unresolved Choices

- O1: Whether to create a separate numeric-format strategy feature using prompt variants, guarded normalization, or a hybrid approach.
- O2: Whether Qwen3-ASR 1.7B should be evaluated later as a final-only correction candidate with an explicit user-wait budget.

## PMB Promotion Candidates

- P1: If validated, promote the durable baseline definition and benchmark outcome to `project_memory_bank/modules/asr_audio/summary.md`.
- P2: If validated, promote model resource sizing guidance to PMB or the model inventory.
- P3: If a candidate beats Qwen3 0.6B and is product-feasible, create a separate model-profile/runtime-switch feature instead of changing PMB directly from this benchmark.
