//
//  VPNMonitor.swift
//  RoutePilot
//

import Foundation

/// VPN 状态监控器
actor VPNMonitor {
    static let shared = VPNMonitor()

    // MARK: - 状态
    private(set) var activeVPNs: [VPNStatus] = []
    private var previousVPNNames: Set<String> = []
    private var isChecking = false

    // MARK: - 回调
    var onVPNConnected: (@Sendable (String) async -> Void)?
    var onVPDisconnected: (@Sendable (String) async -> Void)?
    var onStatusChanged: (@Sendable ([VPNStatus]) async -> Void)?

    /// 设置回调（从 MainActor 调用）
    func setCallbacks(
        onConnected: @escaping @Sendable (String) async -> Void,
        onDisconnected: @escaping @Sendable (String) async -> Void,
        onStatusChanged: @escaping @Sendable ([VPNStatus]) async -> Void
    ) {
        self.onVPNConnected = onConnected
        self.onVPDisconnected = onDisconnected
        self.onStatusChanged = onStatusChanged
    }

    // MARK: - 初始化
    private init() {}

    // MARK: - 监控
    func startMonitoring() async {
        await VPNService.shared.startMonitoring { [weak self] vpnName in
            Task {
                await self?.handleVPNStatusChange(vpnName: vpnName)
            }
        }
        NSLog("[RoutePilot] VPN 监控已启动")

        // 首次检查（延迟一下让 SCDynamicStore 准备好）
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        await checkStatus(enabledVPNNames: nil)
    }

    private func handleVPNStatusChange(vpnName: String?) async {
        guard let vpnName = vpnName else {
            // 接口变化但无法确定 VPN 名称，执行完整检查
            _ = await checkStatus(enabledVPNNames: nil)
            return
        }

        NSLog("[RoutePilot] VPN 状态变化: \(vpnName)")
        // 执行完整检查以获取最新状态
        _ = await checkStatus(enabledVPNNames: nil)
    }

    /// 检查 VPN 状态
    /// - Parameter enabledVPNNames: 已启用的 VPN 名称集合，用于过滤回调
    /// - Returns: 当前活跃的 VPN 列表
    @discardableResult
    func checkStatus(enabledVPNNames: Set<String>?) async -> [VPNStatus] {
        guard !isChecking else {
            NSLog("[RoutePilot] checkStatus 跳过：正在检查中")
            return activeVPNs
        }
        isChecking = true
        NSLog("[RoutePilot] checkStatus 开始")

        // 使用 SCDynamicStore 获取 VPN 状态
        let result = await VPNService.shared.getVPNStatusFromStore()

        let previousNames = previousVPNNames
        // 只统计已启用的 VPN
        let currentEnabledNames: Set<String>
        if let enabled = enabledVPNNames {
            currentEnabledNames = Set(result.filter { enabled.contains($0.name) }.map { $0.name })
        } else {
            currentEnabledNames = Set(result.map { $0.name })
        }

        NSLog("[RoutePilot] 之前连接: \(previousNames), 当前连接: \(currentEnabledNames)")

        activeVPNs = result

        // 检测新连接的 VPN
        let newlyConnected = currentEnabledNames.subtracting(previousNames)
        let newlyDisconnected = previousNames.subtracting(currentEnabledNames)
        let isFirstCheck = previousNames.isEmpty

        NSLog("[RoutePilot] 新连接: \(newlyConnected), 新断开: \(newlyDisconnected), 首次检查: \(isFirstCheck)")

        // 触发回调
        for vpnName in newlyConnected where !isFirstCheck {
            await onVPNConnected?(vpnName)
        }

        for vpnName in newlyDisconnected {
            await onVPDisconnected?(vpnName)
        }

        // 状态变化回调
        await onStatusChanged?(result)

        previousVPNNames = currentEnabledNames
        isChecking = false

        return result
    }

    /// 获取当前活跃 VPN
    func getActiveVPNs() -> [VPNStatus] {
        activeVPNs
    }

    /// 判断指定 VPN 是否连接
    func isConnected(_ vpnName: String) -> Bool {
        activeVPNs.contains { $0.name == vpnName }
    }
}