import Foundation

public struct NumericITNChange: Codable, Equatable, Sendable {
    public let rule: String
    public let original: String
    public let normalized: String
}

public struct NumericITNResult: Codable, Equatable, Sendable {
    public let original: String
    public let normalized: String
    public let changes: [NumericITNChange]
}

public struct NumericITN: Sendable {
    public init() {}

    public func normalize(_ input: String) -> NumericITNResult {
        var changes: [NumericITNChange] = []
        var text = input

        text = rewriteVersionLikeExpressions(text, changes: &changes)
        text = rewriteDecimalExpressions(text, changes: &changes)
        text = rewriteUnitNumbers(text, changes: &changes)
        text = rewriteContextDigitSequences(text, changes: &changes)
        text = compactTechnicalUnitSpacing(text, changes: &changes)

        return NumericITNResult(original: input, normalized: text, changes: changes)
    }

    private func rewriteVersionLikeExpressions(_ text: String, changes: inout [NumericITNChange]) -> String {
        replaceTokenRuns(in: text, rule: "numeric_itn_version", changes: &changes) { run, _, _, _ in
            let parts = run.split(separator: "点", omittingEmptySubsequences: false)
            guard parts.count >= 3, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
            let normalizedParts = parts.compactMap { parseSimpleNumericPart(String($0)) }
            guard normalizedParts.count == parts.count else { return nil }
            return normalizedParts.joined(separator: ".")
        }
    }

    private func rewriteDecimalExpressions(_ text: String, changes: inout [NumericITNChange]) -> String {
        replaceTokenRuns(in: text, rule: "numeric_itn_decimal", changes: &changes) { run, start, _, chars in
            guard !hasImmediatePrefix("百分之", chars: chars, start: start) else { return nil }
            guard run.filter({ $0 == "点" }).count == 1 else { return nil }
            let parts = run.split(separator: "点", omittingEmptySubsequences: false)
            guard parts.count == 2, let left = parts.first, let right = parts.last else { return nil }
            guard !left.isEmpty, !right.isEmpty else { return nil }
            guard right.allSatisfy({ Self.chineseDigitValue($0) != nil }) else { return nil }
            guard let leftValue = parseSimpleInteger(String(left)) else { return nil }
            let rightDigits = right.compactMap { Self.chineseDigitValue($0).map(String.init) }.joined()
            guard rightDigits.count == right.count else { return nil }
            return "\(leftValue).\(rightDigits)"
        }
    }

    private func rewriteUnitNumbers(_ text: String, changes: inout [NumericITNChange]) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0

        while index < chars.count {
            guard isChineseNumberCharacter(chars[index]) else {
                result.append(chars[index])
                index += 1
                continue
            }

            let start = index
            while index < chars.count, isChineseNumberCharacter(chars[index]) {
                index += 1
            }

            let numberSpan = String(chars[start..<index])
            if isInsideUnsupportedMagnitudeNumber(chars: chars, start: start, end: index) {
                result += numberSpan
                continue
            }

            var lookahead = index
            while lookahead < chars.count, chars[lookahead].isWhitespace {
                lookahead += 1
            }

            guard let unit = readTechnicalUnit(from: chars, at: lookahead) else {
                result += numberSpan
                continue
            }

            if let normalized = normalizeUnitNumber(numberSpan) {
                let original = String(chars[start..<(lookahead + unit.count)])
                let replacement = normalized + unit
                result += replacement
                changes.append(NumericITNChange(rule: "numeric_itn_unit", original: original, normalized: replacement))
                index = lookahead + unit.count
            } else {
                result += numberSpan
            }
        }

