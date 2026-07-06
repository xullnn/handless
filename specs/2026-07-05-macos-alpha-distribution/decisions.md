# Decisions - macOS Closed Alpha Distribution Package

## Confirmed decisions

- D1: Phase 1 targets a small trusted closed alpha for friends and colleagues, not immediate Mac App Store release.
- D2: Phase 1 artifact is an unnotarized closed-alpha DMG containing a drag-installable macOS app.
- D3: Phase 1 does not require Apple Developer Program membership, Developer ID certificates, notarization, stapling, or App Store Connect.
- D4: Phase 1 accepts expected Gatekeeper first-launch friction; tester documentation must explain the Privacy & Security "Open Anyway" flow.
- D5: Phase 1 should not use a `.pkg` installer. A package installer can return in a future Developer ID/Installer certificate path.
- D6: The current app remains a menu-bar `LSUIElement` utility, not an InputMethodKit input method.
- D7: The first closed alpha keeps Qwen3-ASR MLX 0.6B 8-bit behind the segmented localhost HTTP service as the actual-use ASR route.
- D8: Bundle the production Qwen3 0.6B 8-bit model for closed alpha; do not require testers to download or manually place the model.
- D9: Do not bundle `.external/models` wholesale or generated logs/artifacts.
- D10: Do not implement automatic network model download in this feature.
- D11: App-managed Qwen3 service startup is in scope for Phase 1 because testers should not need Terminal.
- D12: Keep ASR local-only; no cloud ASR fallback or audio/text upload is allowed by default.
- D13: Treat macOS TCC permissions as user-granted setup steps. Scripts and the app may guide the user, but cannot silently grant Microphone, Accessibility, or Input Monitoring permissions.
- D14: App Store, TestFlight, Developer ID notarization, stapled DMG, and `.pkg` installer remain future evaluation/distribution paths.
- D15: Phase 1 clean-VM smoke may be manual-assisted. A fully unattended VM login/control harness is useful future validation infrastructure, but it is not required to validate the closed-alpha package once the user can reach the VM desktop and run the smoke steps.

## Open questions / unresolved choices

- Q1: Should the long-term public bundle id remain `dev.localvoiceinput.mvp`, or should distribution switch to a product-style bundle id before broader external testing?
- Q2: Should the Qwen3 service port remain fixed at `18096` for all closed-alpha builds, or should a dynamic-port service discovery file be added after first alpha validation?
- Q3: What is the minimum tester hardware requirement beyond Apple Silicon macOS 13+ after the first non-developer smoke results are collected?
- Q4: Does the Qwen3/MLX/mlx-audio license/notice set require additional legal review before distribution beyond trusted closed alpha?
- Q5: Resolved for Phase 1 by D15: manual-assisted clean VM smoke is acceptable. A separate automation feature can still build a reliable VM login/control harness later.

## External platform facts checked

- Apple support documentation checked on 2026-07-05/2026-07-06 says users can manually override Privacy & Security settings to open an app from an unknown developer, but Apple warns this should only be done when the source is trusted.
- Apple Developer documentation checked on 2026-07-05 says Developer ID and notarization are the formal direct-distribution path outside the Mac App Store.
- Apple Developer documentation checked on 2026-07-05 says hardened runtime is required for notarization.
- Apple Developer documentation checked on 2026-07-05 says Mac App Store distribution requires App Sandbox.
- Apple App Store Connect documentation checked on 2026-07-05 says external TestFlight testing may require review.

## PMB promotion candidates

- Promote the validated closed-alpha packaging workflow to PMB after implementation and validation.
- Promote any stable bundle id, signing, service-supervision, runtime-staging, and TCC lessons after validation.

## Follow-up rationale

- `FUP-001` tracks the formal Developer ID/notarized distribution path after closed alpha proves product stability.
- `FUP-002` tracks richer model delivery/update UX after the first bundled-model alpha validates baseline feasibility.
- `FUP-003` tracks App Store/TestFlight readiness because sandbox and review constraints may force product/runtime architecture changes that are not needed for the closed alpha.
