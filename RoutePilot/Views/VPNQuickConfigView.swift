//
//  VPNQuickConfigView.swift
//  RoutePilot
//

import SwiftUI

/// VPN 快速配置组件：路由管理、操作按钮
struct VPNQuickConfigView: View {
    let vpnName: String
    @Binding var newRoute: String
    @Binding var showDetailView: Bool
    @Binding var detailInitialTab: Int
    @ObservedObject private var app = AppController.shared
    @State private var newNote: String = ""

    var config: VPNConfig? {
        app.vpnConfigs.first { $0.name == vpnName }
    }

    var vpnStatus: VPNStatus? {
        app.activeVPNs.first { $0.name == vpnName }
    }

    var isActiveVPN: Bool {
        vpnStatus != nil
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
                    if let iface = vpnStatus?.interface {
                        Text("(\(iface))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

            if let routes = config?.routes, !routes.isEmpty {
                ForEach(routes) { route in
                    RouteRowView(
                        route: route,
                        vpnName: vpnName
                    )
                }
            }

            // 添加新路由
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TextField("目标地址 (如 10.0.0.0/8)", text: $newRoute)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)

                    Button("添加") {
                        if !newRoute.isEmpty {
                            app.addRoute(newRoute, note: newNote.isEmpty ? nil : newNote, to: vpnName)
                            newRoute = ""
                            newNote = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(newRoute.isEmpty)
                }

                TextField("备注 (可选)", text: $newNote)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .font(.caption)
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

/// 路由行视图
struct RouteRowView: View {
    let route: RouteItem
    let vpnName: String
    @ObservedObject private var app = AppController.shared
    @State private var isEditing: Bool = false
    @State private var editingNote: String = ""

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { route.enabled },
                set: { app.toggleRoute(route, in: vpnName, enabled: $0) }
            ))
            .labelsHidden()
            .controlSize(.small)

            Text(route.destination)
                .font(.caption)

            if let note = route.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                editingNote = route.note ?? ""
                isEditing = true
            }) {
                Image(systemName: "pencil")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $isEditing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("编辑备注")
                        .font(.headline)

                    TextField("备注", text: $editingNote)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)

                    HStack {
                        Button("取消") {
                            isEditing = false
                        }

                        Spacer()

                        Button("保存") {
                            app.updateNote(editingNote.isEmpty ? nil : editingNote, for: route, in: vpnName)
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }

            Button(action: { app.removeRoute(route, from: vpnName) }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}