#if os(macOS)
import Foundation
import XCTest
@testable import LocalVoiceInputMac

final class AppConfigTests: XCTestCase {
    func testNumericITNDefaultsDisabledWhenMissingFromJSON() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        XCTAssertFalse(config.numericITNEnabled)
        XCTAssertEqual(config.asrHTTPURL, "http://127.0.0.1:18096")
    }

    func testDecodesNumericITNEnabledFromJSON() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"numericITNEnabled":true}"#.utf8))
        XCTAssertTrue(config.numericITNEnabled)
    }

    func testCommandLineCanOverrideNumericITN() {
        var config = AppConfig.default
        config.applyCommandLine(["LocalVoiceInput", "--numeric-itn"])
        XCTAssertTrue(config.numericITNEnabled)

        config.applyCommandLine(["LocalVoiceInput", "--no-numeric-itn"])
        XCTAssertFalse(config.numericITNEnabled)
    }

    func testLastNumericITNCommandLineOverrideWins() {
        var config = AppConfig.default
        config.applyCommandLine(["LocalVoiceInput", "--no-numeric-itn", "--numeric-itn"])
        XCTAssertTrue(config.numericITNEnabled)

        config.applyCommandLine(["LocalVoiceInput", "--numeric-itn", "--no-numeric-itn"])
        XCTAssertFalse(config.numericITNEnabled)
    }
}
#endif
