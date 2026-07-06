#if os(macOS)
import Foundation
import XCTest
import LocalVoiceInputCore
@testable import LocalVoiceInputMac

final class AppControllerSessionTests: XCTestCase {
    func testDelayedPasteCompletionFromReplacedSessionIsIgnored() {
        let harness = makeHarness(autoCompletePaste: false)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let oldClient = harness.asrFactory.clients[0]
        harness.audio.emitPCM(twoSecondsOfPCM())
        drainMainQueue()
        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()
        oldClient.emitFinal("旧会话文本")
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.paste.calls.count, 1)
        XCTAssertTrue(harness.history.items.isEmpty)

        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        XCTAssertEqual(harness.asrFactory.clients.count, 2)
        XCTAssertEqual(harness.panel.listeningModes, [.cursorPaste, .cursorPaste])

        harness.paste.completeCall(at: 0, status: .pasted, verification: .confirmed)
        drainMainQueue()

        XCTAssertTrue(harness.history.items.isEmpty)
        XCTAssertTrue(harness.panel.doneEvents.isEmpty)
        XCTAssertEqual(harness.hotkeys.startedTypes, [.pushToTalk, .pushToTalk])
    }

    func testStaleASRFinalAfterShortToLongReplacementIsIgnored() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let oldClient = harness.asrFactory.clients[0]
        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()

        oldClient.emitFinal("不应进入新会话")
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.asrFactory.clients.count, 2)
        XCTAssertEqual(oldClient.cancelCallCount, 1)
        XCTAssertEqual(harness.paste.calls.count, 0)
        XCTAssertTrue(harness.history.items.isEmpty)
        XCTAssertEqual(harness.hotkeys.startedTypes, [.pushToTalk, .longDraft])
        XCTAssertEqual(harness.panel.listeningModes, [.cursorPaste, .floatingDraft])
    }

    func testStaleAudioChunkAfterReplacementDoesNotReachNewASRClient() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let oldToken = tryUnwrap(harness.audio.startedTokens.first)
        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()

        let newClient = harness.asrFactory.clients[1]
        let newToken = tryUnwrap(harness.audio.startedTokens.last)
        XCTAssertNotEqual(oldToken, newToken)

        harness.audio.emitPCM(Data([1, 2, 3, 4]), token: oldToken)
        drainMainQueue()
        XCTAssertTrue(newClient.sentPCM.isEmpty)

        harness.audio.emitPCM(Data([5, 6, 7, 8]), token: newToken)
        drainMainQueue()
        XCTAssertEqual(newClient.sentPCM, [Data([5, 6, 7, 8])])
    }

    func testLateLiveAudioAfterUserStopIsRejectedButFlushedAudioIsSent() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let token = tryUnwrap(harness.audio.startedTokens.first)
        let client = harness.asrFactory.clients[0]
        let flushed = Data([9, 9, 9, 9])
        harness.audio.flushChunks = [flushed]

        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()
        harness.audio.emitPCM(Data([1, 2, 3, 4]), token: token)
        drainMainQueue()

        XCTAssertEqual(client.sentPCM, [flushed])
        XCTAssertEqual(client.finishCallCount, 1)
    }

    func testLateAudioFromStoppedSessionDoesNotReachNextSession() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let oldToken = tryUnwrap(harness.audio.startedTokens.first)
        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()

        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.asrFactory.clients.count, 2)
        let newClient = harness.asrFactory.clients[1]
        let newToken = tryUnwrap(harness.audio.startedTokens.last)
        XCTAssertNotEqual(oldToken, newToken)

        harness.audio.emitPCM(Data([1, 2, 3, 4]), token: oldToken)
        drainMainQueue()
        XCTAssertTrue(newClient.sentPCM.isEmpty)

        harness.audio.emitPCM(Data([5, 6, 7, 8]), token: newToken)
        drainMainQueue()
        XCTAssertEqual(newClient.sentPCM, [Data([5, 6, 7, 8])])
    }

    func testLongToShortReplacementStartsPushToTalkAndCancelsLongSession() {
        let harness = makeHarness()
        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()

        let oldClient = harness.asrFactory.clients[0]
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.asrFactory.clients.count, 2)
        XCTAssertEqual(oldClient.cancelCallCount, 1)
        XCTAssertEqual(harness.hotkeys.startedTypes, [.longDraft, .pushToTalk])
        XCTAssertEqual(harness.panel.listeningModes, [.floatingDraft, .cursorPaste])
    }

    func testCancelDoesNotRouteOutputOrHistoryAndIgnoresLateFinal() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let oldClient = harness.asrFactory.clients[0]
        harness.audio.emitPCM(twoSecondsOfPCM())
        drainMainQueue()
        harness.hotkeys.triggerCancel()
        drainMainQueue()

        oldClient.emitFinal("取消之后的迟到文本")
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.paste.calls.count, 0)
        XCTAssertTrue(harness.history.items.isEmpty)
        XCTAssertEqual(harness.panel.doneEvents.map(\.status), [.cancelled])
    }

    func testLocalHTTPBackendEnsuresServiceBeforeStartingASR() {
        let harness = makeHarness(asrBackend: .localHTTP)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.localASRService.prepareCallCount, 0)
        XCTAssertEqual(harness.localASRService.ensureCallCount, 1)
        XCTAssertEqual(harness.asrFactory.clients.count, 1)
        XCTAssertEqual(harness.audio.startedTokens.count, 1)
    }

    func testLocalHTTPBackendDoesNotStartRecordingWhenServiceFails() {
        let error = NSError(
            domain: "test.local-service",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Synthetic local service failure"]
        )
        let harness = makeHarness(asrBackend: .localHTTP, localASRServiceResult: .failure(error))
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.localASRService.ensureCallCount, 1)
        XCTAssertTrue(harness.panel.errors.contains("Synthetic local service failure"))
        XCTAssertEqual(harness.asrFactory.clients.count, 0)
        XCTAssertTrue(harness.audio.startedTokens.isEmpty)
        XCTAssertTrue(harness.hotkeys.startedTypes.isEmpty)
    }

    func testFocusChangeDowngradesCursorPasteToClipboardDraft() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let client = harness.asrFactory.clients[0]
        harness.audio.emitPCM(twoSecondsOfPCM())
        drainMainQueue()
        harness.focus.current = editableFocus(windowTitle: "Different Window")
        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()
        client.emitFinal("焦点变化后的文本")
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.paste.calls.map(\.mode), [.clipboardDraft])
        XCTAssertEqual(harness.history.items.first?.outputMode, .clipboardDraft)
        XCTAssertEqual(harness.panel.doneEvents.first?.status, .copied)
    }

    func testTooShortRealAudioDoesNotRouteOutput() {
        let harness = makeHarness()
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        let client = harness.asrFactory.clients[0]
        harness.audio.emitPCM(Data(count: 1600))
        drainMainQueue()
        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()
        client.emitFinal("太短的文本")
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.paste.calls.count, 0)
        XCTAssertTrue(harness.history.items.isEmpty)
        XCTAssertTrue(harness.panel.errors.contains { $0.contains("录音太短") })
    }

    func testDuckingStartsForRealShortSessionAndRestoresOnStopBeforeFinal() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.beginSessionIds.count, 1)
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)
        let client = harness.asrFactory.clients[0]
        harness.audio.emitPCM(twoSecondsOfPCM())
        drainMainQueue()

        harness.hotkeys.triggerPushToTalkStop()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertEqual(client.finishCallCount, 1)

        client.emitFinal("完成文本")
        drainMainQueue(times: 2)
        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
    }

    func testDuckingStartsForLongSessionAndRestoresOnStop() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.beginSessionIds.count, 1)
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)
        harness.audio.emitPCM(twoSecondsOfPCM())
        drainMainQueue()

        harness.hotkeys.triggerLongDraftStop()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
    }

    func testCancelRestoresDucking() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.hotkeys.triggerCancel()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertEqual(harness.panel.doneEvents.map(\.status), [.cancelled])
    }

    func testReplacementRestoresOldDuckingBeforeStartingNewDucking() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()
        let oldSessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.beginSessionIds.count, 2)
        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [oldSessionId])
        XCTAssertEqual(harness.audioDucker.events, [
            "begin:\(oldSessionId)",
            "restore:\(oldSessionId)",
            "begin:\(harness.audioDucker.beginSessionIds[1])"
        ])
    }

    func testASRErrorRestoresDucking() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.asrFactory.clients[0].emitError()
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertTrue(harness.panel.errors.contains { $0.contains("Synthetic ASR error") })
    }

    func testAudioErrorRestoresDucking() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.audio.emitError()
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertTrue(harness.panel.errors.contains { $0.contains("Synthetic audio error") })
    }

    func testErrorWithPartialRestoresDuckingAndFallbackCopiesSalvage() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.asrFactory.clients[0].emitPartial("已经识别的部分文本")
        drainMainQueue()
        harness.asrFactory.clients[0].emitError()
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertEqual(harness.paste.calls.map(\.mode), [.fallbackCopy])
        XCTAssertEqual(harness.paste.calls.first?.text, "已经识别的部分文本")
        XCTAssertEqual(harness.history.items.first?.text, "已经识别的部分文本")
        XCTAssertEqual(harness.panel.doneEvents.first?.status, .copiedFallback)
    }

    func testStaleASRErrorAfterReplacementDoesNotRestoreNewDucking() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let oldSessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)
        let oldClient = harness.asrFactory.clients[0]

        harness.hotkeys.triggerLongDraftStart()
        drainMainQueue()
        let newSessionId = tryUnwrap(harness.audioDucker.beginSessionIds.last)
        XCTAssertNotEqual(oldSessionId, newSessionId)

        oldClient.emitError()
        drainMainQueue(times: 2)

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [oldSessionId])
        XCTAssertEqual(harness.audioDucker.beginSessionIds, [oldSessionId, newSessionId])
        XCTAssertEqual(harness.panel.errors.count, 0)
    }

    func testMockSessionDoesNotDuckOutput() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.menu.onStartMock?()
        drainMainQueue()

        XCTAssertTrue(harness.audioDucker.beginSessionIds.isEmpty)
        XCTAssertTrue(harness.audioDucker.effectiveRestoreSessionIds.isEmpty)
        XCTAssertTrue(harness.audio.startedTokens.isEmpty)
    }

    func testControllerStopRestoresDuckingBestEffort() {
        let harness = makeHarness(audioDuckingEnabled: true)
        harness.hotkeys.triggerPushToTalkStart()
        drainMainQueue()
        let sessionId = tryUnwrap(harness.audioDucker.beginSessionIds.first)

        harness.controller.stop()
        drainMainQueue()

        XCTAssertEqual(harness.audioDucker.effectiveRestoreSessionIds, [sessionId])
        XCTAssertEqual(harness.hotkeys.stopCallCount, 1)
    }

    private func makeHarness(
        autoCompletePaste: Bool = true,
        audioDuckingEnabled: Bool = false,
        asrBackend: ASRBackend = .funASRWebSocket,
        localASRServiceResult: Result<Void, Error> = .success(())
    ) -> AppControllerHarness {
        AppControllerHarness(
            autoCompletePaste: autoCompletePaste,
            audioDuckingEnabled: audioDuckingEnabled,
            asrBackend: asrBackend,
            localASRServiceResult: localASRServiceResult
        )
    }

    private func drainMainQueue(times: Int = 1, file: StaticString = #filePath, line: UInt = #line) {
        for index in 0..<times {
            let expectation = expectation(description: "drain main queue \(index)")
            DispatchQueue.main.async { expectation.fulfill() }
            wait(for: [expectation], timeout: 1)
        }
    }

    private func tryUnwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
        guard let value else {
            XCTFail("Expected non-nil value", file: file, line: line)
            fatalError("Expected non-nil value")
        }
        return value
    }
}

