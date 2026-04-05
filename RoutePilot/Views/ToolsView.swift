//
//  ToolsView.swift
//  RoutePilot
//

import SwiftUI

/// 工具页面
struct ToolsView: View {
    @Binding var showTools: Bool

    var body: some View {
        ScrollView {
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

                // 公网 IP 查询
                PublicIPView()

                // 路由查询
                RouteQueryView()

                // 路由表查看
                RouteTableView()

                // 路由追踪
                TracerouteView()

                // Ping 测试
                PingView()

                // DNS 查询
                DNSQueryView()

                // 端口连通性测试
                PortTestView()

                Spacer()
            }
        }
    }
}