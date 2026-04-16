import Foundation

class NetworkManager {
    
    // 获取所有网络服务
    func getNetworkServices() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines)
                // 第一行是标题 ("An asterisk (*) denotes that a network service is disabled.")，跳过
                return lines.dropFirst().filter { !$0.isEmpty }.map { line in
                    if line.hasPrefix("*") {
                        return String(line.dropFirst())
                    }
                    return line
                }
            }
        } catch {
            print("获取网络服务失败: \(error)")
        }
        
        return []
    }
    
    // 启用/禁用网络服务
    func setNetworkServiceEnabled(_ serviceName: String, enabled: Bool) {
        // 首先检查服务是否存在
        let availableServices = getNetworkServices()
        guard availableServices.contains(serviceName) else {
            print("跳过不存在的网络服务: \(serviceName)")
            return
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-setnetworkserviceenabled", serviceName, enabled ? "on" : "off"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                print("设置 \(serviceName) 失败")
            } else {
                print("成功\(enabled ? "启用" : "禁用") \(serviceName)")
            }
        } catch {
            print("执行命令失败: \(error)")
        }
    }
    
    // 连接 WiFi
    func connectToWiFi(ssid: String) {
        // 首先获取 Wi-Fi 接口名称
        let wifiInterface = getWiFiInterface()
        
        guard let interface = wifiInterface else {
            print("未找到 Wi-Fi 接口")
            return
        }
        
        // 使用 networksetup 连接 WiFi
        let wifiTask = Process()
        wifiTask.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        wifiTask.arguments = ["-setairportnetwork", interface, ssid]
        
        let pipe = Pipe()
        wifiTask.standardError = pipe
        
        do {
            try wifiTask.run()
            wifiTask.waitUntilExit()
            
            if wifiTask.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                print("连接 WiFi \(ssid) 失败: \(errorOutput)")
            } else {
                print("成功连接 WiFi: \(ssid)")
            }
        } catch {
            print("执行命令失败: \(error)")
        }
    }
    
    // 获取 Wi-Fi 接口名称
    private func getWiFiInterface() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-listallhardwareports"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 解析输出找到 Wi-Fi 接口
                let lines = output.components(separatedBy: .newlines)
                for (index, line) in lines.enumerated() {
                    if line.contains("Wi-Fi") || line.contains("AirPort") {
                        // 下一行包含接口名称
                        if index + 1 < lines.count {
                            let nextLine = lines[index + 1]
                            if nextLine.contains("Device:") {
                                return nextLine.components(separatedBy: ": ").last?.trimmingCharacters(in: .whitespaces)
                            }
                        }
                    }
                }
            }
        } catch {
            print("获取 Wi-Fi 接口失败: \(error)")
        }
        
        return nil
    }
    
    // 开启/关闭 WiFi
    func setWiFiEnabled(_ enabled: Bool) {
        let wifiInterface = getWiFiInterface()
        guard let interface = wifiInterface else { return }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-setairportpower", interface, enabled ? "on" : "off"]
        
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            print("执行命令失败: \(error)")
        }
    }
    
    // 获取当前 WiFi SSID
    func getCurrentWiFiSSID() -> String? {
        let wifiInterface = getWiFiInterface()
        guard let interface = wifiInterface else { return nil }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        task.arguments = ["-getairportnetwork", interface]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // 输出格式: "Current Wi-Fi Network: xxx" 或 "You are not associated with an AirPort network."
                if output.contains("Current Wi-Fi Network:") {
                    return output.replacingOccurrences(of: "Current Wi-Fi Network: ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("获取当前 WiFi 失败: \(error)")
        }
        
        return nil
    }
    
    // 应用规则
    func applyRule(_ rule: Rule) {
        print("应用规则: \(rule.name)")
        
        // 设置 WiFi 开关
        setWiFiEnabled(rule.wifiEnabled)
        
        // 连接指定 WiFi
        if let ssid = rule.wifiNetworkSSID, rule.wifiEnabled {
            // 延迟一下再连接，确保 WiFi 已开启
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.connectToWiFi(ssid: ssid)
            }
        }
        
        // 设置各个网络服务的启用/禁用
        // 如果 WiFi 正在启用，延迟执行以等待硬件就绪
        let delay: Double = rule.wifiEnabled ? 0.5 : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            for serviceConfig in rule.networkServices {
                self.setNetworkServiceEnabled(serviceConfig.serviceName, enabled: serviceConfig.enabled)
            }
        }
    }
}
