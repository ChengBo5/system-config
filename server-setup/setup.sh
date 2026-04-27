#!/bin/bash
set -euo pipefail

# ============================================
# 一键部署脚本 - gost + 9router + nginx
# Miniconda 需单独运行: bash server-setup/scripts/install-python.sh
# 用法: sudo bash server-setup/setup.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 下载 gost (不需要 root，用实际用户身份运行)
sudo -u "${SUDO_USER:-$USER}" bash "$SCRIPT_DIR/scripts/install-gost.sh"

# 注册 gost 服务
bash "$SCRIPT_DIR/scripts/start-gost.sh"

# 下载 9router
sudo -u "${SUDO_USER:-$USER}" bash "$SCRIPT_DIR/scripts/install-9router.sh"

# 注册 9router 服务
bash "$SCRIPT_DIR/scripts/start-9router.sh"

# 安装 nginx + 部署证书和站点配置
bash "$SCRIPT_DIR/scripts/install-nginx.sh"

echo ""
echo "部署完成！"
echo "  gost:     systemctl status gost"
echo "  9router:  systemctl status 9router"
echo "  nginx:    systemctl status nginx"
