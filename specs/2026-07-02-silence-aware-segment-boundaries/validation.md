# Validation - Silence-Aware Segmented ASR Boundaries

## Completion rule

This feature can be marked `passes=true` only when required checks pass and concrete evidence is recorded in `specs/progress.md`.

## Acceptance criteria

- A1: Synthetic audio with a valid low-energy window near the hard boundary cuts at that window instead of the hard boundary.
- A2: Audio after a silence cut is carried into the next segment and is not lost.
- A3: Synthetic audio without a low-energy window hard-cuts at the maximum duration and carries overlap into the next segment.
- A4: Segment metadata/events report boundary decisions and cut reasons.
- A5: Conservative adjacent boundary de-duplication removes exact overlap repeats but leaves non-overlap text unchanged.
- A6: Existing stale-token and cancel self-test behavior still passes.
- A7: The current running user-facing service is not restarted as part of automated validation.

## Required automated checks

```bash
python3 -m py_compile eval/asr_streaming/qwen3_mlx_segmented_cache_service.py
python3 eval/asr_streaming/qwen3_mlx_segmented_cache_service.py self-test
```

## Optional checks

Run a fake HTTP service on a non-user port if needed:

```bash
python3 eval/asr_streaming/qwen3_mlx_segmented_cache_service.py serve --fake-backend --port 18097
```

Run the real segmented regression only after the fake path passes and the user approves any runtime interruption or extra long compute.

## Evidence required in `specs/progress.md`

- Commands run.
- Self-test result.
- Whether the user-facing 18096 service was left running untouched.
- Boundary decision behavior covered by self-test.
- Skipped optional checks with rationale.
