//
//  MenuBarView.swift
//  RoutePilot
//

import SwiftUI

/// 菜单栏主容器视图
struct MenuBarView: View {
    @ObservedObject private var app = AppController.shared
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var selectedVPN: String?
    @State private var newRoute = ""
    @State private var showDetailView: Bool = false
    @State private var detailInitialTab: Int = 0
    @State private var showSettings: Bool = false
    @State private var showTools: Bool = false

    /// 优先选择的 VPN：已启用且非隐藏的活跃 VPN，否则第一个非隐藏配置
    private var preferredVPNName: String {
        // 优先选择已启用且非隐藏的活跃 VPN
        if let activeVPN = app.activeVPNs.first(where: { vpn in
            app.vpnConfigs.contains { $0.name == vpn.name && $0.enabled && !$0.hidden }
        }) {
            return activeVPN.name
        }
        // 否则选择第一个非隐藏的配置
        return app.vpnConfigs.first(where: { !$0.hidden })?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showSettings {
                SettingsView(showSettings: $showSettings)
            } else if showTools {
                ToolsView(showTools: $showTools)
            } else if showDetailView {
                DetailView(
                    showDetailView: $showDetailView,
                    vpnName: selectedVPN ?? preferredVPNName,
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
        .id(localization.currentLanguage)
        .padding()
        .frame(width: 280)
        .frame(maxHeight: 500)
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
