# 服务器部署脚本 - Ubuntu 24.04

服务器环境一键部署工具，方便迁移时快速恢复所有服务。

## 运行时目录

脚本运行后，程序和配置文件统一安装到用户主目录下：

```
~/.system_config/
└── gost/
    ├── gost                  # gost 可执行文件
    └── config.yaml           # gost 转发规则配置
```

service 文件中的路径通过 `__HOME__` 占位符自动替换，迁移时无需手动改路径。

## 项目目录结构

```
server-setup/
├── setup.sh                              # 一键部署 (gost + nginx)
├── scripts/
│   ├── install-gost.sh                   # 下载/更新 gost -> ~/.system_config/gost/
│   ├── start-gost.sh                     # 注册 gost 为 systemd 服务
│   ├── install-nginx.sh                  # 安装 nginx + 部署证书和站点配置
│   └── install-python.sh                 # 安装 Miniconda -> ~/miniconda3/ (需单独运行)
├── configs/
│   ├── gost/
│   │   ├── config.yaml                   # gost 配置模板
│   │   └── gost.service                  # systemd 服务模板
│   └── nginx/
│       ├── certs/                        # SSL 证书 zip 包
│       │   └── joccboy.asia_nginx.zip
│       └── sites-available/
│           └── joccboy.asia.conf         # HTTPS 统一入口配置
└── docs/
    └── init-server.md                    # 新服务器初始化指南
```

## 快速部署

```bash
# 一键部署 gost + nginx (需要 sudo)
sudo bash server-setup/setup.sh

# 单独安装 Miniconda (不需要 sudo)
bash server-setup/scripts/install-python.sh
```

也可以单独运行某个脚本：

```bash
bash server-setup/scripts/install-gost.sh          # 下载 gost
sudo bash server-setup/scripts/start-gost.sh       # 注册 gost 服务
sudo bash server-setup/scripts/install-nginx.sh    # 安装 nginx
```

## 9router 手动安装

9router 不通过脚本管理，手动安装和启动：

```bash
# 安装
npm install -g 9router

# 启动
9router --port 61020 --host 0.0.0.0 --no-browser --skip-update
```

## 服务访问地址

域名: `joccboy.asia`

| 服务 | 访问地址 | 端口 | 说明 |
|------|---------|------|------|
| Gost 代理 | `joccboy.asia:61010` | `:61010` | HTTPS 代理，自带 TLS，不经过 nginx |
| 9router | `https://joccboy.asia/router/v1` | `127.0.0.1:61020` | AI 路由 API，通过 nginx 代理 |
| MCP Market | `https://joccboy.asia/market/` | `127.0.0.1:8000` | SSE 长连接 |
| MCP Account | `https://joccboy.asia/account/` | `127.0.0.1:8001` | SSE 长连接 |

HTTP 80 端口自动跳转 HTTPS 443。

## 服务说明

### Gost HTTPS 代理
- 程序路径: `~/.system_config/gost/gost`
- 配置文件: `~/.system_config/gost/config.yaml`
- 监听端口: `:61010`（自带 TLS，不经过 nginx）
- systemd 服务名: `gost`

#### 客户端连接方式

Gost 运行的是 HTTPS 代理（HTTP over TLS），客户端无需安装 gost，直接配置即可。

**macOS 系统代理：**

系统设置 → 网络 → Wi-Fi → 代理 → 安全 Web 代理 (HTTPS)：
- 服务器: `joccboy.asia`
- 端口: `61010`
- 用户名: `proxy`
- 密码: `MyPassword`

**命令行（curl / wget）：**

```bash
export https_proxy=https://proxy:MyPassword@joccboy.asia:61010
export http_proxy=https://proxy:MyPassword@joccboy.asia:61010

# 测试
curl -I https://www.google.com
```

**浏览器代理插件（SwitchyOmega 等）：**
- 代理协议: HTTPS
- 服务器: `joccboy.asia`
- 端口: `61010`
- 用户名: `proxy`
- 密码: `MyPassword`

**Git：**

```bash
git config --global http.proxy https://proxy:MyPassword@joccboy.asia:61010
git config --global https.proxy https://proxy:MyPassword@joccboy.asia:61010
```

### 9router AI 路由
- 安装方式: `npm install -g 9router`
- 监听地址: `0.0.0.0:61020`
- 手动启动，不使用 systemd
- API: `https://joccboy.asia/router/v1`
- 管理面板: `http://IP:61020/dashboard`（通过 IP 直连访问）

### Nginx HTTPS 入口
- 统一 HTTPS 入口，按路径转发到各个后端服务
- SSL 证书放在 `configs/nginx/certs/`，脚本自动解压部署到 `/etc/nginx/ssl/`

### Miniconda
- 安装到 `~/miniconda3`，不需要 sudo
- 安装完执行 `source ~/.bashrc` 激活

## 验证服务

```bash
systemctl status gost
systemctl status nginx
ss -tlnp | grep -E '61010|61020|8000|8001'
```

## 常用运维命令

```bash
# gost
systemctl status gost
systemctl restart gost
journalctl -u gost -f

# nginx
systemctl status nginx
systemctl restart nginx
nginx -t
```

## 删除服务

```bash
# 删除 gost
sudo systemctl stop gost && sudo systemctl disable gost
sudo rm /etc/systemd/system/gost.service && sudo systemctl daemon-reload

# 删除 nginx
sudo systemctl stop nginx && sudo systemctl disable nginx
sudo apt-get remove -y nginx && sudo systemctl daemon-reload

# 卸载 9router
npm uninstall -g 9router

# 清理安装目录
rm -rf ~/.system_config/
```

## 迁移到新服务器

1. 将项目目录拷贝到新服务器
2. 执行 `sudo bash server-setup/setup.sh`（路径自动适配）
3. 修改 `~/.system_config/` 下的配置文件
4. 手动安装 9router: `npm install -g 9router`
5. 如果域名/证书有变化，更新 `configs/nginx/` 下的对应文件
6. 新服务器初始化参考 `docs/init-server.md`
