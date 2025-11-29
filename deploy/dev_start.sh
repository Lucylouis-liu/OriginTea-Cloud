#!/bin/bash

# dev_start.sh - 开发环境启动脚本
# 使用 docker-compose.dev.yml 启动开发环境，JAR 文件通过 volume 映射到本机
# 方便调试：修改代码后只需重新编译并重启对应服务即可

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCKER_DIR="$PROJECT_ROOT/docker_dev"
COMPOSE_FILE="$DOCKER_DIR/docker-compose.dev.yml"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开发环境启动脚本${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 docker-compose.dev.yml 文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}错误: 未找到开发环境配置文件 $COMPOSE_FILE${NC}"
    exit 1
fi

# 检查基础服务
echo -e "${BLUE}检查基础服务状态...${NC}"

check_service() {
    local service=$1
    if docker ps --format "{{.Names}}" | grep -q "^${service}$"; then
        echo -e "${GREEN}✓ ${service} 正在运行${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ ${service} 未运行${NC}"
        return 1
    fi
}

# 检查 MySQL
if ! check_service "ruoyi-mysql"; then
    echo -e "${YELLOW}启动 MySQL...${NC}"
    cd "$DOCKER_DIR"
    docker-compose -f docker-compose.dev.yml up -d ruoyi-mysql
    echo -e "${YELLOW}等待 MySQL 启动...${NC}"
    sleep 10
fi

# 检查 Redis
if ! check_service "ruoyi-redis"; then
    echo -e "${YELLOW}启动 Redis...${NC}"
    cd "$DOCKER_DIR"
    docker-compose -f docker-compose.dev.yml up -d ruoyi-redis
    sleep 5
fi

# 检查 Nacos
if ! check_service "ruoyi-nacos"; then
    echo -e "${YELLOW}启动 Nacos...${NC}"
    cd "$DOCKER_DIR"
    docker-compose -f docker-compose.dev.yml up -d ruoyi-nacos
    echo -e "${YELLOW}等待 Nacos 启动...${NC}"
    sleep 15
fi

# 检查应用服务 JAR 文件是否存在
echo -e "${BLUE}检查应用服务 JAR 文件...${NC}"

declare -A JAR_FILES=(
    ["ruoyi-gateway"]="ruoyi/gateway/jar/ruoyi-gateway.jar"
    ["ruoyi-auth"]="ruoyi/auth/jar/ruoyi-auth.jar"
    ["ruoyi-modules-system"]="ruoyi/modules/system/jar/ruoyi-modules-system.jar"
    ["ruoyi-modules-gen"]="ruoyi/modules/gen/jar/ruoyi-modules-gen.jar"
    ["ruoyi-modules-job"]="ruoyi/modules/job/jar/ruoyi-modules-job.jar"
    ["ruoyi-modules-file"]="ruoyi/modules/file/jar/ruoyi-modules-file.jar"
    ["ruoyi-visual-monitor"]="ruoyi/visual/monitor/jar/ruoyi-visual-monitor.jar"
)

MISSING_JARS=()
for service in "${!JAR_FILES[@]}"; do
    jar_path="$DOCKER_DIR/${JAR_FILES[$service]}"
    if [ ! -f "$jar_path" ]; then
        MISSING_JARS+=("$service")
        echo -e "${YELLOW}⚠ ${service}: JAR 文件不存在 ${jar_path}${NC}"
    else
        echo -e "${GREEN}✓ ${service}: JAR 文件存在${NC}"
    fi
done

if [ ${#MISSING_JARS[@]} -gt 0 ]; then
    echo -e "${YELLOW}以下服务的 JAR 文件不存在，请先执行编译：${NC}"
    for service in "${MISSING_JARS[@]}"; do
        echo -e "${YELLOW}  - ${service}${NC}"
    done
    echo -e "${BLUE}提示: 运行 ./01_build_jar.sh [服务名] 来编译服务${NC}"
    read -p "是否继续启动其他服务? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 启动应用服务
echo -e "${BLUE}启动应用服务...${NC}"
cd "$DOCKER_DIR"

# 如果指定了服务名，只启动该服务
if [ $# -gt 0 ]; then
    for service in "$@"; do
        echo -e "${YELLOW}启动服务: ${service}...${NC}"
        docker-compose -f docker-compose.dev.yml up -d "$service"
        sleep 3
    done
else
    # 启动所有应用服务
    echo -e "${YELLOW}启动所有应用服务...${NC}"
    docker-compose -f docker-compose.dev.yml up -d \
        ruoyi-gateway \
        ruoyi-auth \
        ruoyi-modules-system \
        ruoyi-modules-gen \
        ruoyi-modules-job \
        ruoyi-modules-file \
        ruoyi-visual-monitor
fi

# 启动 Nginx
if ! check_service "ruoyi-nginx"; then
    echo -e "${YELLOW}启动 Nginx...${NC}"
    docker-compose -f docker-compose.dev.yml up -d ruoyi-nginx
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开发环境启动完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${BLUE}提示:${NC}"
echo -e "${BLUE}1. 修改代码后，运行 ./01_build_jar.sh [服务名] 重新编译${NC}"
echo -e "${BLUE}2. 然后运行 docker-compose -f docker-compose.dev.yml restart [服务名] 重启服务${NC}"
echo -e "${BLUE}3. 查看日志: docker logs -f [容器名]${NC}"

