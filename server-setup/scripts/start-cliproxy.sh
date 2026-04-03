#!/bin/bash
set -euo pipefail

# ============================================
# CLIProxyAPIPlus systemd 服务安装脚本
# 功能:
#   1. 将 cliproxy.service 配置复制到 /etc/systemd/system/
#   2. 自动替换 __HOME__ 为当前用户主目录
#   3. 注册为系统服务，开机自启，崩溃自动重启
# 用法: sudo bash server-setup/scripts/start-cliproxy.sh
# 前置条件: 先运行 install-cliproxy.sh
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_TEMPLATE="${SCRIPT_DIR}/configs/cliproxy/cliproxy.service"
SERVICE_NAME="cliproxy"
REAL_HOME=$(eval echo "~${SUDO_USER:-$USER}")

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

# 检查程序是否已安装
if [[ ! -x "${REAL_HOME}/.system_config/cliproxy/cli-proxy-api-plus" ]]; then
    echo "未找到程序: ${REAL_HOME}/.system_config/cliproxy/cli-proxy-api-plus"
    echo "请先运行 install-cliproxy.sh"
    exit 1
fi

# 替换 __HOME__ 和 __USER__ 占位符为实际值，写入 systemd 目录
sed -e "s|__HOME__|${REAL_HOME}|g" -e "s|__USER__|${SUDO_USER:-$USER}|g" "$SERVICE_TEMPLATE" \
    > /etc/systemd/system/${SERVICE_NAME}.service

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl restart ${SERVICE_NAME}

echo "CLIProxyAPIPlus 服务已安装并启动"
echo "程序路径: ${REAL_HOME}/.system_config/cliproxy/cli-proxy-api-plus"
echo "配置文件: ${REAL_HOME}/.system_config/cliproxy/config.yaml"
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
