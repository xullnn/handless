#if os(macOS)
import Foundation
import XCTest
@testable import LocalVoiceInputMac

final class AppConfigTests: XCTestCase {
    func testNumericITNDefaultsDisabledWhenMissingFromJSON() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data("{}".utf8))
        XCTAssertFalse(config.numericITNEnabled)
        XCTAssertEqual(config.asrHTTPURL, "http://127.0.0.1:18096")
        XCTAssertEqual(config.audioDucking, .default)
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

    func testDecodesAudioDuckingConfigFromJSON() throws {
        let config = try JSONDecoder().decode(AppConfig.self, from: Data("""
        {
          "audioDucking": {
            "enabled": true,
            "targetVolume": 0.12,
            "muteInsteadOfDuck": true
          }
        }
        """.utf8))

        XCTAssertTrue(config.audioDucking.enabled)
        XCTAssertEqual(config.audioDucking.targetVolume, 0.12)
        XCTAssertTrue(config.audioDucking.muteInsteadOfDuck)
    }

    func testAudioDuckingTargetVolumeIsClamped() throws {
        let high = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"audioDucking":{"targetVolume":2.5}}"#.utf8))
        XCTAssertEqual(high.audioDucking.targetVolume, 1.0)

        let low = try JSONDecoder().decode(AppConfig.self, from: Data(#"{"audioDucking":{"targetVolume":-0.5}}"#.utf8))
        XCTAssertEqual(low.audioDucking.targetVolume, 0.0)
    }

    func testCommandLineCanOverrideAudioDucking() {
        var config = AppConfig.default
        config.applyCommandLine(["LocalVoiceInput", "--audio-ducking"])
        XCTAssertTrue(config.audioDucking.enabled)

        config.applyCommandLine(["LocalVoiceInput", "--no-audio-ducking"])
        XCTAssertFalse(config.audioDucking.enabled)
    }

    func testLastAudioDuckingEnableDisableCommandLineOverrideWins() {
        var enabledFirst = AppConfig.default
        enabledFirst.applyCommandLine(["LocalVoiceInput", "--audio-ducking", "--no-audio-ducking"])
        XCTAssertFalse(enabledFirst.audioDucking.enabled)

        var disabledFirst = AppConfig.default
        disabledFirst.applyCommandLine(["LocalVoiceInput", "--no-audio-ducking", "--audio-ducking"])
        XCTAssertTrue(disabledFirst.audioDucking.enabled)

        var volumeThenDisable = AppConfig.default
        volumeThenDisable.applyCommandLine(["LocalVoiceInput", "--audio-ducking-volume", "0.05", "--no-audio-ducking"])
        XCTAssertFalse(volumeThenDisable.audioDucking.enabled)
        XCTAssertEqual(volumeThenDisable.audioDucking.targetVolume, 0.05)

        var disableThenVolume = AppConfig.default
        disableThenVolume.applyCommandLine(["LocalVoiceInput", "--no-audio-ducking", "--audio-ducking-volume", "0.05"])
        XCTAssertTrue(disableThenVolume.audioDucking.enabled)
        XCTAssertEqual(disableThenVolume.audioDucking.targetVolume, 0.05)
    }

    func testCommandLineCanSetAudioDuckingVolumeAndMute() {
        var config = AppConfig.default
        config.applyCommandLine([
            "LocalVoiceInput",
            "--audio-ducking-volume",
            "0.05",
            "--audio-ducking-mute"
        ])

        XCTAssertTrue(config.audioDucking.enabled)
        XCTAssertEqual(config.audioDucking.targetVolume, 0.05)
        XCTAssertTrue(config.audioDucking.muteInsteadOfDuck)

        config.applyCommandLine(["LocalVoiceInput", "--no-audio-ducking-mute"])
        XCTAssertFalse(config.audioDucking.muteInsteadOfDuck)
    }
}
#endif
