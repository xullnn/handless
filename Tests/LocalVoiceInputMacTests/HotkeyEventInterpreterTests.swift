#if os(macOS)
import ApplicationServices
import XCTest
import LocalVoiceInputCore
@testable import LocalVoiceInputMac

final class HotkeyEventInterpreterTests: XCTestCase {
    func testRightCommandPeriodStartsAndStopsLongDraft() {
        var interpreter = HotkeyEventInterpreter()

        let rightCommandDown = interpreter.handle(
            HotkeyPhysicalEvent(type: .flagsChanged, keyCode: 54, flags: .maskCommand),
            appSessionActive: false
        )
        XCTAssertEqual(rightCommandDown, .passThrough)
        XCTAssertTrue(interpreter.isRightCommandDown)

        let start = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 47, flags: .maskCommand),
            appSessionActive: false
        )
        XCTAssertEqual(start.actions, [.startLongDraft, .consumeEvent])
        XCTAssertTrue(start.consumesEvent)
        XCTAssertEqual(interpreter.mode, .longDraft)

        let stop = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 47, flags: .maskCommand),
            appSessionActive: true
        )
        XCTAssertEqual(stop.actions, [.stopLongDraft, .consumeEvent])
        XCTAssertTrue(stop.consumesEvent)
        XCTAssertEqual(interpreter.mode, .idle)
    }

    func testLeftCommandPeriodDoesNotTriggerLongDraft() {
        var interpreter = HotkeyEventInterpreter()

        let result = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 47, flags: .maskCommand),
            appSessionActive: false
        )

        XCTAssertEqual(result, .passThrough)
        XCTAssertEqual(interpreter.mode, .idle)
    }

    func testOptionSpaceNoLongerTriggersLongDraft() {
        var interpreter = HotkeyEventInterpreter()

        let result = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 49, flags: .maskAlternate),
            appSessionActive: false
        )

        XCTAssertEqual(result, .passThrough)
        XCTAssertEqual(interpreter.mode, .idle)
    }

    func testRightOptionPushToTalkLifecycle() {
        var interpreter = HotkeyEventInterpreter()

        let start = interpreter.handle(
            HotkeyPhysicalEvent(type: .flagsChanged, keyCode: 61, flags: .maskAlternate),
            appSessionActive: false
        )
        XCTAssertEqual(start.actions, [.startPushToTalk, .consumeEvent])
        XCTAssertTrue(start.consumesEvent)

        let stop = interpreter.handle(
            HotkeyPhysicalEvent(type: .flagsChanged, keyCode: 61, flags: []),
            appSessionActive: true
        )
        XCTAssertEqual(stop.actions, [.stopPushToTalk, .consumeEvent])
        XCTAssertTrue(stop.consumesEvent)
        XCTAssertEqual(interpreter.mode, .idle)
    }

    func testRepeatedRightCommandPeriodIsConsumedWithoutRepeatingAction() {
        var interpreter = HotkeyEventInterpreter()
        _ = interpreter.handle(
            HotkeyPhysicalEvent(type: .flagsChanged, keyCode: 54, flags: .maskCommand),
            appSessionActive: false
        )

        let result = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 47, flags: .maskCommand, isRepeat: true),
            appSessionActive: false
        )

        XCTAssertEqual(result.actions, [])
        XCTAssertTrue(result.consumesEvent)
        XCTAssertEqual(interpreter.mode, .idle)
    }

    func testEscapeCancelsActiveAppSessionEvenWhenStateMachineIsIdle() {
        var interpreter = HotkeyEventInterpreter()

        let result = interpreter.handle(
            HotkeyPhysicalEvent(type: .keyDown, keyCode: 53),
            appSessionActive: true
        )

        XCTAssertEqual(result.actions, [.cancelActiveSession])
        XCTAssertTrue(result.consumesEvent)
    }
}
#endif
