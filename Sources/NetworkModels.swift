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

    // 应用控制
    var appActions: [AppActionConfig]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case wifiEnabled
        case wifiNetworkSSID
        case networkServices
        case appActions
    }

    init(
        id: UUID,
        name: String,
        isEnabled: Bool,
        wifiEnabled: Bool,
        wifiNetworkSSID: String?,
        networkServices: [NetworkServiceConfig],
        appActions: [AppActionConfig] = []
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.wifiEnabled = wifiEnabled
        self.wifiNetworkSSID = wifiNetworkSSID
        self.networkServices = networkServices
        self.appActions = appActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        wifiEnabled = try container.decode(Bool.self, forKey: .wifiEnabled)
        wifiNetworkSSID = try container.decodeIfPresent(String.self, forKey: .wifiNetworkSSID)
        networkServices = try container.decode([NetworkServiceConfig].self, forKey: .networkServices)
        appActions = try container.decodeIfPresent([AppActionConfig].self, forKey: .appActions) ?? []
    }
}

struct NetworkServiceConfig: Codable, Identifiable {
    let id: UUID
    var serviceName: String  // 如 "Wi-Fi", "Thunderbolt Ethernet", "USB 10/100/1000 LAN"
    var enabled: Bool
}

enum AppActionType: String, Codable, CaseIterable, Identifiable {
    case open
    case quit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open:
            return "打开"
        case .quit:
            return "关闭"
        }
    }
}

struct AppActionConfig: Codable, Identifiable {
    let id: UUID
    var appName: String
    var bundleIdentifier: String?
    var appPath: String?
    var action: AppActionType
}

struct AppConfig: Codable {
    var rules: [Rule]
    var currentRuleIndex: Int
    var launchAtLogin: Bool
    
    // 快捷键配置；nil 表示关闭全局快捷键
    var hotkeyEnabled: Bool
    var hotkeyKeyCode: Int?
    var hotkeyModifiers: UInt?

    enum CodingKeys: String, CodingKey {
        case rules
        case currentRuleIndex
        case launchAtLogin
        case hotkeyEnabled
        case hotkeyKeyCode
        case hotkeyModifiers
    }
    
    init() {
        // 默认规则为空，需要用户自行配置
        self.rules = []
        self.currentRuleIndex = 0
        self.launchAtLogin = false
        self.hotkeyEnabled = false
        self.hotkeyKeyCode = nil
        self.hotkeyModifiers = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decode([Rule].self, forKey: .rules)
        currentRuleIndex = try container.decode(Int.self, forKey: .currentRuleIndex)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hotkeyEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotkeyEnabled) ?? false
        hotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .hotkeyKeyCode)
        hotkeyModifiers = try container.decodeIfPresent(UInt.self, forKey: .hotkeyModifiers)
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
