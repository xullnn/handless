#if os(macOS)
import Foundation
import ApplicationServices
import LocalVoiceInputCore

final class HotkeyController {
    var onPushToTalkStart: (() -> Void)?
    var onPushToTalkStop: (() -> Void)?
    var onLongDraftStart: (() -> Void)?
    var onLongDraftStop: (() -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((String) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var interpreter = HotkeyEventInterpreter()
    private var appSessionActive = false

    func start() {
        guard PermissionManager.accessibilityTrusted else {
            PermissionManager.promptAccessibilityIfNeeded()
            onError?("辅助功能权限尚未生效。请在系统设置 → 隐私与安全性 → 辅助功能中启用 LocalVoiceInput，然后退出并重新打开 App。")
            return
        }
        guard PermissionManager.inputMonitoringTrusted else {
            PermissionManager.requestInputMonitoringIfNeeded()
            onError?("输入监控权限尚未生效。请在系统设置 → 隐私与安全性 → 输入监控中启用 LocalVoiceInput，然后退出并重新打开 App。")
            return
        }

        let mask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: HotkeyController.handleEvent,
            userInfo: refcon
        ) else {
            onError?("无法创建全局快捷键事件监听。请确认 LocalVoiceInput 已同时拥有辅助功能和输入监控权限；如果刚授权，请退出并重新打开 App。")
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        let wasPushToTalk = interpreter.mode == .pushToTalk
        resetSessionTracking()
        if wasPushToTalk { onPushToTalkStop?() }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
    }

    func noteSessionStarted(type: SessionType) {
        appSessionActive = true
        interpreter.noteSessionStarted(type: type)
    }

    func noteSessionEnded() {
        resetSessionTracking()
    }

    private static let handleEvent: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let controller = Unmanaged<HotkeyController>.fromOpaque(refcon).takeUnretainedValue()
        return controller.process(type: type, event: event)
    }

    private func process(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let physicalEvent = HotkeyPhysicalEvent(
            type: physicalEventType(from: type),
            keyCode: keyCode,
            flags: event.flags,
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )
        let interpretation = interpreter.handle(physicalEvent, appSessionActive: appSessionActive)
        perform(interpretation.actions)
        return interpretation.consumesEvent ? nil : Unmanaged.passUnretained(event)
    }

    private func physicalEventType(from type: CGEventType) -> HotkeyPhysicalEventType {
        switch type {
        case .flagsChanged:
            return .flagsChanged
        case .keyDown:
            return .keyDown
        default:
            return .other
        }
    }

    private func perform(_ actions: [HotkeyAction]) {
        for action in actions {
            switch action {
            case .startPushToTalk:
                onPushToTalkStart?()
            case .stopPushToTalk:
                onPushToTalkStop?()
            case .startLongDraft:
                onLongDraftStart?()
            case .stopLongDraft:
                onLongDraftStop?()
            case .cancelActiveSession:
                onCancel?()
            case .consumeEvent:
                break
            }
        }
    }

    private func resetSessionTracking() {
        interpreter.resetSessionTracking()
        appSessionActive = false
    }
}
#endif
