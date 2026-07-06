#if os(macOS)
import XCTest
@testable import LocalVoiceInputMac

final class AppDiagnosticsSummaryTests: XCTestCase {
    func testDiagnosticsIncludesRuntimeMetadataWithoutTranscriptContent() {
        var config = AppConfig.default
        config.mockTranscript = "这段测试转写不能出现在诊断摘要里"
        config.asrBackend = .localHTTP
        config.asrHTTPURL = "http://127.0.0.1:18096"
        config.numericITNEnabled = true
        config.audioDucking.enabled = true

        let summary = AppDiagnosticsSummary.make(
            config: config,
            now: Date(timeIntervalSince1970: 0)
        )

        XCTAssertTrue(summary.contains("LocalVoiceInput Diagnostics"))
        XCTAssertTrue(summary.contains("Generated: 1970-01-01T00:00:00Z"))
        XCTAssertTrue(summary.contains("ASR Backend: local-http"))
        XCTAssertTrue(summary.contains("ASR URL: http://127.0.0.1:18096"))
        XCTAssertTrue(summary.contains("Numeric ITN: true"))
        XCTAssertTrue(summary.contains("Audio Ducking: true"))
        XCTAssertTrue(summary.contains("Logs Directory:"))
        XCTAssertFalse(summary.contains(config.mockTranscript))
    }
}
#endif
