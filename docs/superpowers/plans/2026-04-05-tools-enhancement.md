# 工具功能增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 增强工具页面功能：VPN 环境提示、HTTPS IP 查询、Ping 测试、DNS 查询、端口连通性测试

**Architecture:** 在现有 ToolsView.swift 中添加新功能模块，复用卡片样式，每个功能独立实现

**Tech Stack:** Swift, SwiftUI, URLSession, Network.framework, Process

---

## 文件结构

| 文件 | 职责 |
|------|------|
| `RoutePilot/Views/ToolsView.swift` | 工具页面主视图，包含所有功能模块 |

---

### Task 1: 公网 IP 改用 HTTPS API

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

**说明：** ip-api.com 的 HTTPS 需要付费，改用 ipapi.co 的免费 HTTPS API

- [ ] **Step 1: 修改公网 IP 查询 API**

将 `queryPublicIP()` 方法中的 API 从 `http://ip-api.com/json/` 改为 `https://ipapi.co/json/`

```swift
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
                    // 创建兼容的 PublicIPInfo
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
```

- [ ] **Step 2: 更新 PublicIPInfo 模型**

修改 `RoutePilot/Models/PublicIPInfo.swift` 添加初始化方法：

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
    
    /// 手动初始化
    init(status: String, country: String, city: String, isp: String, query: String) {
        self.status = status
        self.country = country
        self.city = city
        self.isp = isp
        self.query = query
    }
}
```

- [ ] **Step 3: 移除 Info.plist 中的 ATS 例外**

删除 `RoutePilot/Resources/Info.plist` 中的 `NSAppTransportSecurity` 配置，因为不再需要 HTTP

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 5: 提交**

```bash
git add RoutePilot/Views/ToolsView.swift RoutePilot/Models/PublicIPInfo.swift RoutePilot/Resources/Info.plist
git commit -m "feat: 公网 IP 查询改用 HTTPS API"
```

---

### Task 2: 路由追踪 VPN 环境提示

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 在路由追踪模块添加 VPN 警告提示**

在路由追踪模块的描述文本下方添加警告提示：

找到 `Text("追踪到目标的网络路径")` 下方添加：

```swift
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
```

- [ ] **Step 2: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 3: 提交**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 路由追踪添加 VPN 环境警告提示"
```

---

### Task 3: 添加 Ping 测试工具

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加 Ping 测试状态变量**

在 `ToolsView` 结构体中添加：

```swift
// Ping 测试状态
@State private var pingTarget: String = ""
@State private var pingResults: [String] = []
@State private var isPinging = false
@State private var pingProcess: Process?
```

- [ ] **Step 2: 添加 Ping 方法**

```swift
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
```

- [ ] **Step 3: 添加 Ping 测试 UI**

在路由追踪模块之后添加：

```swift
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
                        .font(.caption2)
                        .fontDesign(.monospace)
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
```

