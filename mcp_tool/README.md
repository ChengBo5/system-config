# Binance MCP 服务 HTTPS 部署指南

## 架构说明

对外 HTTPS 由根目录的 gost 统一负责（TLS 终止 + 转发），本服务只监听本地端口：

```
客户端 (Kiro)
    ↓ HTTPS
gost (为每个 MCP 服务开一个 TLS 端口)
    ↓ HTTP (本机)
    ├─→ binance_market.py (127.0.0.1:8000)
    └─→ binance_account.py (127.0.0.1:8001)
```

对外暴露方式见根目录 `README.md` 的「MCP 服务」一节：在 `gost/config.yaml` 里照
9router/trade 的写法，为 8000 / 8001 各加一段 `tls` 监听 + `forwarder`，并放行对应安全组端口。

## 部署步骤

### 1. 安装依赖

```bash
cd mcp_tool
pip3 install -r requirements.txt
```

### 2. 配置环境变量

编辑 `.env` 文件：
```env
API_KEY=your_binance_api_key
API_SECRET=your_binance_api_secret
TESTNET=false
```

### 3. 对外 HTTPS（可选，由 gost 负责）

本服务只监听本地端口，对外 HTTPS 交给根目录的 gost。若要对外暴露，在 `gost/config.yaml`
里为 8000 / 8001 各加一段 `tls` 监听 + `forwarder`（写法参考 9router/trade），
证书共用 `gost/ssl/`，并放行相应安全组端口。详见根目录 `README.md`。

### 4. 启动 MCP 服务

```bash
# 启动 Market Data 服务
nohup python3 binance_market.py --transport sse --host 127.0.0.1 --port 8000 > market.log 2>&1 &

# 启动 Account 服务
nohup python3 binance_account.py --transport sse --host 127.0.0.1 --port 8001 > account.log 2>&1 &
```

### 5. 验证部署

```bash
# 检查服务是否运行
ps aux | grep binance

# 本地测试（对外则换成 gost 暴露的 https://域名:端口/）
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8001/health
```

## 客户端配置

对外用 gost 暴露后，在本地 `.kiro/settings/mcp.json` 中填对应的 `https://域名:端口/` 地址
（端口为你在 `gost/config.yaml` 里为 market / account 分配的对外端口）：

```json
{
  "mcpServers": {
    "binance-market": {
      "url": "https://korea.joccboy.asia:<market端口>/",
      "transport": "sse"
    },
    "binance-account": {
      "url": "https://korea.joccboy.asia:<account端口>/",
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
```

## 故障排查

### 连接不上 / 502
```bash
# 检查服务是否运行
ps aux | grep binance

# 检查端口
netstat -tlnp | grep 8000
netstat -tlnp | grep 8001

# 查看日志
tail -f market.log
tail -f account.log

# 检查 gost 是否在监听对外端口、转发是否正确
pm2 logs gost
```

### SSL 证书问题
证书由 gost 统一加载（`gost/ssl/`）。检查/更换证书后 `pm2 restart gost` 即可。
