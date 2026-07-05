#if os(macOS)
import Foundation
import AppKit
import LocalVoiceInputCore

final class AppController {
    struct Dependencies {
        let menu: MenuBarControlling
        let panel: FloatingPanelPresenting
        let focusDetector: FocusDetecting
        let hotkeys: HotkeyControlling
        let audio: AudioCapturing
        let clipboard: ClipboardManaging
        let pasteRouter: PasteRouting
        let history: HistoryRecording
        let asrClientFactory: ASRClientMaking
        let focusMonitoringEnabled: Bool

        static func production(config: AppConfig) -> Dependencies {
            let clipboard = ClipboardManager()
            let keyboard = KeyboardSimulator()
            return Dependencies(
                menu: MenuBarController(),
                panel: FloatingPanelController(),
                focusDetector: FocusDetector(),
                hotkeys: HotkeyController(),
                audio: AudioCapture(),
                clipboard: clipboard,
                pasteRouter: PasteEngine(clipboard: clipboard, keyboard: keyboard, policy: config.outputPolicy),
                history: HistoryStore(policy: HistoryPolicy(maxItems: config.historyMaxItems)),
                asrClientFactory: DefaultASRClientFactory(),
                focusMonitoringEnabled: true
            )
        }
    }

    private let config: AppConfig
    private let menu: MenuBarControlling
    private let panel: FloatingPanelPresenting
    private let focusDetector: FocusDetecting
    private let hotkeys: HotkeyControlling
    private let audio: AudioCapturing
    private let audioSessionGate = AudioSessionGate()
    private let clipboard: ClipboardManaging
    private let pasteRouter: PasteRouting
    private let history: HistoryRecording
    private let asrClientFactory: ASRClientMaking
    private let focusMonitoringEnabled: Bool

    private var activeASR: ASRClientProtocol?
    private var stateMachine = VoiceSessionStateMachine()
    private var transcript: TranscriptBuffer?
    private var activeSessionId: String?
    private var activeSessionType: SessionType = .pushToTalk
    private var initialFocus = FocusSnapshot.unknown
    private var activeOutputMode: OutputMode = .clipboardDraft
    private var lastFinalText: String = ""
    private var didFinalize = false
    private var forceMockForCurrentSession = false
    private var userRequestedFinish = false
    private var focusTracker: FocusChangeTracker?
    private var focusMonitorTimer: Timer?
    private var activeASRClientId: ObjectIdentifier?
    private var activeSessionAudioMs = 0.0
    private let minimumRoutableRealAudioMs = 1100.0

    init(config: AppConfig) {
        self.config = config
        let dependencies = Dependencies.production(config: config)
        self.menu = dependencies.menu
        self.panel = dependencies.panel
        self.focusDetector = dependencies.focusDetector
        self.hotkeys = dependencies.hotkeys
        self.audio = dependencies.audio
        self.clipboard = dependencies.clipboard
        self.pasteRouter = dependencies.pasteRouter
        self.history = dependencies.history
        self.asrClientFactory = dependencies.asrClientFactory
        self.focusMonitoringEnabled = dependencies.focusMonitoringEnabled
        setupCallbacks()
    }

    init(config: AppConfig, dependencies: Dependencies) {
        self.config = config
        self.menu = dependencies.menu
        self.panel = dependencies.panel
        self.focusDetector = dependencies.focusDetector
        self.hotkeys = dependencies.hotkeys
        self.audio = dependencies.audio
        self.clipboard = dependencies.clipboard
        self.pasteRouter = dependencies.pasteRouter
        self.history = dependencies.history
        self.asrClientFactory = dependencies.asrClientFactory
        self.focusMonitoringEnabled = dependencies.focusMonitoringEnabled
        setupCallbacks()
    }

    func start() {
        ConfigPaths.ensureDirectories()
        PermissionManager.requestMicrophoneIfNeeded()
        if !PermissionManager.accessibilityTrusted {
            PermissionManager.promptAccessibilityIfNeeded()
        }
        if !PermissionManager.inputMonitoringTrusted {
            PermissionManager.requestInputMonitoringIfNeeded()
        }
        audio.prewarm()
        hotkeys.start()
        menu.setStatus("🎙")
    }

