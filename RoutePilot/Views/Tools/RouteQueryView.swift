//
//  RouteQueryView.swift
//  RoutePilot
//

import SwiftUI

/// 路由查询结果
struct RouteQueryResult {
    let resolvedIP: String?
    let interface: String
    let matchedVPN: String?
}

/// 路由查询组件
struct RouteQueryView: View {
    @ObservedObject private var app = AppController.shared
    @State private var debugInput: String = ""
    @State private var debugResult: RouteQueryResult?
    @State private var debugError: String?
    @State private var isDebugging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("tools.route_query".localized)
                .font(.subheadline)
                .fontWeight(.medium)

            Text("tools.route_query_desc".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                ClearableTextField(placeholder: "input.ip_or_domain".localized, text: $debugInput)
                    .onSubmit {
                        runDebugQuery()
                    }

                Button("tools.query".localized) {
                    runDebugQuery()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(debugInput.isEmpty || isDebugging)
            }

            if isDebugging {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("tools.querying".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let result = debugResult {
                VStack(alignment: .leading, spacing: 6) {
                    if let ip = result.resolvedIP {
                        HStack {
                            Text("result.resolved_ip".localized + ":")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ip)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    HStack {
                        Text("result.outgoing_interface".localized + ":")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(result.interface)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }

                    if let vpn = result.matchedVPN {
                        HStack {
                            Text("result.matched_vpn".localized + ":")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(vpn)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else if result.interface.hasPrefix("ppp") || result.interface.hasPrefix("utun") {
                        HStack {
                            Text("result.matched_vpn".localized + ":")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("result.no_match".localized)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cardBackground)
                )
            }

            if let error = debugError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cardBackground)
        )
    }

    private func runDebugQuery() {
        guard !debugInput.isEmpty else { return }
        isDebugging = true
        debugResult = nil
        debugError = nil

        Task {
            let input = debugInput.trimmingCharacters(in: .whitespaces)
            var ipToQuery = input
            var resolvedIP: String? = nil

            // 判断是否是域名
            let hasLetters = input.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            if hasLetters {
                let digProcess = Process()
                digProcess.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
                digProcess.arguments = ["+short", input, "A"]

                let digPipe = Pipe()
                digProcess.standardOutput = digPipe

                do {
                    try digProcess.run()
                    digProcess.waitUntilExit()

                    let digData = digPipe.fileHandleForReading.readDataToEndOfFile()
                    let digOutput = String(data: digData, encoding: .utf8) ?? ""
                    let lines = digOutput.components(separatedBy: "\n").filter { !$0.isEmpty }

                    if let firstIP = lines.first {
                        ipToQuery = firstIP
                        resolvedIP = firstIP
                    } else {
                        await MainActor.run {
                            isDebugging = false
                            debugError = "result.query_failed".localized
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        isDebugging = false
                        debugError = "result.query_failed".localized
                    }
                    return
                }
            }

            // 查询路由
            let routeProcess = Process()
            routeProcess.executableURL = URL(fileURLWithPath: "/sbin/route")
            routeProcess.arguments = ["-n", "get", ipToQuery]

            let routePipe = Pipe()
            routeProcess.standardOutput = routePipe
            routeProcess.standardError = routePipe

            do {
                try routeProcess.run()
                routeProcess.waitUntilExit()

                let data = routePipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                var interface: String?
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("interface:") {
                        interface = trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
                        break
                    }
                }

                await MainActor.run {
                    isDebugging = false
                    if let iface = interface {
                        let matchedVPN = app.vpnConfigs.first { config in
                            app.activeVPNs.contains { $0.name == config.name && $0.interface == iface }
                        }?.name

                        debugResult = RouteQueryResult(
                            resolvedIP: resolvedIP,
                            interface: iface,
                            matchedVPN: matchedVPN
                        )
                    } else {
                        debugError = "result.no_route_info".localized
                    }
                }
            } catch {
                await MainActor.run {
                    isDebugging = false
                    debugError = String(format: "error.query_format".localized, error.localizedDescription)
                }
            }
        }
    }
}