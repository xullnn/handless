import Foundation

public enum HotkeyInputEvent: Equatable, Sendable {
    case rightOptionDown
    case rightOptionUp
    case longShortcut
    case escape
    case externalSessionEnded
}

public enum HotkeyAction: Equatable, Sendable {
    case startPushToTalk
    case stopPushToTalk
    case startLongDraft
    case stopLongDraft
    case cancelActiveSession
    case consumeEvent
}

public enum HotkeyMode: Equatable, Sendable {
    case idle
    case pushToTalk
    case longDraft
}

public struct HotkeyStateMachine: Equatable, Sendable {
    public private(set) var mode: HotkeyMode
    public private(set) var isRightOptionDown: Bool

    public init(mode: HotkeyMode = .idle, isRightOptionDown: Bool = false) {
        self.mode = mode
        self.isRightOptionDown = isRightOptionDown
    }

    @discardableResult
    public mutating func send(_ event: HotkeyInputEvent) -> [HotkeyAction] {
        switch event {
        case .rightOptionDown:
            guard !isRightOptionDown else { return [.consumeEvent] }
            isRightOptionDown = true
            guard mode != .pushToTalk else { return [.consumeEvent] }
            mode = .pushToTalk
            return [.startPushToTalk, .consumeEvent]

        case .rightOptionUp:
            guard isRightOptionDown else { return [.consumeEvent] }
            isRightOptionDown = false
            switch mode {
            case .pushToTalk:
                mode = .idle
                return [.stopPushToTalk, .consumeEvent]
            case .longDraft, .idle:
                return [.consumeEvent]
            }

        case .longShortcut:
            switch mode {
            case .idle:
                mode = .longDraft
                return [.startLongDraft, .consumeEvent]
            case .longDraft:
                mode = .idle
                return [.stopLongDraft, .consumeEvent]
            case .pushToTalk:
                mode = .longDraft
                return [.startLongDraft, .consumeEvent]
            }

        case .escape:
            switch mode {
            case .idle:
                return []
            case .pushToTalk, .longDraft:
                mode = .idle
                isRightOptionDown = false
                return [.cancelActiveSession, .consumeEvent]
            }

        case .externalSessionEnded:
            mode = .idle
            isRightOptionDown = false
            return []
        }
    }
}
