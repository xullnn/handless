#if os(macOS)
import Foundation
import LocalVoiceInputCore

protocol LocalHTTPASRTransport {
    func post(
        serviceURL: URL,
        path: String,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> [String: Any]
}

final class URLSessionLocalHTTPASRTransport: LocalHTTPASRTransport {
    func post(
        serviceURL: URL,
        path: String,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> [String: Any] {
        let url = serviceURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error>!
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(ASRClientError.httpFailed(error.localizedDescription))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                result = .failure(ASRClientError.malformedResponse("missing HTTP response"))
                return
            }
            let body = data ?? Data()
            guard (200..<300).contains(http.statusCode) else {
                let text = String(data: body, encoding: .utf8) ?? ""
                result = .failure(ASRClientError.httpFailed("HTTP \(http.statusCode): \(text.prefix(500))"))
                return
            }
            if body.isEmpty {
                result = .success(["events": []])
                return
            }
            do {
                let parsed = try JSONSerialization.jsonObject(with: body)
                guard let object = parsed as? [String: Any] else {
                    result = .failure(ASRClientError.malformedResponse("response body is not a JSON object"))
                    return
                }
                if let error = object["error"] as? String, !error.isEmpty {
                    result = .failure(ASRClientError.httpFailed(error))
                    return
                }
                result = .success(object)
            } catch {
                result = .failure(ASRClientError.malformedResponse(error.localizedDescription))
            }
        }
        task.resume()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            task.cancel()
            throw ASRClientError.httpFailed("request timed out for \(path)")
        }
        return try result.get()
    }
}

final class LocalHTTPASRClient: ASRClientProtocol {
    var onEvent: ((ASREvent) -> Void)?
    var onError: ((Error) -> Void)?

    private let serviceURLString: String
    private let serviceURL: URL?
    private let transport: LocalHTTPASRTransport
    private let timeout: TimeInterval
    private let tokenProvider: () -> Int
    private let queue = DispatchQueue(label: "LocalVoiceInput.LocalHTTPASRClient")
    private let stateLock = NSLock()

    private var sessionId = ""
    private var sessionToken = 0
    private var chunkIndex = 0
    private var audioOffsetMs = 0.0
    private var startedAt: DispatchTime?
    private var hasStarted = false
    private var didFinish = false
    private var cancelled = false

    init(
        serviceURLString: String,
        transport: LocalHTTPASRTransport = URLSessionLocalHTTPASRTransport(),
        timeout: TimeInterval = 30,
        tokenProvider: @escaping () -> Int = { Int.random(in: 1..<Int.max) }
    ) {
        self.serviceURLString = serviceURLString
        self.serviceURL = URL(string: serviceURLString)
        self.transport = transport
        self.timeout = timeout
        self.tokenProvider = tokenProvider
    }

    func start(sessionId: String, hotwords: [String: String]) {
        guard let serviceURL, LocalHTTPASRClient.isAllowedLoopbackURL(serviceURL) else {
            onError?(ASRClientError.unsupportedServiceURL(serviceURLString))
            return
        }
        setCancelled(false)
        queue.async {
            guard !self.isCancelled() else { return }
            self.sessionId = sessionId
            self.sessionToken = self.tokenProvider()
            self.chunkIndex = 0
            self.audioOffsetMs = 0
            self.startedAt = .now()
            self.hasStarted = true
            self.didFinish = false

            let payload: [String: Any] = [
                "session_id": sessionId,
                "session_token": self.sessionToken,
                "case_id": sessionId,
                "hotwords": hotwords,
                "sample_rate": 16000,
                "sample_width_bytes": 2,
                "channels": 1,
                "recv_offset_ms": 0.0
            ]
            self.post(path: "/start", payload: payload, allowFinal: false)
        }
    }