private final class AppControllerHarness {
    let menu = FakeMenuBarController()
    let panel = FakeFloatingPanel()
    let focus = FakeFocusDetector(current: editableFocus())
    let hotkeys = FakeHotkeyController()
    let audio = FakeAudioCapture()
    let audioDucker = FakeSystemAudioDucker()
    let clipboard = FakeClipboard()
    let paste: FakePasteRouter
    let history = FakeHistoryRecorder()
    let asrFactory = FakeASRClientFactory()
    let localASRService: FakeLocalASRServiceManager
    let controller: AppController

    init(
        autoCompletePaste: Bool,
        audioDuckingEnabled: Bool,
        asrBackend: ASRBackend,
        localASRServiceResult: Result<Void, Error>
    ) {
        paste = FakePasteRouter(autoComplete: autoCompletePaste)
        localASRService = FakeLocalASRServiceManager(result: localASRServiceResult)
        var config = AppConfig.default
        config.mockASR = false
        config.asrBackend = asrBackend
        config.audioDucking.enabled = audioDuckingEnabled
        let dependencies = AppController.Dependencies(
            menu: menu,
            panel: panel,
            focusDetector: focus,
            hotkeys: hotkeys,
            audio: audio,
            audioDucker: audioDucker,
            clipboard: clipboard,
            pasteRouter: paste,
            history: history,
            asrClientFactory: asrFactory,
            localASRService: localASRService,
            focusMonitoringEnabled: false
        )
        controller = AppController(config: config, dependencies: dependencies)
    }
}

