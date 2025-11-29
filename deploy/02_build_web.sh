#!/bin/bash

# 02_build_web.sh - 构建前端项目并复制到Docker目录

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Windows Git Bash路径转换：Docker需要Windows格式路径
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$MSYSTEM" ]]; then
    # Windows环境，转换路径格式
    # 方法1: 使用pwd -W（Git Bash特有，最可靠）
    cd "$PROJECT_ROOT/ruoyi-ui"
    if pwd -W &> /dev/null; then
        UI_DIR_DOCKER=$(pwd -W | sed 's|\\|/|g')
    # 方法2: 使用cygpath（如果可用）
    elif command -v cygpath &> /dev/null 2>&1; then
        UI_DIR_DOCKER=$(cygpath -w "$PROJECT_ROOT/ruoyi-ui" | sed 's|\\|/|g')
    # 方法3: 手动转换
    elif [[ "$PROJECT_ROOT" =~ ^/([a-z])/(.*) ]]; then
        DRIVE_LETTER=$(echo "${BASH_REMATCH[1]}" | tr '[:lower:]' '[:upper:]')
        PATH_PART="${BASH_REMATCH[2]}"
        UI_DIR_DOCKER="${DRIVE_LETTER}:/${PATH_PART}/ruoyi-ui"
    else
        UI_DIR_DOCKER="$PROJECT_ROOT/ruoyi-ui"
    fi
    cd "$SCRIPT_DIR"
else
    UI_DIR_DOCKER="$PROJECT_ROOT/ruoyi-ui"
fi

UI_DIR="$PROJECT_ROOT/ruoyi-ui"
DOCKER_NGINX_DIR="$PROJECT_ROOT/docker_dev/nginx/html/dist"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始构建前端项目...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查前端目录
if [ ! -f "$UI_DIR/package.json" ]; then
    echo -e "${RED}错误: 未找到前端项目目录 $UI_DIR${NC}"
    exit 1
fi

# 检查Node.js是否安装
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}未检测到本地Node.js，使用Docker容器构建...${NC}"
    
    # 使用Node.js Docker镜像构建
    CONTAINER_NAME="ruoyi-web-build-$(date +%s)"
    
    echo -e "${YELLOW}使用Docker容器构建前端...${NC}"
    
    # 使用Node.js官方镜像进行构建
    # 在Windows上避免使用 -w 参数，改为在命令中切换目录
    docker run --rm \
        --name "$CONTAINER_NAME" \
        -v "$UI_DIR_DOCKER:/workspace" \
        node:16-alpine \
        sh -c "cd /workspace && npm install --registry=https://registry.npmmirror.com && npm run build:prod"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 前端构建失败${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}使用本地Node.js环境构建...${NC}"
    
    cd "$UI_DIR"
    
    # 安装依赖
    echo -e "${YELLOW}安装npm依赖...${NC}"
    npm install --registry=https://registry.npmmirror.com
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: npm install 失败${NC}"
        exit 1
    fi
    
    # 构建生产版本
    echo -e "${YELLOW}构建生产版本...${NC}"
    npm run build:prod
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}错误: 前端构建失败${NC}"
        exit 1
    fi
fi

# 检查构建输出目录
DIST_DIR="$UI_DIR/dist"
if [ ! -d "$DIST_DIR" ]; then
    echo -e "${RED}错误: 构建输出目录不存在: $DIST_DIR${NC}"
    exit 1
fi

# 创建Docker nginx目录
echo -e "${YELLOW}复制前端文件到Docker目录...${NC}"
mkdir -p "$DOCKER_NGINX_DIR"

# 清空目标目录（如果存在）
if [ -d "$DOCKER_NGINX_DIR" ]; then
    rm -rf "$DOCKER_NGINX_DIR"/*
fi

# 复制构建文件
cp -r "$DIST_DIR"/* "$DOCKER_NGINX_DIR/"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}前端构建完成！${NC}"
echo -e "${GREEN}文件已复制到: $DOCKER_NGINX_DIR${NC}"
echo -e "${GREEN}========================================${NC}"

