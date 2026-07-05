# Core Logic Module

`Sources/LocalVoiceInputCore` owns platform-independent behavior.

Stable responsibilities:

- Voice session state transitions.
- Hotkey state machine for Right Option, Right Command + `.`, cross-mode replacement, and Esc behavior.
- Focus snapshot data model and sticky focus-change detection.
- Output mode routing based on focus, session type, policy, secure fields, and focus changes.
- ASR event disposition so online partials update the floating panel and offline segments do not finalize until user stop.
- Transcript merging with stale-session and late-partial protection.
- Rule-based correction, hotword correction, homophone correction, final-output numeric ITN for simple and strong-context numeric forms, and history reduction.

Stable NumericITN boundary:

- NumericITN is a local deterministic final-output correction pass, controlled by the app's numeric ITN setting/override.
- It handles simple decimals, version-like dotted expressions, strong digit-sequence contexts, bounded `十/百/千` integers in technical-unit context, complete percent expressions, and narrow ordinal/document contexts.
- It intentionally avoids bare integer rewriting, broad prose quantities, dates, times, money, `万/亿`, approximate percent phrases, colloquial omitted-place numbers, and partial/floating-panel normalization until those forms have separate validation.

Tests live under `Tests/LocalVoiceInputCoreTests` and cover most pure logic contracts.

Go Deeper:

- See `../../core/system_overview.md` for the runtime flow.
- See `../../integration/output_safety_flow.md` for output routing constraints.
