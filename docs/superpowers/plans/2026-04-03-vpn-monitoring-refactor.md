# VPN 监控重构实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 NWPathMonitor 重构为 SCDynamicStore，实现精确的 VPN 连接/断开监听

**Architecture:** VPNService 使用 SCDynamicStore 监听网络接口 IPv4 变化，过滤 VPN 接口，回调通知 AppController 处理路由

**Tech Stack:** Swift, SCDynamicStore, SystemConfiguration framework

---

## 文件结构

| 文件 | 变更类型 | 职责 |
|------|---------|------|
| `RoutePilot/Services/VPNService.swift` | 重构 | SCDynamicStore 监听、VPN 状态获取 |
| `RoutePilot/ViewModels/AppController.swift` | 修改 | 移除 NWPathMonitor，新增监控逻辑 |

---

### Task 1: 在 VPNService 中添加 SCDynamicStore 监听

**Files:**
- Modify: `RoutePilot/Services/VPNService.swift`

- [ ] **Step 1: 添加 SystemConfiguration import 和存储属性**

在文件顶部 import 部分添加，并在 actor 内添加属性：

```swift
import Foundation
import Network
import SystemConfiguration

/// VPN 检测服务
actor VPNService {

    static let shared = VPNService()

    private var store: SCDynamicStore?
    private var monitoringCallback: (@MainActor (String?) -> Void)?

    private init() {}
```

- [ ] **Step 2: 实现 startMonitoring 方法**

在 `VPNService` 中添加：

```swift
/// 启动 SCDynamicStore 监听
func startMonitoring(callback: @escaping @MainActor (String?) -> Void) {
    self.monitoringCallback = callback

    let storeContext = SCDynamicStoreContext(
        version: 0,
        info: Unmanaged.passUnretained(self).toOpaque(),
        retain: nil,
        release: nil,
        copyDescription: nil
    )

    store = SCDynamicStoreCreate(
        nil,
        "RoutePilot" as CFString,
        { store, changedKeys, info in
            guard let info = info else { return }
            let service = Unmanaged<VPNService>.fromOpaque(info).takeUnretainedValue()
            Task {
                await service.handleStoreChange(changedKeys: changedKeys)
            }
        },
        &storeContext
    )

    guard let store = store else {
        NSLog("[VPNService] Failed to create SCDynamicStore")
        return
    }

    // 监听所有网络接口的 IPv4 配置变化
    let patterns = ["State:/Network/Interface/.*/IPv4"] as CFArray
    SCDynamicStoreSetNotificationKeys(store, nil, patterns)

    // 将 store 添加到 RunLoop
    SCDynamicStoreAddToRunLoop(store, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)

    NSLog("[VPNService] SCDynamicStore 监控已启动")
}
```

- [ ] **Step 3: 实现 handleStoreChange 方法**

在 `VPNService` 中添加：

```swift
/// 处理 SCDynamicStore 变化
private func handleStoreChange(changedKeys: CFArray) {
    guard let keys = changedKeys as? [String] else { return }

    for key in keys {
        // 提取接口名: State:/Network/Interface/ppp0/IPv4
        let parts = key.split(separator: "/")
        guard parts.count >= 4 else { continue }

        let interface = String(parts[3])

        // 过滤 VPN 接口
        if isVPNInterface(interface) {
            NSLog("[VPNService] VPN 接口变化: \(interface)")

            // 获取该接口对应的 VPN 名称
            if let vpnName = getVPNNameForInterface(interface) {
                await MainActor.run {
                    monitoringCallback?(vpnName)
                }
            }
        }
    }
}

/// 判断是否为 VPN 接口
private func isVPNInterface(_ interface: String) -> Bool {
    interface.hasPrefix("ppp") ||
    interface.hasPrefix("utun") ||
    interface.hasPrefix("ipsec")
}
```

- [ ] **Step 4: 实现 stopMonitoring 方法**

在 `VPNService` 中添加：

