#if os(macOS)
import Foundation
import LocalVoiceInputCore

enum ASRBackend: String, Codable {
    case funASRWebSocket = "funasr-websocket"
    case localHTTP = "local-http"
}

struct AppConfig: Codable {
    var asrURL: String
    var asrBackend: ASRBackend
    var asrHTTPURL: String
    var mockASR: Bool
    var mockTranscript: String
    var hotwords: [String: String]
    var homophones: [String: String]
    var outputPolicy: OutputPolicy
    var correctionMode: CorrectionMode
    var numericITNEnabled: Bool
    var historyMaxItems: Int

    static let `default` = AppConfig(
        asrURL: "ws://127.0.0.1:10095",
        asrBackend: .funASRWebSocket,
        asrHTTPURL: "http://127.0.0.1:18096",
        mockASR: false,
        mockTranscript: "这是一次本地语音输入测试，松开快捷键以后会自动粘贴或者复制到剪切板。",
        hotwords: [
            "qwen三": "Qwen3",
            "fun asr": "FunASR",
            "麦克不 pro": "MacBook Pro",
            "麦克布克 pro": "MacBook Pro"
        ],
        homophones: [:],
        outputPolicy: .default,
        correctionMode: .clean,
        numericITNEnabled: false,
        historyMaxItems: 20
    )

    init(
        asrURL: String,
        asrBackend: ASRBackend,
        asrHTTPURL: String,
        mockASR: Bool,
        mockTranscript: String,
        hotwords: [String: String],
        homophones: [String: String],
        outputPolicy: OutputPolicy,
        correctionMode: CorrectionMode,
        numericITNEnabled: Bool,
        historyMaxItems: Int
    ) {
        self.asrURL = asrURL
        self.asrBackend = asrBackend
        self.asrHTTPURL = asrHTTPURL
        self.mockASR = mockASR
        self.mockTranscript = mockTranscript
        self.hotwords = hotwords
        self.homophones = homophones
        self.outputPolicy = outputPolicy
        self.correctionMode = correctionMode
        self.numericITNEnabled = numericITNEnabled
        self.historyMaxItems = historyMaxItems
    }

    enum CodingKeys: String, CodingKey {
        case asrURL
        case asrBackend
        case asrHTTPURL
        case mockASR
        case mockTranscript
        case hotwords
        case homophones
        case outputPolicy
        case correctionMode
        case numericITNEnabled
        case historyMaxItems
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppConfig.default
        asrURL = try values.decodeIfPresent(String.self, forKey: .asrURL) ?? defaults.asrURL
        asrBackend = try values.decodeIfPresent(ASRBackend.self, forKey: .asrBackend) ?? defaults.asrBackend
        asrHTTPURL = try values.decodeIfPresent(String.self, forKey: .asrHTTPURL) ?? defaults.asrHTTPURL
        mockASR = try values.decodeIfPresent(Bool.self, forKey: .mockASR) ?? defaults.mockASR
        mockTranscript = try values.decodeIfPresent(String.self, forKey: .mockTranscript) ?? defaults.mockTranscript
        hotwords = try values.decodeIfPresent([String: String].self, forKey: .hotwords) ?? defaults.hotwords
        homophones = try values.decodeIfPresent([String: String].self, forKey: .homophones) ?? defaults.homophones
        outputPolicy = try values.decodeIfPresent(OutputPolicy.self, forKey: .outputPolicy) ?? defaults.outputPolicy
        correctionMode = try values.decodeIfPresent(CorrectionMode.self, forKey: .correctionMode) ?? defaults.correctionMode
        numericITNEnabled = try values.decodeIfPresent(Bool.self, forKey: .numericITNEnabled) ?? defaults.numericITNEnabled
        historyMaxItems = try values.decodeIfPresent(Int.self, forKey: .historyMaxItems) ?? defaults.historyMaxItems
    }

    static func loadFromDefaultLocation(commandLine: [String]) -> AppConfig {
        var config = AppConfig.default
        let url = ConfigPaths.configURL
        if let data = try? Data(contentsOf: url), let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = decoded
        }
        config.applyCommandLine(commandLine)
        return config
    }

    mutating func applyCommandLine(_ commandLine: [String]) {
        if commandLine.contains("--mock-asr") {
            mockASR = true
        }
        if let idx = commandLine.firstIndex(of: "--asr-url"), commandLine.indices.contains(commandLine.index(after: idx)) {
            asrURL = commandLine[commandLine.index(after: idx)]
        }
        if let idx = commandLine.firstIndex(of: "--asr-http-url"), commandLine.indices.contains(commandLine.index(after: idx)) {
            asrHTTPURL = commandLine[commandLine.index(after: idx)]
        }
        if let idx = commandLine.firstIndex(of: "--asr-backend"), commandLine.indices.contains(commandLine.index(after: idx)) {
            let raw = commandLine[commandLine.index(after: idx)]
            if let backend = ASRBackend(rawValue: raw) {
                asrBackend = backend
            }
        }
        if commandLine.contains("--local-http-asr") {
            asrBackend = .localHTTP
        }
        if let idx = commandLine.firstIndex(of: "--mock-transcript"), commandLine.indices.contains(commandLine.index(after: idx)) {
            mockTranscript = commandLine[commandLine.index(after: idx)]
        }
        if let enableIndex = commandLine.lastIndex(of: "--numeric-itn") {
            if let disableIndex = commandLine.lastIndex(of: "--no-numeric-itn") {
                numericITNEnabled = enableIndex > disableIndex
            } else {
                numericITNEnabled = true
            }
        } else if commandLine.contains("--no-numeric-itn") {
            numericITNEnabled = false
        }
    }
}

enum ConfigPaths {
    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("LocalVoiceInput", isDirectory: true)
    }

    static var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    static var historyURL: URL {
        appSupportDirectory.appendingPathComponent("history.json")
    }

    static func ensureDirectories() {
        try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
    }
}
#endif
