//
//  QuickButton.swift
//  RoutePilot
//

import SwiftUI

/// 快捷选择按钮（用于接口过滤、端口快捷选择等）
struct QuickButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

/// Mini 尺寸快捷按钮
struct MiniQuickButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        if isSelected {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.mini)
        }
    }
}