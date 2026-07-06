# Decisions — Closed-Alpha Launch And Lifecycle Ergonomics

## Confirmed decisions

- D1: Closed-alpha builds should be Dock-visible by default because host smoke showed a pure menu-bar utility is not reliable enough as the only launch/quit surface for non-technical testers.
- D2: Use a short, visible app-owned status item label instead of relying on the generic microphone symbol.
- D3: Treat start-at-login, onboarding, and settings UI as follow-up features rather than blocking the first ergonomics hardening pass.
- D4: Add logs and diagnostics entry points directly to the menu because closed-alpha testers should not need Terminal for basic support collection.
- D5: Diagnostics must be safe by default and must not include transcript history or recorded audio.
- D6: Preserve a menu-bar-only escape hatch for developer use via `LOCALVOICEINPUT_MENU_BAR_ONLY=1` at build time and `--menu-bar-only` at launch time.

## Open questions / unresolved choices

- Q1: Whether the final product brand should remain `LocalVoiceInput` or switch to a shorter user-facing name before notarized wider distribution.
- Q2: Whether a future normal foreground helper window is worth adding for onboarding/settings while keeping the dictation surface menu-bar-first.

## PMB promotion candidates

- Promote clearer lifecycle menu behavior to `project_memory_bank/modules/macos_app/summary.md` after validation.
- Promote app icon bundling to `project_memory_bank/modules/packaging_ops/summary.md` after validation.
