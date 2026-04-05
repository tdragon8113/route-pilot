//
//  Color+Theme.swift
//  RoutePilot
//

import SwiftUI

extension Color {
    /// 卡片背景色 - 深色模式下比纯黑稍亮
    static var cardBackground: Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                // 深色模式：使用稍亮的灰色
                return NSColor(white: 0.18, alpha: 1.0)
            } else {
                // 浅色模式：使用系统默认
                return .controlBackgroundColor
            }
        }))
    }
}