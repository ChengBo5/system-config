# system-config

服务器服务配置与部署，方便迁移时快速恢复。纯 gost 方案：一个 gost 进程，同域名不同端口对外提供 HTTPS，多项服务共用同一张证书（证书只认域名不认端口）。gost 用 pm2 托管。

## 项目结构

```
system-config/
├── gost/
│   ├── gost              # gost 程序（下载获取，见下；已 gitignore）
│   ├── config.yaml       # gost 配置（443 代理 + 各端口转发）
│   ├── download-gost.sh  # 下载/更新最新版 gost
│   └── ssl/
│       ├── ssl.crt       # 证书完整链（自行放入，已 gitignore）
│       └── ssl.key       # 私钥（自行放入，已 gitignore）
└── mcp_tool/             # Binance MCP 服务（market / account），详见其 README
```

## 服务清单

域名：`korea.joccboy.asia`（换域名只需换证书，端口/配置不变）

| 服务 | 对外地址 | 后端 | 说明 |
|---|---|---|---|
| 翻墙代理 | `korea.joccboy.asia:443` | — | gost HTTP over TLS + 账号密码 |
| 9router | `https://korea.joccboy.asia:61001/`、`/v1` | `127.0.0.1:61000` | TLS 终止后裸转发，根路径透传 |
| trade | `https://korea.joccboy.asia:61014/` | `127.0.0.1:61013` | TLS 终止后裸转发 |
| MCP Market | 本地 `127.0.0.1:8000` | — | SSE，默认不对外，需要则加 gost 转发 |
| MCP Account | 本地 `127.0.0.1:8001` | — | SSE，默认不对外，需要则加 gost 转发 |

> 云服务器安全组需放行入站端口 **443、61001、61014**（以及你为 MCP 另开的端口）。

---

## 一、部署 gost

### 1. 下载最新版 gost

用脚本自动识别架构、取 GitHub 最新版并装到 `gost/` 目录（已是最新版会跳过）：

```bash
bash gost/download-gost.sh
```

以后更新 gost 也是重跑这个脚本，然后 `pm2 restart gost`。

> 下载慢/被墙时，去 Releases 页手动下对应架构的包，解压出 `gost` 放到 `gost/` 目录：
> https://github.com/go-gost/gost/releases/latest

### 2. 放置证书

把证书放入 `gost/ssl/`：`ssl.crt`（完整链）、`ssl.key`（私钥）。
例如 `korea.joccboy.asia` 的 bundle 重命名为 `ssl.crt`、私钥重命名为 `ssl.key`。

`config.yaml` 里用相对路径 `ssl/ssl.crt`、`ssl/ssl.key`，相对 gost 进程工作目录（即 `gost/`）。

### 3. 修改代理密码

编辑 `gost/config.yaml`，把 `CHANGE_ME` 改成你自己的强密码。

### 4. 用 pm2 托管

必须在 `gost/` 目录下启动，`config.yaml` 的 `ssl/` 相对路径才解析得到（pm2 以当前目录为进程 cwd）：

```bash
cd gost
pm2 start ./gost --name gost -- -C config.yaml
pm2 save
pm2 startup     # 按输出的命令再执行一次，配置开机自启
```

pm2 常用命令：

```bash
pm2 status
pm2 logs gost
pm2 restart gost
pm2 stop gost
pm2 delete gost
```

---

## 二、9router（手动安装）

9router 监听本地 `61000`，由 gost 在 `61001` 上做 HTTPS 转发。

```bash
npm install -g 9router
9router --port 61000 --host 127.0.0.1 --no-browser --skip-update
```

- API：`https://korea.joccboy.asia:61001/v1`
- 控制台：`https://korea.joccboy.asia:61001/`（登录在根路径）

## 三、trade 交易网站

trade 应用监听本地 `61013`，由 gost 在 `61014` 上做 HTTPS 转发，访问 `https://korea.joccboy.asia:61014/`。

## 四、MCP 服务

Binance MCP（market / account）见 `mcp_tool/README.md`。默认只监听本地 `8000` / `8001`。如需对外 HTTPS，在 `gost/config.yaml` 里照 9router/trade 的写法各加一段 `tls` 监听 + `forwarder` 转发到对应本地端口，并放行相应安全组端口。

---

## 客户端连接翻墙代理

gost 跑的是 HTTPS 代理（HTTP over TLS），客户端无需安装 gost，直接配置即可（账号 `proxy`，密码为你在 config.yaml 设置的值）。

**命令行（curl / wget）：**

```bash
export https_proxy=https://proxy:你的密码@korea.joccboy.asia:443
export http_proxy=https://proxy:你的密码@korea.joccboy.asia:443
curl -I https://www.google.com
```

**系统 / 浏览器代理（SwitchyOmega 等）：**
- 协议：HTTPS
- 服务器：`korea.joccboy.asia`，端口：`443`
- 用户名：`proxy`，密码：你在 config.yaml 设置的值

**Git：**

```bash
git config --global http.proxy  https://proxy:你的密码@korea.joccboy.asia:443
git config --global https.proxy https://proxy:你的密码@korea.joccboy.asia:443
```

---

## 说明与注意

- gost 对网站采用「TLS 终止 + 裸 TCP 转发」，后端看到的是本机来源，拿不到真实客户端 IP，也没有 HTTP 层访问日志。
- 换域名/换证书：替换 `gost/ssl/ssl.crt`、`ssl.key` 后 `pm2 restart gost` 即可，端口和配置不用改。
- 更新 gost：重跑「下载最新版 gost」，然后 `pm2 restart gost`。
- 证书私钥、gost 二进制均已在 `.gitignore` 中忽略，不会进仓库。

## 迁移到新服务器

1. 把项目目录拷贝到新服务器。
2. 装 pm2（`npm install -g pm2`），下载 gost（见上），把证书放入 `gost/ssl/`。
3. `cd gost && pm2 start ./gost --name gost -- -C config.yaml && pm2 save`。
4. 按需手动启动 9router、trade、MCP 后端。
