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
                Text("共 \(vpnLogs.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("清除") {
                    app.clearLogs()
                }
                .controlSize(.small)
            }

            if vpnLogs.isEmpty {
                VStack {
                    Spacer()
                    Text("暂无日志")
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
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}