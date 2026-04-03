//
//  LogService.swift
//  RoutePilot
//

import Foundation

/// 日志服务
actor LogService {

    static let shared = LogService()

    private let logFile = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Logs/RoutePilot/operations.log")

    private init() {}

    /// 追加日志到文件
    func append(_ entry: LogEntry) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timeString = formatter.string(from: entry.time)

        let vpnPart = entry.vpnName != nil ? "[\(entry.vpnName!)] " : ""
        let logLine = "\(timeString) [\(entry.level.rawValue)] \(vpnPart)\(entry.message)\n"

        // 确保目录存在
        let logDir = logFile.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: logDir.path) {
            try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        }

        // 写入文件
        guard let data = logLine.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: logFile)
        }
    }

    /// 从文件加载日志
    func loadLogs() -> [LogEntry] {
        guard FileManager.default.fileExists(atPath: logFile.path),
              let data = try? Data(contentsOf: logFile),
              let content = String(data: data, encoding: .utf8) else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var logs: [LogEntry] = []
        for line in content.split(separator: "\n").reversed() {
            let lineStr = String(line)
            guard lineStr.count >= 19,
                  let date = formatter.date(from: String(lineStr.prefix(19))) else { continue }

            let remainder = String(lineStr.dropFirst(20))

            // 解析格式: 2026-04-03 11:30:00 [LEVEL] [VPN名] 消息
            var level: LogEntry.LogLevel = .info
            var vpnName: String? = nil
            var message = remainder

            // 提取日志级别
            if remainder.hasPrefix("[") {
                if let levelEnd = remainder.firstIndex(of: "]") {
                    let levelStr = String(remainder[remainder.index(after: remainder.startIndex)..<levelEnd])
                    level = LogEntry.LogLevel(rawValue: levelStr) ?? .info
                    message = String(remainder[remainder.index(after: levelEnd)...]).trimmingCharacters(in: .whitespaces)
                }
            }

            // 提取VPN名（如果有）
            if message.hasPrefix("[") {
                if let vpnEnd = message.firstIndex(of: "]") {
                    let potentialVPN = String(message[message.index(after: message.startIndex)..<vpnEnd])
                    if !potentialVPN.contains(" ") {
                        vpnName = potentialVPN
                        message = String(message[message.index(after: vpnEnd)...]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }

            logs.append(LogEntry(time: date, vpnName: vpnName, message: message, level: level))
        }

        return Array(logs.prefix(500))
    }

    /// 清除日志文件
    func clearLogs() {
        try? FileManager.default.removeItem(at: logFile)
    }
}