import Cocoa
import UserNotifications

class HotkeyManager {
    private let networkManager: NetworkManager
    private let configManager: ConfigManager
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    init(networkManager: NetworkManager, configManager: ConfigManager) {
        self.networkManager = networkManager
        self.configManager = configManager
    }
    
    func registerHotkeys() {
        unregisterHotkey()
        
        let keyCode = configManager.config.hotkeyKeyCode ?? 1
        let modifiers = NSEvent.ModifierFlags(rawValue: configManager.config.hotkeyModifiers ?? 4456448)
        
        // 静默检查辅助功能权限（绝不弹窗，用户可在设置中手动授权）
        if !AXIsProcessTrusted() {
            print("警告：未获得辅助功能权限，全局快捷键将无法生效。请在 系统设置 -> 隐私与安全性 -> 辅助功能 中启用 NetSwitch")
        }
        
        // 注册全局监控
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains(modifiers) && Int(event.keyCode) == keyCode {
                self?.handleHotKey()
            }
        }
        
        // 注册本地监控
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            if event.modifierFlags.contains(modifiers) && Int(event.keyCode) == keyCode {
                self?.handleHotKey()
                return nil
            }
            return event
        }
        
        print("快捷键已注册: \(modifiers) + \(keyCode)")
    }
    
    @objc func handleHotKey() {
        print("快捷键触发: 切换规则")
        guard !configManager.config.rules.isEmpty else {
            showNotification(title: "NetSwitch", message: "请先配置规则")
            return
        }
        
        configManager.switchToNextRule()
        if let currentRule = configManager.getCurrentRule() {
            networkManager.applyRule(currentRule)
            showNotification(title: "NetSwitch", message: "已切换到: \(currentRule.name)")
        }
    }
    
    private func showNotification(title: String, message: String) {
        guard Bundle.main.bundleIdentifier != nil else {
            print("系统通知（由于未打包无法弹出）- \(title): \(message)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知失败: \(error)")
            }
        }
    }
    
    func unregisterHotkey() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
