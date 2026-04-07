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

    /// 默认选中的 VPN
    private var defaultSelectedVPN: String? {
        // 优先选已连接且未隐藏的 VPN
        if let activeVPN = app.activeVPNs.first(where: { vpn in
            app.vpnConfigs.contains { $0.enabled && !$0.hidden && $0.name == vpn.name }
        }) {
            return activeVPN.name
        }
        // 其次选第一个未隐藏的配置
        return app.vpnConfigs.first(where: { !$0.hidden })?.name
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
        .id(localization.currentLanguage)
        .padding()
        .frame(width: 280)
        .fixedSize(horizontal: false, vertical: true)
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
            // 设置默认选中的 VPN
            if selectedVPN == nil {
                selectedVPN = defaultSelectedVPN
            }
        }
        .onChange(of: app.vpnConfigs.count) { _ in
            // VPN 配置数量变化时更新选中状态
            if selectedVPN == nil {
                selectedVPN = defaultSelectedVPN
            }
        }
        .onChange(of: app.activeVPNs.count) { _ in
            // VPN 连接数量变化时，优先选中已连接的 VPN
            if let activeVPN = defaultSelectedVPN, selectedVPN != activeVPN {
                // 如果当前选中的 VPN 未连接，自动切换到已连接的
                let wasConnected = app.activeVPNs.contains { $0.name == selectedVPN }
                if !wasConnected {
                    selectedVPN = activeVPN
                }
            }
        }
    }
}
