import Cocoa
import SwiftUI
import Combine

@main
struct NetSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var networkManager = NetworkManager()
    var configManager = ConfigManager()
    var hotkeyManager: HotkeyManager?
    private var cancellables = Set<AnyCancellable>()
    private var lastHotkeyKeyCode: Int?
    private var lastHotkeyModifiers: UInt?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 检查是否已有实例在运行
        let runningApps = NSWorkspace.shared.runningApplications
        if let bundleID = Bundle.main.bundleIdentifier {
            let sameAppCount = runningApps.filter { app in
                app.bundleIdentifier == bundleID && app.processIdentifier != ProcessInfo.processInfo.processIdentifier
            }.count
            
            if sameAppCount > 0 {
                print("NetSwitch 已在运行中，退出当前实例")
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
                return
            }
        }
        
        // 隐藏 dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 创建菜单栏状态项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "NetSwitch")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.image?.isTemplate = true
        }

        // 4. 加载配置
        configManager.loadConfig()

        // 5. 初始化快捷键管理器
        hotkeyManager = HotkeyManager(networkManager: networkManager, configManager: configManager)

        // 6. 监听配置变化以实时更新菜单栏和快捷键
        configManager.$config
            .receive(on: RunLoop.main)
            .sink { [weak self] newConfig in
                self?.updateStatusItemIcon(config: newConfig)
                
                // 仅在快捷键配置真正发生变化时才重新注册
                if newConfig.hotkeyKeyCode != self?.lastHotkeyKeyCode || 
                   newConfig.hotkeyModifiers != self?.lastHotkeyModifiers {
                    self?.lastHotkeyKeyCode = newConfig.hotkeyKeyCode
                    self?.lastHotkeyModifiers = newConfig.hotkeyModifiers
                    self?.hotkeyManager?.registerHotkeys()
                }
            }
            .store(in: &cancellables)

        // 7. 初始注册快捷键
        hotkeyManager?.registerHotkeys()

        // 8. 初始更新图标
        updateStatusItemIcon()
    }
    
    @objc func statusItemClicked() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // 当前规则名称
        if let currentRule = configManager.getCurrentRule() {
            let statusLabel = NSMenuItem(title: "当前: \(currentRule.name)", action: nil, keyEquivalent: "")
            statusLabel.isEnabled = false
            menu.addItem(statusLabel)
            
            menu.addItem(NSMenuItem.separator())
            
            // 下一个规则快捷切换
            let switchItem = NSMenuItem(title: "切换到 \(configManager.getNextRuleName())", action: #selector(switchRule), keyEquivalent: "")
            switchItem.target = self
            menu.addItem(switchItem)
            
            menu.addItem(NSMenuItem.separator())
            
            // 所有规则列表
            for rule in configManager.config.rules {
                let item = NSMenuItem(title: rule.name, action: #selector(applyRule(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = rule.id.uuidString
                if rule.id == currentRule.id {
                    item.state = .on
                }
                menu.addItem(item)
            }
            
            menu.addItem(NSMenuItem.separator())
        } else {
            let statusLabel = NSMenuItem(title: "未配置规则", action: nil, keyEquivalent: "")
            statusLabel.isEnabled = false
            menu.addItem(statusLabel)
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // 配置
        let configItem = NSMenuItem(title: "配置规则...", action: #selector(openConfig), keyEquivalent: ",")
        configItem.target = self
        menu.addItem(configItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        // 直接弹回菜单
        statusItem.popUpMenu(menu)
    }
    
    @objc func switchRule() {
        guard configManager.getCurrentRule() != nil else { return }
        configManager.switchToNextRule()
        if let rule = configManager.getCurrentRule() {
            networkManager.applyRule(rule)
        }
        updateStatusItemIcon()
    }
    
    @objc func applyRule(_ sender: Any) {
        if let ruleIDString = (sender as? NSMenuItem)?.representedObject as? String,
           let ruleID = UUID(uuidString: ruleIDString),
           let rule = configManager.config.rules.first(where: { $0.id == ruleID }) {
            configManager.switchToRule(id: ruleID)
            networkManager.applyRule(rule)
            updateStatusItemIcon()
        }
    }
    
    @objc func openConfig() {
        ConfigWindowController.shared.show(configManager: configManager, networkManager: networkManager)
    }
    
    func updateStatusItemIcon(config: AppConfig? = nil) {
        guard let button = statusItem.button else { return }
        
        // 优先使用传入的最新配置，如果没有则使用 manager 当前的
        let currentConfig = config ?? configManager.config
        
        if currentConfig.currentRuleIndex < currentConfig.rules.count {
            let currentRule = currentConfig.rules[currentConfig.currentRuleIndex]
            let symbols = ["circle.fill", "circlebadge.2", "square.fill", "triangle.fill"]
            let symbolName = symbols[currentConfig.currentRuleIndex % symbols.count]
            
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: currentRule.name)
            button.image?.isTemplate = true
            button.title = currentRule.name
            button.imagePosition = .imageLeft
        } else {
            button.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "无规则")
            button.image?.isTemplate = true
            button.title = ""
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterHotkey()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
