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
    @ObservedObject private var app = AppController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 守护进程未安装提示（优先级最高）
            if !DaemonManager.isInstalled && app.passwordlessConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动路由未启用")
                            .font(.caption)
                        Text("请安装守护进程")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("安装") {
                        showSettings = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.1))
                )
                Divider()
            }
            // 免密状态提示
            else if !app.passwordlessConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("建议配置免密授权")
                        .font(.caption)
                    Spacer()
                    Button("配置") {
                        app.configurePasswordless()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                Divider()
            }

            // VPN 列表
            HStack {
                Text("VPN 列表")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(app.vpnConfigs.filter { $0.enabled && !$0.hidden }.count) 个")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

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

            Divider()

            // 选中 VPN 的路由配置
            if let vpnName = selectedVPN {
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
            } else if let firstConfig = app.vpnConfigs.first(where: { $0.enabled && !$0.hidden }) {
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

                Spacer()

                Button("退出") {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}