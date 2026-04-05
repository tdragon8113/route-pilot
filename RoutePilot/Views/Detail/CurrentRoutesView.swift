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
                let interfaceText = vpnStatus?.interface ?? "logs.no_vpn".localized
                Text("route.interface".localized + ": \(interfaceText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("tools.refresh".localized) {
                    if let iface = vpnStatus?.interface {
                        app.fetchCurrentRoutes(interface: iface)
                    }
                }
                .controlSize(.small)
                .disabled(vpnStatus == nil)
            }

            if vpnStatus == nil {
                emptyState("logs.no_vpn".localized)
            } else if app.isLoadingRoutes {
                loadingState
            } else if app.currentRoutes.isEmpty {
                emptyState("route.no_routes".localized)
            } else {
                routesList
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
        .onAppear {
            if let iface = vpnStatus?.interface {
                app.fetchCurrentRoutes(interface: iface)
            }
        }
        .onChange(of: vpnStatus) {
            if let iface = vpnStatus?.interface {
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