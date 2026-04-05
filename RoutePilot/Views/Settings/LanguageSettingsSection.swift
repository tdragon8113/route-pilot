//
//  LanguageSettingsSection.swift
//  RoutePilot
//

import SwiftUI

/// 语言设置组件
struct LanguageSettingsSection: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        SettingsSection(title: "settings.language".localized, icon: "globe") {
            HStack {
                Text("settings.language".localized)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $localization.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
            }
        }
    }
}