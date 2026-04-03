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
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                )
                .onTapGesture {
                    onTap()
                }

            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isConnected ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: isConnected ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 14))
                        .foregroundColor(isConnected ? .green : .gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(config.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(config.enabled ? .primary : .secondary)

                    HStack(spacing: 4) {
                        if !config.enabled {
                            Text("已禁用")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else if isConnected {
                            Text("已连接")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }

                        if !config.routes.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(config.routes.count) 条路由")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}