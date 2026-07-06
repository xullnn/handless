import Foundation

#if os(macOS)
import AppKit
import LocalVoiceInputCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = AppConfig.loadFromDefaultLocation(commandLine: CommandLine.arguments)
        appController = AppController(config: config)
        appController?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appController?.stop()
    }
}

private func shouldLaunchAsMenuBarOnly(commandLine: [String]) -> Bool {
    commandLine.contains("--menu-bar-only")
}

private func installApplicationMenu() {
    let mainMenu = NSMenu()
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu(title: "LocalVoiceInput")

    let quitItem = NSMenuItem(title: "退出 LocalVoiceInput", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    quitItem.target = NSApplication.shared
    appMenu.addItem(quitItem)

    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)
    NSApplication.shared.mainMenu = mainMenu
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
if shouldLaunchAsMenuBarOnly(commandLine: CommandLine.arguments) {
    app.setActivationPolicy(.accessory)
} else {
    app.setActivationPolicy(.regular)
    installApplicationMenu()
}
app.run()

#else
print("LocalVoiceInputMac is a macOS-only menu-bar app. Run this target on macOS 13 or later.")
#endif
