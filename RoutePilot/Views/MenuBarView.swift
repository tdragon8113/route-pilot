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
    @State private var showTools: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else if showTools {
                ToolsView(showTools: $showTools)
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
                    showSettings: $showSettings,
                    showTools: $showTools
                )
            }
        }
        .padding()
        .frame(width: showTools ? 600 : 280)
        .frame(maxHeight: showTools ? 500 : nil)
        .overlay(alignment: .top) {
            if let toast = app.currentToast {
                ToastView(toast: toast, onDismiss: { app.clearToast() })
                    .padding(.top, 12)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.25)),
                        removal: .opacity.animation(.easeOut(duration: 0.25))
                    ))
            }
        }
        .onAppear {
            app.refreshSystemVPNs()
        }
    }
}
