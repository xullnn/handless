import XCTest
@testable import LocalVoiceInputCore

final class OutputModeRouterTests: XCTestCase {
    func testOutputPolicyDecodesOldConfigWithoutAllowlist() throws {
        let data = """
        {
          "autoPasteEnabled": true,
          "restoreClipboardAfterPaste": false,
          "downgradeToClipboardWhenFocusChanges": true,
          "pasteSecureFields": false,
          "preferClipboardForLowConfidence": true
        }
        """.data(using: .utf8)!

        let policy = try JSONDecoder().decode(OutputPolicy.self, from: data)

        XCTAssertTrue(policy.autoPasteEnabled)
        XCTAssertEqual(policy.forcePasteWhenFocusLowConfidenceForBundleIds, [])
    }

    func testHighConfidenceEditableRoutesToCursorPaste() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: true, confidence: .high)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk), .cursorPaste)
    }

    func testNoInputFocusRoutesToClipboardDraft() {
        let snapshot = FocusSnapshot(isEditable: false, isSecureTextField: false, canPaste: false, confidence: .low)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk), .clipboardDraft)
    }

    func testSecureTextFieldNeverAutoPastesByDefault() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: true, canPaste: true, confidence: .high)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk), .clipboardDraft)
    }

    func testLongDraftRoutesToFloatingDraftEvenWhenCursorExists() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: true, confidence: .high)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .longDraft), .floatingDraft)
    }

    func testFocusChangeDowngradesToClipboard() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: true, confidence: .high)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk, focusChangedDuringRecording: true), .clipboardDraft)
    }

    func testAutoPasteDisabledRoutesToClipboard() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: true, confidence: .high)
        let policy = OutputPolicy(autoPasteEnabled: false)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk, policy: policy), .clipboardDraft)
    }

    func testLowConfidenceEditableRoutesToClipboardByDefault() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: true, confidence: .low)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk), .clipboardDraft)
    }

    func testAllowlistedLowConfidenceAppCanAttemptCursorPaste() {
        let snapshot = FocusSnapshot(
            frontmostAppBundleId: "com.openai.codex",
            isEditable: false,
            isSecureTextField: false,
            canPaste: false,
            confidence: .low
        )
        let policy = OutputPolicy(forcePasteWhenFocusLowConfidenceForBundleIds: ["com.openai.codex"])
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk, policy: policy), .cursorPaste)
    }

    func testAllowlistedLowConfidenceAppStillDowngradesAfterFocusChange() {
        let snapshot = FocusSnapshot(
            frontmostAppBundleId: "com.openai.codex",
            isEditable: false,
            isSecureTextField: false,
            canPaste: false,
            confidence: .low
        )
        let policy = OutputPolicy(forcePasteWhenFocusLowConfidenceForBundleIds: ["com.openai.codex"])
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk, focusChangedDuringRecording: true, policy: policy), .clipboardDraft)
    }

    func testAllowlistedLowConfidenceAppRespectsAutoPasteDisabled() {
        let snapshot = FocusSnapshot(
            frontmostAppBundleId: "com.openai.codex",
            isEditable: false,
            isSecureTextField: false,
            canPaste: false,
            confidence: .low
        )
        let policy = OutputPolicy(
            autoPasteEnabled: false,
            forcePasteWhenFocusLowConfidenceForBundleIds: ["com.openai.codex"]
        )
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk, policy: policy), .clipboardDraft)
    }

    func testNonPasteableEditableRoutesToClipboard() {
        let snapshot = FocusSnapshot(isEditable: true, isSecureTextField: false, canPaste: false, confidence: .high)
        XCTAssertEqual(OutputModeRouter.decide(snapshot: snapshot, sessionType: .pushToTalk), .clipboardDraft)
    }
}
