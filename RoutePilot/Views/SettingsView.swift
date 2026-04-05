//
//  SettingsView.swift
//  RoutePilot
//

import SwiftUI

/// 设置视图
struct SettingsView: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Button(action: { showSettings = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text("设置")
                    .font(.headline)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                BackgroundServiceSection()
                ThemeSettingsSection()
                AppSettingsSection()
                AboutSection()
            }
        }
    }
}