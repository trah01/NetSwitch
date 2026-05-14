import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications
import UniformTypeIdentifiers

class ConfigWindowController: NSObject, NSWindowDelegate {
    static let shared = ConfigWindowController()
    private var window: NSWindow?
    private var configManager: ConfigManager?
    private var networkManager: NetworkManager?

    private override init() {
        super.init()
    }

    func show(configManager: ConfigManager, networkManager: NetworkManager) {
        self.configManager = configManager
        self.networkManager = networkManager
        
        // 激活应用并将其置于前台，确保窗口在点击时能正确显示在最上层
        NSApp.activate(ignoringOtherApps: true)
        
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ConfigView(configManager: configManager, networkManager: networkManager)
        let hostingView = NSHostingView(rootView: contentView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "NetSwitch 配置"
        newWindow.contentView = hostingView
        newWindow.minSize = NSSize(width: 500, height: 400)
        newWindow.delegate = self
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        // 防止窗口关闭时被释放，便于后续重新显示
        newWindow.isReleasedWhenClosed = false

        self.window = newWindow
    }

    // 拦截红绿灯关闭按钮：隐藏窗口而非关闭应用
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        // 仅在窗口真正关闭时才清理引用（一般不会走到这里）
        window = nil
        configManager = nil
        networkManager = nil
    }
}

struct ConfigView: View {
    @ObservedObject var configManager: ConfigManager
    let networkManager: NetworkManager
    @State private var selectedTab: String = "rules"
    @State private var selectedRuleIndex: Int = 0
    @State private var showSaveToast = false
    @State private var hideSaveToastWorkItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("规则配置")
                    .font(.headline)
                    .padding(.leading)

                Spacer()

