import XCTest
@testable import LocalVoiceInputCore

final class NumericITNTests: XCTestCase {
    func testConvertsSimpleDecimalsWithoutUnits() {
        assertNormalize("零点六", "0.6")
        assertNormalize("三点一四", "3.14")
        assertNormalize("这个版本的实时因子是零点二零八。", "这个版本的实时因子是0.208。")
    }

    func testConvertsVersionLikeExpressions() {
        assertNormalize("当前版本是一点二点三。", "当前版本是1.2.3。")
    }

    func testConvertsDecimalsWithTechnicalUnits() {
        assertNormalize("零点六B", "0.6B")
        assertNormalize("模型大小大约是零点六 B。", "模型大小大约是0.6B。")
    }

    func testConvertsStrongUnitIntegerContexts() {
        assertNormalize("十六KB", "16KB")
        assertNormalize("这个接口使用一六 KB 单声道音频。", "这个接口使用16KB 单声道音频。")
        assertNormalize("这台电脑有四十八 GB 内存。", "这台电脑有48GB 内存。")
    }

    func testConvertsStrongDigitSequenceContexts() {
        assertNormalize("验证码是八零六二一九。", "验证码是806219。")
        assertNormalize("这个服务监听一八一零五端口。", "这个服务监听18105端口。")
        assertNormalize("订单编号是一二三四五六。", "订单编号是123456。")
        assertNormalize("我们先处理 case 零三。", "我们先处理 case 03。")
    }

    func testLeavesAmbiguousPhrasesUnchanged() {
        let unchanged = [
            "我有一点问题需要确认。",
            "这件事一点也不难。",
            "我想说三点建议。",
            "这个方案有两点需要调整。",
            "这次错误率下降了百分之三点五。",
            "模型文件大约占用九百六十四 MB。",
            "十几个样本还不够。",
            "千万不要这样做。",
            "一二三木头人。"
        ]

        for input in unchanged {
            assertNormalize(input, input)
        }
    }

    func testReportsAppliedChanges() {
        let result = NumericITN().normalize("验证码是八零六二一九，版本是一点二点三。")
        XCTAssertEqual(result.normalized, "验证码是806219，版本是1.2.3。")
        XCTAssertEqual(result.changes.map(\.rule), ["numeric_itn_version", "numeric_itn_digit_sequence"])
    }

    private func assertNormalize(_ input: String, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(NumericITN().normalize(input).normalized, expected, file: file, line: line)
    }
}
