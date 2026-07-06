# Plan — Closed-Alpha Launch And Lifecycle Ergonomics

## Implementation sequence

1. Add a small pure presentation helper for menu-bar state labels, tooltips, and menu status text.
2. Update `MenuBarController` to use a variable-width LocalVoiceInput status item with clear state text.
3. Extend the menu callbacks for opening logs and copying diagnostics.
4. Wire the new callbacks through `AppController` without changing dictation/session behavior.
5. Add a lightweight diagnostics summary helper that reports app/config/runtime paths and safe runtime settings.
6. Generate and include a simple alpha app icon resource.
7. Update `scripts/build_macos_app.sh` to copy the icon and write `CFBundleIconFile`.
8. Update closed-alpha documentation with launch, find, quit, and diagnostic instructions.
9. Add focused tests for the new pure helper(s).
10. Build and validate the app and closed-alpha package.

## Touched areas

- `Sources/LocalVoiceInputMac/MenuBarController.swift`
- `Sources/LocalVoiceInputMac/AppController.swift`
- `Sources/LocalVoiceInputMac/AppControllerDependencies.swift`
- `Sources/LocalVoiceInputMac/*Diagnostics*`
- `Resources/AppIcon.icns`
- `scripts/build_macos_app.sh`
- `docs/macos-alpha-distribution.md`
- `Tests/LocalVoiceInputMacTests/*`

## Validation implementation notes

- Unit tests should cover menu-bar presentation and diagnostics string safety.
- Manual validation should focus on whether the app can be found and quit from the menu-bar item after launch.

## PMB promotion candidates

- Update `project_memory_bank/modules/macos_app/summary.md` only after validation if the clearer lifecycle menu becomes stable product behavior.
- Update `project_memory_bank/modules/packaging_ops/summary.md` only after validation if app icon bundling becomes part of the stable build workflow.

## Risks and mitigations

- Risk: A text-based status item consumes too much menu-bar space.
  Mitigation: Use short labels such as `LVI`, `REC`, and `LVI!`.
- Risk: A custom icon is confused with the macOS microphone privacy dot.
  Mitigation: Use visible app text in the status item instead of a standalone microphone glyph.
- Risk: Diagnostics accidentally expose user content.
  Mitigation: Keep diagnostics to paths, config flags, backend type, URL, and service/log locations; do not include transcripts or audio.
- Risk: App icon generation adds toolchain fragility.
  Mitigation: Commit the generated `.icns` and make the build script copy it when present.

## Notes

- Start-at-login, first-run onboarding, and settings UI are intentionally follow-up features.
