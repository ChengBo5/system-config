#!/bin/bash
set -euo pipefail

# ============================================
# Miniconda 安装脚本
# 功能:
#   1. 下载最新版 Miniconda
#   2. 静默安装到 ~/miniconda3
#   3. 初始化 shell 环境 (conda init)
#   4. 已安装则跳过
# 用法: bash server-setup/scripts/install-python.sh
# ============================================

INSTALL_DIR="$HOME/miniconda3"

# ---- 检查是否已安装 ----
if [[ -d "$INSTALL_DIR" ]] && [[ -x "$INSTALL_DIR/bin/conda" ]]; then
    echo "Miniconda 已安装: $INSTALL_DIR"
    "$INSTALL_DIR/bin/conda" --version
    echo "如需更新: conda update conda"
    exit 0
fi

# ---- 检测系统架构 ----
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  ARCH_NAME="x86_64" ;;
    aarch64) ARCH_NAME="aarch64" ;;
    *) echo "不支持的架构: $ARCH"; exit 1 ;;
esac

# ---- 下载最新版 Miniconda ----
INSTALLER="/tmp/miniconda_installer.sh"
URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-${ARCH_NAME}.sh"

echo "下载 Miniconda (${ARCH_NAME})..."
echo "URL: ${URL}"
curl -L --fail --progress-bar -o "$INSTALLER" "$URL" || {
    echo "下载失败，请检查网络"
    exit 1
}

# ---- 静默安装 ----
# -b: 静默模式，不修改 .bashrc
# -p: 指定安装路径
echo "安装到 ${INSTALL_DIR}..."
bash "$INSTALLER" -b -p "$INSTALL_DIR"
rm -f "$INSTALLER"  # 清理安装包

# ---- 初始化 conda ----
# 将 conda init 写入 .bashrc，下次登录自动激活
"$INSTALL_DIR/bin/conda" init bash

echo ""
echo "Miniconda 安装完成: $INSTALL_DIR"
"$INSTALL_DIR/bin/conda" --version
echo ""
echo "请运行以下命令激活 conda (或重新登录):"
echo "  source ~/.bashrc"
echo ""
echo "常用命令:"
echo "  conda create -n myenv python=3.12  # 创建虚拟环境"
echo "  conda activate myenv               # 激活环境"
echo "  conda deactivate                   # 退出环境"
echo "  conda env list                     # 查看所有环境"
echo "  conda update conda                 # 更新 conda"
echo ""
echo "卸载 Miniconda:"
echo "  rm -rf ${INSTALL_DIR}"
echo "  # 然后删除 ~/.bashrc 中 conda init 相关的内容"