    func stop() {
        hotkeys.stop()
        cancelSession()
    }

    private func setupCallbacks() {
        menu.onStartMock = { [weak self] in self?.beginSession(type: .pushToTalk, forceMock: true) }
        menu.onStop = { [weak self] in self?.finishSession() }
        menu.onCopyLast = { [weak self] in self?.copyLastResult() }
        menu.onClearHistory = { [weak self] in self?.history.clear() }
        menu.onPromptPermissions = {
            PermissionManager.requestMicrophoneIfNeeded()
            PermissionManager.promptAccessibilityIfNeeded()
            PermissionManager.requestInputMonitoringIfNeeded()
        }

        panel.onCancel = { [weak self] in self?.cancelSession() }
        panel.onCopy = { [weak self] in
            guard let self else { return }
            let text = self.lastFinalText.isEmpty ? self.transcript?.latestText ?? "" : self.lastFinalText
            if !text.isEmpty {
                self.clipboard.writeString(text)
                self.panel.updateDone(status: .copied, text: text, restoredClipboard: false)
            }
        }
        panel.onRestoreClipboard = { [weak self] in self?.clipboard.restoreLastSavedSnapshot() }
        panel.onFinish = { [weak self] in self?.finishSession() }
        panel.onQuit = {
            NSApplication.shared.terminate(nil)
        }

        hotkeys.onPushToTalkStart = { [weak self] in self?.beginSession(type: .pushToTalk, forceMock: false, replacingExisting: true) }
        hotkeys.onPushToTalkStop = { [weak self] in self?.finishSession() }
        hotkeys.onLongDraftStart = { [weak self] in self?.beginSession(type: .longDraft, forceMock: false, replacingExisting: true) }
        hotkeys.onLongDraftStop = { [weak self] in self?.finishSession() }
        hotkeys.onCancel = { [weak self] in self?.cancelSession() }
        hotkeys.onError = { [weak self] message in self?.panel.updateError(message) }

        audio.onPCMChunk = { [weak self] token, data in
            DispatchQueue.main.async { self?.sendPCMToActiveASR(data, audioSessionToken: token) }
        }
        audio.onError = { [weak self] error in
            DispatchQueue.main.async { self?.handleError(error) }
        }
    }

    private func beginSession(type: SessionType, forceMock: Bool, replacingExisting: Bool = false) {
        DispatchQueue.main.async {
            if self.activeSessionId != nil {
                guard replacingExisting else { return }
                self.abandonActiveSessionForReplacement()
            }
            self.stateMachine = VoiceSessionStateMachine()
            self.stateMachine.send(.hotkeyDown)
            self.activeSessionType = type
            self.forceMockForCurrentSession = forceMock
            self.didFinalize = false
            self.userRequestedFinish = false
            self.lastFinalText = ""
            self.activeSessionAudioMs = 0
            self.initialFocus = self.focusDetector.snapshot()
            self.focusTracker = FocusChangeTracker(initial: self.initialFocus)
            let audioSessionToken = self.audioSessionGate.begin()
            self.activeOutputMode = OutputModeRouter.decide(
                snapshot: self.initialFocus,
                sessionType: type,
                focusChangedDuringRecording: false,
                policy: self.config.outputPolicy
            )
            self.panel.updateDiagnostics(self.focusDiagnostic(self.initialFocus, mode: self.activeOutputMode, changed: false))
            let sessionId = UUID().uuidString
            self.activeSessionId = sessionId
            self.transcript = TranscriptBuffer(sessionId: sessionId)
            self.stateMachine.send(.focusChecked)
            self.hotkeys.noteSessionStarted(type: type)
            self.panel.showListening(mode: self.activeOutputMode)
            self.menu.setStatus("🔴")
            self.startFocusMonitoring(sessionId: sessionId)
            self.startASR(sessionId: sessionId, forceMock: forceMock)
            guard self.activeSessionId == sessionId else { return }
            if !(self.config.mockASR || forceMock) {
                self.audio.start(sessionToken: audioSessionToken)
            }
        }
    }