```swift
/// 停止监听
func stopMonitoring() {
    guard let store = store else { return }
    SCDynamicStoreRemoveFromRunLoop(store, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
    self.store = nil
    self.monitoringCallback = nil
    NSLog("[VPNService] SCDynamicStore 监控已停止")
}
```

- [ ] **Step 5: 提交**

```bash
git add RoutePilot/Services/VPNService.swift
git commit -m "feat: 添加 SCDynamicStore 监听功能"
```

---

### Task 2: 实现从 SCDynamicStore 获取 VPN 状态

**Files:**
- Modify: `RoutePilot/Services/VPNService.swift`

- [ ] **Step 1: 实现 getVPNStatusFromStore 方法**

在 `VPNService` 中添加：

```swift
/// 从 SCDynamicStore 获取 VPN 状态
func getVPNStatusFromStore() -> [VPNStatus] {
    var result: [VPNStatus] = []

    guard let store = store ?? SCDynamicStoreCreate(nil, "RoutePilot" as CFString, nil, nil) else {
        return result
    }

    // 获取所有接口
    let key = "State:/Network/Interface" as CFString
    guard let interfaces = SCDynamicStoreCopyValue(store, key) as? [String: Any] else {
        return result
    }

    // 遍历接口
    if let interfaceList = interfaces["Interfaces"] as? [String] {
        for interface in interfaceList {
            if isVPNInterface(interface) {
                // 检查接口是否有 IPv4 配置（表示已连接）
                let ipv4Key = "State:/Network/Interface/\(interface)/IPv4" as CFString
                if let ipv4Config = SCDynamicStoreCopyValue(store, ipv4Key) as? [String: Any] {
                    // 获取 VPN 名称
                    if let vpnName = getVPNNameForInterface(interface) {
                        result.append(VPNStatus(name: vpnName, connected: true, interface: interface))
                        NSLog("[VPNService] 从 Store 获取 VPN: \(vpnName), 接口: \(interface)")
                    }
                }
            }
        }
    }

    return result
}
```

- [ ] **Step 2: 实现 getVPNNameForInterface 方法**

在 `VPNService` 中添加：

```swift
/// 获取接口对应的 VPN 名称
private func getVPNNameForInterface(_ interface: String) -> String? {
    // 使用 scutil 获取接口对应的 VPN 名称
    // 先尝试从 scutil --nc list 获取已连接的 VPN
    let output = ShellRunner.shared.runWithOutputSync("/usr/sbin/scutil --nc list")

    for line in output.split(separator: "\n") {
        let lineStr = String(line)
        guard lineStr.contains("(Connected)") else { continue }

        // 提取 VPN 名称
        let namePattern = "\"([^\"]+)\""
        guard let nameRegex = try? NSRegularExpression(pattern: namePattern) else { continue }
        let range = NSRange(lineStr.startIndex..., in: lineStr)
        let matches = nameRegex.matches(in: lineStr, range: range)

        guard let nameMatch = matches.first,
              let vpnNameRange = Range(nameMatch.range(at: 1), in: lineStr) else { continue }

        let vpnName = String(lineStr[vpnNameRange])

        // 检查该 VPN 的接口是否匹配
        let statusOutput = ShellRunner.shared.runWithOutputSync("/usr/sbin/scutil --nc status \"\(vpnName)\"")
        if statusOutput.contains("InterfaceName : \(interface)") {
            return vpnName
        }
    }

    return nil
}
```

- [ ] **Step 3: 在 ShellRunner 中添加同步方法**

在 `RoutePilot/Utils/ShellRunner.swift` 中添加：

```swift
/// 执行 Shell 命令，返回输出（同步版本，用于 SCDynamicStore 回调）
func runWithOutputSync(_ command: String) -> String {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.arguments = ["-c", command]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe

    do {
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return "ERROR: \(error.localizedDescription)"
    }
}
```

- [ ] **Step 4: 提交**

