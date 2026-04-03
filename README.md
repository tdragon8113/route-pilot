# RoutePilot

macOS 菜单栏应用，自动管理 VPN 路由规则。

## 功能

- 自动检测 VPN 连接状态
- VPN 连接时自动添加配置的路由规则
- 支持多个 VPN 同时连接，每个 VPN 可独立配置路由
- 自定义 VPN 接口名（支持 L2TP/IPSec、Cisco IPSec 等）
- 免密授权配置，无需每次输入密码
- 分级日志系统（debug、info、warning、error）

## 安装

1. 克隆仓库
```bash
git clone https://github.com/tdragon8113/route-pilot.git
```

2. 构建项目
```bash
cd route-pilot
xcodebuild -project RoutePilot.xcodeproj -scheme RoutePilot -configuration Debug build
```

3. 运行应用
```bash
open ~/Library/Developer/Xcode/DerivedData/RoutePilot-*/Build/Products/Debug/RoutePilot.app
```

## 使用

1. 启动应用后，菜单栏显示天线图标
2. 点击图标打开主界面，显示系统 VPN 列表
3. 选择 VPN，配置路由规则（如 `10.0.0.0/8`）
4. 连接 VPN 后，应用自动添加路由
5. 可配置免密授权，避免每次输入密码

## 配置

- 配置文件：`~/Library/Application Support/RoutePilot/config.json`
- 日志文件：`~/Library/Logs/RoutePilot/operations.log`

## 免密授权

应用支持配置 sudoers 免密执行路由命令：

```bash
# 手动配置（可选）
sudo echo "$(whoami) ALL=(ALL) NOPASSWD: /sbin/route" | sudo tee /etc/sudoers.d/autoroute
sudo chmod 440 /etc/sudoers.d/autoroute
```

或在应用内点击"配置免密授权"按钮。

## 技术栈

- Swift / SwiftUI
- NWPathMonitor（网络状态监听）
- Actor 并发模型

## License

MIT