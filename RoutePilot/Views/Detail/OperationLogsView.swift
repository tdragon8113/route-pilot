//
//  OperationLogsView.swift
//  RoutePilot
//

import SwiftUI

/// 操作日志视图
struct OperationLogsView: View {
    let vpnName: String
    @ObservedObject private var app = AppController.shared

    private var vpnLogs: [LogEntry] {
        app.logs.filter { $0.vpnName == nil || $0.vpnName == vpnName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("logs.count".localized.localized(with: vpnLogs.count))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("logs.clear".localized) {
                    app.clearLogs()
                }
                .controlSize(.small)
            }

            if vpnLogs.isEmpty {
                VStack {
                    Spacer()
                    Text("logs.no_logs".localized)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(vpnLogs) { log in
                            HStack(spacing: 4) {
                                Image(systemName: log.level.icon)
                                    .foregroundColor(log.level.color)
                                    .font(.caption)
                                Text(log.timeString)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(width: 60, alignment: .leading)
                                Text(log.message)
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
    }
}