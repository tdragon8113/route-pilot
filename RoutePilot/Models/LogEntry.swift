//
//  LogEntry.swift
//  RoutePilot
//

import Foundation
import SwiftUI

/// 日志条目模型
struct LogEntry: Identifiable {
    let id = UUID()
    let time: Date
    let vpnName: String?
    let message: String
    let level: LogLevel

    /// 日志级别
    enum LogLevel: String, Codable {
        case debug = "DEBUG"
        case info = "INFO"
        case success = "SUCCESS"
        case warning = "WARNING"
        case error = "ERROR"

        var icon: String {
            switch self {
            case .debug: return "ladybug"
            case .info: return "info.circle"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .debug: return .gray
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }
    }

    /// 格式化时间字符串
    var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: time)
    }
}