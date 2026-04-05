//
//  ToolsView.swift
//  RoutePilot
//

import SwiftUI

/// 工具页面
struct ToolsView: View {
    @Binding var showTools: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Button(action: { showTools = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text("工具")
                    .font(.headline)

                Spacer()
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PublicIPView()
                    RouteQueryView()
                    RouteTableView()
                    TracerouteView()
                    PingView()
                    DNSQueryView()
                    PortTestView()
                }
            }
            .frame(height: 650)
        }
    }
}