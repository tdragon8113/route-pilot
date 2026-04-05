//
//  AppSettingsSection.swift
//  RoutePilot
//

import SwiftUI

/// 应用设置组件
struct AppSettingsSection: View {
    @State private var launchAtLogin = false

    var body: some View {
        SettingsSection(title: "settings.app_settings".localized, icon: "gearshape.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("settings.launch_at_login".localized, isOn: Binding(
                    get: { launchAtLogin },
                    set: { toggleLaunchAtLogin($0) }
                ))
                .font(.subheadline)
            }
        }
        .onAppear {
            launchAtLogin = LoginServiceKit.isExistLoginItems()
        }
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            LoginServiceKit.addLoginItems()
        } else {
            LoginServiceKit.removeLoginItems()
        }
        launchAtLogin = LoginServiceKit.isExistLoginItems()
    }
}