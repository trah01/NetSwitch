# NetSwitch - macOS 网络规则切换工具

一个简洁的 macOS 菜单栏应用，用于快速切换网络配置规则。

## 功能

- 菜单栏常驻，一键切换网络规则
- 支持配置多个规则，每个规则包含：
  - WiFi 开关
  - 自动连接指定 WiFi 网络
  - 启用/禁用特定网卡（如以太网、USB 网卡等）
- 全局快捷键切换（默认 `Cmd+Option+Ctrl+S`）
- 规则配置界面
- 简洁的 UI 设计，无渐变蓝紫和 emoji

## 项目结构

```
switch/
├── Sources/
│   ├── NetSwitchApp.swift      # 主应用和菜单栏
│   ├── NetworkManager.swift    # 网络控制逻辑
│   ├── NetworkModels.swift     # 数据模型和配置管理
│   ├── HotkeyManager.swift     # 全局快捷键管理
│   └── ConfigWindow.swift      # 配置窗口 UI
├── Info.plist                   # 应用配置
├── Makefile                     # 构建脚本
├── Package.swift                # Swift Package 配置
└── README.md                    # 说明文档
```

## 构建

```bash
make build
```

构建产物位于 `build/NetSwitch.app`

## 运行

```bash
make run
```

或直接打开 `build/NetSwitch.app`

## 使用方法

1. 首次运行后，点击菜单栏的 NetSwitch 图标
2. 选择 "配置规则..." 添加和编辑规则
3. 为每个规则设置：
   - 规则名称
   - WiFi 开关状态
   - 要连接的 WiFi SSID（可选）
   - 各个网络服务的启用/禁用状态
4. 点击菜单栏图标即可快速切换规则
5. 使用快捷键 `Cmd+Option+Ctrl+S` 在全局范围内快速切换

## 配置示例

### 工作模式
- 启用 WiFi
- 连接公司 WiFi (SSID: Office-WiFi)
- 启用以太网
- 启用 Wi-Fi 网卡

### 家用模式
- 启用 WiFi
- 连接家中 WiFi (SSID: Home-WiFi)
- 禁用以太网
- 启用 Wi-Fi 网卡

## 技术栈

- Swift 5.7+
- Cocoa / SwiftUI
- NSEvent（全局快捷键）
- networksetup（网络控制）

## 权限说明

应用使用 NSEvent 全局监控来注册快捷键，首次使用时系统会提示需要辅助功能权限。请在：
`系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能`
中授权 NetSwitch。

## 注意事项

- 网络控制需要 system 权限，应用会通过 `networksetup` 命令行工具执行
- 某些网络操作可能需要管理员权限
- 配置文件保存在 `~/Library/Application Support/NetSwitch/config.json`

## 许可证

MIT
