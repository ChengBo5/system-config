#!/bin/bash
set -e

INSTALL_DIR="$HOME/.system_config/9router"

echo "=== Installing 9router ==="

# 创建安装目录
mkdir -p "$INSTALL_DIR"

# 检查 Node.js
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed. Please install Node.js 20+ first."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo "Error: Node.js version 20+ is required. Current version: $(node -v)"
    exit 1
fi

echo "Node.js version: $(node -v)"

# 克隆或更新仓库
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "Updating existing 9router installation..."
    cd "$INSTALL_DIR"
    git pull
else
    echo "Cloning 9router repository..."
    git clone https://github.com/decolua/9router.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 安装依赖
echo "Installing dependencies..."
npm install

# 构建
echo "Building 9router..."
npm run build

# 创建 .env 文件（如果不存在）
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "Creating .env file..."
    cat > "$INSTALL_DIR/.env" << 'EOF'
# 9router 配置
PORT=8317
HOSTNAME=0.0.0.0
NODE_ENV=production

# 安全配置（请修改这些值）
JWT_SECRET=your-secure-secret-change-this
INITIAL_PASSWORD=123456
API_KEY_SECRET=endpoint-proxy-api-key-secret
MACHINE_ID_SALT=endpoint-proxy-salt

# 数据目录
DATA_DIR=__HOME__/.9router

# 基础 URL
BASE_URL=http://localhost:8317
NEXT_PUBLIC_BASE_URL=http://localhost:8317
NEXT_PUBLIC_CLOUD_URL=https://9router.com

# HTTPS 反代配置（如果使用 nginx 反代）
AUTH_COOKIE_SECURE=false
REQUIRE_API_KEY=false
EOF
    # 替换 HOME 路径
    sed -i "s|__HOME__|$HOME|g" "$INSTALL_DIR/.env"
    echo ".env file created. Please edit $INSTALL_DIR/.env to configure your settings."
fi

echo ""
echo "=== 9router installed successfully ==="
echo "Install directory: $INSTALL_DIR"
echo ""
echo "Next steps:"
echo "1. Edit $INSTALL_DIR/.env to configure your settings"
echo "2. Run 'sudo bash server-setup/scripts/start-9router.sh' to register as systemd service"
echo "3. Access dashboard at http://localhost:8317/dashboard"
