#!/bin/bash

# 04_build_nacos.sh - 创建Nacos容器并配置基础信息

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
NACOS_CONF_DIR="$DOCKER_DIR/nacos/conf"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始创建Nacos容器并配置...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

# 检查Nacos配置文件
if [ ! -f "$NACOS_CONF_DIR/application.properties" ]; then
    echo -e "${RED}错误: 未找到Nacos配置文件${NC}"
    exit 1
fi

# 进入docker目录
cd "$DOCKER_DIR"

# 停止并删除已存在的Nacos容器
echo -e "${YELLOW}检查并清理已存在的Nacos容器...${NC}"
docker-compose stop ruoyi-nacos 2>/dev/null || true
docker-compose rm -f ruoyi-nacos 2>/dev/null || true

# 启动Nacos容器（依赖MySQL）
echo -e "${YELLOW}启动Nacos容器...${NC}"
docker-compose up -d ruoyi-nacos

# 等待Nacos启动
echo -e "${YELLOW}等待Nacos服务启动...${NC}"
sleep 15

# 检查Nacos是否就绪
MAX_RETRIES=60
RETRY_COUNT=0
NACOS_URL="http://localhost:8848/nacos"

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "$NACOS_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}Nacos服务已就绪${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待Nacos启动... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: Nacos服务启动超时${NC}"
    echo -e "${YELLOW}请检查Nacos日志: docker logs ruoyi-nacos${NC}"
    exit 1
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Nacos容器创建完成！${NC}"
echo -e "${GREEN}Nacos控制台地址: http://localhost:8848/nacos${NC}"
echo -e "${GREEN}默认用户名/密码: nacos/nacos${NC}"
echo -e "${YELLOW}提示: 可以运行 04_config_nacos.sh 自动配置所有配置信息${NC}"
echo -e "${GREEN}========================================${NC}"

