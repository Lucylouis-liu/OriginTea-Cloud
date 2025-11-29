#!/bin/bash

# 05_build_redis.sh - 创建Redis容器

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker_dev"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始创建Redis容器...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

# 进入docker目录
cd "$DOCKER_DIR"

# 停止并删除已存在的Redis容器
echo -e "${YELLOW}检查并清理已存在的Redis容器...${NC}"
docker-compose stop ruoyi-redis 2>/dev/null || true
docker-compose rm -f ruoyi-redis 2>/dev/null || true

# 启动Redis容器
echo -e "${YELLOW}启动Redis容器...${NC}"
docker-compose up -d ruoyi-redis

# 等待Redis启动
echo -e "${YELLOW}等待Redis服务启动...${NC}"
sleep 5

# 检查Redis是否就绪
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker exec ruoyi-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo -e "${GREEN}Redis服务已就绪${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待Redis启动... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 1
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: Redis服务启动超时${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Redis容器创建完成！${NC}"
echo -e "${GREEN}========================================${NC}"

