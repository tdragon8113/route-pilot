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
    @State private var isSettingUp = false

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

    /// 一键启用后台服务：配置免密授权 + 安装守护进程
    private func setupBackgroundService() {
        isSettingUp = true
        daemonError = nil

        Task {
            // 步骤 1: 配置免密授权（如果未配置）
            if !app.passwordlessConfigured {
                let success = await RouteService.shared.configurePasswordless()
                if !success {
                    await MainActor.run {
                        daemonError = "免密授权配置失败"
                        isSettingUp = false
                    }
                    return
                }
                await MainActor.run {
                    app.passwordlessConfigured = true
                }
            }

            // 步骤 2: 安装守护进程
            let result = DaemonManager.install()
            await MainActor.run {
                isSettingUp = false
                if result.0 {
                    checkDaemonStatus()
                } else {
                    daemonError = result.1 ?? "安装失败"
                }
            }
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
                    // MARK: - 后台服务
                    SettingsSection(title: "后台服务", icon: "server.rack") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("VPN 连接时自动添加路由，退出应用后仍生效")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if !daemonInstalled {
                                // 未安装：显示一键启用按钮
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                        Text("点击下方按钮，自动完成配置")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Button(action: setupBackgroundService) {
                                        HStack {
                                            if isSettingUp {
                                                ProgressView()
                                                    .controlSize(.small)
                                                Text("配置中...")
                                            } else {
                                                Image(systemName: "power")
                                                Text("启用后台服务")
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)
                                    .disabled(isSettingUp)

                                    Text("将自动配置免密授权并安装守护进程")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.blue.opacity(0.08))
                                )
                            } else {
                                // 已安装：显示状态和控制按钮
                                HStack {
                                    HStack(spacing: 4) {
                                        Image(systemName: daemonRunning ? "checkmark.circle.fill" : "pause.circle.fill")
                                            .foregroundColor(daemonRunning ? .green : .orange)
                                        Text(daemonRunning ? "运行中" : "已停止")
                                            .font(.caption)
                                            .foregroundColor(daemonRunning ? .green : .orange)
                                    }

                                    Spacer()

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

                                if app.passwordlessConfigured {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                            .font(.caption2)
                                        Text("免密授权已配置")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            if let error = daemonError {
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
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
        .frame(width: 300, height: 400)
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