    private func abandonActiveSessionForReplacement() {
        stateMachine.send(.cancel)
        audioSessionGate.end()
        audio.cancel()
        activeASR?.cancel()
        activeASR = nil
        activeASRClientId = nil
        activeSessionId = nil
        transcript = nil
        didFinalize = false
        userRequestedFinish = false
        forceMockForCurrentSession = false
        activeSessionAudioMs = 0
        focusTracker = nil
        stopFocusMonitoring()
        menu.setStatus("🎙")
    }

    private func startASR(sessionId: String, forceMock: Bool) {
        let client = asrClientFactory.makeClient(config: config, forceMock: forceMock)
        let clientId = ObjectIdentifier(client)
        client.onEvent = { [weak self, sessionId, clientId] event in
            DispatchQueue.main.async {
                self?.handleASREvent(event, expectedSessionId: sessionId, clientId: clientId)
            }
        }
        client.onError = { [weak self, sessionId, clientId] error in
            DispatchQueue.main.async {
                self?.handleError(error, expectedSessionId: sessionId, clientId: clientId)
            }
        }
        activeASR = client
        activeASRClientId = clientId
        client.start(sessionId: sessionId, hotwords: config.hotwords)
    }

    private func finishSession() {
        DispatchQueue.main.async {
            guard let sessionId = self.activeSessionId, !self.userRequestedFinish else { return }
            self.userRequestedFinish = true
            if self.stateMachine.state == .recording {
                self.stateMachine.send(.hotkeyUp)
            }
            self.panel.updateFinalizing()
            self.recomputeOutputModeForFocusChange()

            if self.config.mockASR || self.forceMockForCurrentSession {
                self.activeASR?.finish()
                self.scheduleFinalizeTimeout(seconds: 2.0, sessionId: sessionId)
                return
            }

            self.audio.stopAndFlush { [weak self, sessionId] audioSessionToken, remainingChunks in
                guard let self else { return }
                guard self.activeSessionId == sessionId, self.userRequestedFinish else { return }
                for chunk in remainingChunks {
                    self.sendPCMToActiveASR(chunk, audioSessionToken: audioSessionToken)
                }
                self.activeASR?.finish()
                self.scheduleFinalizeTimeout(seconds: self.finalizeTimeoutSeconds(), sessionId: sessionId)
            }
        }
    }

