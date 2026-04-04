//
//  AppController.swift
//  RoutePilot
//

import Foundation
import SwiftUI
import Combine

/// 应用控制器
@MainActor
class AppController: ObservableObject {
    static let shared = AppController()

    // MARK: - 系统状态
    @Published var systemVPNs: [String] = []
    @Published var activeVPNs: [VPNStatus] = []
    @Published var vpnConnected: Bool = false

    // MARK: - 用户配置
    @Published var vpnConfigs: [VPNConfig] = []

    // MARK: - 系统状态
    @Published var passwordlessConfigured: Bool = false
    @Published var isProcessing: Bool = false
    @Published var isConfiguring: Bool = false

    // MARK: - 日志
    @Published var logs: [LogEntry] = []
    @Published var logFilter: LogEntry.LogLevel = .info

    // MARK: - 当前路由
    @Published var currentRoutes: [String] = []
    @Published var isLoadingRoutes: Bool = false

    // MARK: - 私有属性
    private let configFile = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("RoutePilot/config.json")

    private init() {
        loadConfig()
        Task { await loadLogs() }
        checkPasswordless()
        refreshSystemVPNs()
        startVPNMonitoring()
    }

    // MARK: - 辅助方法：更新 VPN 配置
    private func updateVPNConfig(_ name: String, transform: (inout VPNConfig) -> Void) {
        guard let index = vpnConfigs.firstIndex(where: { $0.name == name }) else { return }
        transform(&vpnConfigs[index])
        objectWillChange.send()
        saveConfig()
    }

    // MARK: - 系统VPN列表
    func refreshSystemVPNs() {
        Task {
            let vpns = await VPNService.shared.getSystemVPNs()

            var newConfigs: [VPNConfig] = []
            for vpn in vpns {
                if let existing = self.vpnConfigs.first(where: { $0.name == vpn }) {
                    newConfigs.append(existing)
                } else {
                    newConfigs.append(VPNConfig(name: vpn))
                }
            }

            self.systemVPNs = vpns
            self.vpnConfigs = newConfigs
            saveConfig()
        }
    }

    // MARK: - VPN 监控
    private func startVPNMonitoring() {
        Task {
            await VPNMonitor.shared.startMonitoring()

            // 设置回调
            await VPNMonitor.shared.setCallbacks(
                onConnected: { [weak self] vpnName in
                    await MainActor.run {
                        self?.handleVPNConnected(vpnName)
                    }
                },
                onDisconnected: { [weak self] vpnName in
                    await MainActor.run {
                        self?.handleVPDisconnected(vpnName)
                    }
                },
                onStatusChanged: { [weak self] statusList in
                    await MainActor.run {
                        self?.activeVPNs = statusList
                        self?.updateMenuBarStatus()
                    }
                }
            )
        }
    }

    private func handleVPNConnected(_ vpnName: String) {
        // 守护进程负责自动路由，GUI 只记录状态
        log("检测到 VPN 连接: \(vpnName)", level: .info, vpnName: vpnName)

        // 如果守护进程未安装，提示用户
        if !DaemonManager.isInstalled {
            log("守护进程未安装，自动路由功能不可用", level: .warning, vpnName: vpnName)
        }
    }

    private func handleVPDisconnected(_ vpnName: String) {
        log("检测到 VPN 断开: \(vpnName)", level: .info, vpnName: vpnName)
    }

    // MARK: - 路由配置
    func addRoute(_ destination: String, note: String? = nil, to vpnName: String) {
        // 判断路由类型
        let type: RouteType
        if destination.contains("/") {
            type = .cidr
        } else if DNSService.isDomain(destination) {
            type = .domain
            log("检测到域名类型路由: \(destination)", level: .info, vpnName: vpnName)
        } else {
            // 可能是单 IP，当作 CIDR 处理
            type = .cidr
        }

        log("添加路由规则: \(destination) -> \(vpnName)", vpnName: vpnName)
        if let index = vpnConfigs.firstIndex(where: { $0.name == vpnName }) {
            vpnConfigs[index].routes.append(RouteItem(destination: destination, type: type, note: note))
            saveConfig()
            log("路由规则已保存", level: .success, vpnName: vpnName)
        } else {
            log("未找到 VPN 配置: \(vpnName)", level: .error, vpnName: vpnName)
        }
    }

    // MARK: - VPN 显示控制
    /// 设置 VPN 启用状态
    func setVPNEnabled(_ vpnName: String, enabled: Bool) {
        updateVPNConfig(vpnName) { $0.enabled = enabled }
        updateMenuBarStatus()
    }

    /// 更新菜单栏图标状态
    private func updateMenuBarStatus() {
        // 只统计已启用的 VPN 连接状态
        vpnConnected = activeVPNs.contains { vpn in
            vpnConfigs.first { $0.name == vpn.name }?.enabled ?? false
        }
    }

