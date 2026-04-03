#!/bin/bash
set -euo pipefail

# ============================================
# Gost 下载/更新脚本
# 功能: 从 GitHub 下载最新版 gost，如果本地已有且是最新版则跳过
# 下载源: https://github.com/go-gost/gost/releases
# 安装目录: ~/.system_config/gost/
# 用法: bash server-setup/scripts/install-gost.sh
# ============================================

# gost 安装到 ~/.system_config/gost/
INSTALL_DIR="$HOME/.system_config/gost"
mkdir -p "$INSTALL_DIR"
GOST_BIN="${INSTALL_DIR}/gost"
REPO="go-gost/gost"

# 复制配置文件到安装目录
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$SCRIPT_DIR/configs/gost/config.yaml" ]] && [[ ! -f "$INSTALL_DIR/config.yaml" ]]; then
    cp "$SCRIPT_DIR/configs/gost/config.yaml" "$INSTALL_DIR/config.yaml"
    echo "配置文件已复制: $INSTALL_DIR/config.yaml"
fi

# 通过 GitHub API 获取最新 release 的版本号
# 返回格式: 3.2.6 (不带 v 前缀)
get_latest_version() {
    curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"v\([^"]*\)".*/\1/'
}

# 获取本地已安装的 gost 版本号
# 通过 gost -V 输出解析，只取第一个匹配的版本号避免日期干扰
get_local_version() {
    if [[ -x "$GOST_BIN" ]]; then
        "$GOST_BIN" -V 2>/dev/null | grep -oP '\d+\.\d+\.\d+(-rc\d+)?' | head -1 || echo ""
    else
        echo ""
    fi
}

# 检测系统 CPU 架构，映射为 gost 发布包的架构名
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armv7" ;;
        *) echo "不支持的架构: $arch" >&2; exit 1 ;;
    esac
}

# 下载指定版本的 gost 并安装
# 参数: $1 = 版本号 (如 3.2.6)
download_gost() {
    local version="$1"
    local arch
    arch=$(get_arch)
    local filename="gost_${version}_linux_${arch}.tar.gz"
    local url="https://github.com/${REPO}/releases/download/v${version}/${filename}"

    echo "下载 gost v${version} (${arch})..."
    echo "URL: ${url}"

    curl -L --fail --progress-bar -o "/tmp/${filename}" "$url" || {
        echo "下载失败，请检查版本号或网络连接"
        exit 1
    }

    echo "解压中..."
    tar -xzf "/tmp/${filename}" -C /tmp/ gost

    mv /tmp/gost "$GOST_BIN"
    chmod +x "$GOST_BIN"
    rm -f "/tmp/${filename}"

    echo "安装完成: $GOST_BIN"
    "$GOST_BIN" -V
}

# ---- 主逻辑 ----

echo "检查 GitHub 最新版本..."
LATEST=$(get_latest_version)

if [[ -z "$LATEST" ]]; then
    echo "无法获取最新版本信息，请检查网络"
    exit 1
fi

echo "最新版本: v${LATEST}"

if [[ -x "$GOST_BIN" ]]; then
    LOCAL=$(get_local_version)
    echo "本地版本: v${LOCAL}"

    if [[ "$LOCAL" == "$LATEST" ]]; then
        echo "已是最新版本，无需更新"
        exit 0
    fi

    echo "发现新版本，开始更新..."
    download_gost "$LATEST"
    echo "更新完成: v${LOCAL} -> v${LATEST}"
else
    echo "未找到 gost，开始首次下载..."
    download_gost "$LATEST"
    echo "首次安装完成"
fi
