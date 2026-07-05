#if os(macOS)
import ApplicationServices
import XCTest
@testable import LocalVoiceInputMac

final class KeyboardSimulatorTests: XCTestCase {
    func testCommandVPastePlanReleasesTriggerModifiersBeforePasteShortcut() {
        let plan = KeyboardSimulator.commandVPastePlan()

        XCTAssertEqual(plan.map(\.keyCode), [61, 54, 55, 9, 9, 55])
        XCTAssertEqual(plan.map(\.keyDown), [false, false, true, true, false, false])
        XCTAssertEqual(plan[0].flags, [])
        XCTAssertEqual(plan[1].flags, [])
        XCTAssertEqual(plan[2].flags, .maskCommand)
        XCTAssertEqual(plan[3].flags, .maskCommand)
        XCTAssertEqual(plan[4].flags, .maskCommand)
        XCTAssertEqual(plan[5].flags, [])
    }
}
#endif
