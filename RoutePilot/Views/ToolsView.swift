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

            // 工具卡片 - 两列布局
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 16) {
                    PublicIPView()
                    RouteTableView()
                    PingView()
                    PortTestView()
                }

                VStack(spacing: 16) {
                    RouteQueryView()
                    TracerouteView()
                    DNSQueryView()
                }
            }
        }
    }
}