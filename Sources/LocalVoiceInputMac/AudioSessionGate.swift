#if os(macOS)
import Foundation

struct AudioSessionToken: Equatable, Sendable {
    let rawValue: UInt64
}

final class AudioSessionGate {
    private var nextRawValue: UInt64 = 0
    private(set) var activeToken: AudioSessionToken?

    func begin() -> AudioSessionToken {
        nextRawValue &+= 1
        let token = AudioSessionToken(rawValue: nextRawValue)
        activeToken = token
        return token
    }

    func end() {
        activeToken = nil
    }

    func accepts(_ token: AudioSessionToken?) -> Bool {
        guard let token, let activeToken else { return false }
        return token == activeToken
    }
}
#endif
