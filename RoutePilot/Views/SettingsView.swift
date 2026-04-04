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

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            LoginServiceKit.addLoginItems()
        } else {
            LoginServiceKit.removeLoginItems()
        }
        // 刷新状态
        launchAtLogin = LoginServiceKit.isExistLoginItems()
    }

    private func checkLaunchStatus() -> Bool {
        LoginServiceKit.isExistLoginItems()
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
                        Toggle("开机启动", isOn: Binding(
                            get: { launchAtLogin },
                            set: { toggleLaunchAtLogin($0) }
                        ))
                        .font(.subheadline)
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
                            Text("1.0.0")
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // 返回应用时刷新状态
            launchAtLogin = checkLaunchStatus()
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