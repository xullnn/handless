# Decisions — Session Coordinator Integration Tests

## Confirmed decisions

- D1: Build internal test seams around `AppController` instead of adding real macOS UI automation for this pass.
- D2: Preserve production wiring and user-facing behavior; this feature is about automated regression coverage.
- D3: Keep real microphone, AX, CGEvent, and physical focus behavior in the manual smoke layer.

## Open questions / unresolved choices

- None for this implementation pass.

## PMB promotion candidates

- Promote only after validation if the internal test seams become stable durable architecture.
