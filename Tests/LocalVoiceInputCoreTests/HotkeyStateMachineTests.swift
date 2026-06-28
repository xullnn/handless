import XCTest
@testable import LocalVoiceInputCore

final class HotkeyStateMachineTests: XCTestCase {
    func testRightOptionPushToTalkLifecycle() {
        var machine = HotkeyStateMachine()

        XCTAssertEqual(machine.send(.rightOptionDown), [.startPushToTalk, .consumeEvent])
        XCTAssertEqual(machine.mode, .pushToTalk)
        XCTAssertEqual(machine.send(.rightOptionUp), [.stopPushToTalk, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)
    }

    func testOptionSpaceConvertsActivePushToTalkToLongDraft() {
        var machine = HotkeyStateMachine()

        _ = machine.send(.rightOptionDown)
        XCTAssertEqual(machine.send(.optionSpace), [.convertPushToTalkToLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
        XCTAssertEqual(machine.send(.rightOptionUp), [.consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
    }

    func testLongDraftIgnoresRightOptionRelease() {
        var machine = HotkeyStateMachine(mode: .longDraft)

        XCTAssertEqual(machine.send(.rightOptionDown), [.consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
        XCTAssertEqual(machine.send(.rightOptionUp), [.consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
    }

    func testOptionSpaceStopsLongDraft() {
        var machine = HotkeyStateMachine(mode: .longDraft)

        XCTAssertEqual(machine.send(.optionSpace), [.toggleLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)
    }

    func testOptionSpaceDoesNotInterruptActivePushToTalk() {
        var machine = HotkeyStateMachine(mode: .pushToTalk, isRightOptionDown: true)

        XCTAssertEqual(machine.send(.optionSpace), [.convertPushToTalkToLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
    }

    func testEscCancelsActiveSessionAndConsumesEvent() {
        var machine = HotkeyStateMachine(mode: .pushToTalk, isRightOptionDown: true)

        XCTAssertEqual(machine.send(.escape), [.cancelActiveSession, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)
    }
}