                Button(action: {
                    addNewRule()
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)

                Button(action: {
                    deleteSelectedRule()
                }) {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(configManager.config.rules.count <= 1)
                .padding(.trailing)
            }
            .frame(height: 44)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                // 左侧侧边栏
                VStack(spacing: 0) {
                    List {
                        Section(header: Text("规则").font(.caption)) {
                            ForEach(configManager.config.rules.indices, id: \.self) { index in
                                HStack {
                                    if index == configManager.config.currentRuleIndex {
                                        Image(systemName: "circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.accentColor)
                                    }
                                    Text(configManager.config.rules[index].name)
                                        .padding(.vertical, 4)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .tag(index)
                                .onTapGesture {
                                    selectedTab = "rules"
                                    selectedRuleIndex = index
                                }
                                .listRowBackground(selectedTab == "rules" && selectedRuleIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                            }
                        }
                        
                        Section(header: Text("设置").font(.caption)) {
                            HStack {
                                Image(systemName: "gearshape")
                                Text("通用设置")
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTab = "general"
                            }
                            .listRowBackground(selectedTab == "general" ? Color.accentColor.opacity(0.2) : Color.clear)
                        }
                    }
                    .listStyle(.sidebar)
                }
                .frame(width: 180)

                Divider()

                // 右侧区域
                if selectedTab == "general" {
                    GeneralSettingsView(configManager: configManager)
                        .padding()
                } else if selectedRuleIndex < configManager.config.rules.count {
                    RuleEditView(
                        rule: $configManager.config.rules[selectedRuleIndex],
                        networkManager: networkManager
                    )
                    .padding()
                } else {
                    Text("请选择项目")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            Divider()

            // 底部按钮
            HStack {
                Spacer()

                Button("保存") {
                    configManager.saveConfig()
                    showSaveSuccessToast()
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("关闭") {
                    NSApp.keyWindow?.orderOut(nil)
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 500, minHeight: 400)
        .overlay(alignment: .top) {
            if showSaveToast {
                SaveToastView()
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            if !configManager.config.rules.isEmpty {
                // 初始化为当前规则
                selectedRuleIndex = configManager.config.currentRuleIndex
            }
        }
    }

    private func addNewRule() {
        let newRule = Rule(
            id: UUID(),
            name: "新规则 \(configManager.config.rules.count + 1)",
            isEnabled: false,
            wifiEnabled: true,
            wifiNetworkSSID: nil,
            networkServices: []
        )
        configManager.config.rules.append(newRule)
        selectedTab = "rules"
        selectedRuleIndex = configManager.config.rules.count - 1
    }

    private func showSaveSuccessToast() {
        hideSaveToastWorkItem?.cancel()

        withAnimation(.easeOut(duration: 0.15)) {
            showSaveToast = true
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeIn(duration: 0.2)) {
                showSaveToast = false
            }
        }
        hideSaveToastWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private func deleteSelectedRule() {
        guard configManager.config.rules.count > 1,
              selectedRuleIndex < configManager.config.rules.count else {
            return
        }
        
        // 如果删除的是当前规则，重置为第一个
        if selectedRuleIndex == configManager.config.currentRuleIndex {
            configManager.config.currentRuleIndex = 0
        } else if selectedRuleIndex < configManager.config.currentRuleIndex {
            configManager.config.currentRuleIndex -= 1
        }
        
        configManager.config.rules.remove(at: selectedRuleIndex)
        if selectedRuleIndex >= configManager.config.rules.count {
            selectedRuleIndex = max(0, configManager.config.rules.count - 1)
        }
        
        // 持久化删除操作
        configManager.saveConfig()
    }
}

struct SaveToastView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)

            Text("保存成功")
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 4)
    }
}

struct RuleEditView: View {
    @Binding var rule: Rule
    let networkManager: NetworkManager
    @State private var availableServices: [String] = []
    @State private var showError: String?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 规则名称
                VStack(alignment: .leading, spacing: 8) {
                    Text("规则名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("名称", text: $rule.name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                
                // WiFi 设置
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("启用 WiFi", isOn: $rule.wifiEnabled)
                    
                    if rule.wifiEnabled {
                        HStack {
                            Text("连接 WiFi:")
                            TextField("SSID (可选)", text: Binding(
                                get: { rule.wifiNetworkSSID ?? "" },
                                set: { rule.wifiNetworkSSID = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
                
                Divider()
                
                // 网络服务设置
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("网络服务")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            refreshNetworkServices()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("刷新网络列表")
                    }
                    
                    if availableServices.isEmpty {
                        Text("未找到网络服务，请点击刷新")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(availableServices, id: \.self) { serviceName in
                                NetworkServiceEditRow(config: networkServiceConfigBinding(for: serviceName))
                            }
                        }
                    }
                }

                Divider()

                // 应用控制
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("应用控制")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: {
                            addAppAction()
                        }) {
                            Label("添加", systemImage: "plus")
                        }
                        .buttonStyle(.borderless)
                    }

                    if rule.appActions.isEmpty {
                        Text("未配置应用动作")
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach($rule.appActions) { $appAction in
                                AppActionEditRow(
                                    action: $appAction,
                                    onDelete: {
                                        deleteAppAction(id: appAction.id)
                                    }
                                )
                            }
                        }
                    }
                }
                
                if let error = showError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            refreshNetworkServices()
        }
    }
    
    private func networkServiceConfigBinding(for serviceName: String) -> Binding<NetworkServiceConfig> {
        Binding(
            get: {
                if let config = rule.networkServices.first(where: { $0.serviceName == serviceName }) {
                    return config
                }
                return NetworkServiceConfig(
                    id: UUID(),
                    serviceName: serviceName,
                    enabled: true
                )
            },
            set: { newValue in
                if let index = rule.networkServices.firstIndex(where: { $0.serviceName == serviceName }) {
                    rule.networkServices[index] = newValue
                } else {
                    rule.networkServices.append(newValue)
                }
            }
        )
    }
    
    private func refreshNetworkServices() {
        availableServices = networkManager.getNetworkServices()
        showError = nil
        
        // 初始化未配置的服务
        for service in availableServices {
            if !rule.networkServices.contains(where: { $0.serviceName == service }) {
                rule.networkServices.append(NetworkServiceConfig(
                    id: UUID(),
                    serviceName: service,
                    enabled: true
                ))
            }
        }
        
        if availableServices.isEmpty {
            showError = "未检测到网络服务，请检查系统网络设置"
        }
    }

    private func addAppAction() {
        rule.appActions.append(AppActionConfig(
            id: UUID(),
            appName: "",
            bundleIdentifier: nil,
            appPath: nil,
            action: .open,
            priority: nextAppActionPriority()
        ))
    }

    private func deleteAppAction(id: UUID) {
        rule.appActions.removeAll { $0.id == id }
    }

    private func nextAppActionPriority() -> Int {
        (rule.appActions.map(\.priority).max() ?? 0) + 10
    }
}

struct NetworkServiceEditRow: View {
    @Binding var config: NetworkServiceConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(config.serviceName, isOn: $config.enabled)
                .font(.body)

