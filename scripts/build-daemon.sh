#!/bin/bash
# 编译 RoutePilotDaemon

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DAEMON_SOURCE="$PROJECT_DIR/Daemon/main.swift"
BUILD_DIR="$PROJECT_DIR/build"
DAEMON_BINARY="$BUILD_DIR/route-pilot-daemon"

echo "编译 RoutePilotDaemon..."

# 创建 build 目录
mkdir -p "$BUILD_DIR"

# 编译 daemon
swiftc -O \
    -o "$DAEMON_BINARY" \
    "$DAEMON_SOURCE" \
    -framework Foundation \
    -framework SystemConfiguration

echo "编译完成: $DAEMON_BINARY"
echo "大小: $(ls -lh "$DAEMON_BINARY" | awk '{print $5}')"