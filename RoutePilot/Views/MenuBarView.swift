//
//  MenuBarView.swift
//  RoutePilot
//

import SwiftUI

/// 菜单栏主容器视图
struct MenuBarView: View {
    @ObservedObject private var app = AppController.shared
    @State private var selectedVPN: String?
    @State private var newRoute = ""
    @State private var showDetailView: Bool = false
    @State private var detailInitialTab: Int = 0
    @State private var showSettings: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else if showDetailView {
                DetailView(
                    showDetailView: $showDetailView,
                    vpnName: selectedVPN ?? app.activeVPNs.first?.name ?? app.vpnConfigs.first?.name ?? "",
                    initialTab: detailInitialTab
                )
            } else {
                MainView(
                    selectedVPN: $selectedVPN,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab,
                    showSettings: $showSettings
                )
            }
        }
        .padding()
        .frame(width: 280)
        .frame(minHeight: 450)
        .onAppear {
            app.refreshSystemVPNs()
        }
    }
}