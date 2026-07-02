# Plan - Qwen3 0.6B Prompt A/B Benchmark

## Implementation Sequence

1. Add a focused report generator for Qwen3 0.6B prompt-vs-no-prompt results.
   - Load numeric-format analyses.
   - Load case-level comparison JSON.
   - Load base-suite comparison JSON.
   - Write `comparison.json`, `comparison.md`, and `recommendation.md`.

2. Add a small runner script.
   - Default mode reuses known no-prompt and prompt summaries.
   - `RUN_FRESH=1` mode reruns numeric/base suites for no-prompt and prompt using the segmented service gate.
   - Always regenerates numeric analyses and prompt-vs-no-prompt comparison reports.

3. Generate an A/B report using existing validated result summaries.
   - No-prompt source: full benchmark Qwen3 0.6B segmented numeric/base summaries.
   - Prompt source: segmented numeric/base prompt-v1 summaries.

4. Record SDD evidence.
   - Output directory.
   - Commands run.
   - Numeric pass delta.
   - Base regression result.
   - Recommendation.

## Touched Areas

- `eval/asr_streaming/qwen3_prompt_ab_report.py`
- `scripts/run_qwen3_06b_prompt_ab_benchmark.sh`
- `specs/2026-07-02-qwen3-06b-prompt-ab-benchmark/`
- `specs/progress.md`
- `specs/feature_matrix.json`

No expected changes:

- `Sources/`
- `Tests/`
- macOS App runtime behavior

## Validation Implementation Notes

- Validate JSON and Python syntax.
- Run script dry-run.
- Run script in reuse-existing mode.
- Validate that generated reports are non-empty.
- Do not require fresh reruns unless reused summaries are missing or mismatched.

## Risks And Mitigations

- Risk: Numeric CER/WER appears worse because Arabic-number formatting differs from spoken-form references.
  Mitigation: Treat numeric pass rate as primary for numeric suite and state the caveat in the report.

- Risk: Prompt evidence from an older run may not match the latest route.
  Mitigation: Verify metadata: same model id, same segmented runner, same case manifests, prompt enabled for prompt runs, prompt disabled for no-prompt runs.

- Risk: Prompt improves numeric formatting but hurts realtime UX.
  Mitigation: Include first partial latency and base-suite regression guard in the recommendation.
