#if os(macOS)
import Foundation

enum ListeningIndicator {
    static let frameCount = 3

    static func nextFrame(after frame: Int) -> Int {
        (frame + 1) % frameCount
    }

    static func text(for frame: Int) -> String {
        let activeFrame = ((frame % frameCount) + frameCount) % frameCount
        return (0..<frameCount).map { index in
            index == activeFrame ? "●" : "○"
        }.joined(separator: "  ")
    }
}
#endif
