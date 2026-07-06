#if os(macOS)
import Foundation
import AppKit

final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let appTitleItem = NSMenuItem(title: "LocalVoiceInput", action: nil, keyEquivalent: "")
    private let statusMenuItem = NSMenuItem(title: "状态：就绪", action: nil, keyEquivalent: "")

    var onStartMock: (() -> Void)?
    var onStop: (() -> Void)?
    var onCopyLast: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onPromptPermissions: (() -> Void)?
    var onOpenLogs: (() -> Void)?
    var onCopyDiagnostics: (() -> Void)?

    init() {
        setup()
    }

    func setStatus(_ text: String) {
        DispatchQueue.main.async {
            self.configureButton(for: text)
        }
    }

    private func setup() {
        configureButton(for: "🎙")
        let menu = NSMenu()
        appTitleItem.isEnabled = false
        statusMenuItem.isEnabled = false
        menu.addItem(appTitleItem)
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "开始一次模拟听写", action: #selector(startMock), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "停止/完成", action: #selector(stop), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "复制上一条结果", action: #selector(copyLast), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "清空历史", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "检查/申请权限", action: #selector(promptPermissions), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "打开日志文件夹", action: #selector(openLogs), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "复制诊断摘要", action: #selector(copyDiagnostics), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出 LocalVoiceInput", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items { item.target = self }
        statusItem.menu = menu
    }

    @objc private func startMock() { onStartMock?() }
    @objc private func stop() { onStop?() }
    @objc private func copyLast() { onCopyLast?() }
    @objc private func clearHistory() { onClearHistory?() }
    @objc private func promptPermissions() { onPromptPermissions?() }
    @objc private func openLogs() { onOpenLogs?() }
    @objc private func copyDiagnostics() { onCopyDiagnostics?() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    private func configureButton(for status: String) {
        guard let button = statusItem.button else { return }
        let presentation = MenuBarStatusPresentation.make(for: status)
        button.image = nil
        button.title = presentation.statusItemTitle
        button.toolTip = presentation.tooltip
        statusMenuItem.title = presentation.menuStatusTitle
    }
}
#endif
