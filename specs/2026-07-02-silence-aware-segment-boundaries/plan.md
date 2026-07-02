# Plan - Silence-Aware Segmented ASR Boundaries

## Implementation sequence

1. Add a boundary policy and boundary decision data structures to the segmented-cache service.
2. Implement pure local audio boundary selection:
   - scan backward from the target cut point
   - require a continuous low-energy window
   - fall back to hard cut plus overlap when no safe window exists
3. Update active-segment commit flow:
   - commit only the selected prefix audio
   - rewrite the committed segment cache file to match the committed prefix
   - carry post-cut audio into the next active segment
   - reset partial counters without replaying old partial prefixes
4. Add conservative adjacent-segment suffix/prefix de-duplication for overlap-originated repeats.
5. Extend `self-test` with synthetic audio and fake backend assertions.
6. Run syntax, self-test, and targeted service fake checks.
7. Record validation evidence in SDD.

## Touched areas

- `eval/asr_streaming/qwen3_mlx_segmented_cache_service.py`
- `specs/2026-07-02-silence-aware-segment-boundaries/`
- `specs/feature_matrix.json`
- `specs/progress.md`

## Validation implementation notes

- Start with fake/self-test because it exercises boundary mechanics without model latency or ASR quality noise.
- Use synthetic silence and non-silence audio so expected cut/carry behavior is deterministic.
- Do not run the App against the changed service until the service self-test and fake route pass.

## PMB promotion candidates

- If validated, promote the durable fact that the segmented-cache route uses silence-aware boundary selection plus overlap fallback.

## Risks and mitigations

- Risk: Low-energy detection cuts inside a word.
  Mitigation: Require a minimum continuous low-energy window and search only near the boundary.

- Risk: Carry audio breaks segment timestamps or cache files.
  Mitigation: Add explicit metadata diagnostics and self-test file-size/time assertions.

- Risk: Overlap causes repeated text in final output.
  Mitigation: Only perform exact adjacent suffix/prefix de-duplication, and only when overlap is involved.

- Risk: Boundary logic changes user-facing runtime unexpectedly.
  Mitigation: Do not restart the current service during implementation; validate on self-test/fake paths first.
