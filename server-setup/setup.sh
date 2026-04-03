#!/bin/bash
set -euo pipefail

# ============================================
# 一键部署脚本 - gost + CLIProxyAPIPlus + nginx
# Miniconda 需单独运行: bash server-setup/scripts/install-python.sh
# 用法: sudo bash server-setup/setup.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 下载 gost (不需要 root，用实际用户身份运行)
sudo -u "${SUDO_USER:-$USER}" bash "$SCRIPT_DIR/scripts/install-gost.sh"

# 注册 gost 服务
bash "$SCRIPT_DIR/scripts/start-gost.sh"

# 下载 CLIProxyAPIPlus
sudo -u "${SUDO_USER:-$USER}" bash "$SCRIPT_DIR/scripts/install-cliproxy.sh"

# 注册 CLIProxyAPIPlus 服务
bash "$SCRIPT_DIR/scripts/start-cliproxy.sh"

# 安装 nginx + 部署证书和站点配置
bash "$SCRIPT_DIR/scripts/install-nginx.sh"

echo ""
echo "部署完成！"
echo "  gost:      systemctl status gost"
echo "  cliproxy:  systemctl status cliproxy"
echo "  nginx:     systemctl status nginx"