- [ ] **Step 4: 构建验证**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 5: 提交**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加 Ping 测试工具"
```

---

### Task 4: 添加 DNS 查询工具

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加 DNS 查询状态变量**

```swift
// DNS 查询状态
@State private var dnsTarget: String = ""
@State private var dnsRecords: [(type: String, value: String)] = []
@State private var isQueryingDNS = false
@State private var dnsError: String?
```

- [ ] **Step 2: 添加 DNS 查询方法**

```swift
private func queryDNS() {
    guard !dnsTarget.isEmpty else { return }
    isQueryingDNS = true
    dnsRecords = []
    dnsError = nil

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
    process.arguments = ["+short", dnsTarget, "ANY"]

    let pipe = Pipe()
    process.standardOutput = pipe

    Task {
        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            var records: [(type: String, value: String)] = []
            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                
                // 简单判断记录类型
                let type: String
                if trimmed.contains(".") && !trimmed.hasPrefix("\"") {
                    if trimmed.allSatisfy({ $0.isNumber || $0 == "." }) {
                        type = "A"
                    } else {
                        type = "CNAME"
                    }
                } else {
                    type = "TXT"
                }
                records.append((type: type, value: trimmed))
            }

            await MainActor.run {
                isQueryingDNS = false
                dnsRecords = records
            }
        } catch {
            await MainActor.run {
                isQueryingDNS = false
                dnsError = "查询失败"
            }
        }
    }
}
```

- [ ] **Step 3: 添加 DNS 查询 UI**

在 Ping 测试模块之后添加：

```swift
// DNS 查询
VStack(alignment: .leading, spacing: 8) {
    Text("DNS 查询")
        .font(.subheadline)
        .fontWeight(.medium)

    Text("查询域名解析记录")
        .font(.caption)
        .foregroundColor(.secondary)

    HStack {
        TextField("输入域名", text: $dnsTarget)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .disabled(isQueryingDNS)
            .onSubmit {
                queryDNS()
            }

        Button(isQueryingDNS ? "查询中..." : "查询") {
            queryDNS()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(dnsTarget.isEmpty || isQueryingDNS)
    }

    if !dnsRecords.isEmpty {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(dnsRecords, id: \.value) { record in
                HStack {
                    Text(record.type)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .frame(width: 50, alignment: .leading)
                    Text(record.value)
                        .font(.caption2)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    if let error = dnsError {
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

- [ ] **Step 5: 提交**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加 DNS 查询工具"
```

---

### Task 5: 添加端口连通性测试

**Files:**
- Modify: `RoutePilot/Views/ToolsView.swift`

- [ ] **Step 1: 添加端口测试状态变量**

```swift
// 端口测试状态
@State private var portHost: String = ""
@State private var portNumber: String = ""
@State private var portResult: String?
@State private var isTestingPort = false
```

- [ ] **Step 2: 添加端口测试方法**

使用 Network.framework 进行 TCP 连接测试：

```swift
import Network

private func testPort() {
    guard !portHost.isEmpty, !portNumber.isEmpty, let port = UInt16(portNumber) else { return }
    isTestingPort = true
    portResult = nil

    let host = NWEndpoint.Host(portHost)
    let port = NWEndpoint.Port(rawValue: port)!
    
    let connection = NWConnection(host: host, port: port, using: .tcp)
    
    connection.stateUpdateHandler = { state in
        DispatchQueue.main.async {
            switch state {
            case .ready:
                self.portResult = "✓ 端口 \(self.portNumber) 开放"
                self.isTestingPort = false
                connection.cancel()
            case .failed(let error):
                self.portResult = "✗ 端口 \(self.portNumber) 不可达: \(error.localizedDescription)"
                self.isTestingPort = false
            case .waiting(let error):
                self.portResult = "⏳ 等待连接: \(error.localizedDescription)"
            default:
                break
            }
        }
    }
    
    connection.start(queue: .global())
    
    // 5 秒超时
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        if isTestingPort {
            portResult = "✗ 连接超时"
            isTestingPort = false
            connection.cancel()
        }
    }
}
```

- [ ] **Step 3: 添加端口测试 UI**

在 DNS 查询模块之后添加：

```swift
// 端口连通性测试
VStack(alignment: .leading, spacing: 8) {
    Text("端口测试")
        .font(.subheadline)
        .fontWeight(.medium)

    Text("测试 TCP 端口连通性")
        .font(.caption)
        .foregroundColor(.secondary)

    HStack {
        TextField("主机", text: $portHost)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .frame(width: 120)

        TextField("端口", text: $portNumber)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
            .frame(width: 60)

        Button(isTestingPort ? "测试中..." : "测试") {
            testPort()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(portHost.isEmpty || portNumber.isEmpty || isTestingPort)
    }

    if let result = portResult {
        Text(result)
            .font(.caption)
            .foregroundColor(result.hasPrefix("✓") ? .green : .orange)
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

- [ ] **Step 5: 提交**

```bash
git add RoutePilot/Views/ToolsView.swift
git commit -m "feat: 添加端口连通性测试工具"
```

---

### Task 6: 更新 CHANGELOG

- [ ] **Step 1: 更新 CHANGELOG.md**

```markdown
## [v1.6.0] - 2026-04-05

### 新功能

- **Ping 测试** - 测试网络连通性，显示延迟和丢包率
- **DNS 查询** - 查询域名解析记录
- **端口测试** - 测试 TCP 端口连通性

### 改进

- 公网 IP 查询改用 HTTPS API，更安全
- 路由追踪添加 VPN 环境警告提示
```

- [ ] **Step 2: 提交 CHANGELOG**

```bash
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG v1.6.0"
```

---

### Task 7: 最终测试

- [ ] **Step 1: 完整构建测试**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build 2>&1 | tail -10
```

- [ ] **Step 2: 运行应用手动测试**

```bash
open ~/Library/Developer/Xcode/DerivedData/RoutePilot-*/Build/Products/Debug/RoutePilot.app
```

验证项：
- [ ] 公网 IP 查询使用 HTTPS
- [ ] VPN 连接时路由追踪显示警告
- [ ] Ping 测试正常工作
- [ ] DNS 查询正常工作
- [ ] 端口测试正常工作

- [ ] **Step 3: 推送并发布**

```bash
git push origin main
git tag v1.6.0
git push origin v1.6.0
```