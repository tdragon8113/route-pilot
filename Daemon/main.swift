//
//  main.swift
//  RoutePilotDaemon
//

import Foundation
import SystemConfiguration

// MARK: - 配置模型

struct VPNConfig: Codable {
    let name: String
    let enabled: Bool
    var routes: [RouteItem]
}

struct RouteItem: Codable {
    let id: UUID
    let destination: String
    let type: RouteType
    let note: String?
    let enabled: Bool
}

enum RouteType: String, Codable {
    case cidr
    case domain
}

struct AppConfig: Codable {
    let vpnConfigs: [VPNConfig]
    let passwordlessConfigured: Bool
}

// MARK: - 日志

func log(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let logMessage = "[\(timestamp)] \(message)\n"

    let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Logs/RoutePilot")
    let logFile = logDir.appendingPathComponent("daemon.log")

    try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)

    if let handle = FileHandle(forWritingAtPath: logFile.path) {
        handle.seekToEndOfFile()
        handle.write(logMessage.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? logMessage.write(to: logFile, atomically: true, encoding: .utf8)
    }

    print(logMessage, terminator: "")
}

// MARK: - 配置读取

func loadConfig() -> AppConfig? {
    let configFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("RoutePilot/config.json")

    guard let data = try? Data(contentsOf: configFile),
          let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
        return nil
    }
    return config
}

// MARK: - VPN 检测

func isVPNInterface(_ interface: String) -> Bool {
    interface.hasPrefix("ppp") ||
    interface.hasPrefix("utun") ||
    interface.hasPrefix("ipsec")
}

