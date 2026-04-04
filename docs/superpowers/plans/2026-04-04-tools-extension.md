# 工具功能扩展实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在工具页面新增公网 IP 查询、路由表查看、路由追踪三个功能模块

**Architecture:** 基于 SwiftUI 实现，复用现有的卡片样式，每个功能独立实现、互不依赖

**Tech Stack:** Swift, SwiftUI, URLSession, Process (系统命令)

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `RoutePilot/Views/ToolsView.swift` | 工具页面主视图，包含所有功能模块 |
| `RoutePilot/Models/PublicIPInfo.swift` | 公网 IP 信息数据模型 |
| `RoutePilot/Models/RouteEntry.swift` | 路由表条目数据模型 |
| `RoutePilot/Models/TracerouteHop.swift` | 路由追踪跳数数据模型 |

---

### Task 1: 创建数据模型

**Files:**
- Create: `RoutePilot/Models/PublicIPInfo.swift`
- Create: `RoutePilot/Models/RouteEntry.swift`
- Create: `RoutePilot/Models/TracerouteHop.swift`

- [ ] **Step 1: 创建 PublicIPInfo 数据模型**

```swift
//
//  PublicIPInfo.swift
//  RoutePilot
//

import Foundation

/// 公网 IP 信息
struct PublicIPInfo: Codable {
    let status: String
    let country: String
    let city: String
    let isp: String
    let query: String

    /// 是否查询成功
    var isSuccess: Bool {
        status == "success"
    }
}
```

- [ ] **Step 2: 创建 RouteEntry 数据模型**

```swift
//
//  RouteEntry.swift
//  RoutePilot
//

import Foundation

/// 路由表条目
struct RouteEntry: Identifiable {
    let id = UUID()
    let destination: String
    let gateway: String
    let flags: String
    let interface: String
}
```

- [ ] **Step 3: 创建 TracerouteHop 数据模型**

```swift
//
//  TracerouteHop.swift
//  RoutePilot
//

import Foundation

/// 路由追踪跳数
struct TracerouteHop: Identifiable {
    let id = UUID()
    let hopNumber: Int
    let ip: String?
    let hostname: String?
    let time: String?
}
```

- [ ] **Step 4: 提交数据模型**

```bash
git add RoutePilot/Models/PublicIPInfo.swift RoutePilot/Models/RouteEntry.swift RoutePilot/Models/TracerouteHop.swift
git commit -m "feat: 添加工具功能数据模型"
```

---

### Task 2: 实现公网 IP 查询功能

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加公网 IP 查询状态变量**

在 `ToolsView` 结构体中添加状态变量：

```swift
// 公网 IP 查询状态
@State private var publicIPInfo: PublicIPInfo?
@State private var isQueryingIP = false
@State private var ipQueryError: String?
```

- [ ] **Step 2: 实现公网 IP 查询方法**

在 `ToolsView` 中添加查询方法：

```swift
private func queryPublicIP() {
    isQueryingIP = true
    ipQueryError = nil

    guard let url = URL(string: "http://ip-api.com/json/") else { return }

    Task {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let info = try JSONDecoder().decode(PublicIPInfo.self, from: data)

            await MainActor.run {
                isQueryingIP = false
                if info.isSuccess {
                    publicIPInfo = info
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
```

- [ ] **Step 3: 添加公网 IP 查询 UI**

在 `body` 的标题栏之后、路由查询之前添加：

```swift
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
```

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 5: 提交公网 IP 查询功能**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加公网 IP 查询功能"
```

---

### Task 3: 实现路由表查看功能

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加路由表查看状态变量**

在 `ToolsView` 结构体中添加状态变量：

```swift
// 路由表状态
@State private var routeEntries: [RouteEntry] = []
@State private var filteredRoutes: [RouteEntry] = []
@State private var routeFilterInterface: String = ""
@State private var routeFilterIP: String = ""
@State private var availableInterfaces: [String] = []
@State private var isLoadingRoutes = false
```

- [ ] **Step 2: 实现路由表获取方法**

在 `ToolsView` 中添加方法：

```swift
private func loadRouteTable() {
    isLoadingRoutes = true

    Task {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/netstat")
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
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 4,
                      !parts[0].hasPrefix("Destination") else { continue }

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
                self.filteredRoutes = entries
                self.availableInterfaces = ["全部"] + interfaces.sorted()
                self.isLoadingRoutes = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingRoutes = false
            }
        }
    }
}

