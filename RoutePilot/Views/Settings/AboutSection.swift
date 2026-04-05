//
//  AboutSection.swift
//  RoutePilot
//

import SwiftUI

/// 关于信息组件
struct AboutSection: View {
    var body: some View {
        SettingsSection(title: "关于", icon: "info.circle.fill") {
            HStack {
                Text("版本")
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