        return result
    }

    private func rewriteContextDigitSequences(_ text: String, changes: inout [NumericITNChange]) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0

        while index < chars.count {
            guard Self.chineseDigitValue(chars[index]) != nil else {
                result.append(chars[index])
                index += 1
                continue
            }

            let start = index
            while index < chars.count, Self.chineseDigitValue(chars[index]) != nil {
                index += 1
            }

            let span = String(chars[start..<index])
            if span.count >= 2, hasStrongDigitSequenceContext(chars: chars, start: start, end: index) {
                let replacement = span.compactMap { Self.chineseDigitValue($0).map(String.init) }.joined()
                result += replacement
                changes.append(NumericITNChange(rule: "numeric_itn_digit_sequence", original: span, normalized: replacement))
            } else {
                result += span
            }
        }

        return result
    }

    private func compactTechnicalUnitSpacing(_ text: String, changes: inout [NumericITNChange]) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0

        while index < chars.count {
            guard isASCIIDigit(chars[index]) else {
                result.append(chars[index])
                index += 1
                continue
            }

            let numberStart = index
            while index < chars.count, isASCIIDigit(chars[index]) {
                index += 1
            }
            if index < chars.count, chars[index] == "." {
                let dotIndex = index
                index += 1
                let fractionStart = index
                while index < chars.count, isASCIIDigit(chars[index]) {
                    index += 1
                }
                if fractionStart == index {
                    index = dotIndex
                }
            }

            let numberEnd = index
            var lookahead = index
            var sawSpace = false
            while lookahead < chars.count, chars[lookahead].isWhitespace {
                sawSpace = true
                lookahead += 1
            }

            if sawSpace, let unit = readTechnicalUnit(from: chars, at: lookahead) {
                let original = String(chars[numberStart..<(lookahead + unit.count)])
                let replacement = String(chars[numberStart..<numberEnd]) + unit
                result += replacement
                changes.append(NumericITNChange(rule: "numeric_itn_unit_spacing", original: original, normalized: replacement))
                index = lookahead + unit.count
            } else {
                result += String(chars[numberStart..<numberEnd])
            }
        }

        return result
    }

    private func replaceTokenRuns(
        in text: String,
        rule: String,
        changes: inout [NumericITNChange],
        transform: (String, Int, Int, [Character]) -> String?
    ) -> String {
        let chars = Array(text)
        var result = ""
        var index = 0

        while index < chars.count {
            guard isNumericTokenCharacter(chars[index]) else {
                result.append(chars[index])
                index += 1
                continue
            }

            let start = index
            while index < chars.count, isNumericTokenCharacter(chars[index]) {
                index += 1
            }

            let run = String(chars[start..<index])
            if let normalized = transform(run, start, index, chars), normalized != run {
                result += normalized
                changes.append(NumericITNChange(rule: rule, original: run, normalized: normalized))
            } else {
                result += run
            }
        }

        return result
    }

    private func parseSimpleNumericPart(_ text: String) -> String? {
        if text.allSatisfy({ Self.chineseDigitValue($0) != nil }) {
            return text.compactMap { Self.chineseDigitValue($0).map(String.init) }.joined()
        }
        return parseSimpleInteger(text).map(String.init)
    }

    private func normalizeUnitNumber(_ text: String) -> String? {
        if text.allSatisfy({ Self.chineseDigitValue($0) != nil }) {
            return text.compactMap { Self.chineseDigitValue($0).map(String.init) }.joined()
        }
        guard let value = parseSimpleInteger(text), value < 100 else { return nil }
        return String(value)
    }

    private func parseSimpleInteger(_ text: String) -> Int? {
        let chars = Array(text)
        guard !chars.isEmpty else { return nil }

        if chars.count == 1, let digit = Self.chineseDigitValue(chars[0]) {
            return digit
        }

        if chars.count == 1, chars[0] == "十" {
            return 10
        }

        if chars.count == 2, chars[0] == "十", let ones = Self.chineseDigitValue(chars[1]) {
            return 10 + ones
        }

        if chars.count == 2, let tens = Self.chineseDigitValue(chars[0]), chars[1] == "十" {
            return tens * 10
        }

        if chars.count == 3, let tens = Self.chineseDigitValue(chars[0]), chars[1] == "十", let ones = Self.chineseDigitValue(chars[2]) {
            return tens * 10 + ones
        }

        return nil
    }

    private func hasStrongDigitSequenceContext(chars: [Character], start: Int, end: Int) -> Bool {
        let beforeStart = max(0, start - 10)
        let afterEnd = min(chars.count, end + 6)
        let before = String(chars[beforeStart..<start])
        let after = String(chars[end..<afterEnd])

        let beforeKeywords = ["验证码", "编号", "订单", "样本", "case", "Case", "CASE", "ID", "id", "Id"]
        let afterKeywords = ["端口", "编号", "ID", "id", "Id"]

        return beforeKeywords.contains(where: before.contains) || afterKeywords.contains(where: after.contains)
    }

    private func hasImmediatePrefix(_ prefix: String, chars: [Character], start: Int) -> Bool {
        let prefixChars = Array(prefix)
        guard start >= prefixChars.count else { return false }
        return Array(chars[(start - prefixChars.count)..<start]) == prefixChars
    }

    private func isInsideUnsupportedMagnitudeNumber(chars: [Character], start: Int, end: Int) -> Bool {
        let magnitudes = Set<Character>(["百", "千", "万", "亿"])
        if start > 0, magnitudes.contains(chars[start - 1]) {
            return true
        }
        if end < chars.count, magnitudes.contains(chars[end]) {
            return true
        }
        return false
    }

    private func isASCIIDigit(_ character: Character) -> Bool {
        character >= "0" && character <= "9"
    }

    private func readTechnicalUnit(from chars: [Character], at index: Int) -> String? {
        let units = ["GB", "MB", "KB", "B"]
        for unit in units {
            let unitChars = Array(unit)
            guard index + unitChars.count <= chars.count else { continue }
            if Array(chars[index..<(index + unitChars.count)]) == unitChars {
                return unit
            }
        }
        return nil
    }

    private func isNumericTokenCharacter(_ character: Character) -> Bool {
        character == "点" || isChineseNumberCharacter(character)
    }

    private func isChineseNumberCharacter(_ character: Character) -> Bool {
        Self.chineseDigitValue(character) != nil || character == "十"
    }

    private static func chineseDigitValue(_ character: Character) -> Int? {
        switch character {
        case "零", "〇":
            return 0
        case "一":
            return 1
        case "二", "两":
            return 2
        case "三":
            return 3
        case "四":
            return 4
        case "五":
            return 5
        case "六":
            return 6
        case "七":
            return 7
        case "八":
            return 8
        case "九":
            return 9
        default:
            return nil
        }
    }
}
