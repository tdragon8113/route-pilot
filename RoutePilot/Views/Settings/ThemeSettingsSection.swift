//
//  ThemeSettingsSection.swift
//  RoutePilot
//

import SwiftUI

/// 主题设置组件
struct ThemeSettingsSection: View {
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    var body: some View {
        SettingsSection(title: "settings.appearance".localized, icon: "paintbrush.fill") {
            HStack {
                Text("settings.theme".localized)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $appTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName)
                            .tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                .onChange(of: appTheme) { _, newTheme in
                    applyTheme(newTheme)
                }
            }
        }
    }

    private func applyTheme(_ theme: AppTheme) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}

/// 应用主题枚举
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "theme.light".localized
        case .dark: return "theme.dark".localized
        case .system: return "theme.system".localized
        }
    }
}