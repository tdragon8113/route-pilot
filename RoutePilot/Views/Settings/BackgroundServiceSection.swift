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
        SettingsSection(title: "settings.background_service".localized, icon: "server.rack") {
            VStack(alignment: .leading, spacing: 8) {
                Text("settings.background_service_desc".localized)
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
                Text("service.setup_hint".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: setupBackgroundService) {
                HStack {
                    if isSettingUp {
                        ProgressView()
                            .controlSize(.small)
                        Text("service.enabling".localized)
                    } else {
                        Image(systemName: "power")
                        Text("service.enable".localized)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isSettingUp)

            Text("service.setup_desc".localized)
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
                Text(daemonRunning ? "service.running".localized : "service.stopped".localized)
                    .font(.caption)
                    .foregroundColor(daemonRunning ? .green : .orange)
            }

            Spacer()

            if daemonRunning {
                Button("service.stop".localized) {
                    stopDaemon()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("service.start".localized) {
                    startDaemon()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .id(daemonInstalled) // Force view rebuild
            }

            Button("service.uninstall".localized, role: .destructive) {
                uninstallDaemon()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .id("\(daemonInstalled)-\(daemonRunning)") // Force entire HStack rebuild on state change

        if app.passwordlessConfigured {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .font(.caption2)
                Text("service.passwordless_configured".localized)
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
                    app.showToast("service.enabled".localized, type: .success)
                } else {
                    daemonError = result.1 ?? "error.operation_failed".localized
                    app.showToast("toast.error".localized, type: .error)
                }
            }
        }
    }

    private func uninstallDaemon() {
        daemonError = nil

        Task {
            let result = DaemonManager.uninstall()
            await MainActor.run {
                if result.0 {
                    checkDaemonStatus()
                    app.passwordlessConfigured = false
                    app.showToast("service.disabled".localized, type: .success)
                } else {
                    daemonError = result.1 ?? "error.operation_failed".localized
                    app.showToast("toast.error".localized, type: .error)
                }
            }
        }
    }

    private func startDaemon() {
        daemonError = nil

        Task {
            let result = DaemonManager.start()
            await MainActor.run {
                if result.0 {
                    checkDaemonStatus()
                    app.showToast("service.running".localized, type: .success)
                } else {
                    daemonError = result.1 ?? "error.operation_failed".localized
                    app.showToast("toast.error".localized, type: .error)
                }
            }
        }
    }

    private func stopDaemon() {
        daemonError = nil

        Task {
            let result = DaemonManager.stop()
            await MainActor.run {
                if result.0 {
                    checkDaemonStatus()
                    app.showToast("service.stopped".localized, type: .success)
                } else {
                    daemonError = result.1 ?? "error.operation_failed".localized
                    app.showToast("toast.error".localized, type: .error)
                }
            }
        }
    }
}