# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

RoutePilot 是一个 macOS 菜单栏应用，用于自动管理 VPN 路由。采用 GUI + 守护进程架构，即使退出应用，VPN 连接时仍会自动添加预设路由规则。

## 构建命令

```bash
# 构建守护进程（需要先执行）
./scripts/build-daemon.sh

# 构建项目（会自动打包守护进程到 app）
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build

# 运行应用
open ~/Library/Developer/Xcode/DerivedData/RoutePilot-*/Build/Products/Debug/RoutePilot.app
```

## 架构说明

### 整体架构

```
┌─────────────────────────────────────────────┐
│           RoutePilot GUI 应用                │
│  - 配置管理（VPN、路由规则）                  │
│  - 手动操作（一键添加/删除路由）              │
│  - 安装/卸载守护进程                          │
└──────────────────┬──────────────────────────┘
                   │ 共享配置文件
                   ▼
┌─────────────────────────────────────────────┐
│         RoutePilotDaemon（守护进程）          │
│  - SCDynamicStore 事件监听 VPN 状态          │
│  - 自动执行路由添加                           │
│  - launchd 管理（LaunchAgent）               │
└─────────────────────────────────────────────┘
```

### 目录结构

```
RoutePilot/
├── App/           # 应用入口
├── Models/        # 数据模型（VPNConfig、RouteItem）
├── Views/         # SwiftUI 视图
├── ViewModels/    # 状态管理（AppController）
├── Services/      # 业务服务（VPN、路由、DNS、日志）
├── Utils/         # 工具类（DaemonManager、LoginServiceKit）
├── Daemon/        # 守护进程源码
└── scripts/       # 构建脚本
```

### 核心组件

**AppController** (`ViewModels/AppController.swift`)
- 主控制器，ObservableObject 单例
- VPN 配置管理、状态展示
- 不再自动添加路由（由守护进程负责）

**VPNMonitor** (`ViewModels/VPNMonitor.swift`) - Actor
- SCDynamicStore 监听 VPN 状态变化
- 事件驱动，通知 GUI 更新界面

**VPNService** (`Services/VPNService.swift`) - Actor
- 获取系统 VPN 列表和连接状态
- 解析 `scutil --nc list` 输出

**RouteService** (`Services/RouteService.swift`) - Actor
- 添加/删除路由规则
- 免密授权配置（sudoers.d）

**DaemonManager** (`Utils/DaemonManager.swift`)
- 安装/卸载/启动/停止守护进程
- 生成 LaunchAgent plist

**RoutePilotDaemon** (`Daemon/main.swift`)
- 独立进程，通过 SCDynamicStore 监听 VPN
- 读取共享配置，自动执行路由
- 日志：`~/Library/Logs/RoutePilot/daemon.log`

### 关键系统命令

| 功能 | 命令 |
|------|------|
| VPN 列表 | `scutil --nc list` |
| VPN 状态 | `scutil --nc status "VPN名"` |
| 接口状态 | `ifconfig ppp0` |
| 路由表 | `netstat -rn` |
| 添加路由 | `route add 10.0.0.0/8 -interface ppp0` |
| 删除路由 | `route delete 10.0.0.0/8 -interface ppp0` |

### 权限处理

路由操作需要 root 权限：
1. **免密模式**：配置 `/etc/sudoers.d/autoroute`（推荐）
2. **系统授权**：AppleScript `do shell script ... with administrator privileges`

守护进程执行路由时使用 `sudo route add ...`，依赖免密授权。

### 配置持久化

- 配置文件：`~/Library/Application Support/RoutePilot/config.json`
- GUI 日志：`~/Library/Logs/RoutePilot/operations.log`
- 守护进程日志：`~/Library/Logs/RoutePilot/daemon.log`
- 守护进程二进制：`~/Library/Application Support/RoutePilot/route-pilot-daemon`

## 调试命令

```bash
# 查看已连接 VPN
scutil --nc list | grep Connected

# 查看路由表
netstat -rn | grep -E "ppp|utun"

# 查看守护进程状态
launchctl list | grep RoutePilot
ps aux | grep route-pilot-daemon

# 查看守护进程日志
tail -f ~/Library/Logs/RoutePilot/daemon.log

# 手动控制守护进程
launchctl load ~/Library/LaunchAgents/com.sunny.RoutePilotDaemon.plist
launchctl unload ~/Library/LaunchAgents/com.sunny.RoutePilotDaemon.plist
```

## 发布流程

**重要：必须先更新 CHANGELOG，再创建 tag，否则 Release 页面不会显示变更日志。**

```bash
# 1. 更新 CHANGELOG.md，添加新版本的变更记录

# 2. 提交 CHANGELOG 更新
git add CHANGELOG.md
git commit -m "docs: 更新 CHANGELOG v1.x.x"
git push origin main

# 3. 创建版本标签并推送（触发 CI 和 Release）
git tag v1.x.x
git push origin main --tags
```

GitHub Actions 工作流：
- **CI** (`.github/workflows/ci.yml`) - 构建 daemon + 验证构建
- **Release** (`.github/workflows/release.yml`) - 打包发布 DMG + 自动更新 Homebrew tap

**自动化流程**：
1. 构建 DMG 并上传到 Release
2. 提取 CHANGELOG 对应版本内容
3. 自动更新 Homebrew tap 的版本号和 SHA256

**前置配置**：
- 需要在仓库 Secrets 中配置 `TAP_TOKEN`（有 repo 权限的 Personal Access Token）

如果发布出错需要重新发布：
```bash
# 删除本地和远程 tag
git tag -d v1.x.x
git push origin :refs/tags/v1.x.x

# 删除 GitHub Release（如果已创建）
gh release delete v1.x.x -y

# 修正后重新创建 tag
git tag v1.x.x
git push origin main --tags
```

## 注意事项

- **守护进程依赖免密授权**：必须先配置 `/etc/sudoers.d/autoroute`
- **VPN 类型**：L2TP/IPSec 使用 `ppp0`，IKEv2 使用 `utun`
- **多 VPN**：同时连接多个 VPN 时，守护进程分别处理
- **配置共享**：GUI 和守护进程读取同一配置文件

## 后续计划

| 项目 | 说明 | 优先级 |
|------|------|--------|
| 多语言扩展 | 添加日文、韩文等 | 低 |
| 单元测试 | 提高代码质量，覆盖率 80%+ | 中 |
| CI 优化 | Release 后自动更新 Homebrew tap SHA256 | 中 |
| 官方 Homebrew | 项目 star 100+ 后申请加入官方 Cask | 低 |
| 代码签名 | $99/年 Apple Developer，解决首次打开警告 | 低 |