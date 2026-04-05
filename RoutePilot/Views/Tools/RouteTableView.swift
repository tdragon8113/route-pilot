//
//  RouteTableView.swift
//  RoutePilot
//

import SwiftUI

/// 路由表组件
struct RouteTableView: View {
    @State private var routeEntries: [RouteEntry] = []
    @State private var routeFilterInterface: String = ""
    @State private var routeFilterIP: String = ""
    @State private var availableInterfaces: [String] = []
    @State private var isLoadingRoutes = false

    private var allInterfacesKey: String { "route.all_interfaces".localized }

    private var displayedRoutes: [RouteEntry] {
        var result = routeEntries

        if !routeFilterInterface.isEmpty && routeFilterInterface != allInterfacesKey {
            result = result.filter { $0.interface == routeFilterInterface }
        }

        if !routeFilterIP.isEmpty {
            result = result.filter { $0.destination.contains(routeFilterIP) || $0.gateway.contains(routeFilterIP) }
        }

        return result
    }

    private var interfaceButtons: [String] {
        [allInterfacesKey] + availableInterfaces
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("tools.route_table".localized)
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
                    ForEach(interfaceButtons, id: \.self) { iface in
                        QuickButton(
                            title: iface,
                            isSelected: routeFilterInterface == iface || (routeFilterInterface.isEmpty && iface == allInterfacesKey)
                        ) {
                            routeFilterInterface = iface
                        }
                    }
                }
            }

            ClearableTextField(placeholder: "result.ip".localized + " " + "tools.query".localized, text: $routeFilterIP)

            if isLoadingRoutes {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("result.loading".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if routeEntries.isEmpty {
                Text("result.click_refresh".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if displayedRoutes.isEmpty {
                Text("result.no_matching_routes".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("route.destination".localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 100, alignment: .leading)
                            Text("route.gateway".localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            Text("route.interface".localized)
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
                .fill(Color.cardBackground)
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
                    self.availableInterfaces = interfaces.sorted()
                    self.routeFilterInterface = ""
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