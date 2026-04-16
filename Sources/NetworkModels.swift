import Foundation

struct Rule: Codable, Identifiable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    
    // WiFi 设置
    var wifiEnabled: Bool
    var wifiNetworkSSID: String?  // 要连接的 WiFi 网络
    
    // 网卡设置
    var networkServices: [NetworkServiceConfig]
}

struct NetworkServiceConfig: Codable, Identifiable {
    let id: UUID
    var serviceName: String  // 如 "Wi-Fi", "Thunderbolt Ethernet", "USB 10/100/1000 LAN"
    var enabled: Bool
}

struct AppConfig: Codable {
    var rules: [Rule]
    var currentRuleIndex: Int
    var launchAtLogin: Bool
    
    // 快捷键配置
    var hotkeyKeyCode: Int?      // 默认 1 (S)
    var hotkeyModifiers: UInt?   // 默认 [.command, .option, .control]
    
    init() {
        // 默认规则为空，需要用户自行配置
        self.rules = []
        self.currentRuleIndex = 0
        self.launchAtLogin = false
        // 默认快捷键: Cmd + Opt + Ctrl + S
        self.hotkeyKeyCode = 1
        self.hotkeyModifiers = 4456448 // NSEvent.ModifierFlags([.command, .option, .control]).rawValue
    }
}

class ConfigManager: ObservableObject {
    @Published var config: AppConfig
    private let configFile: URL
    
    init() {
        self.configFile = Self.getConfigFileURL()
        self.config = AppConfig()
    }
    
    private static func getConfigFileURL() -> URL {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return FileManager.default.temporaryDirectory
        }
        let netSwitchDir = appSupport.appendingPathComponent("NetSwitch")
        
        // 创建目录
        try? FileManager.default.createDirectory(at: netSwitchDir, withIntermediateDirectories: true)
        
        return netSwitchDir.appendingPathComponent("config.json")
    }
    
    func loadConfig() {
        guard let data = try? Data(contentsOf: configFile) else {
            saveConfig()
            return
        }
        
        if var loadedConfig = try? JSONDecoder().decode(AppConfig.self, from: data) {
            // 校正 currentRuleIndex，防止删除规则后索引越界
            if loadedConfig.rules.isEmpty {
                loadedConfig.currentRuleIndex = 0
            } else if loadedConfig.currentRuleIndex >= loadedConfig.rules.count {
                loadedConfig.currentRuleIndex = 0
            }
            self.config = loadedConfig
        } else {
            saveConfig()
        }
    }
    
    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFile)
        }
    }
    
    func getCurrentRule() -> Rule? {
        if config.currentRuleIndex < config.rules.count {
            return config.rules[config.currentRuleIndex]
        }
        return nil
    }
    
    func getNextRuleName() -> String {
        guard !config.rules.isEmpty else { return "无规则" }
        let nextIndex = (config.currentRuleIndex + 1) % config.rules.count
        return config.rules[nextIndex].name
    }
    
    func switchToNextRule() {
        guard !config.rules.isEmpty else { return }
        config.currentRuleIndex = (config.currentRuleIndex + 1) % config.rules.count
        saveConfig()
    }
    
    func switchToRule(name: String) {
        if let index = config.rules.firstIndex(where: { $0.name == name }) {
            config.currentRuleIndex = index
            saveConfig()
        }
    }
    
    func switchToRule(id: UUID) {
        if let index = config.rules.firstIndex(where: { $0.id == id }) {
            config.currentRuleIndex = index
            saveConfig()
        }
    }
}
