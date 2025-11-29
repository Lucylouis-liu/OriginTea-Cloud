#!/bin/bash

# 06_start.sh - 启动所有服务

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
echo -e "${GREEN}开始启动所有服务...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

# 进入docker目录
cd "$DOCKER_DIR"

# 检查基础服务是否运行
echo -e "${YELLOW}检查基础服务状态...${NC}"

check_service() {
    local service_name=$1
    if docker ps --format '{{.Names}}' | grep -q "^${service_name}$"; then
        echo -e "${GREEN}✓ $service_name 正在运行${NC}"
        return 0
    else
        echo -e "${RED}✗ $service_name 未运行${NC}"
        return 1
    fi
}

# 检查MySQL
if ! check_service "ruoyi-mysql"; then
    echo -e "${YELLOW}MySQL未运行，请先执行 03_build_mysql.sh${NC}"
    exit 1
fi

# 等待MySQL完全就绪
echo -e "${YELLOW}等待MySQL服务完全就绪...${NC}"
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # 测试从容器内访问MySQL（模拟服务容器的访问方式）
    if docker exec ruoyi-mysql mysql -uroot -ppassword -h ruoyi-mysql -e "SELECT 1;" 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}✓ MySQL服务已就绪并可访问${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
        echo -e "${YELLOW}等待MySQL就绪... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    fi
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: MySQL服务启动超时或无法访问${NC}"
    echo -e "${YELLOW}请检查MySQL日志: docker logs ruoyi-mysql${NC}"
    exit 1
fi

# 额外等待，确保MySQL完全初始化
echo -e "${YELLOW}等待MySQL完全初始化...${NC}"
sleep 5

# 检查Redis
if ! check_service "ruoyi-redis"; then
    echo -e "${YELLOW}Redis未运行，请先执行 05_build_redis.sh${NC}"
    exit 1
fi

# 检查Nacos
if ! check_service "ruoyi-nacos"; then
    echo -e "${YELLOW}Nacos未运行，请先执行 04_build_nacos.sh${NC}"
    exit 1
fi

# 等待Nacos完全就绪
echo -e "${YELLOW}等待Nacos服务完全就绪...${NC}"
MAX_RETRIES=90
RETRY_COUNT=0
NACOS_URL="http://localhost:8848/nacos"

# 检查HTTP接口
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s "$NACOS_URL" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Nacos HTTP服务已就绪${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待Nacos HTTP就绪... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: Nacos HTTP服务启动超时${NC}"
    echo -e "${YELLOW}请检查Nacos日志: docker logs ruoyi-nacos${NC}"
    exit 1
fi

# 检查gRPC端口（Nacos 2.x需要）
echo -e "${YELLOW}等待Nacos gRPC服务就绪...${NC}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 60 ]; do
    if docker exec ruoyi-nacos sh -c "netstat -an 2>/dev/null | grep -q ':9848.*LISTEN'" 2>/dev/null; then
        # 进一步检查 gRPC 服务是否真的可用（通过测试连接）
        if docker exec ruoyi-nacos sh -c "timeout 2 sh -c 'echo > /dev/tcp/localhost/9848' 2>/dev/null" || \
           docker exec ruoyi-nacos sh -c "nc -z localhost 9848 2>/dev/null"; then
            echo -e "${GREEN}✓ Nacos gRPC服务已就绪${NC}"
            break
        fi
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
        echo -e "${YELLOW}等待Nacos gRPC就绪... ($RETRY_COUNT/60)${NC}"
    fi
    sleep 2
done

if [ $RETRY_COUNT -eq 60 ]; then
    echo -e "${YELLOW}警告: Nacos gRPC服务检查超时，但继续启动服务${NC}"
fi

# 通过 Nacos API 验证服务是否真的就绪
echo -e "${YELLOW}验证Nacos服务注册中心是否就绪...${NC}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt 30 ]; do
    # 尝试访问 Nacos 的命名服务 API
    if curl -s "http://localhost:8848/nacos/v1/ns/service/list?pageNo=1&pageSize=1" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Nacos服务注册中心已就绪${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
        echo -e "${YELLOW}等待Nacos服务注册中心就绪... ($RETRY_COUNT/30)${NC}"
    fi
    sleep 2
done

# 额外等待一下，确保Nacos完全初始化（包括服务注册中心完全就绪）
echo -e "${YELLOW}等待Nacos完全初始化...${NC}"
sleep 15

# 启动应用服务
echo -e "${YELLOW}启动应用服务...${NC}"

# 按依赖顺序启动服务
echo -e "${YELLOW}0. 启动 Sentinel 控制台(如未启动)...${NC}"
if ! check_service "ruoyi-sentinel"; then
    docker-compose up -d ruoyi-sentinel
    sleep 5
fi

echo -e "${YELLOW}1. 启动网关服务...${NC}"
docker-compose up -d ruoyi-gateway
sleep 15  # 增加等待时间，确保网关有足够时间连接Nacos

echo -e "${YELLOW}2. 启动认证服务...${NC}"
docker-compose up -d ruoyi-auth
sleep 15  # 增加等待时间，确保认证服务有足够时间连接Nacos

echo -e "${YELLOW}3. 启动系统服务...${NC}"
docker-compose up -d ruoyi-modules-system
sleep 15  # 增加等待时间，确保有足够时间连接MySQL

echo -e "${YELLOW}4. 启动代码生成服务...${NC}"
docker-compose up -d ruoyi-modules-gen
sleep 15  # 增加等待时间，确保有足够时间连接MySQL

echo -e "${YELLOW}5. 启动定时任务服务...${NC}"
docker-compose up -d ruoyi-modules-job
sleep 15  # 增加等待时间，确保有足够时间连接MySQL

echo -e "${YELLOW}6. 启动文件服务...${NC}"
docker-compose up -d ruoyi-modules-file
sleep 3

echo -e "${YELLOW}7. 启动监控服务...${NC}"
docker-compose up -d ruoyi-visual-monitor
sleep 3

echo -e "${YELLOW}8. 启动Nginx前端服务...${NC}"
docker-compose up -d ruoyi-nginx
sleep 3

# 显示所有服务状态
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}所有服务启动完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}服务状态:${NC}"
docker-compose ps

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}服务访问地址:${NC}"
echo -e "${GREEN}  前端: http://localhost${NC}"
echo -e "${GREEN}  网关: http://localhost:8080${NC}"
echo -e "${GREEN}  Nacos: http://localhost:8848/nacos${NC}"
echo -e "${GREEN}  监控中心: http://localhost:9100${NC}"
echo -e "${GREEN}  Sentinel 控制台: http://localhost:8718 (sentinel / sentinel)${NC}"
echo -e "${GREEN}========================================${NC}"

