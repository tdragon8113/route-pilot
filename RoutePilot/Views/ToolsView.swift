//
//  ToolsView.swift
//  RoutePilot
//

import SwiftUI

/// 工具页面
struct ToolsView: View {
    @Binding var showTools: Bool

    var body: some View {
        GeometryReader { geometry in
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

                    // 自适应网格布局：每 320px 一列
                    toolsGrid(width: geometry.size.width)

                    Spacer()
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private func toolsGrid(width: CGFloat) -> some View {
        let columnCount = max(1, Int(width / 320))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)

        LazyVGrid(columns: columns, spacing: 16) {
            PublicIPView()
            RouteQueryView()
            RouteTableView()
            TracerouteView()
            PingView()
            DNSQueryView()
            PortTestView()
        }
    }
}