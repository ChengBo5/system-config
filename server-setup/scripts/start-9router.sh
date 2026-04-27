#!/bin/bash
set -euo pipefail

# ============================================
# 9router systemd 服务安装脚本
# 功能:
#   1. 将 9router.service 配置复制到 /etc/systemd/system/
#   2. 自动替换占位符为实际值
#   3. 注册为系统服务，开机自启，崩溃自动重启
# 用法: sudo bash server-setup/scripts/start-9router.sh
# 前置条件: 先运行 install-9router.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_TEMPLATE="${SCRIPT_DIR}/configs/9router/9router.service"
SERVICE_NAME="9router"
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 检查 service 模板文件
if [[ ! -f "$SERVICE_TEMPLATE" ]]; then
    echo "未找到 service 配置: $SERVICE_TEMPLATE"
    exit 1
fi

# 检查 9router 是否已安装
NPM_GLOBAL_BIN=$(sudo -u "$REAL_USER" npm bin -g 2>/dev/null || sudo -u "$REAL_USER" npm prefix -g 2>/dev/null | xargs -I{} echo "{}/bin")
NINE_ROUTER_BIN="${NPM_GLOBAL_BIN}/9router"

if [[ ! -x "$NINE_ROUTER_BIN" ]]; then
    echo "未找到 9router 命令: $NINE_ROUTER_BIN"
    echo "请先运行 install-9router.sh"
    exit 1
fi

echo "9router 路径: $NINE_ROUTER_BIN"

# 替换占位符，写入 systemd 目录
sed -e "s|__HOME__|${REAL_HOME}|g" \
    -e "s|__USER__|${REAL_USER}|g" \
    -e "s|__NPM_GLOBAL_BIN__|${NPM_GLOBAL_BIN}|g" \
    "$SERVICE_TEMPLATE" > /etc/systemd/system/${SERVICE_NAME}.service

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}

# 检查状态
echo ""
systemctl status ${SERVICE_NAME} --no-pager

echo ""
echo "9router 服务已安装并启动"
echo "Dashboard: http://localhost:8317/dashboard"
echo ""
echo "常用命令:"
echo "  systemctl status ${SERVICE_NAME}    # 查看状态"
echo "  systemctl restart ${SERVICE_NAME}   # 重启"
echo "  systemctl stop ${SERVICE_NAME}      # 停止"
echo "  journalctl -u ${SERVICE_NAME} -f    # 查看日志"
echo ""
echo "删除服务:"
echo "  sudo systemctl stop ${SERVICE_NAME}"
echo "  sudo systemctl disable ${SERVICE_NAME}"
echo "  sudo rm /etc/systemd/system/${SERVICE_NAME}.service"
echo "  sudo systemctl daemon-reload"
