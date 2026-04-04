//
//  RouteService.swift
//  RoutePilot
//

import Foundation

/// 路由操作服务
actor RouteService {

    static let shared = RouteService()

    private init() {}

    /// 检查免密配置是否存在
    var isPasswordlessConfigured: Bool {
        FileManager.default.fileExists(atPath: "/etc/sudoers.d/autoroute")
    }

    /// 解析路由项获取实际的目标地址列表
    /// - Parameter routes: 路由项列表
    /// - Returns: 解析后的目标地址列表（域名已转换为 IP）
    private func resolveDestinations(routes: [RouteItem]) async -> [(destination: String, original: String)] {
        var results: [(String, String)] = []

        for route in routes {
            if route.type == .domain {
                // 域名类型需要解析
                let ips = await DNSService.shared.resolve(domain: route.destination)
                if ips.isEmpty {
                    // 解析失败，记录但跳过
                    results.append((route.destination, route.destination)) // 保留原值用于日志
                } else {
                    for ip in ips {
                        results.append((ip, route.destination))
                    }
                }
            } else {
                // CIDR 类型直接使用
                results.append((route.destination, route.destination))
            }
        }

        return results
    }

    /// 添加路由
    func addRoutes(routes: [RouteItem], interface: String) async -> (success: Bool, error: String?) {
        guard !routes.isEmpty else {
            return (true, nil)
        }

        // 解析域名获取 IP
        let resolvedRoutes = await resolveDestinations(routes: routes)
        let validRoutes = resolvedRoutes.filter { !$0.destination.contains("/") || $0.destination == $0.original }

        guard !validRoutes.isEmpty else {
            return (false, "所有域名解析失败")
        }

        let passwordless = isPasswordlessConfigured

        if passwordless {
            var allCommands: [String] = []
            for (destination, _) in validRoutes {
                // 对于解析出的 IP，需要添加 /32 作为单主机路由
                let routeDest = destination.contains("/") ? destination : "\(destination)/32"
                allCommands.append("sudo /sbin/route add \(routeDest) -interface \(interface) 2>&1 || echo \"FAILED: \(routeDest)\"")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            let output = await ShellRunner.shared.runWithOutput(combinedCommand)

            let success = !output.contains("FAILED")
            return (success, success ? nil : output)
        } else {
            var allCommands: [String] = []
            for (destination, _) in validRoutes {
                let routeDest = destination.contains("/") ? destination : "\(destination)/32"
                allCommands.append("/sbin/route add \(routeDest) -interface \(interface)")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            let script = "do shell script \"\(combinedCommand)\" with administrator privileges"
            let success = await ShellRunner.shared.runAppleScript(script)

            return (success, success ? nil : "授权被取消或执行失败")
        }
    }

    /// 删除路由
    func removeRoutes(routes: [RouteItem], interface: String) async -> Bool {
        guard !routes.isEmpty else {
            return true
        }

        // 解析域名获取 IP
        let resolvedRoutes = await resolveDestinations(routes: routes)

        let passwordless = isPasswordlessConfigured

        if passwordless {
            var allCommands: [String] = []
            for (destination, _) in resolvedRoutes {
                let routeDest = destination.contains("/") ? destination : "\(destination)/32"
                allCommands.append("sudo /sbin/route delete \(routeDest) -interface \(interface) 2>/dev/null || true")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            return await ShellRunner.shared.run(combinedCommand)
        } else {
            var allCommands: [String] = []
            for (destination, _) in resolvedRoutes {
                let routeDest = destination.contains("/") ? destination : "\(destination)/32"
                allCommands.append("/sbin/route delete \(routeDest) -interface \(interface) 2>/dev/null || true")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            let script = "do shell script \"\(combinedCommand)\" with administrator privileges"
            return await ShellRunner.shared.runAppleScript(script)
        }
    }

    /// 配置免密授权
    func configurePasswordless() async -> Bool {
        let username = NSUserName()
        let content = "\(username) ALL=(ALL) NOPASSWD: /sbin/route"
        let script = "do shell script \"mkdir -p /etc/sudoers.d && echo '\(content)' | sudo tee /etc/sudoers.d/autoroute && sudo chmod 440 /etc/sudoers.d/autoroute\" with administrator privileges"
        return await ShellRunner.shared.runAppleScript(script)
    }

    /// 移除免密授权
    func removePasswordless() async -> Bool {
        let script = "do shell script \"sudo rm -f /etc/sudoers.d/autoroute\" with administrator privileges"
        return await ShellRunner.shared.runAppleScript(script)
    }
}