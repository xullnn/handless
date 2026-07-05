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

    func testLongShortcutReplacesActivePushToTalkWithLongDraft() {
        var machine = HotkeyStateMachine()

        _ = machine.send(.rightOptionDown)
        XCTAssertEqual(machine.send(.longShortcut), [.startLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
        XCTAssertEqual(machine.send(.rightOptionUp), [.consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
    }

    func testRightOptionReplacesActiveLongDraftWithPushToTalk() {
        var machine = HotkeyStateMachine(mode: .longDraft)

        XCTAssertEqual(machine.send(.rightOptionDown), [.startPushToTalk, .consumeEvent])
        XCTAssertEqual(machine.mode, .pushToTalk)
        XCTAssertEqual(machine.send(.rightOptionUp), [.stopPushToTalk, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)
    }

    func testLongShortcutStartsAndStopsLongDraft() {
        var machine = HotkeyStateMachine(mode: .longDraft)

        XCTAssertEqual(machine.send(.longShortcut), [.stopLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)

        var idleMachine = HotkeyStateMachine()
        XCTAssertEqual(idleMachine.send(.longShortcut), [.startLongDraft, .consumeEvent])
        XCTAssertEqual(idleMachine.mode, .longDraft)
    }

    func testLongShortcutDoesNotEmitOptionSpaceConversion() {
        var machine = HotkeyStateMachine(mode: .pushToTalk, isRightOptionDown: true)

        XCTAssertEqual(machine.send(.longShortcut), [.startLongDraft, .consumeEvent])
        XCTAssertEqual(machine.mode, .longDraft)
    }

    func testEscCancelsActiveSessionAndConsumesEvent() {
        var machine = HotkeyStateMachine(mode: .pushToTalk, isRightOptionDown: true)

        XCTAssertEqual(machine.send(.escape), [.cancelActiveSession, .consumeEvent])
        XCTAssertEqual(machine.mode, .idle)
    }
}
