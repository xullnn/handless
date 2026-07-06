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
}
#endif
