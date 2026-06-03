//
//  VPNService.swift
//  RoutePilot
//

import Foundation
import SystemConfiguration

/// VPN 检测服务
actor VPNService {

    static let shared = VPNService()

    private var store: SCDynamicStore?
    private var runLoopSource: CFRunLoopSource?
    private var monitoringCallback: (@MainActor (String?) -> Void)?

    private init() {}

    /// 获取系统 VPN 列表（含 Tunnelblick / OpenVPN）
    func getSystemVPNs() async -> [String] {
        let output = await ShellRunner.shared.runWithOutput("/usr/sbin/scutil --nc list")
        var vpns = parseScutilVPNNames(from: output)

        for openVPNName in OpenVPNDetector.discoverOpenVPNProfiles() where !vpns.contains(openVPNName) {
            vpns.append(openVPNName)
        }

        return vpns
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

        // 创建 RunLoop Source 并添加到主线程 RunLoop
        runLoopSource = SCDynamicStoreCreateRunLoopSource(nil, store, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
        }

        NSLog("[VPNService] SCDynamicStore 监控已启动")
    }

    /// 处理 SCDynamicStore 变化
    private func handleStoreChange(changedKeys: CFArray) async {
        guard let keys = changedKeys as? [String] else { return }

        var vpnChanged = false
        var vpnName: String?

        for key in keys {
            // 提取接口名: State:/Network/Interface/ppp0/IPv4
            let parts = key.split(separator: "/")
            guard parts.count >= 4 else { continue }

            let interface = String(parts[3])

            // 过滤 VPN 接口
            if isVPNInterface(interface) {
                NSLog("[VPNService] VPN 接口变化: \(interface)")
                vpnChanged = true

                // 获取该接口对应的 VPN 名称
                if let name = getVPNNameForInterface(interface) {
                    vpnName = name
                }
            }
        }

        // 如果 VPN 接口有变化，触发回调
        if vpnChanged {
            let callback = monitoringCallback
            await MainActor.run {
                // 传递 nil 表示需要完整检查状态
                callback?(vpnName)
            }
        }
    }

    /// 从 SCDynamicStore 获取 VPN 状态
    func getVPNStatusFromStore() -> [VPNStatus] {
        var result: [VPNStatus] = []
        var seenNames = Set<String>()

        guard let store = store ?? SCDynamicStoreCreate(nil, "RoutePilot" as CFString, nil, nil) else {
            return result
        }

        // 获取所有接口
        let key = "State:/Network/Interface" as CFString
        guard let interfaces = SCDynamicStoreCopyValue(store, key) as? [String: Any] else {
            return appendOpenVPNStatuses(to: result, seenNames: &seenNames)
        }

        // 遍历接口
        if let interfaceList = interfaces["Interfaces"] as? [String] {
            for interface in interfaceList {
                if isVPNInterface(interface) {
                    // 检查接口是否有 IPv4 配置（表示已连接）
                    let ipv4Key = "State:/Network/Interface/\(interface)/IPv4" as CFString
                    if SCDynamicStoreCopyValue(store, ipv4Key) != nil {
                        // 获取 VPN 名称
                        if let vpnName = getVPNNameForInterface(interface) {
                            result.append(VPNStatus(name: vpnName, connected: true, interface: interface))
                            seenNames.insert(vpnName)
                            NSLog("[VPNService] 从 Store 获取 VPN: \(vpnName), 接口: \(interface)")
                        }
                    }
                }
            }
        }

        return appendOpenVPNStatuses(to: result, seenNames: &seenNames)
    }

    /// 判断是否为 VPN 接口
    private func isVPNInterface(_ interface: String) -> Bool {
        interface.hasPrefix("ppp") ||
        interface.hasPrefix("utun") ||
        interface.hasPrefix("ipsec")
    }

    /// 获取接口对应的 VPN 名称
    private func getVPNNameForInterface(_ interface: String) -> String? {
        if let systemName = systemVPNName(for: interface) {
            return systemName
        }

        let claimedInterfaces = OpenVPNDetector.systemConnectedVPNInterfaces()
        return OpenVPNDetector.resolveOpenVPNName(for: interface, excludingInterfaces: claimedInterfaces)
    }

    private func systemVPNName(for interface: String) -> String? {
        let output = ShellRunner.runWithOutputSync("/usr/sbin/scutil --nc list")

        for vpnName in parseScutilVPNNames(from: output) {
            let escapedName = vpnName.replacingOccurrences(of: "\"", with: "\\\"")
            let statusOutput = ShellRunner.runWithOutputSync("/usr/sbin/scutil --nc status \"\(escapedName)\"")
            guard statusOutput.localizedCaseInsensitiveContains("Connected") else { continue }

            if statusOutput.contains("InterfaceName : \(interface)") {
                return vpnName
            }
        }

        return nil
    }

    private func parseScutilVPNNames(from output: String) -> [String] {
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

    private func appendOpenVPNStatuses(to result: [VPNStatus], seenNames: inout Set<String>) -> [VPNStatus] {
        var merged = result
        let claimedInterfaces = OpenVPNDetector.systemConnectedVPNInterfaces()

        for connection in OpenVPNDetector.discoverActiveOpenVPNConnections(excludingInterfaces: claimedInterfaces) {
            guard let interface = connection.interface,
                  !seenNames.contains(connection.name) else { continue }

            merged.append(VPNStatus(name: connection.name, connected: true, interface: interface))
            seenNames.insert(connection.name)
            NSLog("[VPNService] 从 OpenVPN 获取 VPN: \(connection.name), 接口: \(interface)")
        }

        return merged
    }

    /// 停止监听
    func stopMonitoring() {
        guard let source = runLoopSource else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
        runLoopSource = nil
        store = nil
        monitoringCallback = nil
        NSLog("[VPNService] SCDynamicStore 监控已停止")
    }
}