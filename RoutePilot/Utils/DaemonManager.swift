//
//  DaemonManager.swift
//  RoutePilot
//

import Foundation

/// 守护进程管理器
enum DaemonManager {

    static let daemonLabel = "com.sunny.RoutePilotDaemon"
    static let daemonBinaryName = "route-pilot-daemon"

    /// 守护进程存放目录（用户目录，无需 sudo）
    static var daemonDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("RoutePilot")
    }

    static var daemonBinaryPath: String {
        daemonDirectory.appendingPathComponent(daemonBinaryName).path
    }

    static let launchAgentsPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        .appendingPathComponent("LaunchAgents")

    /// 检查守护进程是否已安装
    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: daemonBinaryPath) &&
        FileManager.default.fileExists(atPath: launchAgentsPath.appendingPathComponent("\(daemonLabel).plist").path)
    }

    /// 检查守护进程是否正在运行
    static var isRunning: Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["list", daemonLabel]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.contains(daemonLabel)
        } catch {
            return false
        }
    }

    /// 安装守护进程（同时配置免密授权）
    /// - Returns: (成功, 错误信息)
    static func install() -> (Bool, String?) {
        // 1. 获取应用内嵌的 daemon 可执行文件路径
        let bundledDaemon = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(daemonBinaryName)")

        guard FileManager.default.fileExists(atPath: bundledDaemon.path) else {
            return (false, String.localizedStatic("error.daemon_not_found"))
        }

        // 2. 配置免密授权（需要 sudo）
        let username = NSUserName()
        let sudoersContent = "\(username) ALL=(ALL) NOPASSWD: /sbin/route add, /sbin/route delete"
        let sudoersScript = "mkdir -p /etc/sudoers.d && echo '\(sudoersContent)' | tee /etc/sudoers.d/autoroute && chmod 440 /etc/sudoers.d/autoroute"

        let sudoersResult = runWithAdminPrivileges(sudoersScript)
        guard sudoersResult.success else {
            return (false, String.localizedFormat("error.install_failed", sudoersResult.error ?? String.localizedStatic("error.unknown")))
        }

        // 3. 复制守护进程到用户目录（无需 sudo）
        do {
            try FileManager.default.createDirectory(at: daemonDirectory, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: bundledDaemon, to: URL(fileURLWithPath: daemonBinaryPath))
            // 设置可执行权限
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: daemonBinaryPath)
        } catch {
            return (false, String.localizedFormat("error.daemon_copy_failed", error.localizedDescription))
        }

        // 4. 生成 LaunchAgent plist
        let plistContent = generatePlist()
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        do {
            try FileManager.default.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)
            try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
        } catch {
            return (false, String.localizedFormat("error.plist_failed", error.localizedDescription))
        }

        // 5. 加载 LaunchAgent
        let loadTask = Process()
        loadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        loadTask.arguments = ["load", plistPath.path]

        do {
            try loadTask.run()
            loadTask.waitUntilExit()
            if loadTask.terminationStatus != 0 {
                return (false, String.localizedStatic("error.launchagent_load_failed"))
            }
        } catch {
            return (false, String.localizedFormat("error.launchctl_failed", error.localizedDescription))
        }

        return (true, nil)
    }

    /// 卸载守护进程（同时清理免密授权配置）
    static func uninstall() -> (Bool, String?) {
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        // 1. 停止守护进程
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath.path]
        try? task.run()
        task.waitUntilExit()

        // 2. 删除用户目录文件（无需 sudo）
        try? FileManager.default.removeItem(at: plistPath)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: daemonBinaryPath))

        // 3. 清理免密授权（需要 sudo）
        let sudoersScript = "rm -f /etc/sudoers.d/autoroute"
        let result = runWithAdminPrivileges(sudoersScript)

        if !result.success {
            return (false, String.localizedFormat("error.uninstall_failed", result.error ?? String.localizedStatic("error.unknown")))
        }

        return (true, nil)
    }

    /// 启动守护进程
    static func start() -> (Bool, String?) {
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            return (false, String.localizedStatic("error.plist_not_exist"))
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", plistPath.path]

        do {
            try task.run()
            task.waitUntilExit()
            return (task.terminationStatus == 0, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    /// 停止守护进程
    static func stop() -> (Bool, String?) {
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", plistPath.path]

        do {
            try task.run()
            task.waitUntilExit()
            return (task.terminationStatus == 0, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - 私有方法

    private static func generatePlist() -> String {
        // 获取用户日志目录
        let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs/RoutePilot").path

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(daemonLabel)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(daemonBinaryPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PATH</key>
                <string>/usr/bin:/bin:/usr/sbin:/sbin</string>
            </dict>
            <key>StandardOutPath</key>
            <string>\(logDir)/daemon.log</string>
            <key>StandardErrorPath</key>
            <string>\(logDir)/daemon.err</string>
        </dict>
        </plist>
        """
    }

    private static func runWithAdminPrivileges(_ command: String) -> (success: Bool, error: String?) {
        let script = "do shell script \"\(command)\" with administrator privileges"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                return (true, nil)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let error = String(data: data, encoding: .utf8) ?? String.localizedStatic("error.unknown")
                return (false, error)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}