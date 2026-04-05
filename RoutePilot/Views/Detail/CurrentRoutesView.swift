//
//  CurrentRoutesView.swift
//  RoutePilot
//

import SwiftUI

/// 当前路由视图
struct CurrentRoutesView: View {
    let vpnStatus: VPNStatus?
    @ObservedObject private var app = AppController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("接口: \(vpnStatus?.interface ?? "未连接")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("刷新") {
                    if let iface = vpnStatus?.interface {
                        app.fetchCurrentRoutes(interface: iface)
                    }
                }
                .controlSize(.small)
                .disabled(vpnStatus == nil)
            }

            if vpnStatus == nil {
                emptyState("VPN 未连接")
            } else if app.isLoadingRoutes {
                loadingState
            } else if app.currentRoutes.isEmpty {
                emptyState("无路由")
            } else {
                routesList
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .onAppear {
            if let iface = vpnStatus?.interface {
                app.fetchCurrentRoutes(interface: iface)
            }
        }
        .onChange(of: vpnStatus) { newValue in
            if let iface = newValue?.interface {
                app.fetchCurrentRoutes(interface: iface)
            } else {
                app.currentRoutes = []
            }
        }
    }

    @ViewBuilder
    private var routesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(app.currentRoutes, id: \.self) { route in
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text(route)
                            .font(.system(.caption, design: .monospaced))
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }
}