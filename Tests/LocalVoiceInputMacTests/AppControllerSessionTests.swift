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

    private func makeHarness(autoCompletePaste: Bool = true) -> AppControllerHarness {
        AppControllerHarness(autoCompletePaste: autoCompletePaste)
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
    let clipboard = FakeClipboard()
    let paste: FakePasteRouter
    let history = FakeHistoryRecorder()
    let asrFactory = FakeASRClientFactory()
    let controller: AppController

    init(autoCompletePaste: Bool) {
        paste = FakePasteRouter(autoComplete: autoCompletePaste)
        var config = AppConfig.default
        config.mockASR = false
        config.asrBackend = .funASRWebSocket
        let dependencies = AppController.Dependencies(
            menu: menu,
            panel: panel,
            focusDetector: focus,
            hotkeys: hotkeys,
            audio: audio,
            clipboard: clipboard,
            pasteRouter: paste,
            history: history,
            asrClientFactory: asrFactory,
            focusMonitoringEnabled: false
        )
        controller = AppController(config: config, dependencies: dependencies)
    }
}

private final class FakeMenuBarController: MenuBarControlling {
    var onStartMock: (() -> Void)?
    var onStop: (() -> Void)?
    var onCopyLast: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onPromptPermissions: (() -> Void)?
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
