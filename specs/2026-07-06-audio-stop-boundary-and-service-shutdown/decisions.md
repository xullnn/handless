# Decisions — Audio Stop Boundary And Service Shutdown Hardening

## Confirmed decisions

- D1: Closed-alpha builds prioritize clean stop boundaries over idle pre-roll convenience. `AudioCapture` should not keep the microphone running while idle to collect pre-roll.
- D2: The user-stop path should close the live audio gate immediately, then send only the trusted chunks returned by `stopAndFlush`.
- D3: The Qwen3 `resource_tracker` warning is treated as a shutdown hygiene issue unless functional failures appear. The fix is graceful app-owned service shutdown first, not broad service-supervision work.
- D4: This feature should not change the current Qwen3 0.6B model, numeric ITN, output audio ducking, or closed-alpha packaging strategy.

## Open questions / unresolved choices

- Whether to add a future user-visible recording latency or pre-roll preference remains open and out of scope.
- Whether to deploy the rebuilt package to the friend MacBook Air for another live smoke remains optional and should be decided after local validation.

## PMB promotion candidates

- If validated, record that the product policy is no idle microphone pre-roll in closed-alpha use.
- If validated, record that the app-managed Qwen3 service exposes and uses a graceful shutdown path.
