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
| 🔄 自动检测 | 实时监听 VPN 连接状态，无需手动干预 |
| 🌐 域名支持 | 支持 `github.com` 等域名格式，自动解析 IP |
| 📋 多 VPN 管理 | 每个 VPN 独立配置路由规则 |
| 🎛️ 显示控制 | 启用/禁用自动路由，隐藏不常用的 VPN |
| 🔀 拖拽排序 | 调整规则优先级，灵活控制路由顺序 |
| 🔐 免密授权 | 配置一次，告别重复密码输入 |
| 🚀 开机启动 | 可选开机自动运行 |

## 应用截图

<img src="assets/主页.png" alt="主界面" width="200">

## 安装

### 下载 DMG（推荐）

从 [Releases](https://github.com/tdragon8113/route-pilot/releases) 下载最新版本。

### 手动构建

```bash
git clone https://github.com/tdragon8113/route-pilot.git
cd route-pilot
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Release build
```

## 使用指南

### 快速开始

1. 启动应用 → 菜单栏显示天线图标
2. 选择 VPN → 从列表中点击要管理的 VPN
3. 添加路由 → 输入 `10.0.0.0/8` 或 `github.com`
4. 连接 VPN → 自动添加路由

### 路由规则示例

| 格式 | 示例 | 说明 |
|------|------|------|
| CIDR | `10.0.0.0/8` | 企业内网 |
| CIDR | `192.168.0.0/16` | 私有网络 |
| CIDR | `172.16.0.0/12` | Docker/K8s |
| 域名 | `github.com` | 自动解析 IP |

### 免密授权

路由操作需要管理员权限，推荐配置免密：

**应用内配置**：设置 → 权限设置 → 配置

**手动配置**：
```bash
sudo echo "$(whoami) ALL=(ALL) NOPASSWD: /sbin/route" | sudo tee /etc/sudoers.d/autoroute
sudo chmod 440 /etc/sudoers.d/autoroute
```

## 常见问题

<details>
<summary><b>VPN 连接后路由没有自动添加？</b></summary>

1. 确认 VPN 在列表中且已启用
2. 检查是否配置了路由规则
3. 查看日志：`~/Library/Logs/RoutePilot/operations.log`
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
| 日志 | `~/Library/Logs/RoutePilot/operations.log` |

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
└── Utils/         # 工具类
```

## 更新日志

详见 [CHANGELOG.md](CHANGELOG.md) 或 [Releases](https://github.com/tdragon8113/route-pilot/releases)。

## 许可证

[MIT License](LICENSE)