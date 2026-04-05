//
//  ToolsView.swift
//  RoutePilot
//

import SwiftUI

/// 工具页面
struct ToolsView: View {
    @Binding var showTools: Bool
    @ObservedObject private var app = AppController.shared
    @State private var debugInput: String = ""
    @State private var debugResult: DebugResult?
    @State private var debugError: String?
    @State private var isDebugging = false

    // 公网 IP 查询状态
    @State private var publicIPInfo: PublicIPInfo?
    @State private var isQueryingIP = false
    @State private var ipQueryError: String?

    // 路由表状态
    @State private var routeEntries: [RouteEntry] = []
    @State private var routeFilterInterface: String = "全部"
    @State private var routeFilterIP: String = ""
    @State private var availableInterfaces: [String] = ["全部"]
    @State private var isLoadingRoutes = false

    // 计算属性：根据过滤条件返回路由
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

    // 路由追踪状态
    @State private var tracerouteTarget: String = ""
    @State private var tracerouteHops: [TracerouteHop] = []
    @State private var isTracing = false
    @State private var tracerouteError: String?
    @State private var tracerouteProcess: Process?

    // Ping 测试状态
    @State private var pingTarget: String = ""
    @State private var pingResults: [String] = []
    @State private var isPinging = false
    @State private var pingProcess: Process?

    struct DebugResult {
        let resolvedIP: String?
        let interface: String
        let matchedVPN: String?
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 标题栏
                HStack {
                    Button(action: { showTools = false }) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.borderless)

                    Text("工具")
                        .font(.headline)

                    Spacer()
                }

            // 公网 IP 查询
            VStack(alignment: .leading, spacing: 8) {
                Text("公网 IP 查询")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("查询当前公网 IP 及地理位置")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if isQueryingIP {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("查询中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let info = publicIPInfo {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("IP:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(info.query)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("位置:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(info.country), \(info.city)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("运营商:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(info.isp)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                if let error = ipQueryError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Button(isQueryingIP ? "查询中..." : "查询") {
                    queryPublicIP()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isQueryingIP)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            // 路由查询
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

            // 路由表查看
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
                            if routeFilterInterface == iface {
                                Button(iface) { routeFilterInterface = iface }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else {
                                Button(iface) { routeFilterInterface = iface }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
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
            .onAppear {
                loadRouteTable()
            }

            // 路由追踪
            VStack(alignment: .leading, spacing: 8) {
                Text("路由追踪")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("追踪到目标的网络路径")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // VPN 环境警告
                if !app.activeVPNs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("VPN 连接时可能无法正常追踪")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                HStack {
                    TextField("输入目标域名或 IP", text: $tracerouteTarget)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .disabled(isTracing)

                    if isTracing {
                        Button("取消") {
                            stopTraceroute()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("追踪") {
                            startTraceroute()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(tracerouteTarget.isEmpty)
                    }
                }

                if !tracerouteHops.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(tracerouteHops) { hop in
                                HStack {
                                    Text("\(hop.hopNumber)")
                                        .font(.caption2)
                                        .frame(width: 20, alignment: .leading)
                                        .foregroundColor(.secondary)

                                    if let ip = hop.ip {
                                        Text(ip)
                                            .font(.caption2)
                                            .foregroundColor(.blue)

                                        if let time = hop.time {
                                            Text(time)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("*")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                if let error = tracerouteError {
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

            // Ping 测试
            VStack(alignment: .leading, spacing: 8) {
                Text("Ping 测试")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("测试网络连通性")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("输入域名或 IP", text: $pingTarget)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .disabled(isPinging)

                    if isPinging {
                        Button("停止") {
                            stopPing()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button("测试") {
                            startPing()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(pingTarget.isEmpty)
                    }
                }

                if !pingResults.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(pingResults, id: \.self) { result in
                                Text(result)
                                    .font(.system(.caption2, design: .monospaced))
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Spacer()
            }
        }
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

            // 判断是否是域名（包含字母）
            let hasLetters = input.unicodeScalars.contains { CharacterSet.letters.contains($0) }
            if hasLetters {
                // 使用 dig 解析域名
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

                // 解析网卡
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
                        // 查找匹配的 VPN
                        let matchedVPN = app.vpnConfigs.first { config in
                            app.activeVPNs.contains { $0.name == config.name && $0.interface == iface }
                        }?.name

                        debugResult = DebugResult(
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

    private func queryPublicIP() {
        isQueryingIP = true
        ipQueryError = nil

        guard let url = URL(string: "https://ipapi.co/json/") else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                // ipapi.co 返回格式: {"ip": "x.x.x.x", "city": "...", "region": "...", "country_name": "...", "org": "..."}
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                await MainActor.run {
                    isQueryingIP = false
                    if let ip = json?["ip"] as? String {
                        publicIPInfo = PublicIPInfo(
                            status: "success",
                            country: json?["country_name"] as? String ?? "",
                            city: json?["city"] as? String ?? "",
                            isp: json?["org"] as? String ?? "",
                            query: ip
                        )
                    } else {
                        ipQueryError = "查询失败"
                    }
                }
            } catch {
                await MainActor.run {
                    isQueryingIP = false
                    ipQueryError = "查询失败，请检查网络连接"
                }
            }
        }
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
                    // 遇到 IPv6 部分就停止
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

    private func startTraceroute() {
        guard !tracerouteTarget.isEmpty else { return }
        isTracing = true
        tracerouteHops = []
        tracerouteError = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
        process.arguments = ["-w", "2", "-q", "1", "-m", "30", tracerouteTarget]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        // 实时读取输出
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let line = String(data: data, encoding: .utf8) ?? ""

            // 解析每一行
            if let hop = parseTracerouteLine(line) {
                DispatchQueue.main.async {
                    self.tracerouteHops.append(hop)
                }
            }
        }

        do {
            try process.run()
            tracerouteProcess = process

            // 监听进程结束
            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isTracing = false
                    self.tracerouteProcess = nil
                }
            }
        } catch {
            isTracing = false
            tracerouteError = "启动失败"
        }
    }

    private func stopTraceroute() {
        tracerouteProcess?.terminate()
        tracerouteProcess = nil
        isTracing = false
    }

    private func parseTracerouteLine(_ line: String) -> TracerouteHop? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 跳过警告和标题行
        if trimmed.hasPrefix("traceroute") { return nil }

        let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
        guard let hopNum = Int(parts[0]) else { return nil }

        // 检查是否超时：格式 "1  *" 或 "1 * * *"
        if parts.count > 1 && String(parts[1]) == "*" {
            return TracerouteHop(hopNumber: hopNum, ip: nil, hostname: nil, time: nil)
        }

        guard parts.count > 1 else { return nil }

        let ip = String(parts[1])
        var time: String? = nil

        // 查找时间
        for i in 2..<parts.count {
            if parts[i].contains("ms") {
                time = String(parts[i])
                break
            }
        }

        return TracerouteHop(hopNumber: hopNum, ip: ip, hostname: nil, time: time)
    }

    private func startPing() {
        guard !pingTarget.isEmpty else { return }
        isPinging = true
        pingResults = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "4", "-W", "2000", pingTarget]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let line = String(data: data, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                self.pingResults.append(line.trimmingCharacters(in: .newlines))
            }
        }

        do {
            try process.run()
            pingProcess = process

            process.terminationHandler = { _ in
                DispatchQueue.main.async {
                    self.isPinging = false
                    self.pingProcess = nil
                }
            }
        } catch {
            isPinging = false
        }
    }

    private func stopPing() {
        pingProcess?.terminate()
        pingProcess = nil
        isPinging = false
    }
}