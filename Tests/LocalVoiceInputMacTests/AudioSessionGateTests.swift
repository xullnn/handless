#if os(macOS)
import XCTest
@testable import LocalVoiceInputMac

final class AudioSessionGateTests: XCTestCase {
    func testOnlyAcceptsActiveToken() {
        let gate = AudioSessionGate()

        let first = gate.begin()
        XCTAssertTrue(gate.accepts(first))
        XCTAssertFalse(gate.accepts(nil))

        let second = gate.begin()
        XCTAssertFalse(gate.accepts(first))
        XCTAssertTrue(gate.accepts(second))

        gate.end()
        XCTAssertFalse(gate.accepts(second))
    }

    func testNewSessionInvalidatesQueuedOldAudioChunks() {
        let gate = AudioSessionGate()

        let oldToken = gate.begin()
        let newToken = gate.begin()

        XCTAssertFalse(gate.accepts(oldToken))
        XCTAssertTrue(gate.accepts(newToken))
    }
}
#endif