    private func scheduleFinalizeTimeout(seconds: TimeInterval, sessionId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.finalizeIfNeeded(reason: "timeout", expectedSessionId: sessionId)
        }
    }

    private func cancelSession() {
        DispatchQueue.main.async {
            guard self.activeSessionId != nil else { return }
            self.stateMachine.send(.cancel)
            self.audioSessionGate.end()
            self.audio.cancel()
            self.activeASR?.cancel()
            self.activeASR = nil
            self.activeASRClientId = nil
            self.activeSessionId = nil
            self.transcript = nil
            self.didFinalize = false
            self.userRequestedFinish = false
            self.forceMockForCurrentSession = false
            self.activeSessionAudioMs = 0
            self.focusTracker = nil
            self.stopFocusMonitoring()
            self.hotkeys.noteSessionEnded()
            self.menu.setStatus("🎙")
            self.panel.updateDone(status: .cancelled, text: "", restoredClipboard: false)
        }
    }

    private func handleASREvent(_ event: ASREvent, expectedSessionId: String, clientId: ObjectIdentifier) {
        guard isCurrentASR(sessionId: expectedSessionId, clientId: clientId) else { return }
        guard event.sessionId == expectedSessionId else { return }
        guard var buffer = transcript else { return }
        buffer.apply(event)
        transcript = buffer

        switch ASREventRouter.disposition(for: event, state: stateMachine.state, userRequestedFinish: userRequestedFinish) {
        case .updatePartial:
            panel.updatePartial(buffer.latestText)
        case .finalize:
            finalizeIfNeeded(reason: event.mode == .offline ? "offline_final" : "unknown_final", expectedSessionId: expectedSessionId)
        }
    }

    private func recomputeOutputModeForFocusChange() {
        let latest = focusDetector.snapshot()
        updateFocusTracker(with: latest)
        updateOutputModeForCurrentFocusState()
    }

    private func updateFocusTracker(with latest: FocusSnapshot) {
        if focusTracker == nil {
            focusTracker = FocusChangeTracker(initial: initialFocus)
        }
        guard var tracker = focusTracker else { return }
        tracker.observe(latest)
        focusTracker = tracker
    }

    private func updateOutputModeForCurrentFocusState() {
        let changed = focusTracker?.didChange ?? false
        let newMode = OutputModeRouter.decide(
            snapshot: initialFocus,
            sessionType: activeSessionType,
            focusChangedDuringRecording: changed,
            policy: config.outputPolicy
        )
        if newMode != activeOutputMode {
            activeOutputMode = newMode
            panel.updateMode(newMode)
        }
        panel.updateDiagnostics(focusDiagnostic(initialFocus, mode: activeOutputMode, changed: changed))
    }

    private func startFocusMonitoring(sessionId: String) {
        guard focusMonitoringEnabled else { return }
        stopFocusMonitoring()
        focusMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.recordFocusSample(sessionId: sessionId)
        }
    }

    private func stopFocusMonitoring() {
        focusMonitorTimer?.invalidate()
        focusMonitorTimer = nil
    }

    private func recordFocusSample(sessionId: String) {
        guard activeSessionId == sessionId else { return }
        let wasChanged = focusTracker?.didChange ?? false
        updateFocusTracker(with: focusDetector.snapshot())
        let changed = focusTracker?.didChange ?? false
        if changed && !wasChanged {
            updateOutputModeForCurrentFocusState()
        }
    }

    private func finalizeIfNeeded(reason: String, expectedSessionId: String? = nil) {
        guard !didFinalize, let currentSessionId = activeSessionId else { return }
        if let expectedSessionId, expectedSessionId != currentSessionId { return }
        didFinalize = true
        stateMachine.send(.finalASRReceived)
        activeASR?.cancel()
        activeASR = nil
        activeASRClientId = nil
        audioSessionGate.end()
        audio.cancel()
        stopFocusMonitoring()

        let raw = transcript?.finalText.isEmpty == false ? transcript!.finalText : (transcript?.latestText ?? "")
        let fallbackText = raw.isEmpty && (config.mockASR || forceMockForCurrentSession) ? config.mockTranscript : raw
        if !(config.mockASR || forceMockForCurrentSession),
           activeSessionAudioMs < minimumRoutableRealAudioMs {
            panel.updateError("录音太短，没有输出。请按住 Right Option 说完后再松开。")
            cleanupSession(resetLastText: false)
            return
        }
        guard !fallbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            panel.updateError("没有识别到文本。")
            cleanupSession(resetLastText: false)
            return
        }

        let correction = CorrectionPipeline(config: CorrectionConfig(
            mode: config.correctionMode,
            hotwords: config.hotwords,
            homophones: config.homophones,
            removeFillers: true,
            ensureTerminalPunctuation: true,
            numericITNEnabled: config.numericITNEnabled
        )).correct(fallbackText)
        stateMachine.send(.correctionFinished)

        let finalText = correction.corrected
        lastFinalText = finalText
        let outputMode = activeOutputMode
        let appliedRules = correction.appliedRules
        pasteRouter.routeAsync(text: finalText, mode: outputMode) { [weak self, currentSessionId, finalText, appliedRules] output in
            DispatchQueue.main.async {
                self?.completeFinalOutput(
                    output: output,
                    finalText: finalText,
                    outputMode: outputMode,
                    correctionRules: appliedRules,
                    expectedSessionId: currentSessionId
                )
            }
        }
    }

    private func completeFinalOutput(
        output: OutputResult,
        finalText: String,
        outputMode: OutputMode,
        correctionRules: [String],
        expectedSessionId: String
    ) {
        guard activeSessionId == expectedSessionId, didFinalize else { return }
        panel.updateDiagnostics(outputDiagnostic(output))
        stateMachine.send(.outputRouted)
        history.append(text: finalText, outputMode: outputMode, correctionRules: correctionRules)
        panel.updateDone(status: output.status, text: finalText, restoredClipboard: output.restoredClipboard)
        cleanupSession(resetLastText: false)
    }

    private func cleanupSession(resetLastText: Bool) {
        activeASR?.cancel()
        activeASR = nil
        activeASRClientId = nil
        audioSessionGate.end()
        activeSessionId = nil
        transcript = nil
        didFinalize = false
        userRequestedFinish = false
        forceMockForCurrentSession = false
        activeSessionAudioMs = 0
        focusTracker = nil
        stopFocusMonitoring()
        hotkeys.noteSessionEnded()
        if resetLastText { lastFinalText = "" }
        menu.setStatus("🎙")
    }

    private func copyLastResult() {
        guard let latest = history.latest() else { return }
        clipboard.writeString(latest.text)
        panel.show(mode: .clipboardDraft)
        panel.updateDone(status: .copied, text: latest.text, restoredClipboard: false)
    }

    private func sendPCMToActiveASR(_ data: Data, audioSessionToken: AudioSessionToken?) {
        guard activeSessionId != nil else { return }
        guard audioSessionGate.accepts(audioSessionToken) else { return }
        activeSessionAudioMs += Double(data.count) / 2.0 / 16_000.0 * 1000.0
        activeASR?.sendPCM(data)
    }

    private func finalizeTimeoutSeconds() -> TimeInterval {
        guard !config.mockASR, !forceMockForCurrentSession else { return 2.0 }
        switch config.asrBackend {
        case .funASRWebSocket:
            return 3.5
        case .localHTTP:
            let audioSeconds = activeSessionAudioMs / 1000.0
            return min(120.0, max(12.0, audioSeconds * 0.75 + 10.0))
        }
    }

    private func isCurrentASR(sessionId: String, clientId: ObjectIdentifier) -> Bool {
        guard activeSessionId == sessionId, let activeASRClientId else { return false }
        return activeASRClientId == clientId
    }

    private func handleError(_ error: Error, expectedSessionId: String? = nil, clientId: ObjectIdentifier? = nil) {
        if let expectedSessionId, let clientId, !isCurrentASR(sessionId: expectedSessionId, clientId: clientId) {
            return
        }
        let salvage = transcript?.latestText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if activeSessionId != nil, !salvage.isEmpty {
            guard let sessionId = activeSessionId else { return }
            stateMachine.send(.error)
            lastFinalText = salvage
            pasteRouter.routeAsync(text: salvage, mode: .fallbackCopy) { [weak self, sessionId, salvage] output in
                DispatchQueue.main.async {
                    guard let self, self.activeSessionId == sessionId else { return }
                    self.history.append(text: salvage, outputMode: .fallbackCopy, correctionRules: ["error_salvage"])
                    self.panel.updateDone(status: output.status, text: salvage, restoredClipboard: output.restoredClipboard)
                    self.cleanupSession(resetLastText: false)
                }
            }
        } else {
            if activeSessionId != nil {
                stateMachine.send(.error)
            }
            panel.updateError(error.localizedDescription)
            cleanupSession(resetLastText: false)
        }
        menu.setStatus("⚠️")
    }

    private func focusDiagnostic(_ snapshot: FocusSnapshot, mode: OutputMode, changed: Bool) -> String {
        let app = snapshot.frontmostAppBundleId ?? "nil"
        let role = snapshot.elementRole ?? "nil"
        let subrole = snapshot.elementSubrole ?? "nil"
        let editable = snapshot.isEditable ? "T" : "F"
        let paste = snapshot.canPaste ? "T" : "F"
        let secure = snapshot.isSecureTextField ? "T" : "F"
        return "Focus \(app) role=\(role) sub=\(subrole) edit=\(editable) paste=\(paste) secure=\(secure) conf=\(snapshot.confidence.rawValue) mode=\(mode.rawValue) changed=\(changed ? "T" : "F")"
    }

    private func outputDiagnostic(_ output: OutputResult) -> String {
        let changed = focusTracker?.didChange ?? false
        return "Output verify=\(output.verification.rawValue) status=\(output.status.rawValue) restored=\(output.restoredClipboard ? "T" : "F") | \(focusDiagnostic(initialFocus, mode: activeOutputMode, changed: changed))"
    }
}
#endif
