//
//  ShellRunner.swift
//  RoutePilot
//

import Foundation

/// Shell 命令执行工具
actor ShellRunner {

    static let shared = ShellRunner()

    private init() {}

    /// 执行 Shell 命令，返回是否成功
    func run(_ command: String) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// 执行 Shell 命令，返回输出
    func runWithOutput(_ command: String) async -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "ERROR: \(error.localizedDescription)"
        }
    }

    /// 执行 AppleScript
    func runAppleScript(_ script: String) async -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}