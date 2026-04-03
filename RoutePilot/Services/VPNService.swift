//
//  VPNService.swift
//  RoutePilot
//

import Foundation
import Network
import SystemConfiguration

/// VPN 检测服务
actor VPNService {

    static let shared = VPNService()

    private var pathMonitor: NWPathMonitor?
    private var store: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var monitoringCallback: (@MainActor (String?) -> Void)?

    private init() {}

    /// 获取系统 VPN 列表
    func getSystemVPNs() async -> [String] {
        let output = await ShellRunner.shared.runWithOutput("/usr/sbin/scutil --nc list")
        var vpns: [String] = []

        let pattern = "\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return vpns }

        for line in output.split(separator: "\n") {
            let lineString = String(line)
            let range = NSRange(lineString.startIndex..., in: lineString)
            let matches = regex.matches(in: lineString, range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: lineString) {
                    let vpnName = String(lineString[nameRange])
                    if !vpnName.isEmpty && !vpns.contains(vpnName) {
                        vpns.append(vpnName)
                    }
                }
            }
        }

        return vpns
    }

    /// 获取已连接的 VPN 状态
    func getConnectedVPNs(customInterfaces: [String: String] = [:]) async -> [VPNStatus] {
        let output = await ShellRunner.shared.runWithOutput("/usr/sbin/scutil --nc list")
        var result: [VPNStatus] = []

        let namePattern = "\"([^\"]+)\""
        guard let nameRegex = try? NSRegularExpression(pattern: namePattern) else { return result }

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            guard lineStr.contains("(Connected)") else { continue }

            let nameRange = NSRange(lineStr.startIndex..., in: lineStr)
            let nameMatches = nameRegex.matches(in: lineStr, range: nameRange)

            guard let nameMatch = nameMatches.first,
                  let vpnNameRange = Range(nameMatch.range(at: 1), in: lineStr) else { continue }

            let vpnName = String(lineStr[vpnNameRange])
            NSLog("[VPNService] 发现已连接 VPN: \(vpnName)")

            var interface: String?

            // 优先使用自定义接口
            if let customIface = customInterfaces[vpnName], !customIface.isEmpty {
                if await isInterfaceUp(customIface) {
                    interface = customIface
                }
            }

            // 自动检测接口
            if interface == nil {
                interface = await getVPNInterface(vpnName: vpnName)
            }

            NSLog("[VPNService] VPN \(vpnName) 接口: \(interface ?? "nil")")

            if let iface = interface {
                result.append(VPNStatus(name: vpnName, connected: true, interface: iface))
            }
        }

        return result
    }

    /// 获取 VPN 接口名
    private func getVPNInterface(vpnName: String) async -> String? {
        let output = await ShellRunner.shared.runWithOutput("/usr/sbin/scutil --nc status \"\(vpnName)\"")

        for line in output.split(separator: "\n") {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            if lineStr.hasPrefix("InterfaceName :") {
                let parts = lineStr.split(separator: ":")
                if parts.count >= 2 {
                    return String(parts[1].trimmingCharacters(in: .whitespaces))
                }
            }
        }

        return nil
    }

    /// 检查接口是否 UP 和 RUNNING
    private func isInterfaceUp(_ interface: String) async -> Bool {
        let output = await ShellRunner.shared.runWithOutput("/sbin/ifconfig \(interface)")
        return output.contains("flags=") && output.contains("<UP,") && output.contains("RUNNING")
    }

    /// 获取当前路由表
    func getCurrentRoutes(interface: String) async -> [String] {
        let output = await ShellRunner.shared.runWithOutput("/usr/sbin/netstat -rn")
        var routes: [String] = []

        for line in output.split(separator: "\n") {
            let lineStr = String(line)
            if lineStr.contains(interface) {
                let parts = lineStr.split(separator: " ", omittingEmptySubsequences: true)
                if let destination = parts.first {
                    let destStr = String(destination)
                    if destStr != "default" && !destStr.hasPrefix("fe80") {
                        routes.append(destStr)
                    }
                }
            }
        }

        return routes
    }

    /// 启动 SCDynamicStore 监听
    func startMonitoring(callback: @escaping @MainActor (String?) -> Void) {
        self.monitoringCallback = callback

        var storeContext = SCDynamicStoreContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        store = SCDynamicStoreCreate(
            nil,
            "RoutePilot" as CFString,
            { store, changedKeys, info in
                guard let info = info else { return }
                let service = Unmanaged<VPNService>.fromOpaque(info).takeUnretainedValue()
                Task {
                    await service.handleStoreChange(changedKeys: changedKeys)
                }
            },
            &storeContext
        )

        guard let store = store else {
            NSLog("[VPNService] Failed to create SCDynamicStore")
            return
        }

        // 监听所有网络接口的 IPv4 配置变化
        let patterns = ["State:/Network/Interface/.*/IPv4"] as CFArray
        SCDynamicStoreSetNotificationKeys(store, nil, patterns)

        // 创建 RunLoop Source 并添加到 RunLoop
        runLoopSource = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
        }

        NSLog("[VPNService] SCDynamicStore 监控已启动")
    }

    /// 处理 SCDynamicStore 变化
    private func handleStoreChange(changedKeys: CFArray) async {
        guard let keys = changedKeys as? [String] else { return }

        for key in keys {
            // 提取接口名: State:/Network/Interface/ppp0/IPv4
            let parts = key.split(separator: "/")
            guard parts.count >= 4 else { continue }

            let interface = String(parts[3])

            // 过滤 VPN 接口
            if isVPNInterface(interface) {
                NSLog("[VPNService] VPN 接口变化: \(interface)")

                // 获取该接口对应的 VPN 名称
                if let vpnName = getVPNNameForInterface(interface) {
                    // 在 actor 上下文中先获取 callback
                    let callback = monitoringCallback
                    await MainActor.run {
                        callback?(vpnName)
                    }
                }
            }
        }
    }

    /// 判断是否为 VPN 接口
    private func isVPNInterface(_ interface: String) -> Bool {
        interface.hasPrefix("ppp") ||
        interface.hasPrefix("utun") ||
        interface.hasPrefix("ipsec")
    }

    /// 获取接口对应的 VPN 名称（Task 2 将实现）
    private func getVPNNameForInterface(_ interface: String) -> String? {
        // Will be implemented in Task 2
        return nil
    }

    /// 停止监听
    func stopMonitoring() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, CFRunLoopMode.defaultMode)
        runLoopSource = nil
        store = nil
        monitoringCallback = nil
        NSLog("[VPNService] SCDynamicStore 监控已停止")
    }
}