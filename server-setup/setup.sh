#!/bin/bash
set -euo pipefail

# ============================================
# 一键部署脚本 - gost + nginx
# 9router 需手动安装: npm install -g 9router
# Miniconda 需单独运行: bash server-setup/scripts/install-python.sh
# 用法: sudo bash server-setup/setup.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 下载 gost (不需要 root，用实际用户身份运行)
sudo -u "${SUDO_USER:-$USER}" bash "$SCRIPT_DIR/scripts/install-gost.sh"

# 注册 gost 服务
bash "$SCRIPT_DIR/scripts/start-gost.sh"

# 安装 nginx + 部署证书和站点配置
bash "$SCRIPT_DIR/scripts/install-nginx.sh"

echo ""
echo "部署完成！"
echo "  gost:    systemctl status gost"
echo "  nginx:   systemctl status nginx"
echo ""
echo "9router 需手动安装和启动:"
echo "  npm install -g 9router"
echo "  9router --port 61020 --host 0.0.0.0 --no-browser"
