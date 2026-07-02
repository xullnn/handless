# Plan - Full ASR Model Benchmark

## Implementation Sequence

1. Add a benchmark inventory step.
   - Discover selected manifest files.
   - Resolve every audio path.
   - Write `case_inventory.json` with suite, case id, audio path, duration, expected text, scenario, and missing-file status.
   - Record both manifest-row count and unique-audio count. The creation-time baseline is 106 manifest rows and 100 unique audio files.

2. Add or extend a full benchmark orchestrator.
   - Preferred output root: `eval/asr_streaming/results/full-asr-model-benchmark-YYYYMMDD-HHMMSS/`.
   - Reuse existing harness code where possible instead of duplicating scoring logic.
   - Keep model-specific runner details behind model profiles.

3. Implement model profiles.
   - Qwen3-ASR 0.6B MLX file-level profile.
   - Qwen3-ASR 1.7B MLX file-level profile.
   - MiMo-V2.5-ASR MLX file-level profile.
   - Qwen3-ASR 0.6B segmented profile using `qwen3_mlx_segmented_cache_service.py`.
   - Qwen3-ASR 1.7B segmented profile using the same segmented service with the 1.7B model path.
   - MiMo segmented/chunked compatibility probe. Implement only if the API supports it safely; otherwise record unsupported evidence.

4. Add resource sampling around every run.
   - Use or extend `eval/asr_streaming/monitor_pid_resources.py`.
   - Capture peak RSS, mean RSS, peak CPU, mean CPU, model load time, run wall time, and sample count.
   - For service-mode runs, separate model-load resource from per-suite run resource when practical.

5. Run file-level suites.
   - Run every required model over all selected full benchmark manifests.
   - Store one per-model/per-suite summary and one per-case result.

6. Run segmented simulated-realtime suites.
   - Run Qwen3 0.6B and 1.7B through the active segmented local HTTP service.
   - Use realtime-paced input by default for product-path evidence.
   - If long/synthetic suites are too slow for a single uninterrupted run, split by suite but keep one combined report.

7. Run numeric-format analysis.
   - Reuse or extend `eval/asr_streaming/analyze_numeric_format_results.py`.
   - Compare numeric outputs by category and by must-include/must-not-include expectations.

8. Generate comparison artifacts.
   - `comparison.json`: machine-readable aggregate.
   - `comparison.csv`: spreadsheet-friendly aggregate.
   - `comparison.md`: human-readable report with Chinese metric explanations.
   - `recommendation.md`: model ranking and product-path recommendation.

9. Record SDD evidence.
   - Append commands, result directories, key aggregate metrics, blockers, skipped checks, and recommendation to `specs/progress.md`.
   - Update `specs/feature_matrix.json` only after validation or closeout.

## Touched Areas

Expected implementation areas:

- `eval/asr_streaming/`
- `scripts/`
- `specs/2026-07-02-full-asr-model-benchmark/`
- `specs/progress.md`
- `specs/feature_matrix.json`

No expected changes:

- `Sources/`
- `Tests/`
- macOS App runtime behavior
- clipboard, paste, focus, hotkey, or floating-panel code

## Output Directory Contract

Each complete run should produce:

```text
eval/asr_streaming/results/full-asr-model-benchmark-YYYYMMDD-HHMMSS/
  run_manifest.json
  case_inventory.json
  models.json
  suites.json
  file_level/
    <model-id>/<suite-id>/summary.json
    <model-id>/<suite-id>/<case-id>/summary.json
  segmented/
    <model-id>/<suite-id>/summary.json
    <model-id>/<suite-id>/<case-id>/summary.json
  resources/
    <model-id>/<mode>/<suite-id>/resource_samples.jsonl
    <model-id>/<mode>/<suite-id>/resource_summary.json
  numeric/
    <model-id>/<mode>/numeric_format_analysis.json
  comparison.json
  comparison.csv
  comparison.md
  recommendation.md
```

## Comparison Rules

- Report per-suite results before any overall ranking.
- Provide at least two rollups:
  - Raw manifest rollup: every case entry counts as present in its manifest.
  - Deduplicated audio rollup: repeated audio paths count once.
- Treat the raw manifest rollup as the acceptance surface and the deduplicated rollup as an interpretation aid.
- Do not let synthetic cases dominate the overall human-use score; show them as stress evidence.
- Rank models separately for:
  - file-level final accuracy
  - segmented perceived-realtime product fit
  - numeric formatting
  - resource efficiency
  - overall recommendation

## Validation Implementation Notes

- Add a dry-run mode that prints model paths, suite paths, estimated case count, output directory, and commands without running inference.
- Add a small smoke mode that runs one case per model before the full benchmark.
- Include timeout handling per case and per suite.
- Include fail-fast only for missing required model files or invalid manifests. Individual model/case failures should be recorded and the benchmark should continue where possible.

## PMB Promotion Candidates

Promote only after validation:

- Baseline model decision changes.
- Durable model ranking.
- Durable operating guidance for Qwen3 1.7B or MiMo.
- Resource sizing guidance for supported deployment profiles.

## Risks And Mitigations

- Risk: Full benchmark takes a long time.
  Mitigation: Support smoke, per-suite resume, and clear output directories.

- Risk: MiMo consumes high memory or lacks segmented support.
  Mitigation: Run file-level first, measure resources, then classify segmented support explicitly rather than forcing product integration.

- Risk: Duplicate manifests distort aggregate scores.
  Mitigation: Produce both raw and deduplicated rollups.

- Risk: Numeric-format scoring conflicts with literal-reference CER/WER.
  Mitigation: Keep numeric-format pass rates separate from CER/WER and explain both.

- Risk: Comparing file-level and service-mode resource data is misleading.
  Mitigation: Label mode and process boundary for every resource summary.

## Notes

- This feature defines evaluation and reporting only. It does not decide or implement the model switch.
