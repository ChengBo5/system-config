#!/bin/bash
set -euo pipefail

# ============================================
# Nginx 安装与配置脚本
# 功能:
#   1. 安装 nginx (已安装则跳过)
#   2. 解压 SSL 证书到 /etc/nginx/ssl/
#   3. 部署站点配置到 /etc/nginx/sites-available/ 并启用
#   4. 注册开机自启
# 用法: 在主目录执行 sudo bash server-setup/scripts/install-nginx.sh
# ============================================

# 配置文件根目录 (通过脚本相对路径定位，不依赖 pwd)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/configs/nginx"
# SSL 证书在服务器上的存放目录
SSL_DIR="/etc/nginx/ssl"
# 本地证书 zip 包存放目录
CERTS_DIR="$CONFIGS_DIR/certs"

# 检查 root 权限 (nginx 安装和配置需要 root)
if [[ $EUID -ne 0 ]]; then
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# ---- 第一步: 安装 nginx ----
if command -v nginx &> /dev/null; then
    echo "nginx 已安装: $(nginx -v 2>&1)"
else
    echo "安装 nginx..."
    apt-get update -y
    apt-get install -y nginx
    echo "nginx 安装完成"
fi

# ---- 第二步: 部署 SSL 证书 ----
# 遍历 certs/ 目录下所有 *_nginx.zip 文件
# 从文件名提取域名，解压到 /etc/nginx/ssl/域名/ 目录
# 例: joccboy.asia_nginx.zip -> /etc/nginx/ssl/joccboy.asia/
mkdir -p "$SSL_DIR"
if [[ -d "$CERTS_DIR" ]]; then
    for zipfile in "$CERTS_DIR"/*_nginx.zip; do
        [[ ! -f "$zipfile" ]] && continue
        # 提取域名: joccboy.asia_nginx.zip -> joccboy.asia
        domain=$(basename "$zipfile" | sed 's/_nginx\.zip$//')
        mkdir -p "${SSL_DIR}/${domain}"
        unzip -o "$zipfile" -d "${SSL_DIR}/${domain}/"
        echo "SSL 证书已部署: ${domain} -> ${SSL_DIR}/${domain}/"
    done
else
    echo "未找到证书目录: $CERTS_DIR，跳过证书部署"
fi

# ---- 第三步: 部署站点配置 ----
# 将 sites-available/ 下的所有 .conf 文件复制到 nginx 配置目录
# 并创建软链接到 sites-enabled/ 启用站点
if [[ -d "$CONFIGS_DIR/sites-available" ]]; then
    for conf in "$CONFIGS_DIR/sites-available"/*; do
        [[ ! -f "$conf" ]] && continue
        filename=$(basename "$conf")
        cp "$conf" "/etc/nginx/sites-available/$filename"
        ln -sf "/etc/nginx/sites-available/$filename" "/etc/nginx/sites-enabled/$filename"
        echo "站点配置已部署: $filename"
    done
fi

# 删除 nginx 默认站点，避免冲突
rm -f /etc/nginx/sites-enabled/default

# ---- 第四步: 测试并启动 ----
# 先测试配置语法，失败会自动退出 (set -e)
nginx -t

# 设置开机自启并立即启动
systemctl enable nginx
systemctl restart nginx

echo ""
echo "nginx 服务已安装并启动"
echo ""
echo "常用命令:"
echo "  systemctl status nginx    # 查看状态"
echo "  systemctl restart nginx   # 重启"
echo "  systemctl stop nginx      # 停止"
echo "  nginx -t                  # 测试配置"
echo "  journalctl -u nginx -f    # 查看日志"
echo ""
echo "站点配置目录: /etc/nginx/sites-available/"
echo "添加新站点: 把 conf 文件放到 $CONFIGS_DIR/sites-available/ 后重新运行此脚本"
echo ""
echo "删除服务:"
echo "  sudo systemctl stop nginx"
echo "  sudo systemctl disable nginx"
echo "  sudo apt-get remove -y nginx"
echo "  sudo systemctl daemon-reload"
