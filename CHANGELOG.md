# Changelog

All notable changes to this project will be documented in this file.

## [v1.1.0] - 2026-04-03

### 新功能

- **路由规则排序** - 支持拖拽调整路由规则的顺序，按住左侧手柄图标 (≡) 上下拖动
- **路由规则备注** - 为每个路由规则添加备注说明，方便识别用途
- **实时拖拽效果** - 拖拽时其他行自动让位，直观显示目标位置

### 改进

- 使用 SCDynamicStore 替换 NWPathMonitor 监听 VPN 状态，更稳定可靠
- 移除自定义接口功能（简化配置，自动检测更可靠）

### 修复

- 修复 SCDynamicStore 监听偶发性失效问题
- 修复拖拽排序后数据未正确保存的问题

## [v1.0.0] - Initial Release

- 自动检测 VPN 连接状态
- 为每个 VPN 配置独立路由规则
- VPN 连接时自动添加路由
- 支持 L2TP/IPSec 和其他 VPN 类型
- 免密授权配置（可选）
- 菜单栏快速操作