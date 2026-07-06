#if os(macOS)
import Foundation

struct AppDiagnosticsSummary {
    static func make(config: AppConfig, bundle: Bundle = .main, now: Date = Date()) -> String {
        let generatedAt = ISO8601DateFormatter().string(from: now)
        let activeASRURL: String
        switch config.asrBackend {
        case .funASRWebSocket:
            activeASRURL = config.asrURL
        case .localHTTP:
            activeASRURL = config.asrHTTPURL
        }

        let bundleID = bundle.bundleIdentifier ?? "unknown"
        let bundlePath = bundle.bundleURL.path
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"

        return [
            "LocalVoiceInput Diagnostics",
            "Generated: \(generatedAt)",
            "Version: \(version)",
            "Bundle ID: \(bundleID)",
            "Bundle Path: \(bundlePath)",
            "Config Path: \(ConfigPaths.configURL.path)",
            "Logs Directory: \(ConfigPaths.logsDirectory.path)",
            "Cache Directory: \(ConfigPaths.cacheDirectory.path)",
            "ASR Backend: \(config.asrBackend.rawValue)",
            "ASR URL: \(activeASRURL)",
            "Mock ASR: \(config.mockASR)",
            "Numeric ITN: \(config.numericITNEnabled)",
            "Audio Ducking: \(config.audioDucking.enabled)",
            "Audio Ducking Target Volume: \(config.audioDucking.targetVolume)",
            "Audio Ducking Mute: \(config.audioDucking.muteInsteadOfDuck)"
        ].joined(separator: "\n")
    }
}
#endif
