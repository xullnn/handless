# Plan — Simple Numeric ITN

## Implementation sequence

1. Build an offline numeric ITN prototype against recorded text outputs and numeric fixtures.
2. Add test fixtures for positive and negative examples before wiring the feature into the App.
3. Implement the production ITN module as a small local rule engine.
4. Integrate the ITN module into final-output correction only, behind a config flag.
5. Re-run numeric, base, and segmented regression suites to check improvement and regressions.
6. If final-output behavior is stable, consider a separate follow-up for high-confidence partial display normalization.

## Touched areas

- `Sources/LocalVoiceInputCore/CorrectionPipeline.swift` or a neighboring Core module for final-output integration.
- `Sources/LocalVoiceInputCore/` for the new numeric ITN rule engine.
- `Tests/LocalVoiceInputCoreTests/` for unit tests and negative examples.
- `configs/` if a user-facing or runtime config flag is added.
- `eval/asr_streaming/` only for offline analysis/reporting scripts, if needed.

## Validation implementation notes

- Add unit tests that verify exact input/output pairs and no-op behavior for negative examples.
- Reuse the existing numeric cases for product-facing numeric-format pass rate.
- Re-run base cases as a regression guard so normal recognition output is not made worse.
- Report ITN changes separately from ASR raw output so failures can be diagnosed.

## PMB promotion candidates

- After validation, promote the durable decision that simple local numeric ITN is or is not the preferred solution for numeric formatting.

## Risks and mitigations

- Risk: Over-aggressive rules rewrite normal Chinese phrases incorrectly.
  Mitigation: Keep simple mode conservative, add negative tests, and apply to final text only at first.

- Risk: Numeric output improves while benchmark CER/WER appears worse because references are spoken-form Chinese.
  Mitigation: Keep numeric-format pass rate as the primary numeric metric and explain CER/WER limitations in reports.

- Risk: Users need Arabic digits in partial text too.
  Mitigation: Defer partial normalization until final-output ITN is validated; partial text can be treated as a separate feature.

## Notes

- `B`, `KB`, `MB`, `端口`, `版本`, `验证码`, and similar terms are confidence context, not required triggers for decimal conversion.
- Complex large-number handling is intentionally excluded unless real usage shows it is worth the risk.
