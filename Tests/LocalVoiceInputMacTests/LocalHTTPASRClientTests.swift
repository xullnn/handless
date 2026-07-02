#if os(macOS)
import Foundation
import XCTest
import LocalVoiceInputCore
@testable import LocalVoiceInputMac

final class LocalHTTPASRClientTests: XCTestCase {
    func testRejectsNonLoopbackServiceURL() {
        XCTAssertFalse(LocalHTTPASRClient.isAllowedLoopbackURL(URL(string: "http://192.168.1.2:18096")!))
        XCTAssertFalse(LocalHTTPASRClient.isAllowedLoopbackURL(URL(string: "https://127.0.0.1:18096")!))
        XCTAssertTrue(LocalHTTPASRClient.isAllowedLoopbackURL(URL(string: "http://127.0.0.1:18096")!))
        XCTAssertTrue(LocalHTTPASRClient.isAllowedLoopbackURL(URL(string: "http://localhost:18096")!))
    }

    func testStartAndChunkEmitPartialWithSessionToken() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/start" {
                return ["events": []]
            }
            if path == "/chunk" {
                return [
                    "events": [
                        [
                            "kind": "partial",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "实时文本"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 42 }
        )
        let eventExpectation = expectation(description: "partial event")
        client.onEvent = { event in
            XCTAssertEqual(event.sessionId, "s1")
            XCTAssertEqual(event.mode, .online)
            XCTAssertFalse(event.isFinal)
            XCTAssertEqual(event.text, "实时文本")
            eventExpectation.fulfill()
        }
        client.start(sessionId: "s1", hotwords: ["qwen三": "Qwen3"])
        client.sendPCM(Data([0, 0, 1, 0]))
        wait(for: [eventExpectation], timeout: 2)

        let requests = transport.requestsSnapshot()
        XCTAssertEqual(requests.map(\.path), ["/start", "/chunk"])
        XCTAssertEqual(requests[0].payload["session_token"] as? Int, 42)
        XCTAssertEqual(requests[1].payload["chunk_index"] as? Int, 0)
        XCTAssertEqual(requests[1].payload["sample_rate"] as? Int, 16000)
        XCTAssertEqual(requests[1].payload["channels"] as? Int, 1)
        XCTAssertNotNil(requests[1].payload["pcm_base64"] as? String)
    }

    func testIgnoresTokenMismatchAndFinalBeforeFinish() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/chunk" {
                return [
                    "events": [
                        [
                            "kind": "partial",
                            "session_id": payload["session_id"]!,
                            "session_token": 999,
                            "text": "旧会话"
                        ],
                        [
                            "kind": "final",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "不应提前最终输出"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 7 }
        )
        let inverted = expectation(description: "no event")
        inverted.isInverted = true
        client.onEvent = { _ in inverted.fulfill() }
        client.start(sessionId: "s2", hotwords: [:])
        client.sendPCM(Data([0, 0]))
        wait(for: [inverted], timeout: 0.5)
    }

    func testFinishEmitsFinal() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/finish" {
                return [
                    "events": [
                        [
                            "kind": "final",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "最终文本"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 8 }
        )
        let eventExpectation = expectation(description: "final event")
        client.onEvent = { event in
            XCTAssertEqual(event.mode, .offline)
            XCTAssertTrue(event.isFinal)
            XCTAssertEqual(event.text, "最终文本")
            eventExpectation.fulfill()
        }
        client.start(sessionId: "s3", hotwords: [:])
        client.finish()
        wait(for: [eventExpectation], timeout: 2)
    }

    func testIgnoresSegmentDiagnosticsAndEmitsVisibleEventsOnly() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/chunk" {
                return [
                    "events": [
                        [
                            "kind": "segment_final",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "诊断事件不应进入 App"
                        ],
                        [
                            "kind": "partial",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "用户可见草稿"
                        ]
                    ]
                ]
            }
            if path == "/finish" {
                return [
                    "events": [
                        [
                            "kind": "segment_final",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "最终前诊断事件"
                        ],
                        [
                            "kind": "final",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "最终文本"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 11 }
        )
        var received: [ASREvent] = []
        let partialExpectation = expectation(description: "partial")
        let finalExpectation = expectation(description: "final")
        client.onEvent = { event in
            received.append(event)
            if !event.isFinal {
                partialExpectation.fulfill()
            } else {
                finalExpectation.fulfill()
            }
        }
        client.start(sessionId: "segmented", hotwords: [:])
        client.sendPCM(Data([0, 0]))
        client.finish()
        wait(for: [partialExpectation, finalExpectation], timeout: 2)

        XCTAssertEqual(received.map(\.text), ["用户可见草稿", "最终文本"])
        XCTAssertEqual(received.map(\.mode), [.online, .offline])
    }

    func testCancelSuppressesLateCallbacksAndPostsCancel() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/chunk" {
                Thread.sleep(forTimeInterval: 0.05)
                return [
                    "events": [
                        [
                            "kind": "partial",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "late"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 9 }
        )
        let inverted = expectation(description: "no event after cancel")
        inverted.isInverted = true
        client.onEvent = { _ in inverted.fulfill() }
        client.start(sessionId: "s4", hotwords: [:])
        client.sendPCM(Data([0, 0]))
        XCTAssertTrue(transport.waitForPath("/chunk", timeout: 1))
        client.cancel()
        wait(for: [inverted], timeout: 0.5)

        XCTAssertTrue(transport.waitForPath("/cancel", timeout: 1))
    }

    func testImmediateCancelSuppressesStartResponseEvents() {
        let transport = FakeLocalHTTPTransport { path, payload in
            if path == "/start" {
                Thread.sleep(forTimeInterval: 0.05)
                return [
                    "events": [
                        [
                            "kind": "partial",
                            "session_id": payload["session_id"]!,
                            "session_token": payload["session_token"]!,
                            "text": "不应出现"
                        ]
                    ]
                ]
            }
            return ["events": []]
        }
        let client = LocalHTTPASRClient(
            serviceURLString: "http://127.0.0.1:18096",
            transport: transport,
            timeout: 1,
            tokenProvider: { 10 }
        )
        let inverted = expectation(description: "no start response event after immediate cancel")
        inverted.isInverted = true
        client.onEvent = { _ in inverted.fulfill() }
        client.start(sessionId: "s5", hotwords: [:])
        client.cancel()
        wait(for: [inverted], timeout: 0.5)
    }
}

private struct CapturedHTTPRequest {
    var path: String
    var payload: [String: Any]
}

private final class FakeLocalHTTPTransport: LocalHTTPASRTransport {
    private let lock = NSLock()
    private var requests: [CapturedHTTPRequest] = []
    private let handler: (String, [String: Any]) throws -> [String: Any]

    init(handler: @escaping (String, [String: Any]) throws -> [String: Any]) {
        self.handler = handler
    }

    func post(
        serviceURL: URL,
        path: String,
        payload: [String: Any],
        timeout: TimeInterval
    ) throws -> [String: Any] {
        lock.lock()
        requests.append(CapturedHTTPRequest(path: path, payload: payload))
        lock.unlock()
        return try handler(path, payload)
    }

    func requestsSnapshot() -> [CapturedHTTPRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func waitForPath(_ path: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if requestsSnapshot().contains(where: { $0.path == path }) {
                return true
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return false
    }
}
#endif
