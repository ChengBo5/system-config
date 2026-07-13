#!/bin/bash
set -euo pipefail

# ============================================================
# 下载 / 更新 gost 到本脚本所在目录 (gost/)
# 源: https://github.com/go-gost/gost/releases
# 用法: bash download-gost.sh
#   已是最新版则跳过; 有新版或未安装则下载。
# ============================================================

REPO="go-gost/gost"
# 装到脚本所在目录，不依赖执行时的 pwd
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GOST_BIN="${SCRIPT_DIR}/gost"

# 识别 CPU 架构 -> gost 发布包架构名
case "$(uname -m)" in
    x86_64)  ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    armv7l)  ARCH=armv7 ;;
    *) echo "不支持的架构: $(uname -m)" >&2; exit 1 ;;
esac

# 取 GitHub 最新版本号 (去掉 v 前缀)
echo "查询最新版本..."
VER=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
      | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')
if [[ -z "$VER" ]]; then
    echo "无法获取最新版本，请检查网络" >&2
    exit 1
fi
echo "最新版本: v${VER}"

# 已安装且是最新版则跳过
if [[ -x "$GOST_BIN" ]]; then
    LOCAL=$("$GOST_BIN" -V 2>/dev/null | grep -oP '\d+\.\d+\.\d+(-rc\d+)?' | head -1 || echo "")
    echo "本地版本: v${LOCAL:-未知}"
    if [[ "$LOCAL" == "$VER" ]]; then
        echo "已是最新版，无需更新"
        exit 0
    fi
fi

# 下载并解压
FILENAME="gost_${VER}_linux_${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/download/v${VER}/${FILENAME}"
echo "下载: ${URL}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

curl -L --fail --progress-bar -o "${TMP}/${FILENAME}" "$URL"
tar -xzf "${TMP}/${FILENAME}" -C "$TMP" gost
mv -f "${TMP}/gost" "$GOST_BIN"
chmod +x "$GOST_BIN"

echo "安装完成: $GOST_BIN"
"$GOST_BIN" -V
echo ""
echo "若 gost 正在运行, 更新后执行: pm2 restart gost"
