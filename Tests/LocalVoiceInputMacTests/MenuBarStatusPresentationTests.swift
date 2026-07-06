#if os(macOS)
import XCTest
@testable import LocalVoiceInputMac

final class MenuBarStatusPresentationTests: XCTestCase {
    func testIdlePresentationUsesAppOwnedMarker() {
        let presentation = MenuBarStatusPresentation.make(for: "🎙")

        XCTAssertEqual(presentation.statusItemTitle, "LVI")
        XCTAssertEqual(presentation.menuStatusTitle, "状态：就绪")
        XCTAssertTrue(presentation.tooltip.contains("LocalVoiceInput"))
    }

    func testRecordingPresentationRemainsVisibleWithoutMicGlyph() {
        let presentation = MenuBarStatusPresentation.make(for: "🔴")

        XCTAssertEqual(presentation.statusItemTitle, "REC")
        XCTAssertEqual(presentation.menuStatusTitle, "状态：录音中")
        XCTAssertTrue(presentation.tooltip.contains("正在录音"))
    }

    func testWarningPresentationIsDistinct() {
        let presentation = MenuBarStatusPresentation.make(for: "⚠️")

        XCTAssertEqual(presentation.statusItemTitle, "LVI!")
        XCTAssertEqual(presentation.menuStatusTitle, "状态：需要处理")
        XCTAssertTrue(presentation.tooltip.contains("需要处理"))
    }
}
#endif