private final class FakeLocalASRServiceManager: LocalASRServiceManaging {
    private let result: Result<Void, Error>
    private(set) var prepareCallCount = 0
    private(set) var ensureCallCount = 0
    private(set) var stopCallCount = 0

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func prepare(config: AppConfig) {
        prepareCallCount += 1
    }

    func ensureReady(config: AppConfig) -> Result<Void, Error> {
        ensureCallCount += 1
        return result
    }

    func stopManagedService() {
        stopCallCount += 1
    }
}

private final class FakeMenuBarController: MenuBarControlling {
    var onStartMock: (() -> Void)?
    var onStop: (() -> Void)?
    var onCopyLast: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onPromptPermissions: (() -> Void)?
    var onOpenLogs: (() -> Void)?
    var onCopyDiagnostics: (() -> Void)?
    private(set) var statuses: [String] = []

    func setStatus(_ text: String) {
        statuses.append(text)
    }
}

private final class FakeFloatingPanel: FloatingPanelPresenting {
    struct DoneEvent {
        let status: PasteRouteStatus
        let text: String
        let restoredClipboard: Bool
    }

    var onCancel: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCopy: (() -> Void)?
    var onRestoreClipboard: (() -> Void)?
    var onQuit: (() -> Void)?

    private(set) var shownModes: [OutputMode] = []
    private(set) var listeningModes: [OutputMode] = []
    private(set) var modeUpdates: [OutputMode] = []
    private(set) var partials: [String] = []
    private(set) var finalizingCount = 0
    private(set) var doneEvents: [DoneEvent] = []
    private(set) var errors: [String] = []
    private(set) var diagnostics: [String] = []