    /// 隐藏 VPN
    func hideVPN(_ vpnName: String) {
        updateVPNConfig(vpnName) { $0.hidden = true }
    }

    /// 显示单个隐藏的 VPN
    func showVPN(_ vpnName: String) {
        updateVPNConfig(vpnName) { $0.hidden = false }
    }

    /// 显示所有隐藏的 VPN
    func showAllHiddenVPNs() {
        for i in vpnConfigs.indices {
            vpnConfigs[i].hidden = false
        }
        objectWillChange.send()
        saveConfig()
        updateMenuBarStatus()
    }

    /// 是否有隐藏的 VPN
    var hasHiddenVPNs: Bool {
        vpnConfigs.contains { $0.hidden }
    }

    /// 获取可见的 VPN 配置列表
    var visibleVPNConfigs: [VPNConfig] {
        vpnConfigs.filter { !$0.hidden }
    }

    func removeRoute(_ route: RouteItem, from vpnName: String) {
        updateVPNConfig(vpnName) { $0.routes.removeAll { $0.id == route.id } }
    }

    func toggleRoute(_ route: RouteItem, in vpnName: String, enabled: Bool) {
        updateVPNConfig(vpnName) { config in
            if let routeIndex = config.routes.firstIndex(where: { $0.id == route.id }) {
                config.routes[routeIndex].enabled = enabled
            }
        }
    }

    func updateNote(_ note: String?, for route: RouteItem, in vpnName: String) {
        updateVPNConfig(vpnName) { config in
            if let routeIndex = config.routes.firstIndex(where: { $0.id == route.id }) {
                config.routes[routeIndex].note = note
            }
        }
    }

    func moveRoute(_ route: RouteItem, in vpnName: String, direction: MoveDirection) {
        guard let vpnIndex = vpnConfigs.firstIndex(where: { $0.name == vpnName }),
              let routeIndex = vpnConfigs[vpnIndex].routes.firstIndex(where: { $0.id == route.id }) else { return }

        let routes = vpnConfigs[vpnIndex].routes
        let newIndex: Int

        switch direction {
        case .up:
            guard routeIndex > 0 else { return }
            newIndex = routeIndex - 1
        case .down:
            guard routeIndex < routes.count - 1 else { return }
            newIndex = routeIndex + 1
        }

        vpnConfigs[vpnIndex].routes.swapAt(routeIndex, newIndex)
        saveConfig()
    }

    func moveRoute(_ route: RouteItem, toPositionOf target: RouteItem, in vpnName: String) {
        guard let vpnIndex = vpnConfigs.firstIndex(where: { $0.name == vpnName }),
              let fromIndex = vpnConfigs[vpnIndex].routes.firstIndex(where: { $0.id == route.id }),
              let toIndex = vpnConfigs[vpnIndex].routes.firstIndex(where: { $0.id == target.id }) else { return }

        var config = vpnConfigs[vpnIndex]
        let routeToMove = config.routes.remove(at: fromIndex)
        let adjustedToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
        config.routes.insert(routeToMove, at: adjustedToIndex)
        vpnConfigs[vpnIndex] = config
        saveConfig()
    }

    func moveRouteToIndex(_ route: RouteItem, toIndex: Int, in vpnName: String) {
        guard let vpnIndex = vpnConfigs.firstIndex(where: { $0.name == vpnName }),
              let fromIndex = vpnConfigs[vpnIndex].routes.firstIndex(where: { $0.id == route.id }) else { return }

        guard fromIndex != toIndex else { return }

        var config = vpnConfigs[vpnIndex]
        let routeToMove = config.routes.remove(at: fromIndex)
        let insertIndex = fromIndex < toIndex ? toIndex : toIndex
        config.routes.insert(routeToMove, at: insertIndex)
        vpnConfigs[vpnIndex] = config
        saveConfig()
    }

    func moveRoutes(in vpnName: String, from source: IndexSet, to destination: Int) {
        guard let vpnIndex = vpnConfigs.firstIndex(where: { $0.name == vpnName }) else { return }
        vpnConfigs[vpnIndex].routes.move(fromOffsets: source, toOffset: destination)
        saveConfig()
    }

    enum MoveDirection {
        case up, down
    }

