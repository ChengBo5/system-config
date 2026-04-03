#!/bin/bash
set -euo pipefail

# ============================================
# 服务器初始化主脚本 - Ubuntu 24.04
# 功能: 一键部署服务器环境，支持选择性安装
# 用法:
#   sudo bash server-setup/setup.sh          # 安装全部
#   sudo bash server-setup/setup.sh --gost   # 只安装 gost
#   sudo bash server-setup/setup.sh --nginx  # 只安装 nginx
#   sudo bash server-setup/setup.sh --python # 只安装 python
#   sudo bash server-setup/setup.sh --help   # 查看帮助
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="/var/log/server-setup-$(date +%Y%m%d_%H%M%S).log"

# 颜色输出，方便区分日志级别
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数，同时输出到终端和日志文件
log()  { echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; exit 1; }

# 检查 root 权限
[[ $EUID -ne 0 ]] && err "请使用 sudo 运行此脚本"

# 基础系统更新，安装常用工具
setup_base() {
    log "更新系统包..."
    apt-get update -y && apt-get upgrade -y
    apt-get install -y curl wget git unzip software-properties-common \
        build-essential ufw fail2ban
    log "基础环境安装完成"
}

# ---- 解析命令行参数 ----
INSTALL_ALL=false
INSTALL_NGINX=false
INSTALL_GOST=false
INSTALL_PYTHON=false

# 不带参数时默认安装全部
if [[ $# -eq 0 ]]; then
    INSTALL_ALL=true
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)    INSTALL_ALL=true ;;
        --nginx)  INSTALL_NGINX=true ;;
        --gost)   INSTALL_GOST=true ;;
        --python) INSTALL_PYTHON=true ;;
        --help)
            echo "用法: sudo bash server-setup/setup.sh [--all | --nginx | --gost | --python]"
            echo "  不带参数等同于 --all"
            exit 0
            ;;
        *) err "未知参数: $1" ;;
    esac
    shift
done

# ---- 执行安装 ----
setup_base

if $INSTALL_ALL || $INSTALL_GOST; then
    log "========== 安装 Gost =========="
    bash "$SCRIPT_DIR/scripts/install-gost.sh"
fi

if $INSTALL_ALL || $INSTALL_NGINX; then
    log "========== 安装 Nginx =========="
    bash "$SCRIPT_DIR/scripts/install-nginx.sh"
fi

if $INSTALL_ALL || $INSTALL_PYTHON; then
    log "========== 安装 Miniconda =========="
    bash "$SCRIPT_DIR/scripts/install-python.sh"
fi

log "============================================"
log "全部安装完成! 日志文件: $LOG_FILE"
log "============================================"