    func show(mode: OutputMode) {
        shownModes.append(mode)
    }

    func showListening(mode: OutputMode) {
        listeningModes.append(mode)
    }

    func updateMode(_ mode: OutputMode) {
        modeUpdates.append(mode)
    }

    func updatePartial(_ text: String) {
        partials.append(text)
    }

    func updateFinalizing() {
        finalizingCount += 1
    }

    func updateDone(status: PasteRouteStatus, text: String, restoredClipboard: Bool) {
        doneEvents.append(DoneEvent(status: status, text: text, restoredClipboard: restoredClipboard))
    }

    func updateError(_ message: String) {
        errors.append(message)
    }

    func updateDiagnostics(_ text: String) {
        diagnostics.append(text)
    }
}

private final class FakeFocusDetector: FocusDetecting {
    var current: FocusSnapshot
    private(set) var snapshotCallCount = 0

    init(current: FocusSnapshot) {
        self.current = current
    }

    func snapshot() -> FocusSnapshot {
        snapshotCallCount += 1
        return current
    }
}

private final class FakeHotkeyController: HotkeyControlling {
    var onPushToTalkStart: (() -> Void)?
    var onPushToTalkStop: (() -> Void)?
    var onLongDraftStart: (() -> Void)?
    var onLongDraftStop: (() -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((String) -> Void)?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var startedTypes: [SessionType] = []
    private(set) var endedCount = 0

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func noteSessionStarted(type: SessionType) {
        startedTypes.append(type)
    }

    func noteSessionEnded() {
        endedCount += 1
    }

    func triggerPushToTalkStart() {
        onPushToTalkStart?()
    }

    func triggerPushToTalkStop() {
        onPushToTalkStop?()
    }

    func triggerLongDraftStart() {
        onLongDraftStart?()
    }

    func triggerLongDraftStop() {
        onLongDraftStop?()
    }

    func triggerCancel() {
        onCancel?()
    }
}

private final class FakeAudioCapture: AudioCapturing {
    var onPCMChunk: ((AudioSessionToken, Data) -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var prewarmCallCount = 0
    private(set) var startedTokens: [AudioSessionToken] = []
    private(set) var cancelCallCount = 0
    private(set) var stopAndFlushCallCount = 0
    var flushChunks: [Data] = []
    private var currentToken: AudioSessionToken?

    func prewarm() {
        prewarmCallCount += 1
    }

    func start(sessionToken: AudioSessionToken) {
        currentToken = sessionToken
        startedTokens.append(sessionToken)
    }

    func cancel() {
        cancelCallCount += 1
        currentToken = nil
    }

    func stopAndFlush(completion: @escaping (AudioSessionToken?, [Data]) -> Void) {
        stopAndFlushCallCount += 1
        let token = currentToken
        currentToken = nil
        completion(token, flushChunks)
    }

    func emitPCM(_ data: Data, token explicitToken: AudioSessionToken? = nil) {
        guard let token = explicitToken ?? currentToken else { return }
        onPCMChunk?(token, data)
    }

    func emitError() {
        onError?(NSError(domain: "test.audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic audio error"]))
    }
}

private final class FakeSystemAudioDucker: SystemAudioDuckingControlling {
    private(set) var beginSessionIds: [String] = []
    private(set) var restoreCalls: [String?] = []
    private(set) var effectiveRestoreSessionIds: [String] = []
    private(set) var events: [String] = []
    private var activeSessionId: String?