    // MARK: - 路由操作
    func addRoutes(for vpnName: String) {
        guard let config = vpnConfigs.first(where: { $0.name == vpnName }) else { return }
        let routes = config.routes.filter { $0.enabled }
        guard !routes.isEmpty else {
            log("没有启用的路由规则", level: .info, vpnName: vpnName)
            return
        }

        guard let vpnStatus = activeVPNs.first(where: { $0.name == vpnName }) else {
            log("VPN \(vpnName) 未连接", level: .error, vpnName: vpnName)
            return
        }

        isProcessing = true
        let interface = vpnStatus.interface ?? "ppp0"
        log("正在为 \(vpnName) 添加 \(routes.count) 条路由...", vpnName: vpnName)

        Task {
            // 同步免密状态
            let actuallyPasswordless = await RouteService.shared.isPasswordlessConfigured
            if passwordlessConfigured != actuallyPasswordless {
                passwordlessConfigured = actuallyPasswordless
                saveConfig()
            }

            let result = await RouteService.shared.addRoutes(routes: routes, interface: interface)

            isProcessing = false
            if result.success {
                log("成功添加 \(routes.count) 条路由到 \(interface)", level: .success, vpnName: vpnName)
            } else {
                log("添加路由失败: \(result.error ?? "未知错误")", level: .error, vpnName: vpnName)
            }
        }
    }

    func removeRoutes(for vpnName: String) {
        guard let config = vpnConfigs.first(where: { $0.name == vpnName }) else { return }

        guard let vpnStatus = activeVPNs.first(where: { $0.name == vpnName }) else {
            log("VPN \(vpnName) 未连接", level: .error, vpnName: vpnName)
            return
        }

        isProcessing = true
        let interface = vpnStatus.interface ?? "ppp0"
        log("正在清理 \(vpnName) 的路由...", vpnName: vpnName)

        Task {
            // 同步免密状态
            let actuallyPasswordless = await RouteService.shared.isPasswordlessConfigured
            if passwordlessConfigured != actuallyPasswordless {
                passwordlessConfigured = actuallyPasswordless
                saveConfig()
            }

            let success = await RouteService.shared.removeRoutes(routes: config.routes, interface: interface)

            isProcessing = false
            if success {
                log("已清理路由", level: .success, vpnName: vpnName)
            } else {
                log("清理路由失败", level: .error, vpnName: vpnName)
            }
        }
    }

    // MARK: - 免密配置
    func checkPasswordless() {
        Task {
            passwordlessConfigured = await RouteService.shared.isPasswordlessConfigured
        }
    }

    func configurePasswordless() {
        isConfiguring = true
        log("正在配置免密授权...")

        Task {
            let success = await RouteService.shared.configurePasswordless()

            isConfiguring = false
            if success {
                passwordlessConfigured = true
                saveConfig()
                log("免密授权配置成功", level: .success)
            } else {
                log("免密授权配置失败", level: .error)
            }
        }
    }

    func removePasswordless() {
        isConfiguring = true
        log("正在移除免密授权...")

        Task {
            let success = await RouteService.shared.removePasswordless()

            isConfiguring = false
            if success {
                passwordlessConfigured = false
                saveConfig()
                log("已移除免密授权", level: .success)
            } else {
                log("移除免密授权失败", level: .error)
            }
        }
    }

    // MARK: - 日志
    private func log(_ message: String, level: LogEntry.LogLevel = .info, vpnName: String? = nil) {
        let entry = LogEntry(time: Date(), vpnName: vpnName, message: message, level: level)

        // 更新内存日志列表
        logs.insert(entry, at: 0)
        if logs.count > 500 {
            logs.removeLast()
        }

        // 写入日志文件
        Task { await LogService.shared.append(entry) }
    }

    private func loadLogs() async {
        logs = await LogService.shared.loadLogs()
    }

    func clearLogs() {
        logs.removeAll()
        Task { await LogService.shared.clearLogs() }
    }

    /// 过滤后的日志
    var filteredLogs: [LogEntry] {
        let levels: [LogEntry.LogLevel] = {
            switch logFilter {
            case .debug: return [.debug, .info, .success, .warning, .error]
            case .info: return [.info, .success, .warning, .error]
            case .success: return [.success, .warning, .error]
            case .warning: return [.warning, .error]
            case .error: return [.error]
            }
        }()
        return logs.filter { levels.contains($0.level) }
    }

    // MARK: - 获取当前路由
    func fetchCurrentRoutes(interface: String) {
        isLoadingRoutes = true
        currentRoutes = []

        Task {
            let routes = await VPNService.shared.getCurrentRoutes(interface: interface)
            self.currentRoutes = routes
            self.isLoadingRoutes = false
        }
    }

    // MARK: - 持久化
    private func loadConfig() {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(Config.self, from: data) else { return }

        vpnConfigs = config.vpnConfigs
        passwordlessConfigured = config.passwordlessConfigured
    }

    func saveConfig() {
        let config = Config(vpnConfigs: vpnConfigs, passwordlessConfigured: passwordlessConfigured)

        try? FileManager.default.createDirectory(at: configFile.deletingLastPathComponent(), withIntermediateDirectories: true)

        if let data = try? JSONEncoder().encode(config) {
            try? data.write(to: configFile)
        }
    }

    private struct Config: Codable {
        let vpnConfigs: [VPNConfig]
        let passwordlessConfigured: Bool
    }
}