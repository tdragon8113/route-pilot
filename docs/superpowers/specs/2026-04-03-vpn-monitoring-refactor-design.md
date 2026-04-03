# VPN 监控重构设计

**日期**: 2026-04-03
**主题**: 将 NWPathMonitor 重构为 SCDynamicStore

## 背景

当前使用 `NWPathMonitor` 监听网络变化，存在问题：
- 只监听"网络路径可用性"，不精确监听 VPN 状态
- 多个 VPN 场景可能漏触发
- 无法区分具体哪个 VPN 连接/断开

## 目标

- 精确监听 VPN 连接/断开事件
- 支持多种 VPN 类型（L2TP/IPSec、Cisco IPSec 等）
- 从 SCDynamicStore 直接获取 VPN 状态和接口名
- 每个 VPN 可独立控制是否启用监控

## 设计决策

| 需求 | 决定 |
|------|------|
| 监听事件 | VPN 连接/断开 |
| 接口获取 | 从 SCDynamicStore 直接获取 |
| NWPathMonitor | 完全移除 |
| 监听范围 | 所有网络接口 |
| VPN 控制 | 复用 enabled 字段 |
| 启用后行为 | 立即检查已连接 VPN |

## 架构变更

### 当前架构

```
AppController
    └── NWPathMonitor.pathUpdateHandler
            └── checkVPNStatus()
                    └── VPNService.getConnectedVPNs()
                            └── scutil --nc list
                            └── scutil --nc status
```

### 重构后架构

```
AppController
    └── VPNService.startMonitoring(callback)
            └── SCDynamicStore
                    └── 监听 State:/Network/Interface/.*/IPv4
                    └── 回调接口变化
                    └── 获取 VPN 状态和接口名
```

## 组件改造

### VPNService

```swift
actor VPNService {
    // 新增
    private var store: SCDynamicStore?

    /// 启动 SCDynamicStore 监听
    func startMonitoring(callback: @escaping @MainActor (String?) -> Void)

    /// 停止监听
    func stopMonitoring()

    /// 从 SCDynamicStore 获取 VPN 状态
    func getVPNStatusFromStore() -> [VPNStatus]

    /// 获取接口对应的 VPN 名称
    private func getVPNNameForInterface(_ interface: String) -> String?

    // 移除：NWPathMonitor 相关逻辑
}
```

### AppController

```swift
class AppController {
    // 移除
    // private var pathMonitor: NWPathMonitor?

    // 修改 init()
    private init() {
        loadConfig()
        Task { await loadLogs() }
        checkPasswordless()
        refreshSystemVPNs()
        startVPNMonitoring()  // 新方法
    }

    /// 启动 VPN 监控
    private func startVPNMonitoring()

    /// 处理 VPN 状态变化
    private func handleVPNStatusChange(vpnName: String?)

    /// 检查并处理单个 VPN
    func checkVPNAndAddRoutes(_ vpnName: String)
}
```

## 监听策略

### SCDynamicStore Keys

监听所有网络接口的 IPv4 配置变化：

```swift
let patterns = [
    "State:/Network/Interface/.*/IPv4"
]
```

### VPN 接口识别

| 接口前缀 | VPN 类型 |
|---------|---------|
| ppp* | L2TP/IPSec |
| utun* | Cisco IPSec, 其他 |
| ipsec* | IPSec |

### 回调处理流程

```
1. 接口 IPv4 配置变化
2. 过滤 VPN 相关接口（ppp*, utun*, ipsec*）
3. 获取接口对应的 VPN 名称
4. 检查 VPNConfig.enabled
5. enabled=true → 触发路由处理
```

## enabled 字段逻辑

### 状态变更处理

```swift
func setVPNEnabled(_ enabled: Bool, for vpnName: String) {
    // 更新配置
    vpnConfigs[index].enabled = enabled
    saveConfig()

    if enabled {
        // 立即检查该 VPN 是否已连接
        checkVPNAndAddRoutes(vpnName)
    }
}
```

### 自动添加路由条件

```swift
func autoAddRoutes(for vpnName: String) {
    guard let config = vpnConfigs.first(where: { $0.name == vpnName }) else { return }
    guard config.enabled else {
        log("VPN \(vpnName) 已禁用，跳过")
        return
    }
    // 添加路由...
}
```

## 文件变更

| 文件 | 变更 |
|------|------|
| `VPNService.swift` | 重构，移除 NWPathMonitor，新增 SCDynamicStore |
| `AppController.swift` | 移除 NWPathMonitor，新增 startVPNMonitoring |

## 测试要点

1. 单个 VPN 连接/断开，路由正确添加/移除
2. 多个 VPN 同时连接，各自独立处理
3. 禁用 VPN 后连接，不添加路由
4. 启用已连接的 VPN，立即添加路由
5. 不同 VPN 类型（L2TP、Cisco IPSec）都能识别