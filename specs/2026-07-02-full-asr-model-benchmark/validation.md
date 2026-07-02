# Validation - Full ASR Model Benchmark

## Completion Rule

This feature can be marked `passes=true` only after the full benchmark contract has been implemented, the required checks have run, and concrete evidence has been recorded in `specs/progress.md`.

Skipped checks are acceptable only when this file marks them optional/not applicable or the user explicitly approves the skip. A model that cannot run a segmented route must be recorded as a compatibility result with evidence, not silently skipped.

## Acceptance Criteria

- A1: The benchmark inventories all selected local runnable manifests and reports exact case counts, missing audio, duplicates, unique-audio count, and suite labels.
- A2: The benchmark validates required model paths before inference:
  - `.external/models/mlx-community__Qwen3-ASR-0.6B-8bit`
  - `.external/models/mlx-community__Qwen3-ASR-1.7B-8bit`
  - `.external/models/MiMo-V2.5-ASR-MLX`
  - `.external/models/MiMo-Audio-Tokenizer`
- A3: File-level evaluation runs for Qwen3 0.6B, Qwen3 1.7B, and MiMo across every required suite.
- A4: Segmented simulated-realtime evaluation runs for Qwen3 0.6B and Qwen3 1.7B across every required suite and every runnable manifest row, or records a blocking failure.
- A5: MiMo segmented/chunked feasibility is explicitly tested or explicitly classified unsupported with inspected local runtime evidence.
- A6: Every per-case result includes expected text, final text, CER, WER, final coverage ratio, duration, wall time, model id, suite id, and error/failure reason if applicable.
- A7: Every product-path segmented result includes first partial latency, partial cadence, final latency, partial event count, final event count, stale-event/cancel leakage status if the adapter supports it, and final coverage ratio.
- A8: Numeric suite analysis includes category-level and aggregate numeric-format pass/fail results separate from CER/WER.
- A9: Resource summaries exist for each model/mode/suite combination that ran, including peak RSS, mean RSS if sampled, peak CPU, mean CPU if sampled, wall time, model load time where available, and sample count.
- A10: The comparison report includes Chinese explanations for CER, WER, RTF, RSS, CPU, first partial latency, final latency, final coverage ratio, and numeric-format pass rate.
- A11: The comparison report includes model vendor, parameter scale, release date, local model path, and role for every model.
- A12: The recommendation explicitly compares every candidate against Qwen3 0.6B baseline and separates:
  - replacement candidate
  - final-only correction candidate
  - offline quality reference
  - not recommended / blocked
- A13: The final recommendation does not claim App readiness from file-level results alone.
- A14: The feature does not modify Swift App runtime behavior.
- A15: `specs/progress.md` records commands, result directory paths, aggregate metrics, blockers, skipped checks, and the final recommendation.
- A16: The report includes both raw manifest-row rollups and deduplicated-audio rollups, and states which one is used for acceptance.

## Required Automated Checks

These commands define the expected validation set after implementation:

```bash
python3 -m json.tool specs/feature_matrix.json >/dev/null
python3 -m json.tool specs/2026-07-02-full-asr-model-benchmark/feature.json >/dev/null
```

If a benchmark runner is added:

```bash
bash -n scripts/run_full_asr_model_benchmark.sh
DRY_RUN=1 bash scripts/run_full_asr_model_benchmark.sh
```

Smoke before full run:

```bash
SMOKE=1 bash scripts/run_full_asr_model_benchmark.sh
```

Full run:

```bash
bash scripts/run_full_asr_model_benchmark.sh
```

Result validation:

```bash
python3 -m json.tool eval/asr_streaming/results/<full-benchmark-run>/comparison.json >/dev/null
test -s eval/asr_streaming/results/<full-benchmark-run>/comparison.md
test -s eval/asr_streaming/results/<full-benchmark-run>/recommendation.md
```

## Manual Review Checks

- Read `comparison.md` and confirm the metric explanations are understandable to a non-specialist technical reader.
- Read `recommendation.md` and confirm the final recommendation does not collapse file-level quality and realtime product fit into one unsupported conclusion.
- Confirm that any skipped segmented MiMo result is explained by runtime/API evidence.
- Confirm that no audio/text upload or cloud service is used.

## Optional / Not Applicable Checks

- Manual macOS App smoke is not required for this benchmark unless a model is proposed as the new runtime default. This feature is evaluation-only.
- Running deleted historical models is not required.

## Evidence Required In `specs/progress.md`

- Feature id and date.
- Exact commands run.
- Model paths and model metadata.
- Suite manifests and case counts.
- Output directory.
- Aggregate quality, latency, and resource table.
- Numeric-format summary.
- Compatibility summary for file-level and segmented modes.
- Recommendation and rationale.
- Any skipped checks or blockers.