private func filterRoutes() {
    var result = routeEntries

    if !routeFilterInterface.isEmpty && routeFilterInterface != "全部" {
        result = result.filter { $0.interface == routeFilterInterface }
    }

    if !routeFilterIP.isEmpty {
        result = result.filter { $0.destination.contains(routeFilterIP) || $0.gateway.contains(routeFilterIP) }
    }

    filteredRoutes = result
}
```

- [ ] **Step 3: 添加路由表查看 UI**

在公网 IP 查询模块之后、路由查询之前添加：

```swift
// 路由表查看
VStack(alignment: .leading, spacing: 8) {
    Text("路由表")
        .font(.subheadline)
        .fontWeight(.medium)

    HStack {
        Picker("接口", selection: $routeFilterInterface) {
            ForEach(availableInterfaces, id: \.self) { iface in
                Text(iface).tag(iface)
            }
        }
        .frame(width: 80)
        .onChange(of: routeFilterInterface) { _ in filterRoutes() }

        TextField("IP 过滤", text: $routeFilterIP)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .onChange(of: routeFilterIP) { _ in filterRoutes() }
    }

    if isLoadingRoutes {
        HStack {
            ProgressView().controlSize(.small)
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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

                ForEach(filteredRoutes.prefix(50)) { route in
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
```

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 5: 提交路由表查看功能**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加路由表查看功能"
```

---

### Task 4: 实现路由追踪功能

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加路由追踪状态变量**

在 `ToolsView` 结构体中添加状态变量：

```swift
// 路由追踪状态
@State private var tracerouteTarget: String = ""
@State private var tracerouteHops: [TracerouteHop] = []
@State private var isTracing = false
@State private var tracerouteError: String?
@State private var tracerouteProcess: Process?
```

- [ ] **Step 2: 实现路由追踪方法**

在 `ToolsView` 中添加方法：

```swift
private func startTraceroute() {
    guard !tracerouteTarget.isEmpty else { return }
    isTracing = true
    tracerouteHops = []
    tracerouteError = nil

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/sbin/traceroute")
    process.arguments = [tracerouteTarget]

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

    // 匹配格式: "1  192.168.1.1 (192.168.1.1)  1.234 ms"
    // 或: "2  * * *"
    let parts = trimmed.split(separator: " ", omittingEmptySubsequences: true)
    guard let hopNum = Int(parts[0]) else { return nil }

    if parts[1] == "*" {
        return TracerouteHop(hopNumber: hopNum, ip: nil, hostname: nil, time: nil)
    }

    let ip = String(parts[1])
    var hostname: String? = nil
    var time: String? = nil

    // 查找时间
    for i in 2..<parts.count {
        if parts[i].contains("ms") {
            time = String(parts[i])
            break
        }
    }

    return TracerouteHop(hopNumber: hopNum, ip: ip, hostname: hostname, time: time)
}
```

- [ ] **Step 3: 添加路由追踪 UI**

在路由追踪模块位置（工具页面末尾）添加：

```swift
// 路由追踪
VStack(alignment: .leading, spacing: 8) {
    Text("路由追踪")
        .font(.subheadline)
        .fontWeight(.medium)

    Text("追踪到目标的网络路径")
        .font(.caption)
        .foregroundColor(.secondary)

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
```

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 5: 提交路由追踪功能**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加路由追踪功能"
```

---

### Task 5: 整体测试与提交

- [ ] **Step 1: 完整构建测试**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

预期: BUILD SUCCEEDED

- [ ] **Step 2: 运行应用手动测试**

```bash
open ~/Library/Developer/Xcode/DerivedData/RoutePilot-*/Build/Products/Debug/RoutePilot.app
```

验证项：
- [ ] 公网 IP 查询：点击查询，显示 IP、位置、运营商
- [ ] 路由表查看：自动加载，接口和 IP 过滤正常
- [ ] 路由追踪：输入域名/IP，实时显示每一跳

- [ ] **Step 3: 最终提交**

```bash
git push origin main
```