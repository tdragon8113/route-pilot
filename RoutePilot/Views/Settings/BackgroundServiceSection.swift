//
//  BackgroundServiceSection.swift
//  RoutePilot
//

import SwiftUI

/// 后台服务设置组件
struct BackgroundServiceSection: View {
    @ObservedObject private var app = AppController.shared
    @State private var daemonInstalled = false
    @State private var daemonRunning = false
    @State private var daemonError: String?
    @State private var isSettingUp = false

    var body: some View {
        SettingsSection(title: "后台服务", icon: "server.rack") {
            VStack(alignment: .leading, spacing: 8) {
                Text("VPN 连接时自动添加路由，退出应用后仍生效")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !daemonInstalled {
                    installView
                } else {
                    statusView
                }

                if let error = daemonError {
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
        }
        .onAppear {
            checkDaemonStatus()
        }
    }

    @ViewBuilder
    private var installView: some View {
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
    }

    @ViewBuilder
    private var statusView: some View {
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

    private func checkDaemonStatus() {
        daemonInstalled = DaemonManager.isInstalled
        daemonRunning = DaemonManager.isRunning
    }

    private func setupBackgroundService() {
        isSettingUp = true
        daemonError = nil

        Task {
            let result = DaemonManager.install()
            await MainActor.run {
                isSettingUp = false
                if result.0 {
                    app.passwordlessConfigured = true
                    checkDaemonStatus()
                    app.showToast("后台服务已启用", type: .success)
                } else {
                    daemonError = result.1 ?? "安装失败"
                    app.showToast("启用失败", type: .error)
                }
            }
        }
    }

    private func uninstallDaemon() {
        daemonError = nil
        let result = DaemonManager.uninstall()
        if result.0 {
            checkDaemonStatus()
            app.passwordlessConfigured = false
            app.showToast("后台服务已卸载", type: .success)
        } else {
            daemonError = result.1 ?? "卸载失败"
            app.showToast("卸载失败", type: .error)
        }
    }

    private func startDaemon() {
        daemonError = nil
        let result = DaemonManager.start()
        if result.0 {
            checkDaemonStatus()
            app.showToast("后台服务已启动", type: .success)
        } else {
            daemonError = result.1 ?? "启动失败"
            app.showToast("启动失败", type: .error)
        }
    }

    private func stopDaemon() {
        daemonError = nil
        let result = DaemonManager.stop()
        if result.0 {
            checkDaemonStatus()
            app.showToast("后台服务已停止", type: .success)
        } else {
            daemonError = result.1 ?? "停止失败"
            app.showToast("停止失败", type: .error)
        }
    }
}