//
//  SettingsView.swift
//  RoutePilot
//

import SwiftUI

/// 设置视图
struct SettingsView: View {
    @Binding var showSettings: Bool
    @ObservedObject private var app = AppController.shared
    @State private var launchAtLogin = false
    @State private var daemonInstalled = false
    @State private var daemonRunning = false
    @State private var daemonError: String?

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            LoginServiceKit.addLoginItems()
        } else {
            LoginServiceKit.removeLoginItems()
        }
        launchAtLogin = LoginServiceKit.isExistLoginItems()
    }

    private func checkLaunchStatus() -> Bool {
        LoginServiceKit.isExistLoginItems()
    }

    private func checkDaemonStatus() {
        daemonInstalled = DaemonManager.isInstalled
        daemonRunning = DaemonManager.isRunning
    }

    private func installDaemon() {
        guard app.passwordlessConfigured else {
            daemonError = "请先配置免密授权"
            return
        }

        daemonError = nil
        let result = DaemonManager.install()
        if result.0 {
            checkDaemonStatus()
        } else {
            daemonError = result.1 ?? "安装失败"
        }
    }

    private func uninstallDaemon() {
        daemonError = nil
        let result = DaemonManager.uninstall()
        if result.0 {
            checkDaemonStatus()
        } else {
            daemonError = result.1 ?? "卸载失败"
        }
    }

    private func startDaemon() {
        daemonError = nil
        let result = DaemonManager.start()
        if result.0 {
            checkDaemonStatus()
        } else {
            daemonError = result.1 ?? "启动失败"
        }
    }

    private func stopDaemon() {
        daemonError = nil
        let result = DaemonManager.stop()
        if result.0 {
            checkDaemonStatus()
        } else {
            daemonError = result.1 ?? "停止失败"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: { showSettings = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // MARK: - 后台服务（放在最前面，最重要的设置）
                    SettingsSection(title: "后台服务", icon: "server.rack") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("守护进程")
                                        .font(.subheadline)
                                    Text("VPN 连接时自动添加路由，退出应用后仍生效")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if daemonInstalled {
                                    Image(systemName: daemonRunning ? "checkmark.circle.fill" : "pause.circle.fill")
                                        .foregroundColor(daemonRunning ? .green : .orange)
                                        .font(.caption)
                                }
                            }

                            // 未安装时显示醒目提示
                            if !daemonInstalled {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("自动路由功能需要安装守护进程")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }

                                    if !app.passwordlessConfigured {
                                        Text("请先在下方「权限设置」中配置免密授权")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Button("安装守护进程") {
                                            installDaemon()
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
                            } else {
                                // 已安装显示状态
                                HStack {
                                    Text(daemonRunning ? "运行中" : "已停止")
                                        .font(.caption)
                                        .foregroundColor(daemonRunning ? .green : .orange)
                                    Spacer()

                                    // 启动/停止按钮
                                    if daemonRunning {
                                        Button("停止") {
                                            stopDaemon()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    } else {
                                        Button("启动") {
                                            startDaemon()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }

                                    Button("卸载", role: .destructive) {
                                        uninstallDaemon()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }

                            if let error = daemonError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    // MARK: - 权限设置
                    SettingsSection(title: "权限设置", icon: "key.fill") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("免密授权")
                                    .font(.subheadline)
                                Text("无需密码执行路由命令")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if app.passwordlessConfigured {
                                Label("已配置", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            } else {
                                Button("配置") {
                                    app.configurePasswordless()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }

                    // MARK: - 应用设置
                    SettingsSection(title: "应用设置", icon: "gearshape.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("开机启动", isOn: Binding(
                                get: { launchAtLogin },
                                set: { toggleLaunchAtLogin($0) }
                            ))
                            .font(.subheadline)
                        }
                    }

                    // MARK: - VPN 管理
                    let hiddenVPNs = app.vpnConfigs.filter { $0.hidden }
                    if !hiddenVPNs.isEmpty {
                        SettingsSection(title: "隐藏的 VPN", icon: "eye.slash.fill") {
                            ForEach(hiddenVPNs) { config in
                                HStack {
                                    Text(config.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Button("显示") {
                                        app.showVPN(config.name)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }

                    // MARK: - 关于
                    SettingsSection(title: "关于", icon: "info.circle.fill") {
                        HStack {
                            Text("版本")
                                .font(.subheadline)
                            Spacer()
                            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Link(destination: URL(string: "https://github.com/tangda1999/RoutePilot")!) {
                            HStack {
                                Image(systemName: "link")
                                Text("GitHub")
                            }
                            .font(.subheadline)
                        }
                    }
                }
            }

            Divider()

            Button("关闭") {
                showSettings = false
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(width: 300, height: 450)
        .onAppear {
            launchAtLogin = checkLaunchStatus()
            checkDaemonStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin = checkLaunchStatus()
            checkDaemonStatus()
        }
    }
}

/// 设置分组组件
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }
}