```bash
git add RoutePilot/Services/VPNService.swift RoutePilot/Utils/ShellRunner.swift
git commit -m "feat: 实现从 SCDynamicStore 获取 VPN 状态"
```

---

### Task 3: 重构 AppController 使用新监控

**Files:**
- Modify: `RoutePilot/ViewModels/AppController.swift`

- [ ] **Step 1: 移除 NWPathMonitor 属性，添加新属性**

在 `AppController` 中，找到并修改：

```swift
// MARK: - 私有属性
private let configFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("RoutePilot/config.json")

// 删除这行:
// private var pathMonitor: NWPathMonitor?

private var previousVPNNames: Set<String> = []
private var isCheckingVPN = false
```

- [ ] **Step 2: 修改 init() 方法**

修改 `private init()`：

```swift
private init() {
    loadConfig()
    Task { await loadLogs() }
    checkPasswordless()
    refreshSystemVPNs()
    startVPNMonitoring()  // 替换原来的 startNetworkMonitor()
}
```

- [ ] **Step 3: 实现 startVPNMonitoring 方法**

在 `AppController` 中添加：

```swift
// MARK: - VPN 监控
private func startVPNMonitoring() {
    Task {
        await VPNService.shared.startMonitoring { [weak self] vpnName in
            guard let self = self else { return }
            self.handleVPNStatusChange(vpnName: vpnName)
        }
    }
    NSLog("[RoutePilot] VPN 监控已启动")

    // 首次检查
    checkVPNStatus()
}
```

- [ ] **Step 4: 实现 handleVPNStatusChange 方法**

在 `AppController` 中添加：

```swift
private func handleVPNStatusChange(vpnName: String?) {
    guard let vpnName = vpnName else {
        // 接口变化但无法确定 VPN 名称，执行完整检查
        checkVPNStatus()
        return
    }

    NSLog("[RoutePilot] VPN 状态变化: \(vpnName)")

    // 更新 VPN 状态
    Task {
        let result = await VPNService.shared.getVPNStatusFromStore()
        self.activeVPNs = result
        self.vpnConnected = !result.isEmpty

        // 更新 previousVPNNames
        let currentNames = Set(result.map { $0.name })
        let wasConnected = self.previousVPNNames.contains(vpnName)
        let nowConnected = currentNames.contains(vpnName)

        self.previousVPNNames = currentNames

        // 处理连接/断开
        if nowConnected && !wasConnected {
            self.log("检测到 VPN 连接: \(vpnName)", level: .info, vpnName: vpnName)
            self.autoAddRoutes(for: vpnName)
        } else if !nowConnected && wasConnected {
            self.log("检测到 VPN 断开: \(vpnName)", level: .info, vpnName: vpnName)
        }
    }
}
```

- [ ] **Step 5: 简化 checkVPNStatus 方法**

修改 `checkVPNStatus()` 方法：

```swift
private func checkVPNStatus() {
    guard !isCheckingVPN else {
        NSLog("[RoutePilot] checkVPNStatus 跳过：正在检查中")
        return
    }
    isCheckingVPN = true
    NSLog("[RoutePilot] checkVPNStatus 开始")

    Task {
        // 使用 SCDynamicStore 获取 VPN 状态
        let result = await VPNService.shared.getVPNStatusFromStore()

        let previousNames = self.previousVPNNames
        let currentNames = Set(result.map { $0.name })

        NSLog("[RoutePilot] 之前连接: \(previousNames), 当前连接: \(currentNames)")

        self.activeVPNs = result
        self.vpnConnected = !result.isEmpty

        // 检测新连接的 VPN
        let newlyConnected = currentNames.subtracting(previousNames)
        let isFirstCheck = previousNames.isEmpty
        let vpnToProcess = isFirstCheck ? currentNames : newlyConnected

        NSLog("[RoutePilot] 新连接的 VPN: \(newlyConnected), 首次检查: \(isFirstCheck)")

        for vpnName in vpnToProcess {
            self.log("检测到 VPN 连接: \(vpnName)", level: .info, vpnName: vpnName)
            self.autoAddRoutes(for: vpnName)
        }

        self.previousVPNNames = currentNames
        self.isCheckingVPN = false
    }
}
```

