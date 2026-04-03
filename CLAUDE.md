# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

RoutePilot 是一个 macOS 菜单栏应用，用于自动管理 VPN 路由。当 VPN 连接时，自动通过 VPN 接口添加配置的路由规则。支持多个 VPN 同时连接，每个 VPN 可独立配置路由规则。

## 构建命令

```bash
# 构建项目
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build

# 清理构建
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot clean

# 运行应用（构建后）
open ~/Library/Developer/Xcode/DerivedData/RoutePilot-*/Build/Products/Debug/RoutePilot.app
```

## 架构说明

### 目录结构

```
RoutePilot/
├── App/           # 应用入口
├── Models/        # 数据模型
├── Views/         # SwiftUI 视图
├── ViewModels/    # 状态管理
├── Services/      # 业务服务
└── Utils/         # 工具类
```

### 核心组件

**AppController** (`ViewModels/AppController.swift`) - 主控制器，ObservableObject 单例
- 系统状态：VPN 列表、连接状态、路由表
- 用户配置：每个 VPN 的路由规则和自定义接口
- 网络监控：NWPathMonitor 监听变化，自动触发路由添加

**VPNService** (`Services/VPNService.swift`) - VPN 检测服务 (Actor)
- 获取系统 VPN 列表和连接状态
- 解析 `scutil --nc list` 输出
- 自动检测或使用自定义接口名

**RouteService** (`Services/RouteService.swift`) - 路由操作服务 (Actor)
- 添加/删除路由规则
- 免密授权配置（sudoers.d）
- 权限处理：免密模式 or AppleScript 系统授权

**LogService** (`Services/LogService.swift`) - 日志服务 (Actor)
- 日志文件：`~/Library/Logs/RoutePilot/operations.log`
- 支持分级：debug、info、success、warning、error

**ShellRunner** (`Utils/ShellRunner.swift`) - Shell 命令执行工具 (Actor)
- 执行系统命令并返回输出
- 执行 AppleScript 获取管理员权限

### 关键系统命令

| 功能 | 命令 |
|------|------|
| VPN 列表 | `scutil --nc list` |
| VPN 状态 | `scutil --nc status "VPN名"` |
| 接口状态 | `ifconfig ppp0` |
| 路由表 | `netstat -rn` |
| 添加路由 | `route add 10.0.0.0/8 -interface ppp0` |
| 删除路由 | `route delete 10.0.0.0/8 -interface ppp0` |

### VPN 状态监控

使用 `NWPathMonitor` 监听网络变化：
1. 网络变化触发 `checkVPNStatus()`
2. 解析已连接 VPN，获取接口名
3. 对比 `previousVPNNames` 检测新连接
4. 对新连接 VPN 自动调用 `autoAddRoutes()`

### 自定义接口

每个 VPN 可设置 `customInterface`：
- 手动指定接口名（如 `ppp0`、`utun4`）
- 优先级高于自动检测
- 设置后验证接口是否 UP 和 RUNNING

### 权限处理

两种执行路由命令方式：
1. **免密模式**：配置 `/etc/sudoers.d/autoroute`
2. **系统授权**：AppleScript `do shell script ... with administrator privileges`

### 配置持久化

- 配置文件：`~/Library/Application Support/RoutePilot/config.json`
- 日志文件：`~/Library/Logs/RoutePilot/operations.log`

## 调试命令

```bash
# 查看已连接 VPN
scutil --nc list | grep Connected

# 查看路由表
netstat -rn | grep ppp

# 查看接口状态
ifconfig ppp0

# 查看日志
cat ~/Library/Logs/RoutePilot/operations.log

# 检查免密配置
cat /etc/sudoers.d/autoroute
```

## 发布流程

```bash
# 创建版本标签触发 CI 和 Release
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 工作流：
- **CI** (`.github/workflows/ci.yml`) - 每次 push/PR 验证构建
- **Release** (`.github/workflows/release.yml`) - 打标签时打包发布 DMG

## 注意事项

- **沙盒限制**：启用 App Sandbox 可能限制文件写入和系统命令执行
- **VPN 类型**：L2TP/IPSec 使用 `ppp0`，其他 VPN 可能使用 `utun` 接口
- **多 VPN**：同时连接多个 VPN 时，每个有独立接口名
- **路由残留**：VPN 断开后手动添加的路由可能残留，需手动清理