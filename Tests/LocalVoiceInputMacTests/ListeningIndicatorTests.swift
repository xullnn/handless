#if os(macOS)
import XCTest
@testable import LocalVoiceInputMac

final class ListeningIndicatorTests: XCTestCase {
    func testCyclesThreeNonWordFrames() {
        XCTAssertEqual(ListeningIndicator.text(for: 0), "●  ○  ○")
        XCTAssertEqual(ListeningIndicator.text(for: 1), "○  ●  ○")
        XCTAssertEqual(ListeningIndicator.text(for: 2), "○  ○  ●")
        XCTAssertEqual(ListeningIndicator.text(for: 3), "●  ○  ○")
        XCTAssertEqual(ListeningIndicator.nextFrame(after: 2), 0)
    }
}
#endif
