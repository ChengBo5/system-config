#!/bin/bash
set -euo pipefail

# ============================================
# Nginx 安装与配置脚本
# 功能:
#   1. 安装 nginx (已安装则跳过)
#   2. 从 certs/ 目录自动检测域名 (通过 *_bundle.crt 文件名)
#   3. 拷贝 SSL 证书到 /etc/nginx/ssl/
#   4. 将站点配置模板中的 __DOMAIN__ 替换为实际域名后部署
#   5. 注册开机自启
# 用法: 在主目录执行 sudo bash server-setup/scripts/install-nginx.sh
#
# 换域名只需:
#   1. 把新证书按 "域名_bundle.crt" / "域名.key" 放入 certs/
#   2. 删除旧证书文件
#   3. 重新运行此脚本
# ============================================

# 配置文件根目录 (通过脚本相对路径定位，不依赖 pwd)
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGS_DIR="${SCRIPT_DIR}/configs/nginx"
# SSL 证书在服务器上的存放目录
SSL_DIR="/etc/nginx/ssl"
# 本地证书存放目录 (按域名命名: 域名_bundle.crt / 域名.key)
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

# ---- 第二步: 自动检测域名 ----
# 从 certs/ 目录中的 *_bundle.crt 文件名提取域名
# 例: joccboy.asia_bundle.crt -> joccboy.asia
#     hk.joccboy.asia_bundle.crt -> hk.joccboy.asia
DOMAIN=""
for certfile in "$CERTS_DIR"/*_bundle.crt; do
    [[ ! -f "$certfile" ]] && continue
    DOMAIN=$(basename "$certfile" | sed 's/_bundle\.crt$//')
    break  # 只取第一个
done

if [[ -z "$DOMAIN" ]]; then
    echo "错误: 未在 $CERTS_DIR/ 中找到 *_bundle.crt 文件"
    echo "请将证书按以下格式放入:"
    echo "  ${CERTS_DIR}/域名_bundle.crt"
    echo "  ${CERTS_DIR}/域名.key"
    exit 1
fi

echo "检测到域名: $DOMAIN"

# 验证对应的 .key 文件存在
if [[ ! -f "$CERTS_DIR/${DOMAIN}.key" ]]; then
    echo "错误: 找到证书 ${DOMAIN}_bundle.crt 但缺少对应的 ${DOMAIN}.key"
    exit 1
fi

# ---- 第三步: 部署 SSL 证书 ----
mkdir -p "$SSL_DIR"
cp "$CERTS_DIR/${DOMAIN}_bundle.crt" "$SSL_DIR/${DOMAIN}_bundle.crt"
cp "$CERTS_DIR/${DOMAIN}.key"        "$SSL_DIR/${DOMAIN}.key"
# 私钥权限收紧，仅 root 可读
chmod 644 "$SSL_DIR/${DOMAIN}_bundle.crt"
chmod 600 "$SSL_DIR/${DOMAIN}.key"
echo "SSL 证书已部署: $SSL_DIR/${DOMAIN}_bundle.crt"
echo "SSL 私钥已部署: $SSL_DIR/${DOMAIN}.key"

# ---- 第四步: 部署站点配置 (模板替换 __DOMAIN__) ----
# 将 sites-available/ 下的所有 .conf 模板中的 __DOMAIN__ 替换为实际域名
# 生成最终配置到 /etc/nginx/sites-available/ 并启用

# 先清理本脚本之前部署的旧站点配置 (避免 upstream 重复等冲突)
# 删除 sites-enabled 中所有 .conf (保留 default 由后面单独处理)
for old_conf in /etc/nginx/sites-enabled/*.conf; do
    [[ -f "$old_conf" ]] && rm -f "$old_conf"
done
for old_conf in /etc/nginx/sites-available/*.conf; do
    [[ -f "$old_conf" ]] && rm -f "$old_conf"
done

if [[ -d "$CONFIGS_DIR/sites-available" ]]; then
    for conf in "$CONFIGS_DIR/sites-available"/*.conf; do
        [[ ! -f "$conf" ]] && continue
        # 输出文件名也替换域名占位 (如果模板文件名本身不含域名则保持原名)
        filename=$(basename "$conf")
        # 用 sed 替换 __DOMAIN__ 占位符，生成到 nginx 配置目录
        sed "s/__DOMAIN__/${DOMAIN}/g" "$conf" \
            > "/etc/nginx/sites-available/${DOMAIN}.conf"
        ln -sf "/etc/nginx/sites-available/${DOMAIN}.conf" "/etc/nginx/sites-enabled/${DOMAIN}.conf"
        echo "站点配置已部署: ${DOMAIN}.conf (从模板 $filename 生成)"
    done
fi

# 删除 nginx 默认站点，避免冲突
rm -f /etc/nginx/sites-enabled/default

# ---- 第五步: 测试并启动 ----
# 先测试配置语法，失败会自动退出 (set -e)
nginx -t

# 设置开机自启并立即启动
systemctl enable nginx
systemctl restart nginx

echo ""
echo "=========================================="
echo " nginx 部署完成"
echo "=========================================="
echo " 域名:     $DOMAIN"
echo " 证书:     $SSL_DIR/${DOMAIN}_bundle.crt"
echo " 私钥:     $SSL_DIR/${DOMAIN}.key"
echo " 站点配置: /etc/nginx/sites-available/${DOMAIN}.conf"
echo ""
echo "常用命令:"
echo "  systemctl status nginx    # 查看状态"
echo "  systemctl restart nginx   # 重启"
echo "  systemctl stop nginx      # 停止"
echo "  nginx -t                  # 测试配置"
echo "  journalctl -u nginx -f    # 查看日志"
echo ""
echo "换域名:"
echo "  1. 将新证书放入 $CERTS_DIR/ (域名_bundle.crt + 域名.key)"
echo "  2. 删除旧证书文件"
echo "  3. 重新运行此脚本"
echo ""
echo "删除服务:"
echo "  sudo systemctl stop nginx"
echo "  sudo systemctl disable nginx"
echo "  sudo apt-get remove -y nginx"
echo "  sudo systemctl daemon-reload"
