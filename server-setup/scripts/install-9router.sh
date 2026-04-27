#!/bin/bash
set -euo pipefail

# ============================================
# 9router 安装/更新脚本
# 功能: 通过 npm 全局安装 9router
# 用法: bash server-setup/scripts/install-9router.sh
# ============================================

echo "=== 安装 9router ==="

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "错误: 未安装 Node.js，请先安装 Node.js 20+"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [[ "$NODE_VERSION" -lt 20 ]]; then
    echo "错误: 需要 Node.js 20+，当前版本: $(node -v)"
    exit 1
fi

echo "Node.js 版本: $(node -v)"

# 全局安装 9router
echo "通过 npm 全局安装 9router..."
npm install -g 9router

# 确认安装成功
if ! command -v 9router &> /dev/null; then
    echo "错误: 9router 安装失败，未找到命令"
    exit 1
fi

echo ""
echo "=== 9router 安装完成 ==="
echo "版本: $(9router --version 2>/dev/null || echo 'installed')"
echo ""
echo "下一步:"
echo "  sudo bash server-setup/scripts/start-9router.sh   # 注册为 systemd 服务"
