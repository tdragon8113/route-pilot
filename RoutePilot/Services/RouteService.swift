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

    /// 添加路由
    func addRoutes(routes: [RouteItem], interface: String) async -> (success: Bool, error: String?) {
        guard !routes.isEmpty else {
            return (true, nil)
        }

        let passwordless = isPasswordlessConfigured

        if passwordless {
            var allCommands: [String] = []
            for route in routes {
                allCommands.append("sudo /sbin/route add \(route.destination) -interface \(interface) 2>&1 || echo \"FAILED: \(route.destination)\"")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            let output = await ShellRunner.shared.runWithOutput(combinedCommand)

            let success = !output.contains("FAILED")
            return (success, success ? nil : output)
        } else {
            var allCommands: [String] = []
            for route in routes {
                allCommands.append("/sbin/route add \(route.destination) -interface \(interface)")
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

        let passwordless = isPasswordlessConfigured

        if passwordless {
            var allCommands: [String] = []
            for route in routes {
                allCommands.append("sudo /sbin/route delete \(route.destination) -interface \(interface) 2>/dev/null || true")
            }
            let combinedCommand = allCommands.joined(separator: " && ")
            return await ShellRunner.shared.run(combinedCommand)
        } else {
            var allCommands: [String] = []
            for route in routes {
                allCommands.append("/sbin/route delete \(route.destination) -interface \(interface) 2>/dev/null || true")
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