    func sendPCM(_ data: Data) {
        queue.async {
            guard self.hasStarted, !self.isCancelled(), !self.didFinish else { return }
            guard let serviceURL = self.serviceURL else {
                self.emitError(ASRClientError.unsupportedServiceURL(self.serviceURLString))
                return
            }
            guard LocalHTTPASRClient.isAllowedLoopbackURL(serviceURL) else {
                self.emitError(ASRClientError.unsupportedServiceURL(self.serviceURLString))
                return
            }

            let startMs = self.audioOffsetMs
            let durationMs = Double(data.count) / 2.0 / 16_000.0 * 1000.0
            let endMs = startMs + durationMs
            let payload: [String: Any] = [
                "session_id": self.sessionId,
                "session_token": self.sessionToken,
                "case_id": self.sessionId,
                "recv_offset_ms": self.elapsedMs(),
                "audio_start_ms": startMs,
                "audio_end_ms": endMs,
                "chunk_index": self.chunkIndex,
                "pcm_base64": data.base64EncodedString(),
                "sample_rate": 16000,
                "sample_width_bytes": 2,
                "channels": 1
            ]
            self.chunkIndex += 1
            self.audioOffsetMs = endMs
            self.post(path: "/chunk", payload: payload, allowFinal: false)
        }
    }

    func finish() {
        queue.async {
            guard self.hasStarted, !self.isCancelled(), !self.didFinish else { return }
            self.didFinish = true
            let payload: [String: Any] = [
                "session_id": self.sessionId,
                "session_token": self.sessionToken,
                "case_id": self.sessionId,
                "recv_offset_ms": self.elapsedMs()
            ]
            self.post(path: "/finish", payload: payload, allowFinal: true)
        }
    }

    func cancel() {
        guard markCancelledAndClearCallbacks() else { return }
        queue.async {
            guard self.hasStarted else { return }
            guard let serviceURL = self.serviceURL, LocalHTTPASRClient.isAllowedLoopbackURL(serviceURL) else { return }
            let payload: [String: Any] = [
                "session_id": self.sessionId,
                "session_token": self.sessionToken,
                "case_id": self.sessionId,
                "recv_offset_ms": self.elapsedMs()
            ]
            _ = try? self.transport.post(serviceURL: serviceURL, path: "/cancel", payload: payload, timeout: self.timeout)
        }
    }

    private func post(path: String, payload: [String: Any], allowFinal: Bool) {
        guard let serviceURL else {
            emitError(ASRClientError.unsupportedServiceURL(serviceURLString))
            return
        }
        guard !isCancelled() else { return }
        do {
            let response = try transport.post(serviceURL: serviceURL, path: path, payload: payload, timeout: timeout)
            handleResponse(response, allowFinal: allowFinal)
        } catch {
            emitError(error)
        }
    }

    private func handleResponse(_ response: [String: Any], allowFinal: Bool) {
        guard !isCancelled() else { return }
        let rawEvents: [Any]
        if response["kind"] is String {
            rawEvents = [response]
        } else {
            rawEvents = response["events"] as? [Any] ?? []
        }

        for raw in rawEvents {
            guard !isCancelled() else { return }
            guard let object = raw as? [String: Any] else { continue }
            guard let event = makeEvent(from: object, allowFinal: allowFinal) else { continue }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isCancelled() else { return }
                self.onEvent?(event)
            }
        }
    }

    private func makeEvent(from object: [String: Any], allowFinal: Bool) -> ASREvent? {
        let kind = object["kind"] as? String ?? ""
        guard kind == "partial" || kind == "final" else { return nil }
        let eventSessionId = object["session_id"] as? String ?? sessionId
        guard eventSessionId == sessionId else { return nil }
        guard intValue(object["session_token"]) == sessionToken else { return nil }
        let text = object["text"] as? String ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        if kind == "final" {
            guard allowFinal else { return nil }
            return ASREvent(sessionId: sessionId, segmentId: 0, mode: .offline, text: text, isFinal: true)
        }
        return ASREvent(sessionId: sessionId, segmentId: 0, mode: .online, text: text, isFinal: false)
    }

    private func emitError(_ error: Error) {
        guard !isCancelled() else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isCancelled() else { return }
            self.onError?(error)
        }
    }

    private func elapsedMs() -> Double {
        guard let startedAt else { return 0 }
        let nanos = DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds
        return Double(nanos) / 1_000_000.0
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String { return Int(string) }
        return nil
    }

    private func setCancelled(_ value: Bool) {
        stateLock.lock()
        cancelled = value
        stateLock.unlock()
    }

    private func isCancelled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return cancelled
    }

    private func markCancelledAndClearCallbacks() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard !cancelled else { return false }
        cancelled = true
        onEvent = nil
        onError = nil
        return true
    }

    static func isAllowedLoopbackURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "http" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]"
    }
}
#endif
