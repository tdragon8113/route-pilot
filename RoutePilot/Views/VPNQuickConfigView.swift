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
    @Binding var selectedVPN: String?
    @ObservedObject private var app = AppController.shared
    @State private var newNote: String = ""

    // 拖拽状态
    @State private var draggingId: UUID? = nil
    @State private var dragProgress: CGFloat = 0

    private let rowHeight: CGFloat = 32

    var config: VPNConfig? {
        app.vpnConfigs.first { $0.name == vpnName }
    }

    var vpnStatus: VPNStatus? {
        app.activeVPNs.first { $0.name == vpnName }
    }

    var isActiveVPN: Bool {
        vpnStatus != nil
    }

    // 计算每个元素的偏移
    private func offsetForIndex(_ index: Int, routes: [RouteItem]) -> CGFloat {
        guard let draggingId = draggingId,
              let dragStartIndex = routes.firstIndex(where: { $0.id == draggingId }) else {
            return 0
        }

        let isBeingDragged = routes[index].id == draggingId
        if isBeingDragged {
            // 被拖拽元素跟随手指
            return dragProgress * rowHeight
        }

        // 其他元素让位逻辑
        let targetOffset = Int(round(dragProgress))
        let targetIndex = dragStartIndex + targetOffset

        if dragProgress > 0 { // 向下拖
            // 在起点和目标之间的元素向上让
            if index > dragStartIndex && index <= targetIndex {
                return -rowHeight
            }
        } else if dragProgress < 0 { // 向上拖
            // 在目标和起点之间的元素向下让
            if index >= targetIndex && index < dragStartIndex {
                return rowHeight
            }
        }

        return 0
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
                    Text("vpn.connected".localized)
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
                    Button("route.view_routes".localized) {
                        selectedVPN = vpnName
                        if let iface = vpnStatus?.interface {
                            app.fetchCurrentRoutes(interface: iface)
                        }
                        detailInitialTab = 0
                        showDetailView = true
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }

            if let routes = config?.routes, !routes.isEmpty {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                            RouteRowView(
                                route: route,
                                vpnName: vpnName,
                                isBeingDragged: draggingId == route.id,
                                offsetY: offsetForIndex(index, routes: routes),
                                onDragChanged: { id, progress in
                                    draggingId = id
                                    dragProgress = progress
                                },
                                onDragEnded: {
                                    if let startIdx = routes.firstIndex(where: { $0.id == draggingId }) {
                                        let targetOffset = Int(round(dragProgress))
                                        let targetIdx = startIdx + targetOffset
                                        let clampedTarget = max(0, min(routes.count - 1, targetIdx))
                                        if clampedTarget != startIdx {
                                            app.moveRouteToIndex(routes[startIdx], toIndex: clampedTarget, in: vpnName)
                                        }
                                    }
                                    draggingId = nil
                                    dragProgress = 0
                                }
                            )
                        }
                    }
                }
                .frame(height: min(CGFloat(routes.count) * 34 + 8, 150))
            }

            // 添加新路由
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    ClearableTextField(placeholder: "route.add_placeholder".localized, text: $newRoute)

                    Button("route.add".localized.components(separatedBy: " ").first ?? "route.add".localized) {
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

                ClearableTextField(placeholder: "route.note_placeholder".localized, text: $newNote)
                    .font(.caption)
            }

            if isActiveVPN {
                Divider()
                HStack {
                    Button(action: {
                        app.addRoutes(for: vpnName)
                    }) {
                        Label("route.add".localized, systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(app.isProcessing || config?.routes.isEmpty ?? true)

                    Button(action: {
                        app.removeRoutes(for: vpnName)
                    }) {
                        Label("route.clear".localized, systemImage: "minus.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(app.isProcessing)
                }
            }
        }
    }
}

/// 路由行视图 - 支持拖拽排序
struct RouteRowView: View {
    let route: RouteItem
    let vpnName: String
    let isBeingDragged: Bool
    let offsetY: CGFloat
    let onDragChanged: (UUID, CGFloat) -> Void
    let onDragEnded: () -> Void

    @ObservedObject private var app = AppController.shared
    @State private var isEditing: Bool = false
    @State private var editingNote: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // 拖拽手柄
            Image(systemName: "line.3.horizontal")
                .font(.caption2)
                .foregroundColor(isBeingDragged ? .accentColor : .secondary)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5, coordinateSpace: .global)
                        .onChanged { value in
                            let rowHeight: CGFloat = 32
                            let progress = value.translation.height / rowHeight
                            onDragChanged(route.id, progress)
                        }
                        .onEnded { _ in
                            onDragEnded()
                        }
                )

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
                    Text("route.edit_note".localized)
                        .font(.headline)

                    ClearableTextField(placeholder: "route.note".localized, text: $editingNote, width: 200)

                    HStack {
                        Button("btn.cancel".localized) {
                            isEditing = false
                        }

                        Spacer()

                        Button("btn.save".localized) {
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
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isBeingDragged ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isBeingDragged ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .shadow(color: isBeingDragged ? Color.black.opacity(0.3) : Color.clear, radius: isBeingDragged ? 4 : 0)
        .scaleEffect(isBeingDragged ? 1.02 : 1)
        .offset(y: offsetY)
        .animation(.easeOut(duration: isBeingDragged ? 0 : 0.15), value: offsetY)
        .zIndex(isBeingDragged ? 10 : 0)
    }
}