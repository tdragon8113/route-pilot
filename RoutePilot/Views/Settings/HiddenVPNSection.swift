//
//  HiddenVPNSection.swift
//  RoutePilot
//

import SwiftUI

/// 隐藏的 VPN 管理组件
struct HiddenVPNSection: View {
    @ObservedObject private var app = AppController.shared

    private var hiddenVPNs: [VPNConfig] {
        app.vpnConfigs.filter { $0.hidden }
    }

    var body: some View {
        if !hiddenVPNs.isEmpty {
            SettingsSection(title: "隐藏的 VPN", icon: "eye.slash.fill") {
                ForEach(hiddenVPNs) { config in
                    HStack {
                        Text(config.name)
                            .font(.subheadline)
                        Spacer()
                        Button("显示") {
                            app.showVPN(config.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}