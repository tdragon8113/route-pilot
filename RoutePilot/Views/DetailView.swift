//
//  DetailView.swift
//  RoutePilot
//

import SwiftUI

/// 详情视图：当前路由表和完整日志
struct DetailView: View {
    @Binding var showDetailView: Bool
    let vpnName: String
    let initialTab: Int
    @ObservedObject private var app = AppController.shared
    @State private var selectedTab: Int

    init(showDetailView: Binding<Bool>, vpnName: String, initialTab: Int = 0) {
        self._showDetailView = showDetailView
        self.vpnName = vpnName
        self.initialTab = initialTab
        self._selectedTab = State(initialValue: initialTab)
    }

    var vpnStatus: VPNStatus? {
        app.activeVPNs.first { $0.name == vpnName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: { showDetailView = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(vpnName)
                    .font(.headline)

                Spacer()
            }

            Divider()

            Picker("", selection: $selectedTab) {
                Text("当前路由").tag(0)
                Text("操作日志").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                routesView
            } else {
                logsView
            }

            Divider()

            Button("返回") {
                showDetailView = false
            }
        }
    }

    @ViewBuilder
    private var routesView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("接口: \(vpnStatus?.interface ?? "未连接")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("刷新") {
                    if let iface = vpnStatus?.interface {
                        app.fetchCurrentRoutes(interface: iface)
                    }
                }
                .controlSize(.small)
            }

            if app.isLoadingRoutes {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if app.currentRoutes.isEmpty {
                VStack {
                    Spacer()
                    Text("无路由")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(app.currentRoutes, id: \.self) { route in
                            HStack {
                                Image(systemName: "arrow.right.circle")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                Text(route)
                                    .font(.system(.caption, design: .monospaced))
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var logsView: some View {
        let vpnLogs = app.logs.filter { $0.vpnName == nil || $0.vpnName == vpnName }

        VStack(alignment: .leading, spacing: 4) {
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
    }
}