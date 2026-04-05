# RoutePilot

<a href="https://github.com/tdragon8113/route-pilot/releases">
  <img src="https://img.shields.io/github/v/release/tdragon8113/route-pilot?style=flat-square" alt="Release">
</a>
<a href="https://github.com/tdragon8113/route-pilot/blob/main/LICENSE">
  <img src="https://img.shields.io/github/license/tdragon8113/route-pilot?style=flat-square" alt="License">
</a>
<a href="https://github.com/tdragon8113/route-pilot/actions">
  <img src="https://img.shields.io/github/actions/workflow/status/tdragon8113/route-pilot/ci.yml?branch=main&style=flat-square" alt="CI">
</a>

macOS 菜单栏应用，自动管理 VPN 路由规则。VPN 连接时自动添加预设路由，支持域名解析和多 VPN 管理。

## 功能特性

| 功能 | 说明 |
|------|------|
| 🔄 自动路由 | VPN 连接时自动添加预设路由，退出应用后仍生效 |
| 🌐 域名支持 | 支持 `github.com` 等域名格式，自动解析 IP |
| 👥 多 VPN 管理 | 每个 VPN 独立配置路由规则，支持启用/禁用 |
| 🔀 拖拽排序 | 调整规则优先级，灵活控制路由顺序 |
| 🌍 国际化 | 支持中文/英文，实时切换 |
| 🌙 主题切换 | 浅色/深色/跟随系统，深色模式优化 |
| 🔐 免密授权 | 配置一次，告别重复密码输入 |
| 🚀 开机启动 | 可选开机自动运行 |
| 🛠️ 网络工具 | Ping、DNS 查询、端口测试、路由追踪 |

## 安装

### Homebrew（推荐）

```bash
brew tap tdragon8113/tap
brew install --cask route-pilot
```

### 下载 DMG

从 [Releases](https://github.com/tdragon8113/route-pilot/releases) 下载最新版本。

首次打开如提示"无法验证开发者"，请右键点击应用 → 打开 → 点击"打开"。

### 手动构建

```bash
git clone https://github.com/tdragon8113/route-pilot.git
cd route-pilot
./scripts/build-daemon.sh
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Release build
```

## 使用指南

### 快速开始

1. 启动应用 → 菜单栏显示天线图标
2. 启用后台服务 → 首页点击「启用」，一次授权完成全部配置
3. 选择 VPN → 从列表中点击要管理的 VPN
4. 添加路由 → 输入 `10.0.0.0/8` 或 `github.com`
5. 连接 VPN → 守护进程自动添加路由

### 路由规则示例

| 格式 | 示例 | 说明 |
|------|------|------|
| CIDR | `10.0.0.0/8` | 企业内网 |
| CIDR | `192.168.0.0/16` | 私有网络 |
| CIDR | `172.16.0.0/12` | Docker/K8s |
| 域名 | `github.com` | 自动解析 IP |

### 后台服务

首页点击「启用」即可一键完成免密授权和守护进程安装，之后即使退出应用，VPN 连接时仍会自动添加路由。

**授权时会执行**：
1. 配置免密授权 `/etc/sudoers.d/autoroute`（仅允许 `route add/delete`）
2. 复制守护进程到 `~/Library/Application Support/RoutePilot/`
3. 创建 LaunchAgent 并启动

**工作原理**：
- 守护进程通过 SCDynamicStore 监听 VPN 状态变化
- 事件驱动，无需轮询
- 与 GUI 共享配置文件

**日志位置**：`~/Library/Logs/RoutePilot/daemon.log`

## 常见问题

<details>
<summary><b>VPN 连接后路由没有自动添加？</b></summary>

1. 确认已安装守护进程（设置 → 后台服务）
2. 确认 VPN 在列表中且已启用
3. 检查是否配置了路由规则
4. 查看日志：`~/Library/Logs/RoutePilot/daemon.log`
</details>

<details>
<summary><b>守护进程和 GUI 会冲突吗？</b></summary>

不会。守护进程是唯一的自动路由执行者，GUI 只负责配置管理和手动操作。两者职责分离，无冲突。
</details>

<details>
<summary><b>支持哪些 VPN 类型？</b></summary>

- L2TP/IPSec
- Cisco IPSec
- IKEv2
- 使用系统网络扩展的第三方 VPN
</details>

<details>
<summary><b>域名路由的 IP 变化怎么办？</b></summary>

每次 VPN 连接时重新解析域名，自动获取最新 IP 地址。
</details>

## 文件位置

| 文件 | 路径 |
|-----|------|
| 配置 | `~/Library/Application Support/RoutePilot/config.json` |
| GUI 日志 | `~/Library/Logs/RoutePilot/operations.log` |
| 守护进程日志 | `~/Library/Logs/RoutePilot/daemon.log` |
| LaunchAgent | `~/Library/LaunchAgents/com.sunny.RoutePilotDaemon.plist` |
| 守护进程 | `~/Library/Application Support/RoutePilot/route-pilot-daemon` |

## 技术栈

- Swift 5.9 / SwiftUI
- Swift Actor 并发模型
- SCDynamicStore VPN 监控
- macOS 13.0+

## 项目结构

```
RoutePilot/
├── App/           # 应用入口
├── Models/        # 数据模型
├── Views/         # SwiftUI 视图
├── ViewModels/    # 状态管理
├── Services/      # VPN、路由、DNS、日志
├── Utils/         # 工具类
├── Daemon/        # 守护进程源码
└── scripts/       # 构建脚本
```

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md) 或 [Releases](https://github.com/tdragon8113/route-pilot/releases)。

## 许可证

[MIT License](LICENSE)