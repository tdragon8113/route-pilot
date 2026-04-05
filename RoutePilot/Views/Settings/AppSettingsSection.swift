//
//  AppSettingsSection.swift
//  RoutePilot
//

import SwiftUI

/// 应用设置组件
struct AppSettingsSection: View {
    @State private var launchAtLogin = false

    var body: some View {
        SettingsSection(title: "应用设置", icon: "gearshape.fill") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("开机启动", isOn: Binding(
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