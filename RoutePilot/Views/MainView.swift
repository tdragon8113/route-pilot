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

    private func installBackgroundService() {
        isInstalling = true
        installError = nil

        Task {
            let result = DaemonManager.install()
            await MainActor.run {
                isInstalling = false
                if result.0 {
                    app.passwordlessConfigured = true
                    app.showToast("后台服务已启用", type: .success)
                } else {
                    installError = result.1 ?? "安装失败"
                    app.showToast("启用失败", type: .error)
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
                        Text("后台服务未启用")
                            .font(.caption)
                        if let error = installError {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("VPN 连接时无法自动添加路由")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("启用") {
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
            Text("VPN 列表")
                .font(.caption)
                .foregroundColor(.secondary)

            if app.systemVPNs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "vpn.slash")
                        .font(.system(size: 24))
                        .foregroundColor(.gray)
                    Text("未检测到 VPN")
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
                                Button("显示") {
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
                        Text("已隐藏 (\(hiddenVPNs.count))")
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
                    detailInitialTab: $detailInitialTab
                )
                .id(vpnName)
            } else if let activeVPN = app.activeVPNs.first(where: { vpn in
                app.vpnConfigs.contains { $0.enabled && !$0.hidden && $0.name == vpn.name }
            }) {
                VPNQuickConfigView(
                    vpnName: activeVPN.name,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab
                )
                .id(activeVPN.name)
            } else if let firstConfig = app.vpnConfigs.first(where: { !$0.hidden }) {
                VPNQuickConfigView(
                    vpnName: firstConfig.name,
                    newRoute: $newRoute,
                    showDetailView: $showDetailView,
                    detailInitialTab: $detailInitialTab
                )
                .id(firstConfig.name)
            }

            if app.isProcessing || app.isConfiguring {
                HStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text(app.isConfiguring ? "配置中..." : "处理中...")
                        .font(.caption)
                    Spacer()
                }
            }

            // 日志显示
            if !app.logs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("操作日志")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(app.logs.count) 条")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button("查看") {
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
                .help("设置")

                Button(action: { showTools = true }) {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .buttonStyle(.borderless)
                .help("工具")

                Spacer()

                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}