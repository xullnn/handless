# Requirements - Qwen3 0.6B Prompt A/B Benchmark

## Problem

The full ASR model benchmark intentionally ran without a system prompt. Earlier targeted experiments suggested the Qwen3 numeric-style system prompt may improve Arabic-number formatting, but the effect was not recorded as a clean prompt-vs-no-prompt A/B result. The project needs a focused 0.6B-only comparison before deciding whether the prompt should be enabled, refined, or abandoned in favor of local numeric ITN.

## Scope

### IN

- Compare only `qwen3-asr-0.6b-mlx-8bit`.
- Compare two conditions:
  - no system prompt
  - `configs/asr/qwen3_system_prompt.numeric_style.zh.txt`
- Use the active segmented simulated-realtime route, because prompt behavior matters for the real App-facing product path.
- Primary suite: `eval/asr_streaming/cases.numeric.local.jsonl` (`37` cases).
- Regression guard suite: `eval/asr_streaming/cases.local.jsonl` (`10` base cases).
- Produce machine-readable and Chinese human-readable reports.
- Record whether the prompt should be enabled by default.

### OUT

- No comparison across 1.7B or MiMo.
- No full 106-case rerun unless explicitly requested later.
- No App runtime change.
- No default prompt enablement.
- No cloud ASR.
- No upload of audio or text.
- No numeric post-processing implementation in this feature.

## Requirements

- R1: The A/B result must identify the model, prompt file, test suites, and source summaries used.
- R2: Numeric format analysis must compare pass rate, improved cases, worsened cases, and changed final text.
- R3: The report must explain that numeric-suite CER/WER are computed against spoken-form references and can penalize desired Arabic-number formatting.
- R4: Base suite comparison must act as a normal-recognition regression guard using CER, WER, coverage, and first partial latency.
- R5: The recommendation must clearly say whether the prompt should be enabled by default.
- R6: The feature must not modify Swift App runtime behavior or change active ASR defaults.

## Constraints

- Reuse existing prompt and no-prompt evidence when it is from the same 0.6B segmented route and case suites.
- Provide a runner that can regenerate the report and optionally rerun fresh gate passes.
- Keep generated benchmark results local.

## Dependencies

- `2026-07-01-qwen3-segmented-regression-suite`
- `2026-07-02-full-asr-model-benchmark`

## Related PMB Context

- `project_memory_bank/core/current_focus.md`
- `project_memory_bank/modules/asr_audio/summary.md`
