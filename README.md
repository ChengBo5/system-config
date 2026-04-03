# 服务器初始化脚本 - Ubuntu 24.04

## 目录结构

```
server-setup/
├── setup.sh                    # 主入口脚本
├── scripts/
│   ├── install-gost.sh         # Gost 代理安装
│   ├── install-nginx.sh        # Nginx 安装
│   └── install-python.sh       # Python 环境安装
└── configs/
    ├── gost/
    │   └── config.yaml         # Gost 转发规则
    ├── nginx/
    │   └── sites-available/    # Nginx 站点配置
    └── python/
        ├── projects.conf       # Python 项目列表
        └── myapp.service       # systemd 服务模板
```

## 使用方法

```bash
# 迁移到新服务器时
scp -r server-setup/ root@新服务器IP:/root/

# 全部安装
sudo bash setup.sh

# 只安装某个组件
sudo bash setup.sh --gost
sudo bash setup.sh --nginx
sudo bash setup.sh --python
```

## 迁移前准备

1. 修改 `configs/gost/config.yaml` 中的转发规则
2. 把你的 Nginx 站点配置放到 `configs/nginx/sites-available/`
3. 把 Python 项目的 requirements.txt 放到 `configs/python/`
4. 编辑 `configs/python/projects.conf` 添加项目信息
