#if os(macOS)
import XCTest
import LocalVoiceInputCore
@testable import LocalVoiceInputMac

final class PasteEngineTests: XCTestCase {
    func testCursorPasteRouteCompletesAsynchronouslyAfterVerification() {
        let clipboard = FakeClipboardManager()
        let keyboard = FakeKeyboardSimulator()
        let verifier = FakePasteVerifier(results: [.unknown, .confirmed])
        let engine = PasteEngine(
            clipboard: clipboard,
            keyboard: keyboard,
            verifier: verifier,
            policy: .default,
            verificationIntervals: [0.01, 0.01]
        )
        let expectation = expectation(description: "async paste completion")
        var routeCallReturned = false

        engine.routeAsync(text: "异步粘贴", mode: .cursorPaste) { output in
            XCTAssertTrue(routeCallReturned)
            XCTAssertEqual(output.status, .pasted)
            XCTAssertEqual(output.verification, .confirmed)
            XCTAssertEqual(clipboard.currentString, "异步粘贴")
            XCTAssertEqual(keyboard.commandVTargetPids, [123])
            expectation.fulfill()
        }
        routeCallReturned = true

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(verifier.verifyCallCount, 2)
    }

    func testCursorPasteUnknownVerificationFallsBackToCopiedResult() {
        let clipboard = FakeClipboardManager()
        let keyboard = FakeKeyboardSimulator()
        let verifier = FakePasteVerifier(results: [.unknown, .unknown])
        let engine = PasteEngine(
            clipboard: clipboard,
            keyboard: keyboard,
            verifier: verifier,
            policy: .default,
            verificationIntervals: [0.01, 0.01]
        )
        let expectation = expectation(description: "fallback completion")

        engine.routeAsync(text: "兜底复制", mode: .cursorPaste) { output in
            XCTAssertEqual(output.status, .copiedFallback)
            XCTAssertEqual(output.verification, .unknown)
            XCTAssertEqual(clipboard.currentString, "兜底复制")
            XCTAssertEqual(keyboard.commandVTargetPids, [123])
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    func testClipboardDraftCompletesImmediately() {
        let clipboard = FakeClipboardManager()
        let keyboard = FakeKeyboardSimulator()
        let verifier = FakePasteVerifier(results: [])
        let engine = PasteEngine(
            clipboard: clipboard,
            keyboard: keyboard,
            verifier: verifier,
            policy: .default,
            verificationIntervals: [0.01]
        )
        var completed = false

        engine.routeAsync(text: "剪贴板草稿", mode: .clipboardDraft) { output in
            completed = true
            XCTAssertEqual(output.status, .copied)
            XCTAssertEqual(output.verification, .notAttempted)
            XCTAssertEqual(clipboard.currentString, "剪贴板草稿")
        }

        XCTAssertTrue(completed)
        XCTAssertEqual(keyboard.commandVTargetPids, [])
        XCTAssertEqual(verifier.verifyCallCount, 0)
    }
}

private final class FakeClipboardManager: ClipboardManaging {
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
}

private final class FakeKeyboardSimulator: KeyboardSimulating {
    private(set) var commandVTargetPids: [pid_t?] = []

    func pressCommandV() {
        pressCommandV(targetPid: nil)
    }

    func pressCommandV(targetPid: pid_t?) {
        commandVTargetPids.append(targetPid)
    }
}

private final class FakePasteVerifier: PasteVerifying {
    private var results: [PasteVerificationStatus]
    private(set) var verifyCallCount = 0

    init(results: [PasteVerificationStatus]) {
        self.results = results
    }

    func captureFocusedTextSnapshot() -> PasteVerificationSnapshot {
        PasteVerificationSnapshot(
            text: "",
            characterCount: 0,
            selectedRange: TextRange(location: 0, length: 0),
            focusSignature: FocusElementSignature(pid: 123, role: "AXTextArea", subrole: nil, windowTitle: "Fake")
        )
    }

    func verifyInsertion(of insertedText: String, before: PasteVerificationSnapshot) -> PasteVerificationStatus {
        verifyCallCount += 1
        guard !results.isEmpty else { return .unknown }
        return results.removeFirst()
    }
}
#endif
