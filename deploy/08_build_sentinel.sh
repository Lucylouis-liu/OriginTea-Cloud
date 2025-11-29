#!/bin/bash

# 08_build_sentinel.sh - 创建并启动 Sentinel 控制台容器

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
echo -e "${GREEN}开始创建 Sentinel 控制台容器...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

# 进入docker目录
cd "$DOCKER_DIR"

# 停止并删除已存在的 Sentinel 容器
echo -e "${YELLOW}检查并清理已存在的 Sentinel 容器...${NC}"
docker-compose stop ruoyi-sentinel 2>/dev/null || true
docker-compose rm -f ruoyi-sentinel 2>/dev/null || true

# 启动 Sentinel 容器
echo -e "${YELLOW}启动 Sentinel 控制台容器...${NC}"
docker-compose up -d ruoyi-sentinel

# 等待 Sentinel 启动
echo -e "${YELLOW}等待 Sentinel 控制台启动...${NC}"
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "http://localhost:8718" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Sentinel 控制台已就绪 (http://localhost:8718)${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
        echo -e "${YELLOW}等待 Sentinel 启动... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    fi
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: Sentinel 控制台启动超时${NC}"
    echo -e "${YELLOW}请检查 Sentinel 日志: docker logs ruoyi-sentinel${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Sentinel 控制台容器创建完成！${NC}"
echo -e "${GREEN}访问地址: http://localhost:8718  (账号/密码: sentinel/sentinel)${NC}"
echo -e "${GREEN}========================================${NC}"


