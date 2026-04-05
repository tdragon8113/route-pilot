//
//  AboutSection.swift
//  RoutePilot
//

import SwiftUI

/// 关于信息组件
struct AboutSection: View {
    var body: some View {
        SettingsSection(title: "settings.about".localized, icon: "info.circle.fill") {
            HStack {
                Text("settings.version".localized)
                    .font(.subheadline)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Link(destination: URL(string: "https://github.com/tdragon8113/route-pilot")!) {
                HStack {
                    Image(systemName: "link")
                    Text("GitHub")
                }
                .font(.subheadline)
            }
        }
    }
}