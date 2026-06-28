#if os(macOS)
import Foundation
import LocalVoiceInputCore

protocol ASRClientProtocol: AnyObject {
    var onEvent: ((ASREvent) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func start(sessionId: String, hotwords: [String: String])
    func sendPCM(_ data: Data)
    func finish()
    func cancel()
}

enum ASRClientError: Error, LocalizedError {
    case invalidURL(String)
    case notConnected
    case websocketFailed(String)
    case unsupportedServiceURL(String)
    case httpFailed(String)
    case malformedResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let value): return "Invalid ASR URL: \(value)"
        case .notConnected: return "ASR websocket is not connected"
        case .websocketFailed(let message): return "ASR websocket failed: \(message)"
        case .unsupportedServiceURL(let value): return "Unsupported ASR service URL: \(value)"
        case .httpFailed(let message): return "ASR HTTP request failed: \(message)"
        case .malformedResponse(let message): return "Malformed ASR HTTP response: \(message)"
        }
    }
}
#endif
