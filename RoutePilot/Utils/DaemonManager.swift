//
//  DaemonManager.swift
//  RoutePilot
//

import Foundation

/// 守护进程管理器
enum DaemonManager {

    static let daemonLabel = "com.tangda.RoutePilotDaemon"
    static let daemonBinaryName = "route-pilot-daemon"
    static let daemonBinaryPath = "/usr/local/bin/route-pilot-daemon"
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
            return (false, "找不到守护进程可执行文件，请重新安装应用")
        }

        // 2. 一次性执行：配置免密授权 + 复制守护进程（只需一次授权）
        let username = NSUserName()
        let sudoersContent = "\(username) ALL=(ALL) NOPASSWD: /sbin/route"
        let installScript = """
        mkdir -p /etc/sudoers.d && \
        echo '\(sudoersContent)' | tee /etc/sudoers.d/autoroute && \
        chmod 440 /etc/sudoers.d/autoroute && \
        mkdir -p /usr/local/bin && \
        cp '\(bundledDaemon.path)' '\(daemonBinaryPath)' && \
        chmod 755 '\(daemonBinaryPath)'
        """

        let installResult = runWithAdminPrivileges(installScript)
        guard installResult.success else {
            return (false, "安装失败: \(installResult.error ?? "未知错误")")
        }

        // 4. 生成 LaunchAgent plist
        let plistContent = generatePlist()
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        do {
            try FileManager.default.createDirectory(at: launchAgentsPath, withIntermediateDirectories: true)
            try plistContent.write(to: plistPath, atomically: true, encoding: .utf8)
        } catch {
            return (false, "创建 plist 文件失败: \(error.localizedDescription)")
        }

        // 5. 加载 LaunchAgent
        let loadTask = Process()
        loadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        loadTask.arguments = ["load", plistPath.path]

        do {
            try loadTask.run()
            loadTask.waitUntilExit()
            if loadTask.terminationStatus != 0 {
                return (false, "加载 LaunchAgent 失败")
            }
        } catch {
            return (false, "执行 launchctl 失败: \(error.localizedDescription)")
        }

        return (true, nil)
    }

    /// 卸载守护进程（同时清理免密授权配置）
    static func uninstall() -> (Bool, String?) {
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        // 一次性执行所有操作（需要管理员权限）
        let uninstallScript = """
        launchctl unload '\(plistPath.path)' 2>/dev/null || true && \
        rm -f '\(plistPath.path)' '\(daemonBinaryPath)' /etc/sudoers.d/autoroute
        """

        let result = runWithAdminPrivileges(uninstallScript)

        if !result.success {
            return (false, "卸载失败: \(result.error ?? "未知错误")")
        }

        return (true, nil)
    }

    /// 启动守护进程
    static func start() -> (Bool, String?) {
        let plistPath = launchAgentsPath.appendingPathComponent("\(daemonLabel).plist")

        guard FileManager.default.fileExists(atPath: plistPath.path) else {
            return (false, "LaunchAgent plist 不存在")
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
                let error = String(data: data, encoding: .utf8) ?? "未知错误"
                return (false, error)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}