#if os(macOS)
import Foundation

struct MenuBarStatusPresentation: Equatable {
    let statusItemTitle: String
    let tooltip: String
    let menuStatusTitle: String

    static func make(for status: String) -> MenuBarStatusPresentation {
        switch status {
        case "🔴":
            return MenuBarStatusPresentation(
                statusItemTitle: "REC",
                tooltip: "LocalVoiceInput - 正在录音",
                menuStatusTitle: "状态：录音中"
            )
        case "⚠️":
            return MenuBarStatusPresentation(
                statusItemTitle: "LVI!",
                tooltip: "LocalVoiceInput - 需要处理",
                menuStatusTitle: "状态：需要处理"
            )
        default:
            return MenuBarStatusPresentation(
                statusItemTitle: "LVI",
                tooltip: "LocalVoiceInput - 点击打开菜单",
                menuStatusTitle: "状态：就绪"
            )
        }
    }
}
#endif
