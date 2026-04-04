//
//  ToastItem.swift
//  RoutePilot
//

import SwiftUI

/// Toast 提示项
struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let duration: Double

    enum ToastType {
        case info
        case success
        case warning
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var backgroundColor: Color {
            switch self {
            case .info: return Color(nsColor: .controlBackgroundColor)
            case .success: return Color(nsColor: .controlBackgroundColor)
            case .warning: return Color(nsColor: .controlBackgroundColor)
            case .error: return Color(nsColor: .controlBackgroundColor)
            }
        }
    }
}