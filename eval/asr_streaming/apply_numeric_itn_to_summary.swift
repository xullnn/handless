import Foundation

enum ToolError: Error, CustomStringConvertible {
    case missingArgument(String)
    case invalidJSON(String)
    case invalidSummaryShape

    var description: String {
        switch self {
        case .missingArgument(let name):
            return "missing required argument: \(name)"
        case .invalidJSON(let path):
            return "invalid JSON: \(path)"
        case .invalidSummaryShape:
            return "summary JSON must be an object"
        }
    }
}

@main
struct ApplyNumericITNToSummary {
    static func main() throws {
        let args = parseArguments(CommandLine.arguments.dropFirst())
        guard let summaryPath = args["--summary"] else { throw ToolError.missingArgument("--summary") }
        guard let outputPath = args["--out"] else { throw ToolError.missingArgument("--out") }

        let inputURL = URL(fileURLWithPath: summaryPath)
        let data = try Data(contentsOf: inputURL)
        guard var summary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ToolError.invalidSummaryShape
        }

        let itn = NumericITN()
        var changedCaseCount = 0
        var totalChangeCount = 0

        if let cases = summary["cases"] as? [[String: Any]] {
            let transformed = transformCases(cases, itn: itn, changedCaseCount: &changedCaseCount, totalChangeCount: &totalChangeCount)
            summary["cases"] = transformed
        }

        if let caseSummaries = summary["case_summaries"] as? [[String: Any]] {
            let transformed = transformCases(caseSummaries, itn: itn, changedCaseCount: &changedCaseCount, totalChangeCount: &totalChangeCount)
            summary["case_summaries"] = transformed
        }

        summary["numeric_itn"] = [
            "schema_version": "1.0",
            "enabled": true,
            "source": "Sources/LocalVoiceInputCore/NumericITN.swift",
            "source_summary": summaryPath,
            "changed_case_count": changedCaseCount,
            "total_change_count": totalChangeCount,
            "notes": "final_text is replaced with NumericITN-normalized text; raw_final_text preserves the ASR output. CER/WER metrics remain raw ASR metrics and must not be interpreted as ITN text accuracy."
        ]

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let outputData = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        try outputData.write(to: outputURL)
        FileHandle.standardOutput.write(outputData)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func parseArguments(_ args: ArraySlice<String>) -> [String: String] {
        var result: [String: String] = [:]
        var iterator = args.makeIterator()
        while let key = iterator.next() {
            guard key.hasPrefix("--") else { continue }
            if let value = iterator.next() {
                result[key] = value
            }
        }
        return result
    }

    private static func transformCases(
        _ cases: [[String: Any]],
        itn: NumericITN,
        changedCaseCount: inout Int,
        totalChangeCount: inout Int
    ) -> [[String: Any]] {
        cases.map { originalCase in
            var item = originalCase
            guard let finalText = item["final_text"] as? String else { return item }
            let result = itn.normalize(finalText)
            item["raw_final_text"] = finalText
            item["final_text"] = result.normalized
            item["numeric_itn_changed"] = result.normalized != finalText
            item["numeric_itn_changes"] = result.changes.map { change in
                [
                    "rule": change.rule,
                    "original": change.original,
                    "normalized": change.normalized
                ]
            }
            if result.normalized != finalText {
                changedCaseCount += 1
                totalChangeCount += result.changes.count
            }
            return item
        }
    }
}
