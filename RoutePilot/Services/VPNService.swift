//
//  VPNService.swift
//  RoutePilot
//

import Foundation
import Network

/// VPN 检测服务
actor VPNService {

    static let shared = VPNService()

    private var pathMonitor: NWPathMonitor?

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
}