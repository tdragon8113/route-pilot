//
//  MainView.swift
//  RoutePilot
//

import SwiftUI

/// 主视图：VPN 列表、路由配置、操作按钮、日志预览
struct MainView: View {
    @Binding var selectedVPN: String?
    @Binding var newRoute: String
    @Binding var showDetailView: Bool
    @Binding var detailInitialTab: Int
    @Binding var showSettings: Bool
    @Binding var showTools: Bool
    @ObservedObject private var app = AppController.shared
    @State private var isInstalling = false
    @State private var installError: String?
    @State private var showHiddenVPNs = false

    private var hiddenVPNs: [VPNConfig] {
        app.vpnConfigs.filter { $0.hidden }
    }

    /// 当前正在显示的 VPN 名称（用于日志按钮）
    private var currentVPNName: String? {
        if let vpnName = selectedVPN,
           app.vpnConfigs.contains(where: { $0.name == vpnName }) {
            return vpnName
        } else if let activeVPN = app.activeVPNs.first(where: { vpn in
            app.vpnConfigs.contains { $0.enabled && !$0.hidden && $0.name == vpn.name }
        }) {
            return activeVPN.name
        } else if let firstConfig = app.vpnConfigs.first(where: { !$0.hidden }) {
            return firstConfig.name
        }
        return nil
    }

    private func installBackgroundService() {
        isInstalling = true
        installError = nil

        Task {
            let result = DaemonManager.install()
            await MainActor.run {
                isInstalling = false
                if result.0 {
                    app.passwordlessConfigured = true
                    app.showToast("service.enabled".localized, type: .success)
                } else {
                    installError = result.1 ?? "status.install_failed".localized
                    app.showToast("toast.error".localized, type: .error)
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 后台服务未启用提示（直接一键启用）
            if !DaemonManager.isInstalled {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("service.not_enabled".localized)
                            .font(.caption)
                        if let error = installError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("service.not_enabled_desc".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("service.enable".localized) {
                            installBackgroundService()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
                Divider()
            }

            // VPN 列表
            Text("vpn.list".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            if app.systemVPNs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "vpn.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("vpn.not_detected".localized)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(app.vpnConfigs.filter { !$0.hidden }) { config in
                        VPNRowView(
                            config: config,
                            isSelected: selectedVPN == config.name,
                            isConnected: app.activeVPNs.contains { $0.name == config.name },
                            onTap: { selectedVPN = config.name }
                        )
                    }
                }
            }

            // 隐藏的 VPN（可折叠）
            if !hiddenVPNs.isEmpty {
                DisclosureGroup(isExpanded: $showHiddenVPNs) {
                    VStack(spacing: 6) {
                        ForEach(hiddenVPNs) { config in
                            HStack {
                                Text(config.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button("btn.show".localized) {
                                    app.showVPN(config.name)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.leading, 8)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.slash")
                            .font(.caption2)
                        Text("vpn.hidden".localized.localized(with: hiddenVPNs.count))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }

            Divider()

            // 选中 VPN 的路由配置
            if let vpnName = selectedVPN,
               app.vpnConfigs.contains(where: { $0.name == vpnName }) {
                VPNQuickConfigView(
                    vpnName: vpnName,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab,
                    selectedVPN: $selectedVPN
                )
                .id(vpnName)
            } else if let activeVPN = app.activeVPNs.first(where: { vpn in
                app.vpnConfigs.contains { $0.enabled && !$0.hidden && $0.name == vpn.name }
            }) {
                VPNQuickConfigView(
                    vpnName: activeVPN.name,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab,
                    selectedVPN: $selectedVPN
                )
                .id(activeVPN.name)
            } else if let firstConfig = app.vpnConfigs.first(where: { !$0.hidden }) {
                VPNQuickConfigView(
                    vpnName: firstConfig.name,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab,
                    selectedVPN: $selectedVPN
                )
                .id(firstConfig.name)
            }

            if app.isProcessing || app.isConfiguring {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text(app.isConfiguring ? "status.configuring".localized : "status.processing".localized)
                        .font(.caption)
                    Spacer()
                }
            }

            // 日志显示
            if !app.logs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("logs.title".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("logs.count".localized.localized(with: app.logs.count))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button("route.view_routes".localized) {
                            // 设置为当前正在显示的 VPN
                            if let vpnName = currentVPNName {
                                selectedVPN = vpnName
                            }
                            detailInitialTab = 1
                            showDetailView = true
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }

                    ForEach(app.logs.prefix(3)) { log in
                        HStack(spacing: 4) {
                            Image(systemName: log.level.icon)
                                .foregroundColor(log.level.color)
                                .font(.caption2)
                            Text(log.timeString)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(log.message)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.borderless)
                .help("settings.title".localized)

                Button(action: { showTools = true }) {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .buttonStyle(.borderless)
                .help("tools.title".localized)

                Spacer()

                Button("btn.exit".localized) {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}