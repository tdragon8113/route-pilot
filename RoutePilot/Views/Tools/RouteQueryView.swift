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
            Text("路由查询")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("查询 IP 或域名走哪个网卡出口")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("输入 IP 或域名", text: $debugInput)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit {
                        runDebugQuery()
                    }

                Button("查询") {
                    runDebugQuery()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(debugInput.isEmpty || isDebugging)
            }

            if isDebugging {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("查询中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let result = debugResult {
                VStack(alignment: .leading, spacing: 6) {
                    if let ip = result.resolvedIP {
                        HStack {
                            Text("解析 IP:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(ip)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    HStack {
                        Text("出口网卡:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(result.interface)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }

                    if let vpn = result.matchedVPN {
                        HStack {
                            Text("对应 VPN:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(vpn)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    } else if result.interface.hasPrefix("ppp") || result.interface.hasPrefix("utun") {
                        HStack {
                            Text("对应 VPN:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("未匹配到已配置的 VPN")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
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
                .fill(Color(nsColor: .controlBackgroundColor))
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
                            debugError = "无法解析域名"
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        isDebugging = false
                        debugError = "域名解析失败"
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
                        debugError = "未找到路由信息"
                    }
                }
            } catch {
                await MainActor.run {
                    isDebugging = false
                    debugError = "查询失败: \(error.localizedDescription)"
                }
            }
        }
    }
}