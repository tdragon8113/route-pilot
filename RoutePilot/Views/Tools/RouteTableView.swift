//
//  RouteTableView.swift
//  RoutePilot
//

import SwiftUI

/// 路由表组件
struct RouteTableView: View {
    @State private var routeEntries: [RouteEntry] = []
    @State private var routeFilterInterface: String = "全部"
    @State private var routeFilterIP: String = ""
    @State private var availableInterfaces: [String] = ["全部"]
    @State private var isLoadingRoutes = false

    private var displayedRoutes: [RouteEntry] {
        var result = routeEntries

        if !routeFilterInterface.isEmpty && routeFilterInterface != "全部" {
            result = result.filter { $0.interface == routeFilterInterface }
        }

        if !routeFilterIP.isEmpty {
            result = result.filter { $0.destination.contains(routeFilterIP) || $0.gateway.contains(routeFilterIP) }
        }

        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("路由表")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: loadRouteTable) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            // 接口过滤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(availableInterfaces, id: \.self) { iface in
                        QuickButton(
                            title: iface,
                            isSelected: routeFilterInterface == iface
                        ) {
                            routeFilterInterface = iface
                        }
                    }
                }
            }

            TextField("IP 过滤", text: $routeFilterIP)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if isLoadingRoutes {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if routeEntries.isEmpty {
                Text("点击刷新按钮加载路由表")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if displayedRoutes.isEmpty {
                Text("无匹配的路由")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("目标")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text("网关")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            Text("接口")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 50, alignment: .leading)
                        }
                        .foregroundColor(.secondary)

                        ForEach(displayedRoutes.prefix(50)) { route in
                            HStack {
                                Text(route.destination)
                                    .font(.caption2)
                                    .frame(width: 100, alignment: .leading)
                                Text(route.gateway)
                                    .font(.caption2)
                                    .frame(width: 80, alignment: .leading)
                                Text(route.interface)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .frame(width: 50, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func loadRouteTable() {
        isLoadingRoutes = true

        Task {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/netstat")
            process.arguments = ["-rn"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                var entries: [RouteEntry] = []
                var interfaces: Set<String> = []

                for line in output.components(separatedBy: "\n") {
                    if line.contains("Internet6") { break }

                    let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                    guard parts.count >= 4,
                          !parts[0].hasPrefix("Destination"),
                          !parts[0].hasPrefix("Routing"),
                          !parts[0].hasPrefix("Internet") else { continue }

                    let destination = String(parts[0])
                    let gateway = String(parts[1])
                    let flags = String(parts[2])
                    let interface = String(parts[3])

                    entries.append(RouteEntry(
                        destination: destination,
                        gateway: gateway,
                        flags: flags,
                        interface: interface
                    ))
                    interfaces.insert(interface)
                }

                await MainActor.run {
                    self.routeEntries = entries
                    self.availableInterfaces = ["全部"] + interfaces.sorted()
                    self.routeFilterInterface = "全部"
                    self.isLoadingRoutes = false
                }
            } catch {
                await MainActor.run {
                    self.isLoadingRoutes = false
                }
            }
        }
    }
}