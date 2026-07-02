import XCTest
@testable import LocalVoiceInputCore

final class CorrectionPipelineTests: XCTestCase {
    func testAddsTerminalPunctuation() {
        let pipeline = CorrectionPipeline()
        let result = pipeline.correct("我想做一个本地语音输入工具")
        XCTAssertEqual(result.corrected, "我想做一个本地语音输入工具。")
        XCTAssertTrue(result.appliedRules.contains("ensure_terminal_punctuation"))
    }

    func testHotwordReplacement() {
        let config = CorrectionConfig(hotwords: ["qwen三": "Qwen3", "fun asr": "FunASR"])
        let result = CorrectionPipeline(config: config).correct("我想测试 qwen三 和 fun asr")
        XCTAssertEqual(result.corrected, "我想测试 Qwen3 和 FunASR。")
        XCTAssertTrue(result.appliedRules.contains("hotwords"))
    }

    func testHomophoneReplacement() {
        let config = CorrectionConfig(homophones: ["玄界芯片": "玄戒芯片"])
        let result = CorrectionPipeline(config: config).correct("这是一颗玄界芯片")
        XCTAssertEqual(result.corrected, "这是一颗玄戒芯片。")
        XCTAssertTrue(result.appliedRules.contains("homophones"))
    }

    func testRawModeDoesNotRemoveFillersOrAddPunctuation() {
        let config = CorrectionConfig(mode: .raw, hotwords: [:], homophones: [:], removeFillers: true, ensureTerminalPunctuation: true)
        let result = CorrectionPipeline(config: config).correct("嗯 我想说一下")
        XCTAssertEqual(result.corrected, "嗯 我想说一下")
    }

    func testNumericITNIsConfigurable() {
        let disabled = CorrectionPipeline(config: CorrectionConfig(numericITNEnabled: false)).correct("版本是零点六B")
        XCTAssertEqual(disabled.corrected, "版本是零点六B。")
        XCTAssertFalse(disabled.appliedRules.contains("numeric_itn"))

        let enabled = CorrectionPipeline(config: CorrectionConfig(numericITNEnabled: true)).correct("版本是零点六B")
        XCTAssertEqual(enabled.corrected, "版本是0.6B。")
        XCTAssertTrue(enabled.appliedRules.contains("numeric_itn"))
    }

    func testWhitespaceAndPunctuationNormalization() {
        let result = CorrectionPipeline().correct(" 我想测试,  这个功能?? ")
        XCTAssertEqual(result.corrected, "我想测试，这个功能？")
        XCTAssertTrue(result.appliedRules.contains("normalize_whitespace"))
        XCTAssertTrue(result.appliedRules.contains("normalize_punctuation"))
    }
}
