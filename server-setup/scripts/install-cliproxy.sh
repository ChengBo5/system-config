#!/bin/bash
set -euo pipefail

# ============================================
# CLIProxyAPIPlus 下载/更新脚本
# 功能: 从 GitHub 下载最新版，如果本地已有且是最新版则跳过
# 下载源: https://github.com/router-for-me/CLIProxyAPIPlus/releases
# 安装目录: ~/.system_config/cliproxy/
# 用法: bash server-setup/scripts/install-cliproxy.sh
# ============================================

# 安装到 ~/.system_config/cliproxy/
INSTALL_DIR="$HOME/.system_config/cliproxy"
mkdir -p "$INSTALL_DIR"
BIN_NAME="cli-proxy-api-plus"
BIN_PATH="${INSTALL_DIR}/${BIN_NAME}"
REPO="router-for-me/CLIProxyAPIPlus"

# 通过 GitHub API 获取最新 release 的版本号
get_latest_version() {
    curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
        | grep '"tag_name"' \
        | head -1 \
        | sed 's/.*"v\([^"]*\)".*/\1/'
}

# 获取本地已安装的版本号
get_local_version() {
    if [[ -x "$BIN_PATH" ]]; then
        "$BIN_PATH" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+(-\d+)?' | head -1 || echo ""
    else
        echo ""
    fi
}

# 检测系统 CPU 架构
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) echo "不支持的架构: $arch" >&2; exit 1 ;;
    esac
}

# 下载指定版本并安装
# 参数: $1 = 版本号 (如 6.9.10-1)
download_cliproxy() {
    local version="$1"
    local arch
    arch=$(get_arch)
    local filename="CLIProxyAPIPlus_${version}_linux_${arch}.tar.gz"
    local url="https://github.com/${REPO}/releases/download/v${version}/${filename}"

    echo "下载 ${BIN_NAME} v${version} (${arch})..."
    echo "URL: ${url}"

    curl -L --fail --progress-bar -o "/tmp/${filename}" "$url" || {
        echo "下载失败，请检查版本号或网络连接"
        exit 1
    }

    # 解压所有文件到临时目录
    echo "解压中..."
    local tmpdir="/tmp/cliproxy_extract"
    rm -rf "$tmpdir"
    mkdir -p "$tmpdir"
    tar -xzf "/tmp/${filename}" -C "$tmpdir"

    # 移动二进制文件
    mv "$tmpdir/${BIN_NAME}" "$BIN_PATH"
    chmod +x "$BIN_PATH"

    # 如果安装目录下没有配置文件，从包里复制示例配置
    if [[ ! -f "${INSTALL_DIR}/config.yaml" ]] && [[ -f "$tmpdir/config.example.yaml" ]]; then
        cp "$tmpdir/config.example.yaml" "${INSTALL_DIR}/config.yaml"
        echo "配置文件已复制: ${INSTALL_DIR}/config.yaml (请按需修改)"
    fi

    rm -rf "$tmpdir" "/tmp/${filename}"

    echo "安装完成: $BIN_PATH"
}

# ---- 主逻辑 ----

echo "检查 GitHub 最新版本..."
LATEST=$(get_latest_version)

if [[ -z "$LATEST" ]]; then
    echo "无法获取最新版本信息，请检查网络"
    exit 1
fi

echo "最新版本: v${LATEST}"

if [[ -x "$BIN_PATH" ]]; then
    LOCAL=$(get_local_version)
    echo "本地版本: v${LOCAL}"

    if [[ "$LOCAL" == "$LATEST" ]]; then
        echo "已是最新版本，无需更新"
        exit 0
    fi

    echo "发现新版本，开始更新..."
    download_cliproxy "$LATEST"
    echo "更新完成: v${LOCAL} -> v${LATEST}"
else
    echo "未找到 ${BIN_NAME}，开始首次下载..."
    download_cliproxy "$LATEST"
    echo "首次安装完成"
fi
