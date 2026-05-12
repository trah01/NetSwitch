# NetSwitch - macOS 网络规则切换工具

一个简洁的 macOS 菜单栏应用，用于快速切换网络配置和优先级开关应用规则。
<img width="1392" height="1262" alt="image" src="https://github.com/user-attachments/assets/68d0ee3f-1fa0-4efc-a099-35b9fc12f122" />


## 功能

- 菜单栏常驻，一键切换网络规则
- 支持配置多个规则，每个规则包含：
  - WiFi 开关
  - 自动连接指定 WiFi 网络
  - 启用/禁用特定网卡（如以太网、USB 网卡等）
  - 打开/关闭指定应用（如 Clash），允许配置优先级
- 可选全局快捷键切换（默认关闭）
- 规则配置界面
- 简洁的 UI 设计

## 使用方法

1. 首次运行后，点击菜单栏的 NetSwitch 图标
2. 选择 "配置规则..." 添加和编辑规则
3. 为每个规则设置：
   - 规则名称
   - WiFi 开关状态
   - 要连接的 WiFi SSID（可选）
   - 各个网络服务的启用/禁用状态
   - 需要打开或关闭的应用动作，及优先级（可选）
4. 点击菜单栏图标即可快速切换规则
5. 如需全局快捷键，可在通用设置中启用并录制快捷键

## 技术栈

- Swift 5.7+
- Cocoa / SwiftUI
- NSEvent（全局快捷键）
- networksetup（网络控制）

## 权限说明

只有启用全局快捷键后，应用才会使用 NSEvent 全局监控来注册快捷键。首次使用时系统会提示需要辅助功能权限。请在：
`系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能`
中授权 NetSwitch。

## 注意事项

- 网络控制需要 system 权限，应用会通过 `networksetup` 命令行工具执行
- 某些网络操作可能需要管理员权限
- 配置文件保存在 `~/Library/Application Support/NetSwitch/config.json`