    func beginDucking(sessionId: String) {
        beginSessionIds.append(sessionId)
        activeSessionId = sessionId
        events.append("begin:\(sessionId)")
    }

    func restoreDucking(sessionId: String?) {
        restoreCalls.append(sessionId)
        guard let activeSessionId else { return }
        if let sessionId, sessionId != activeSessionId {
            events.append("ignore:\(sessionId)")
            return
        }
        self.activeSessionId = nil
        effectiveRestoreSessionIds.append(activeSessionId)
        events.append("restore:\(activeSessionId)")
    }
}

private final class FakePasteRouter: PasteRouting {
    struct Call {
        let text: String
        let mode: OutputMode
        let completion: (OutputResult) -> Void
    }

    private let autoComplete: Bool
    private(set) var calls: [Call] = []

    init(autoComplete: Bool) {
        self.autoComplete = autoComplete
    }

    func routeAsync(text: String, mode: OutputMode, completion: @escaping (OutputResult) -> Void) {
        let call = Call(text: text, mode: mode, completion: completion)
        calls.append(call)
        if autoComplete {
            completion(OutputResult(status: status(for: mode), restoredClipboard: false, verification: verification(for: mode)))
        }
    }

    func completeCall(
        at index: Int,
        status: PasteRouteStatus = .copied,
        verification: PasteVerificationStatus = .notAttempted
    ) {
        calls[index].completion(OutputResult(status: status, restoredClipboard: false, verification: verification))
    }

