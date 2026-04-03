//
//  VPNQuickConfigView.swift
//  RoutePilot
//

import SwiftUI

/// VPN 快速配置组件：接口设置、路由管理、操作按钮
struct VPNQuickConfigView: View {
    let vpnName: String
    @Binding var newRoute: String
    @Binding var showDetailView: Bool
    @Binding var detailInitialTab: Int
    @ObservedObject private var app = AppController.shared
    @State private var showInterfaceEditor: Bool = false
    @State private var editingInterface: String = ""

    var config: VPNConfig? {
        app.vpnConfigs.first { $0.name == vpnName }
    }

    var vpnStatus: VPNStatus? {
        app.activeVPNs.first { $0.name == vpnName }
    }

    var isActiveVPN: Bool {
        vpnStatus != nil
    }

    var currentInterface: String {
        vpnStatus?.interface ?? config?.customInterface ?? "自动检测"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(vpnName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if isActiveVPN {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("已连接")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                Spacer()

                if isActiveVPN {
                    Button("查看路由") {
                        if let iface = vpnStatus?.interface {
                            app.fetchCurrentRoutes(interface: iface)
                        }
                        detailInitialTab = 0
                        showDetailView = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }

                Toggle("", isOn: Binding(
                    get: { config?.enabled ?? true },
                    set: { newValue in
                        if let index = app.vpnConfigs.firstIndex(where: { $0.name == vpnName }) {
                            app.vpnConfigs[index].enabled = newValue
                            app.saveConfig()
                        }
                    }
                ))
                .labelsHidden()
                .controlSize(.small)
            }

            HStack {
                Text("接口:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if showInterfaceEditor {
                    TextField("如 ppp0 或 utun4", text: $editingInterface)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(width: 100)

                    Button("保存") {
                        app.setCustomInterface(editingInterface, for: vpnName)
                        showInterfaceEditor = false
                    }
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button("取消") {
                        showInterfaceEditor = false
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                } else {
                    Text(currentInterface)
                        .font(.caption)
                        .foregroundColor(config?.customInterface != nil ? .blue : .secondary)

                    Button(action: {
                        editingInterface = config?.customInterface ?? ""
                        showInterfaceEditor = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)

                    if config?.customInterface != nil {
                        Button("重置") {
                            app.setCustomInterface("", for: vpnName)
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .buttonStyle(.borderless)
                    }
                }
            }

            if let routes = config?.routes, !routes.isEmpty {
                ForEach(routes) { route in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { route.enabled },
                            set: { app.toggleRoute(route, in: vpnName, enabled: $0) }
                        ))
                        .labelsHidden()
                        .controlSize(.small)

                        Text(route.destination)
                            .font(.caption)

                        Spacer()

                        Button(action: { app.removeRoute(route, from: vpnName) }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack {
                TextField("添加路由 (如 10.0.0.0/8)", text: $newRoute)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)

                Button("添加") {
                    if !newRoute.isEmpty {
                        app.addRoute(newRoute, to: vpnName)
                        newRoute = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(newRoute.isEmpty)
            }

            if isActiveVPN {
                Divider()
                HStack {
                    Button(action: {
                        app.addRoutes(for: vpnName)
                    }) {
                        Label("添加路由", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(app.isProcessing || config?.routes.isEmpty ?? true)

                    Button(action: {
                        app.removeRoutes(for: vpnName)
                    }) {
                        Label("清理路由", systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(app.isProcessing)
                }
            }
        }
    }
}