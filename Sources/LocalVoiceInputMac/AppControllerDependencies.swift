#if os(macOS)
import Foundation
import LocalVoiceInputCore

protocol MenuBarControlling: AnyObject {
    var onStartMock: (() -> Void)? { get set }
    var onStop: (() -> Void)? { get set }
    var onCopyLast: (() -> Void)? { get set }
    var onClearHistory: (() -> Void)? { get set }
    var onPromptPermissions: (() -> Void)? { get set }

    func setStatus(_ text: String)
}

protocol FloatingPanelPresenting: AnyObject {
    var onCancel: (() -> Void)? { get set }
    var onFinish: (() -> Void)? { get set }
    var onCopy: (() -> Void)? { get set }
    var onRestoreClipboard: (() -> Void)? { get set }
    var onQuit: (() -> Void)? { get set }

    func show(mode: OutputMode)
    func showListening(mode: OutputMode)
    func updateMode(_ mode: OutputMode)
    func updatePartial(_ text: String)
    func updateFinalizing()
    func updateDone(status: PasteRouteStatus, text: String, restoredClipboard: Bool)
    func updateError(_ message: String)
    func updateDiagnostics(_ text: String)
}

protocol FocusDetecting: AnyObject {
    func snapshot() -> FocusSnapshot
}

protocol HotkeyControlling: AnyObject {
    var onPushToTalkStart: (() -> Void)? { get set }
    var onPushToTalkStop: (() -> Void)? { get set }
    var onLongDraftStart: (() -> Void)? { get set }
    var onLongDraftStop: (() -> Void)? { get set }
    var onCancel: (() -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }

    func start()
    func stop()
    func noteSessionStarted(type: SessionType)
    func noteSessionEnded()
}

protocol AudioCapturing: AnyObject {
    var onPCMChunk: ((AudioSessionToken, Data) -> Void)? { get set }
    var onError: ((Error) -> Void)? { get set }

    func prewarm()
    func start(sessionToken: AudioSessionToken)
    func cancel()
    func stopAndFlush(completion: @escaping (AudioSessionToken?, [Data]) -> Void)
}

protocol SystemAudioDuckingControlling: AnyObject {
    func beginDucking(sessionId: String)
    func restoreDucking(sessionId: String?)
}

protocol PasteRouting: AnyObject {
    func routeAsync(text: String, mode: OutputMode, completion: @escaping (OutputResult) -> Void)
}

protocol HistoryRecording: AnyObject {
    func append(text: String, outputMode: OutputMode, correctionRules: [String])
    func latest() -> HistoryItem?
    func clear()
}

protocol ASRClientMaking {
    func makeClient(config: AppConfig, forceMock: Bool) -> ASRClientProtocol
}

struct DefaultASRClientFactory: ASRClientMaking {
    func makeClient(config: AppConfig, forceMock: Bool) -> ASRClientProtocol {
        if config.mockASR || forceMock {
            return MockASRClient(transcript: config.mockTranscript)
        }

        switch config.asrBackend {
        case .funASRWebSocket:
            return FunASRClient(urlString: config.asrURL)
        case .localHTTP:
            return LocalHTTPASRClient(serviceURLString: config.asrHTTPURL)
        }
    }
}

extension MenuBarController: MenuBarControlling {}
extension FloatingPanelController: FloatingPanelPresenting {}
extension FocusDetector: FocusDetecting {}
extension HotkeyController: HotkeyControlling {}
extension AudioCapture: AudioCapturing {}
extension PasteEngine: PasteRouting {}
extension HistoryStore: HistoryRecording {}
#endif