- [ ] **Step 6: 提交**

```bash
git add RoutePilot/ViewModels/AppController.swift
git commit -m "refactor: 使用 SCDynamicStore 替换 NWPathMonitor"
```

---

### Task 4: 实现 enabled 字段立即检查逻辑

**Files:**
- Modify: `RoutePilot/ViewModels/AppController.swift`

- [ ] **Step 1: 添加 toggleVPNEnabled 方法**

在 `AppController` 中找到路由配置部分，添加：

```swift
// MARK: - VPN 开关
func toggleVPNEnabled(_ enabled: Bool, for vpnName: String) {
    if let index = vpnConfigs.firstIndex(where: { $0.name == vpnName }) {
        vpnConfigs[index].enabled = enabled
        saveConfig()

        if enabled {
            log("已启用 \(vpnName)", level: .success, vpnName: vpnName)
            // 立即检查该 VPN 是否已连接
            checkVPNAndAddRoutes(vpnName)
        } else {
            log("已禁用 \(vpnName)", level: .info, vpnName: vpnName)
        }
    }
}

/// 检查并处理单个 VPN
func checkVPNAndAddRoutes(_ vpnName: String) {
    // 检查该 VPN 是否已连接
    if let vpnStatus = activeVPNs.first(where: { $0.name == vpnName }) {
        // 已连接，触发路由添加
        autoAddRoutes(for: vpnName)
    } else {
        log("VPN \(vpnName) 未连接", level: .info, vpnName: vpnName)
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add RoutePilot/ViewModels/AppController.swift
git commit -m "feat: VPN enabled 切换时立即检查连接状态"
```

---

### Task 5: 清理旧代码

**Files:**
- Modify: `RoutePilot/ViewModels/AppController.swift`
- Modify: `RoutePilot/Services/VPNService.swift`

- [ ] **Step 1: 删除 VPNService 中旧的 NWPathMonitor 相关代码**

在 `VPNService.swift` 中，删除：

```swift
// 删除这个属性
private var pathMonitor: NWPathMonitor?
```

保留 `getSystemVPNs()` 和 `getConnectedVPNs()` 方法（仍可用于初始化获取列表）。

- [ ] **Step 2: 删除 AppController 中旧的 startNetworkMonitor 方法**

在 `AppController.swift` 中，删除整个 `startNetworkMonitor()` 方法：

```swift
// 删除这个方法
private func startNetworkMonitor() {
    // ... 整个方法删除
}
```

- [ ] **Step 3: 删除未使用的 import**

在 `AppController.swift` 中，如果 `Network` 不再使用，删除：

```swift
import Network  // 删除这行
```

- [ ] **Step 4: 提交**

```bash
git add RoutePilot/ViewModels/AppController.swift RoutePilot/Services/VPNService.swift
git commit -m "refactor: 清理 NWPathMonitor 相关代码"
```

---

### Task 6: 构建验证

- [ ] **Step 1: 构建项目**

```bash
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 2: 最终提交**

```bash
git add -A
git commit -m "feat: VPN 监控重构完成

- 使用 SCDynamicStore 替换 NWPathMonitor
- 精确监听 VPN 连接/断开事件
- 支持多种 VPN 类型（ppp, utun, ipsec）
- VPN enabled 切换时立即检查连接状态

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
git push
```

---

## 测试清单

手动测试以下场景：

1. [ ] 启动应用，VPN 未连接时状态正确
2. [ ] 连接单个 VPN，自动添加路由
3. [ ] 断开 VPN，状态更新正确
4. [ ] 同时连接多个 VPN，各自独立处理
5. [ ] 禁用 VPN 后连接，不添加路由
6. [ ] 启用已连接的 VPN，立即添加路由
7. [ ] 不同 VPN 类型（L2TP、Cisco IPSec）都能识别