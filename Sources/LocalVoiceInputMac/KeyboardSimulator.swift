#if os(macOS)
import Foundation
import ApplicationServices

protocol KeyboardSimulating: AnyObject {
    func pressCommandV()
    func pressCommandV(targetPid: pid_t?)
}

final class KeyboardSimulator: KeyboardSimulating {
    struct KeyEventPlanStep: Equatable {
        var keyCode: CGKeyCode
        var keyDown: Bool
        var flags: CGEventFlags
        var pauseAfter: Bool
    }

    static func commandVPastePlan() -> [KeyEventPlanStep] {
        [
            KeyEventPlanStep(keyCode: 61, keyDown: false, flags: [], pauseAfter: false), // Right Option
            KeyEventPlanStep(keyCode: 54, keyDown: false, flags: [], pauseAfter: true), // Right Command
            KeyEventPlanStep(keyCode: 55, keyDown: true, flags: .maskCommand, pauseAfter: true), // Command
            KeyEventPlanStep(keyCode: 9, keyDown: true, flags: .maskCommand, pauseAfter: true), // V
            KeyEventPlanStep(keyCode: 9, keyDown: false, flags: .maskCommand, pauseAfter: true),
            KeyEventPlanStep(keyCode: 55, keyDown: false, flags: [], pauseAfter: false)
        ]
    }

    func pressCommandV() {
        pressCommandV(targetPid: nil)
    }

    func pressCommandV(targetPid: pid_t?) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        source.localEventsSuppressionInterval = 0

        // Trigger keys can leave right-side modifiers physically down while the
        // event tap consumes the shortcut. Publish clean key-up events before
        // Cmd+V so the target app receives only the intended paste shortcut.
        for step in Self.commandVPastePlan() {
            postKey(keyCode: step.keyCode, keyDown: step.keyDown, flags: step.flags, source: source, targetPid: targetPid)
            if step.pauseAfter {
                shortDelay()
            }
        }
    }

    func pressReturn() {
        pressKey(keyCode: 36, flags: [])
    }

    private func pressKey(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private func postKey(
        keyCode: CGKeyCode,
        keyDown: Bool,
        flags: CGEventFlags,
        source: CGEventSource,
        targetPid: pid_t? = nil
    ) {
        let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
        event?.flags = flags
        if let targetPid, targetPid > 0 {
            event?.postToPid(targetPid)
        } else {
            event?.post(tap: .cghidEventTap)
        }
    }

    private func shortDelay() {
        Thread.sleep(forTimeInterval: 0.025)
    }
}
#endif
