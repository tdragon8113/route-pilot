//
//  DetailView.swift
//  RoutePilot
//

import SwiftUI

/// 详情视图：当前路由表、操作日志
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
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Button(action: { showDetailView = false }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)

                Text(vpnName)
                    .font(.headline)

                Spacer()
            }

            Picker("", selection: $selectedTab) {
                Text("tab.current_routes".localized).tag(0)
                Text("tab.operation_logs".localized).tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                CurrentRoutesView(vpnStatus: vpnStatus)
            } else {
                OperationLogsView(vpnName: vpnName)
            }
        }
    }
}