# Plan - macOS Closed Alpha Distribution Package

## Implementation sequence

1. Revise the feature contract for the closed-alpha route.
   - Make Phase 1 explicitly unnotarized and closed to trusted testers.
   - Move Developer ID, notarization, stapling, and `.pkg` installer work to follow-ups.
2. Add an asset manifest/preflight layer.
   - Check the app, Qwen3 0.6B model, `.venv-mimo` runtime, `mlx-audio` source, and service source.
   - Print sizes and reject accidental inclusion of `.external/models` wholesale or generated logs.
   - Generate checksums for bundled model/runtime/service artifacts.
3. Add repo-external runtime staging validation.
   - Copy the minimum runtime/model/service assets to a temporary or `dist/` staging root.
   - Start the Qwen3 segmented service using only staged paths.
   - Query `/metadata` or `/health` to prove the staged service can boot outside the repo.
4. Add closed-alpha app resource staging.
   - Build the release app.
   - Copy staged runtime assets into `LocalVoiceInput.app/Contents/Resources/`.
   - Copy alpha config, manifest, checksums, and notices into resources or adjacent DMG files.
5. Implement minimal app-managed service supervision.
   - Add a macOS app service supervisor that checks `127.0.0.1:18096`.
   - Start bundled Python/service/model paths when the selected backend is `local-http` and the service is not already healthy.
   - Use user-writable spool/cache/log paths.
   - Stop the child process on app termination when the app started it.
   - Keep existing manual external-service usage valid when a compatible service is already running.
6. Make alpha defaults double-clickable.
   - Add a build/resource or config path that enables local HTTP ASR, NumericITN, and audio ducking for the closed-alpha app without command-line flags.
   - Preserve existing local development/FunASR paths.
7. Add closed-alpha DMG packaging.
   - Create a DMG containing the self-contained app, an Applications symlink, README, manifest, checksums, and license/notice files.
   - Support `--preflight`, `--stage-runtime`, `--verify-staged-runtime`, `--closed-alpha`, and `--dry-run` modes.
   - Keep a future `--developer-id` path as a separate mode if useful, but do not make it Phase 1 acceptance.
8. Add tester documentation.
   - Explain first-launch Gatekeeper override.
   - Explain required permissions and how to collect diagnostics.
   - State hardware/OS target and local-only privacy boundary.
9. Validate locally.
   - Run automated Swift and shell checks.
   - Verify staged runtime outside the repo.
   - Build the closed-alpha app and DMG.
   - Simulate downloaded/quarantined launch where practical.
   - Run real App smoke with Qwen3, short input, long input, cancel, and audio ducking.

## Touched areas

- `Sources/LocalVoiceInputMac/`
- `scripts/build_macos_app.sh`
- `scripts/package_macos_alpha.sh`
- `scripts/status_localvoiceinput.sh`
- `configs/`
- `docs/macos-alpha-distribution.md`
- `dist/` generated artifacts
- `specs/2026-07-05-macos-alpha-distribution/*`
- `specs/feature_matrix.json`
- `specs/progress.md`

## Validation implementation notes

- The first hard gate is repo-external service startup. If staged runtime cannot boot, packaging may still be implemented but the feature cannot be validated.
- The closed-alpha script must not label the DMG as notarized or Gatekeeper-accepted.
- Gatekeeper `spctl` rejection is expected for Phase 1 and should be recorded as informational evidence, not a failure.
- Status and preflight commands must avoid mutating real user runtime state unless their mode name explicitly says stage/build/package.
- Signing should prefer a stable configured or auto-detected identity, but closed-alpha output may fall back to ad-hoc with a warning.

## PMB promotion candidates

- Promote validated closed-alpha packaging workflow to `project_memory_bank/modules/packaging_ops/summary.md`.
- Promote stable alpha runtime/service supervision policy to `project_memory_bank/core/current_focus.md` only after validation.
- Promote any durable TCC/signing lessons to `project_memory_bank/insights/macos_tcc_codesigning.md`.

## Risks and mitigations

- Risk: `.venv-mimo` may not be relocatable after copying into an app bundle.
  Mitigation: validate staged runtime before treating the DMG as usable; if it fails, keep status `implemented` or `blocked` and record exact failure.
- Risk: App-managed service startup blocks or delays first dictation.
  Mitigation: use explicit health checks, clear errors, and keep the UI recoverable; keep future resource ceilings as a follow-up if needed.
- Risk: Port `18096` is already occupied.
  Mitigation: reuse compatible `/metadata` service when healthy; otherwise show an actionable incompatible-service error.
- Risk: The package accidentally includes obsolete models or generated logs.
  Mitigation: explicit asset allowlist, manifest, size report, and checksum generation.
- Risk: Testers cannot grant permissions because the app is a menu-bar utility.
  Mitigation: provide README guidance and keep PermissionManager prompts/manual permission paths in smoke validation.
- Risk: Closed-alpha testers are confused by Gatekeeper.
  Mitigation: document that this build is intentionally unnotarized and only for trusted testers; include Apple-supported Open Anyway instructions.
- Risk: License/notice coverage is incomplete.
  Mitigation: include discovered local license/readme files and record remaining legal review as a follow-up blocker for wider distribution.

## Notes

- Phase 1 is allowed to be rejected by Gatekeeper until the tester manually overrides it.
- Phase 2 will revisit Developer ID Application, Developer ID Installer, notarization, stapling, and `.pkg` once closed-alpha product stability is proven.
