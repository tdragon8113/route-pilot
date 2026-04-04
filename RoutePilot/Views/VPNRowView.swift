//
//  VPNRowView.swift
//  RoutePilot
//

import SwiftUI

/// VPN 列表行组件
struct VPNRowView: View {
    let config: VPNConfig
    let isSelected: Bool
    let isConnected: Bool
    let onTap: () -> Void
    @ObservedObject private var app = AppController.shared

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )

            HStack(spacing: 10) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusBackgroundColor)
                        .frame(width: 32, height: 32)

                    if config.enabled {
                        Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 14))
                            .foregroundColor(isConnected ? .green : .gray)
                    } else {
                        Image(systemName: "pause.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                    }
                }

                // VPN 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(config.enabled ? .primary : .secondary)

                    HStack(spacing: 4) {
                        if !config.enabled {
                            Text("已禁用")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(3)
                        } else if isConnected {
                            Text("已连接")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.15))
                                .cornerRadius(3)
                        }

                        if !config.routes.isEmpty {
                            Text("\(config.routes.count) 条路由")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // 隐藏按钮（固定宽度，避免切换时跳动）
                Button(action: { app.hideVPN(config.name) }) {
                    Image(systemName: "eye.slash")
                        .font(.caption2)
                        .foregroundColor(config.enabled ? .clear : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(config.enabled)
                .help(config.enabled ? "" : "隐藏此 VPN")

                // 启用开关
                Toggle("", isOn: Binding(
                    get: { config.enabled },
                    set: { newValue in
                        app.setVPNEnabled(config.name, enabled: newValue)
                    }
                ))
                .labelsHidden()
                .controlSize(.small)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button(action: { app.hideVPN(config.name) }) {
                Label("隐藏此 VPN", systemImage: "eye.slash")
            }
        }
    }

    // 辅助计算属性
    private var backgroundColor: Color {
        if isSelected {
            return config.enabled ? Color.blue.opacity(0.1) : Color.orange.opacity(0.08)
        }
        return config.enabled ? Color.gray.opacity(0.05) : Color.gray.opacity(0.08)
    }

    private var borderColor: Color {
        if isSelected {
            return config.enabled ? Color.blue.opacity(0.3) : Color.orange.opacity(0.25)
        }
        return config.enabled ? Color.gray.opacity(0.1) : Color.gray.opacity(0.15)
    }

    private var statusBackgroundColor: Color {
        if !config.enabled {
            return Color.orange.opacity(0.1)
        }
        return isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.1)
    }
}