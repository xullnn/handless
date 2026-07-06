#if os(macOS)
import XCTest
@testable import LocalVoiceInputMac

final class BundledQwenASRServiceManagerTests: XCTestCase {
    func testAcceptsExpectedQwen3SegmentedMetadata() {
        XCTAssertNil(BundledQwenASRServiceManager.metadataCompatibilityFailure(for: [
            "ok": true,
            "service": "qwen3-mlx-segmented-cache-service",
            "model_info": ["id": "qwen3-asr-0.6b-mlx-8bit"],
            "fake_backend": false
        ]))
    }

    func testRejectsUnexpectedModelId() {
        let failure = BundledQwenASRServiceManager.metadataCompatibilityFailure(for: [
            "ok": true,
            "service": "qwen3-mlx-segmented-cache-service",
            "model_info": ["id": "qwen3-asr-1.7b-mlx-8bit"],
            "fake_backend": false
        ])

        XCTAssertEqual(failure, "model_id=qwen3-asr-1.7b-mlx-8bit")
    }

    func testRejectsFakeBackend() {
        let failure = BundledQwenASRServiceManager.metadataCompatibilityFailure(for: [
            "ok": true,
            "service": "qwen3-mlx-segmented-cache-service",
            "model_info": ["id": "qwen3-asr-0.6b-mlx-8bit"],
            "fake_backend": true
        ])

        XCTAssertEqual(failure, "fake_backend=true")
    }

    func testShutdownURLUsesShutdownEndpoint() {
        let url = URL(string: "http://127.0.0.1:18096")!

        XCTAssertEqual(
            BundledQwenASRServiceManager.shutdownURL(for: url).absoluteString,
            "http://127.0.0.1:18096/shutdown"
        )
    }

    func testPostShutdownRequestPostsToShutdownEndpoint() throws {
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalVoiceInputShutdownTest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temp) }

        let portFile = temp.appendingPathComponent("port.txt")
        let markerFile = temp.appendingPathComponent("path.txt")
        let script = """
        import http.server
        import sys

        port_file = sys.argv[1]
        marker_file = sys.argv[2]

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_POST(self):
                with open(marker_file, "w", encoding="utf-8") as handle:
                    handle.write(self.path)
                body = b'{"ok": true}'
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, format, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        with open(port_file, "w", encoding="utf-8") as handle:
            handle.write(str(server.server_port))
        server.handle_request()
        server.server_close()
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", "-u", "-c", script, portFile.path, markerFile.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        let port = try waitForFileContents(portFile).trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceURL = URL(string: "http://127.0.0.1:\(port)")!

        XCTAssertTrue(BundledQwenASRServiceManager.postShutdownRequest(serviceURL: serviceURL, timeout: 2.0))
        process.waitUntilExit()
        XCTAssertEqual(try waitForFileContents(markerFile), "/shutdown")
    }

    private func waitForFileContents(
        _ url: URL,
        timeout: TimeInterval = 3.0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        XCTFail("Timed out waiting for \(url.path)", file: file, line: line)
        return ""
    }
}
#endif
