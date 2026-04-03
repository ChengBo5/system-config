# 新服务器初始化指南

拿到一台全新的 Ubuntu 24.04 服务器后，按以下步骤操作。

## 1. 创建用户并添加 sudo 权限

```bash
# 用 root 登录服务器后，创建新用户（把 chengbo 换成你的用户名）
adduser chengbo

# 将用户添加到 sudo 组
usermod -aG sudo chengbo

# 验证是否成功
id chengbo
# 输出应包含: groups=...,27(sudo)
```

## 2. 安装并配置 SSH

```bash
# 安装 openssh-server（大部分云服务器已预装）
apt-get update -y
apt-get install -y openssh-server

# 确认 ssh 服务运行中
systemctl enable ssh
systemctl start ssh
```

## 3. 配置 SSH 免密登录

在你的本地电脑上操作：

```bash
# 如果本地还没有密钥对，先生成一个（已有则跳过）
ssh-keygen -t ed25519 -C "your_email"
# 一路回车即可，密钥保存在 ~/.ssh/id_ed25519

# 将公钥上传到服务器（把 IP 换成你的服务器地址）
ssh-copy-id chengbo@服务器IP

# 测试免密登录
ssh chengbo@服务器IP
```

如果 `ssh-copy-id` 不可用，手动操作：

```bash
# 本地查看公钥
cat ~/.ssh/id_ed25519.pub

# 登录服务器，手动添加公钥
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "粘贴你的公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## 4. 加固 SSH 安全配置（可选但推荐）

在服务器上编辑 SSH 配置：

```bash
sudo vim /etc/ssh/sshd_config
```

修改以下配置项：

```
# 禁用 root 远程登录
PermitRootLogin no

# 禁用密码登录（确保免密登录测试成功后再改）
PasswordAuthentication no

# 可选: 修改默认端口（减少扫描攻击）
# Port 2222
```

重启 SSH 使配置生效：

```bash
sudo systemctl restart ssh
```

> 注意: 禁用密码登录前，务必确认免密登录已经能正常使用，否则会把自己锁在外面。

## 5. 完成后继续部署

用户和 SSH 配置好后，就可以开始部署服务了：

```bash
# 把项目拷贝到服务器
scp -r server-setup/ chengbo@服务器IP:~/code/server-config/

# 登录服务器，按 README.md 中的步骤执行部署脚本
```

---

## 6. 防火墙配置 (UFW)

```bash
# 启用防火墙
sudo ufw enable

# 放行 SSH（必须先放行，否则会断连）
sudo ufw allow ssh
# 如果改了 SSH 端口: sudo ufw allow 2222/tcp

# 放行 HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# 查看当前规则
sudo ufw status verbose

# 如果需要放行其他端口
# sudo ufw allow 8317/tcp
```

## 7. 防暴力破解 (Fail2Ban)

```bash
sudo apt-get install -y fail2ban

# 创建本地配置（不要直接改 jail.conf）
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo vim /etc/fail2ban/jail.local
```

修改关键配置：

```ini
[sshd]
enabled = true
port = ssh
maxretry = 5        # 最多尝试 5 次
bantime = 3600      # 封禁 1 小时
findtime = 600      # 10 分钟内
```

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

# 查看封禁状态
sudo fail2ban-client status sshd
```

## 8. 设置时区和时间同步

```bash
# 设置时区为上海
sudo timedatectl set-timezone Asia/Shanghai

# 确认时间
timedatectl

# 安装并启用时间同步（Ubuntu 24.04 默认用 systemd-timesyncd）
sudo systemctl enable systemd-timesyncd
sudo systemctl start systemd-timesyncd
```

## 9. 设置 swap 交换空间（小内存服务器推荐）

```bash
# 查看当前 swap
free -h

# 如果没有 swap，创建 2G 交换文件
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# 设置开机自动挂载
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 验证
free -h
```

## 10. 安装常用工具

```bash
sudo apt-get update -y
sudo apt-get install -y \
    curl wget git unzip zip \
    vim htop tree tmux \
    net-tools lsof \
    build-essential \
    software-properties-common
```

各工具用途：
- `htop` — 交互式进程监控，比 top 好用
- `tmux` — 终端复用，断开 SSH 后进程不会挂
- `tree` — 目录结构可视化
- `net-tools` — ifconfig、netstat 等网络工具
- `lsof` — 查看端口占用: `lsof -i :80`

## 11. 配置 Git

```bash
git config --global user.name "your_name"
git config --global user.email "your_email"

# 可选: 生成 SSH 密钥用于 GitHub
ssh-keygen -t ed25519 -C "your_email"
cat ~/.ssh/id_ed25519.pub
# 复制公钥添加到 GitHub -> Settings -> SSH Keys
```

## 12. 设置系统资源限制（高并发场景）

```bash
# 提高最大文件打开数（对 nginx、gost 等网络服务有用）
sudo vim /etc/security/limits.conf
```

添加：

```
* soft nofile 65536
* hard nofile 65536
```

```bash
# 优化内核网络参数
sudo vim /etc/sysctl.conf
```

添加：

```ini
# 允许更多的 TCP 连接
net.core.somaxconn = 65535
# 加快 TIME_WAIT 回收
net.ipv4.tcp_tw_reuse = 1
# 增大端口范围
net.ipv4.ip_local_port_range = 1024 65535
```

```bash
# 使配置生效
sudo sysctl -p
```

## 完整初始化顺序

1. 创建用户 + sudo 权限
2. 配置 SSH + 免密登录
3. 防火墙 (UFW)
4. 防暴力破解 (Fail2Ban)
5. 时区 + 时间同步
6. Swap（小内存服务器）
7. 常用工具
8. Git 配置
9. 系统资源限制（可选）
10. 部署业务服务（运行 setup.sh）
