import AppIntents
import Foundation

// MARK: - Siri 快捷指令注册服务

enum SiriService {
    /// 更新 Siri 快捷指令（在 App 启动后调用）
    static func updateShortcuts() {
        // App Intents 框架通过 SonnetShortcuts（AppShortcutsProvider）自动注册
        // 此处可做手动 donate 或日志
    }

    /// 检查是否支持 Siri（沙盒或模拟器可能不支持）
    static var isSiriAvailable: Bool {
        // 通过检查 AppIntents 框架可用性判断
        if #available(iOS 16.0, *) { return true }
        return false
    }
}
