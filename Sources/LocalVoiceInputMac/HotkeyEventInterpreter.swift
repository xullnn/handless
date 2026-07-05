#if os(macOS)
import Foundation
import ApplicationServices
import LocalVoiceInputCore

enum HotkeyPhysicalEventType: Equatable {
    case flagsChanged
    case keyDown
    case other
}

struct HotkeyPhysicalEvent: Equatable {
    var type: HotkeyPhysicalEventType
    var keyCode: Int64
    var flags: CGEventFlags
    var isRepeat: Bool

    init(type: HotkeyPhysicalEventType, keyCode: Int64, flags: CGEventFlags = [], isRepeat: Bool = false) {
        self.type = type
        self.keyCode = keyCode
        self.flags = flags
        self.isRepeat = isRepeat
    }
}

struct HotkeyEventInterpretation: Equatable {
    var actions: [HotkeyAction]
    var consumesEvent: Bool

    static let passThrough = HotkeyEventInterpretation(actions: [], consumesEvent: false)
}

struct HotkeyEventInterpreter {
    private(set) var stateMachine = HotkeyStateMachine()
    private(set) var isRightCommandDown = false

    var mode: HotkeyMode {
        stateMachine.mode
    }

    mutating func noteSessionStarted(type: SessionType) {
        if type == .longDraft {
            stateMachine = HotkeyStateMachine(mode: .longDraft, isRightOptionDown: stateMachine.isRightOptionDown)
        }
    }

    mutating func noteSessionEnded() {
        resetSessionTracking()
    }

    mutating func resetSessionTracking() {
        _ = stateMachine.send(.externalSessionEnded)
        isRightCommandDown = false
    }

    mutating func handle(_ event: HotkeyPhysicalEvent, appSessionActive: Bool) -> HotkeyEventInterpretation {
        if event.type == .flagsChanged, event.keyCode == 61 {
            let optionDown = event.flags.contains(.maskAlternate)
            return consume(stateMachine.send(optionDown ? .rightOptionDown : .rightOptionUp))
        }

        if event.type == .flagsChanged, event.keyCode == 54 {
            isRightCommandDown = event.flags.contains(.maskCommand)
            return .passThrough
        }

        guard event.type == .keyDown else { return .passThrough }

        if event.keyCode == 47 && isRightCommandDown && event.flags.contains(.maskCommand) {
            let actions = event.isRepeat ? [] : stateMachine.send(.longShortcut)
            return HotkeyEventInterpretation(actions: actions, consumesEvent: true)
        }

        if event.keyCode == 53 {
            guard !event.isRepeat else { return .passThrough }
            let actions = stateMachine.send(.escape)
            if !actions.isEmpty {
                return consume(actions)
            }
            if appSessionActive {
                return HotkeyEventInterpretation(actions: [.cancelActiveSession], consumesEvent: true)
            }
        }

        return .passThrough
    }

    private func consume(_ actions: [HotkeyAction]) -> HotkeyEventInterpretation {
        HotkeyEventInterpretation(actions: actions, consumesEvent: actions.contains(.consumeEvent))
    }
}
#endif