func getVPNNameForInterface(_ interface: String, retryCount: Int = 3) -> String? {
    for attempt in 1...retryCount {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        task.arguments = ["--nc", "list"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            for line in output.split(separator: "\n") {
                let lineStr = String(line)
                guard lineStr.contains("(Connected)") else { continue }

                // 提取 VPN 名称
                let pattern = "\"([^\"]+)\""
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(lineStr.startIndex..., in: lineStr)
                let matches = regex.matches(in: lineStr, range: range)

                guard let nameMatch = matches.first,
                      let vpnNameRange = Range(nameMatch.range(at: 1), in: lineStr) else { continue }

                let vpnName = String(lineStr[vpnNameRange])

                // 检查接口是否匹配
                let statusTask = Process()
                statusTask.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
                statusTask.arguments = ["--nc", "status", vpnName]

                let statusPipe = Pipe()
                statusTask.standardOutput = statusPipe
                try? statusTask.run()
                statusTask.waitUntilExit()
                let statusData = statusPipe.fileHandleForReading.readDataToEndOfFile()
                let statusOutput = String(data: statusData, encoding: .utf8) ?? ""

                if statusOutput.contains("InterfaceName : \(interface)") {
                    return vpnName
                }
            }
        } catch {
            log("获取 VPN 名称失败 (尝试 \(attempt)/\(retryCount)): \(error)")
        }

        // 重试前等待
        if attempt < retryCount {
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    return nil
}

func getActiveVPNs(store: SCDynamicStore) -> [(name: String, interface: String)] {
    var result: [(String, String)] = []

    let key = "State:/Network/Interface" as CFString
    guard let interfaces = SCDynamicStoreCopyValue(store, key) as? [String: Any],
          let interfaceList = interfaces["Interfaces"] as? [String] else {
        return result
    }

    for interface in interfaceList {
        if isVPNInterface(interface) {
            let ipv4Key = "State:/Network/Interface/\(interface)/IPv4" as CFString
            if SCDynamicStoreCopyValue(store, ipv4Key) != nil {
                if let vpnName = getVPNNameForInterface(interface) {
                    result.append((vpnName, interface))
                }
            }
        }
    }

    return result
}

// MARK: - DNS 解析

func resolveDomain(_ domain: String) -> [String] {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", "host -t A \(domain) 2>/dev/null | grep 'has address' | awk '{print $4}'"]

    let pipe = Pipe()
    task.standardOutput = pipe

    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        var ips: [String] = []
        for line in output.split(separator: "\n") {
            let ip = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidIPv4(ip) {
                ips.append(ip)
            }
        }
        return ips
    } catch {
        return []
    }
}

func isValidIPv4(_ ip: String) -> Bool {
    let parts = ip.split(separator: ".")
    guard parts.count == 4 else { return false }
    for part in parts {
        guard let num = Int(part), num >= 0, num <= 255 else { return false }
    }
    return true
}

// MARK: - 路由操作

func addRoutes(routes: [RouteItem], interface: String) {
    log("添加路由到 \(interface)...")

    for route in routes where route.enabled {
        let destinations: [String]

        if route.type == .domain {
            let ips = resolveDomain(route.destination)
            if ips.isEmpty {
                log("域名解析失败: \(route.destination)")
                continue
            }
            destinations = ips.map { "\($0)/32" }
        } else {
            destinations = [route.destination]
        }

        for dest in destinations {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            task.arguments = ["/sbin/route", "add", dest, "-interface", interface]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            do {
                try task.run()
                task.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if task.terminationStatus == 0 {
                    log("成功: route add \(dest) -interface \(interface)")
                } else {
                    log("失败: route add \(dest) -interface \(interface) - \(output)")
                }
            } catch {
                log("执行错误: route add \(dest) -interface \(interface) - \(error)")
            }
        }
    }
}

// MARK: - 守护进程

class Daemon {
    var store: SCDynamicStore?
    var previousVPNs: Set<String> = []

    func run() {
        log("========================================")
        log("RoutePilotDaemon 启动")
        log("========================================")

        var context = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        store = SCDynamicStoreCreate(
            nil,
            "RoutePilotDaemon" as CFString,
            { store, changedKeys, info in
                guard let info = info else { return }
                let daemon = Unmanaged<Daemon>.fromOpaque(info).takeUnretainedValue()
                daemon.handleStoreChange()
            },
            &context
        )

        guard let store = store else {
            log("无法创建 SCDynamicStore")
            return
        }

        let patterns = ["State:/Network/Interface/.*/IPv4"] as CFArray
        SCDynamicStoreSetNotificationKeys(store, nil, patterns)

        let runLoopSource = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, CFRunLoopMode.defaultMode)

        // 首次检查
        handleStoreChange()

        log("开始监听 VPN 状态变化...")
        CFRunLoopRun()
    }

    func handleStoreChange() {
        guard let store = store else { return }

        let activeVPNs = getActiveVPNs(store: store)
        let currentNames = Set(activeVPNs.map { $0.name })

        // 检测新连接
        let newlyConnected = currentNames.subtracting(previousVPNs)
        for name in newlyConnected {
            if let vpn = activeVPNs.first(where: { $0.name == name }) {
                handleVPNConnected(name: name, interface: vpn.interface)
            }
        }

        // 检测断开
        let disconnected = previousVPNs.subtracting(currentNames)
        for name in disconnected {
            handleVPNDisconnected(name: name)
        }

        previousVPNs = currentNames
    }

    func handleVPNConnected(name: String, interface: String) {
        log("VPN 连接: \(name) (\(interface))")

        guard let config = loadConfig() else {
            log("无法读取配置文件")
            return
        }

        guard config.passwordlessConfigured else {
            log("免密授权未配置，跳过路由操作")
            return
        }

        guard let vpnConfig = config.vpnConfigs.first(where: { $0.name == name && $0.enabled }) else {
            log("VPN 未配置或已禁用: \(name)")
            return
        }

        let enabledRoutes = vpnConfig.routes.filter { $0.enabled }
        guard !enabledRoutes.isEmpty else {
            log("没有启用的路由规则")
            return
        }

        addRoutes(routes: enabledRoutes, interface: interface)
    }

    func handleVPNDisconnected(name: String) {
        log("VPN 断开: \(name)")
        // 路由会在 VPN 断开时自动清理，无需手动删除
    }
}

// 启动守护进程
let daemon = Daemon()
daemon.run()