            if config.enabled {
                HStack(spacing: 12) {
                    Picker("IP", selection: $config.ipMode) {
                        ForEach(NetworkIPMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    Picker("DNS", selection: $config.dnsMode) {
                        ForEach(NetworkDNSMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                if config.ipMode == .manual {
                    VStack(alignment: .leading, spacing: 8) {
                        fieldRow("IP 地址", placeholder: "192.168.1.100", text: optionalStringBinding(\.ipAddress))
                        fieldRow("子网掩码", placeholder: "255.255.255.0", text: optionalStringBinding(\.subnetMask))
                        fieldRow("路由器", placeholder: "192.168.1.1", text: optionalStringBinding(\.router))
                    }
                }

                if config.dnsMode == .manual {
                    HStack {
                        Text("DNS")
                            .foregroundColor(.secondary)
                            .frame(width: 64, alignment: .leading)
                        TextField("8.8.8.8, 1.1.1.1", text: optionalStringBinding(\.dnsServers))
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(8)
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<NetworkServiceConfig, String?>) -> Binding<String> {
        Binding(
            get: { config[keyPath: keyPath] ?? "" },
            set: { config[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func fieldRow(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 64, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct AppActionEditRow: View {
    @Binding var action: AppActionConfig
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Picker("", selection: actionTypeBinding) {
                    ForEach(AppActionType.allCases) { actionType in
                        Text(actionType.displayName).tag(actionType)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)

                TextField("应用名称，如 Clash", text: $action.appName)
                    .textFieldStyle(.roundedBorder)

                Button(action: selectApplication) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.borderless)
                .help("选择应用")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("删除")
            }

            HStack(spacing: 12) {
                Picker("阶段", selection: $action.stage) {
                    ForEach(AppActionStage.allCases) { stage in
                        Text(stage.displayName).tag(stage)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Stepper("优先级 \(action.priority)", value: $action.priority, in: 0...999, step: 10)
                    .frame(width: 160, alignment: .leading)

                Text("数值越小越先执行")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack {
                Text("Bundle ID")
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .leading)
                TextField("可选", text: optionalStringBinding(\.bundleIdentifier))
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("路径")
                    .foregroundColor(.secondary)
                    .frame(width: 72, alignment: .leading)
                TextField("可选，选择应用后自动填入", text: optionalStringBinding(\.appPath))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(10)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(8)
    }

    private var actionTypeBinding: Binding<AppActionType> {
        Binding(
            get: { action.action },
            set: { newValue in
                action.action = newValue
                action.stage = newValue.defaultStage
            }
        )
    }

    private func optionalStringBinding(_ keyPath: WritableKeyPath<AppActionConfig, String?>) -> Binding<String> {
        Binding(
            get: { action[keyPath: keyPath] ?? "" },
            set: { action[keyPath: keyPath] = $0.isEmpty ? nil : $0 }
        )
    }

    private func selectApplication() {
        let panel = NSOpenPanel()
        panel.title = "选择应用"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            let bundle = Bundle(url: url)
            action.appPath = url.path
            action.bundleIdentifier = bundle?.bundleIdentifier

            let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            action.appName = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var configManager: ConfigManager
    @State private var isRecordingHotkey = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("常规设置")
                .font(.title2)
                .bold()
            
            Form {
                Section {
                    Toggle("开机自启动", isOn: Binding(
                        get: { configManager.config.launchAtLogin },
                        set: { newValue in
                            configManager.config.launchAtLogin = newValue
                            toggleLaunchAtLogin(newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                }
                
                Divider()
                
                Section(header: Text("快捷键设置").font(.headline)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("启用全局快捷键", isOn: Binding(
                            get: { isHotkeyEnabled },
                            set: { newValue in
                                if newValue {
                                    configManager.config.hotkeyEnabled = true
                                    setDefaultHotkey()
                                } else {
                                    isRecordingHotkey = false
                                    configManager.config.hotkeyEnabled = false
                                    configManager.config.hotkeyKeyCode = nil
                                    configManager.config.hotkeyModifiers = nil
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        
                        if isHotkeyEnabled {
                            Text("点击下方按钮并输入快捷键来更改（用于循环切换规则）")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button(action: {
                                    isRecordingHotkey.toggle()
                                }) {
                                    HStack {
                                        Image(systemName: isRecordingHotkey ? "record.circle" : "keyboard")
                                        Text(isRecordingHotkey ? "请按键..." : hotkeyString)
                                    }
                                    .frame(minWidth: 120)
                                    .padding(8)
                                    .background(isRecordingHotkey ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                }
                                .buttonStyle(.plain)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isRecordingHotkey ? Color.red : Color.gray.opacity(0.5), lineWidth: 1)
                                )
                                
                                if !isRecordingHotkey {
                                    Button("设为默认") {
                                        setDefaultHotkey()
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }
                        } else {
                            Text("关闭后不会监听全局按键，也不需要辅助功能权限。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Spacer()
            
            if isHotkeyEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("关于全局快捷键")
                        .font(.headline)
                    Text("全局快捷键需要“辅助功能”权限才能生效。如果快捷键没反应，请在 [系统设置 -> 隐私与安全性 -> 辅助功能] 中确保 NetSwitch 已启用。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("打开辅助功能设置") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .background(
            KeyEventHandling(isRecording: $isRecordingHotkey) { keyCode, modifiers in
                configManager.config.hotkeyEnabled = true
                configManager.config.hotkeyKeyCode = Int(keyCode)
                configManager.config.hotkeyModifiers = modifiers.rawValue
                isRecordingHotkey = false
            }
        )
    }

    private var isHotkeyEnabled: Bool {
        configManager.config.hotkeyEnabled
    }

    private func setDefaultHotkey() {
        configManager.config.hotkeyEnabled = true
        configManager.config.hotkeyKeyCode = 1
        configManager.config.hotkeyModifiers = 4456448
    }
    
    private var hotkeyString: String {
        guard let keyCode = configManager.config.hotkeyKeyCode,
              let modifiersRaw = configManager.config.hotkeyModifiers else {
            return "无"
        }
        
        let modifiers = NSEvent.ModifierFlags(rawValue: modifiersRaw)
        var str = ""
        if modifiers.contains(.control) { str += "⌃" }
        if modifiers.contains(.option) { str += "⌥" }
        if modifiers.contains(.shift) { str += "⇧" }
        if modifiers.contains(.command) { str += "⌘" }
        
        // 简单映射常见 keycode
        let keyMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
            31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K",
            45: "N", 46: "M"
        ]
        
        str += keyMap[keyCode] ?? "Key(\(keyCode))"
        return str
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("设置自启动失败: \(error)")
                // 显示警告
                let alert = NSAlert()
                alert.messageText = "设置自启动失败"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        } else {
            let alert = NSAlert()
            alert.messageText = "自启动说明"
            alert.informativeText = "在 macOS 12 及以下版本中，请手动在 [系统偏好设置 -> 用户与群组 -> 登录项] 中添加本程序。"
            alert.runModal()
        }
    }
}

// 用于捕获按键的辅助视图
struct KeyEventHandling: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onKeyRecorded: (UInt16, NSEvent.ModifierFlags) -> Void
    
    class Coordinator: NSObject {
        var onKeyRecorded: (UInt16, NSEvent.ModifierFlags) -> Void
        
        init(onKeyRecorded: @escaping (UInt16, NSEvent.ModifierFlags) -> Void) {
            self.onKeyRecorded = onKeyRecorded
        }
    }
    
    class KeyEventView: NSView {
        var coordinator: Coordinator?
        var isRecording: Bool = false
        
        override var acceptsFirstResponder: Bool { true }
        
        override func keyDown(with event: NSEvent) {
            if isRecording {
                coordinator?.onKeyRecorded(event.keyCode, event.modifierFlags)
            } else {
                super.keyDown(with: event)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onKeyRecorded: onKeyRecorded)
    }
    
    func makeNSView(context: Context) -> KeyEventView {
        let view = KeyEventView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: KeyEventView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}