    private func status(for mode: OutputMode) -> PasteRouteStatus {
        switch mode {
        case .cursorPaste:
            return .pasted
        case .clipboardDraft, .floatingDraft:
            return .copied
        case .fallbackCopy:
            return .copiedFallback
        }
    }

    private func verification(for mode: OutputMode) -> PasteVerificationStatus {
        mode == .cursorPaste ? .confirmed : .notAttempted
    }
}

private final class FakeHistoryRecorder: HistoryRecording {
    private(set) var items: [HistoryItem] = []

    func append(text: String, outputMode: OutputMode, correctionRules: [String]) {
        items.insert(HistoryItem(text: text, outputMode: outputMode, correctionRules: correctionRules), at: 0)
    }

    func latest() -> HistoryItem? {
        items.first
    }

    func clear() {
        items.removeAll()
    }
}

private final class FakeASRClientFactory: ASRClientMaking {
    private(set) var clients: [FakeASRClient] = []

    func makeClient(config: AppConfig, forceMock: Bool) -> ASRClientProtocol {
        let client = FakeASRClient()
        clients.append(client)
        return client
    }
}

private final class FakeASRClient: ASRClientProtocol {
    var onEvent: ((ASREvent) -> Void)?
    var onError: ((Error) -> Void)?
    private(set) var startedSessionId: String?
    private(set) var hotwords: [String: String] = [:]
    private(set) var sentPCM: [Data] = []
    private(set) var finishCallCount = 0
    private(set) var cancelCallCount = 0

    func start(sessionId: String, hotwords: [String: String]) {
        startedSessionId = sessionId
        self.hotwords = hotwords
    }

    func sendPCM(_ data: Data) {
        sentPCM.append(data)
    }

    func finish() {
        finishCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }

    func emitFinal(_ text: String) {
        guard let startedSessionId else { return }
        onEvent?(ASREvent(sessionId: startedSessionId, mode: .offline, text: text, isFinal: true))
    }

    func emitPartial(_ text: String) {
        guard let startedSessionId else { return }
        onEvent?(ASREvent(sessionId: startedSessionId, mode: .online, text: text, isFinal: false))
    }

    func emitError() {
        onError?(NSError(domain: "test.asr", code: 1, userInfo: [NSLocalizedDescriptionKey: "Synthetic ASR error"]))
    }
}

private final class FakeClipboard: ClipboardManaging {
    private(set) var currentString = ""
    private var changeCount = 0

    func capture() -> ClipboardSnapshot {
        ClipboardSnapshot(changeCount: changeCount, items: [], capturedAt: Date())
    }

    @discardableResult
    func writeString(_ text: String) -> Int {
        currentString = text
        changeCount += 1
        return changeCount
    }

    @discardableResult
    func restore(_ snapshot: ClipboardSnapshot) -> Int {
        currentString = ""
        changeCount += 1
        return changeCount
    }

    func restoreLastSavedSnapshot() {}
}

private func editableFocus(windowTitle: String = "Window") -> FocusSnapshot {
    FocusSnapshot(
        frontmostAppBundleId: "com.example.editor",
        frontmostAppPid: 123,
        focusedWindowTitle: windowTitle,
        focusedElementIdentifier: "editor",
        elementRole: "AXTextArea",
        isEditable: true,
        isSecureTextField: false,
        canPaste: true,
        confidence: .high
    )
}

private func twoSecondsOfPCM() -> Data {
    Data(count: 16_000 * 2 * 2)
}
#endif
