# Binance MCP 服务 HTTPS 部署指南

## 架构说明

```
客户端 (Kiro)
    ↓ HTTPS
Nginx (443端口)
    ↓ HTTP (内网)
    ├─→ binance_market.py (127.0.0.1:8000)  → https://your-domain.com/market
    └─→ binance_account.py (127.0.0.1:8001) → https://your-domain.com/account
```

## 部署步骤

### 1. 安装依赖

```bash
cd mcp_tool
pip3 install -r requirements.txt
sudo apt install nginx certbot python3-certbot-nginx -y
```

### 2. 配置环境变量

编辑 `.env` 文件：
```env
API_KEY=your_binance_api_key
API_SECRET=your_binance_api_secret
TESTNET=false
```

### 3. 申请 SSL 证书

```bash
sudo certbot --nginx -d your-domain.com
```

证书路径：
- 证书：`/etc/letsencrypt/live/your-domain.com/fullchain.pem`
- 私钥：`/etc/letsencrypt/live/your-domain.com/privkey.pem`

### 4. Nginx 配置

Nginx 配置已统一到 `server-setup/configs/nginx/sites-available/joccboy.asia.conf`，
通过根目录的部署脚本一键部署：

```bash
sudo bash server-setup/setup.sh
```

如需修改域名或证书，替换 `server-setup/configs/nginx/certs/` 下的证书文件
（按 `域名_bundle.crt` + `域名.key` 命名），然后重新运行 `sudo bash server-setup/setup.sh`。
脚本会自动从证书文件名检测域名，无需手动改配置。

### 5. 启动 MCP 服务

```bash
# 启动 Market Data 服务
nohup python3 binance_market.py --transport sse --host 127.0.0.1 --port 8000 > market.log 2>&1 &

# 启动 Account 服务
nohup python3 binance_account.py --transport sse --host 127.0.0.1 --port 8001 > account.log 2>&1 &
```

### 6. 验证部署

```bash
# 检查服务是否运行
ps aux | grep binance

# 测试连接
curl https://your-domain.com/health
curl https://your-domain.com/market
curl https://your-domain.com/account
```

## 客户端配置

在本地 `.kiro/settings/mcp.json` 中添加：

```json
{
  "mcpServers": {
    "binance-market": {
      "url": "https://your-domain.com/market",
      "transport": "sse"
    },
    "binance-account": {
      "url": "https://your-domain.com/account",
      "transport": "sse"
    }
  }
}
```

## 常用命令

```bash
# 查看服务进程
ps aux | grep binance

# 停止服务
pkill -f binance_market.py
pkill -f binance_account.py

# 查看日志
tail -f market.log
tail -f account.log

# 查看 Nginx 日志
sudo tail -f /var/log/nginx/mcp_error.log
sudo tail -f /var/log/nginx/mcp_access.log

# 重启 Nginx
sudo systemctl reload nginx
```

## 故障排查

### 502 错误
```bash
# 检查服务是否运行
ps aux | grep binance

# 检查端口
netstat -tlnp | grep 8000
netstat -tlnp | grep 8001

# 查看日志
tail -f market.log
tail -f account.log
```

### SSL 证书错误
```bash
# 检查证书有效期
sudo certbot certificates

# 手动续期
sudo certbot renew
```
