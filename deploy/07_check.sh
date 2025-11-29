#!/bin/bash

# 07_check.sh - 验证所有部署

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}开始验证部署状态...${NC}"
echo -e "${BLUE}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

cd "$DOCKER_DIR"

# 定义服务列表
declare -A SERVICES=(
    ["ruoyi-mysql"]="3306"
    ["ruoyi-redis"]="6379"
    ["ruoyi-nacos"]="8848"
    ["ruoyi-gateway"]="8080"
    ["ruoyi-auth"]="9200"
    ["ruoyi-modules-system"]="9201"
    ["ruoyi-modules-gen"]="9202"
    ["ruoyi-modules-job"]="9203"
    ["ruoyi-modules-file"]="9300"
    ["ruoyi-visual-monitor"]="9100"
    ["ruoyi-nginx"]="80"
)

# 检查容器状态
echo -e "${YELLOW}检查容器状态...${NC}"
echo ""

ALL_OK=true

for service in "${!SERVICES[@]}"; do
    port="${SERVICES[$service]}"
    
    # 检查容器是否运行
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "${GREEN}✓${NC} ${service} - 容器运行中"
        
        # 检查端口是否可访问
        if command -v nc &> /dev/null; then
            if nc -z localhost "$port" 2>/dev/null; then
                echo -e "  ${GREEN}  ✓${NC} 端口 $port 可访问"
            else
                echo -e "  ${RED}  ✗${NC} 端口 $port 不可访问"
                ALL_OK=false
            fi
        elif command -v curl &> /dev/null; then
            # 对于HTTP服务，使用curl检查
            if [[ "$service" == "ruoyi-nginx" ]] || [[ "$service" == "ruoyi-gateway" ]] || [[ "$service" == "ruoyi-nacos" ]] || [[ "$service" == "ruoyi-visual-monitor" ]]; then
                if curl -s "http://localhost:$port" > /dev/null 2>&1; then
                    echo -e "  ${GREEN}  ✓${NC} HTTP服务可访问 (端口 $port)"
                else
                    echo -e "  ${YELLOW}  ⚠${NC} HTTP服务可能未就绪 (端口 $port)"
                fi
            fi
        fi
    else
        echo -e "${RED}✗${NC} ${service} - 容器未运行"
        ALL_OK=false
    fi
    echo ""
done

# 检查JAR文件
echo -e "${YELLOW}检查JAR文件...${NC}"
JAR_FILES=(
    "docker_dev/ruoyi/gateway/jar/ruoyi-gateway.jar"
    "docker_dev/ruoyi/auth/jar/ruoyi-auth.jar"
    "docker_dev/ruoyi/modules/system/jar/ruoyi-modules-system.jar"
    "docker_dev/ruoyi/modules/gen/jar/ruoyi-modules-gen.jar"
    "docker_dev/ruoyi/modules/job/jar/ruoyi-modules-job.jar"
    "docker_dev/ruoyi/modules/file/jar/ruoyi-modules-file.jar"
    "docker_dev/ruoyi/visual/monitor/jar/ruoyi-visual-monitor.jar"
)

for jar_file in "${JAR_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$jar_file" ]; then
        echo -e "${GREEN}✓${NC} $(basename $jar_file)"
    else
        echo -e "${RED}✗${NC} $(basename $jar_file) - 文件不存在"
        ALL_OK=false
    fi
done
echo ""

# 检查前端文件
echo -e "${YELLOW}检查前端文件...${NC}"
if [ -d "$PROJECT_ROOT/docker_dev/nginx/html/dist" ] && [ "$(ls -A $PROJECT_ROOT/docker_dev/nginx/html/dist 2>/dev/null)" ]; then
    echo -e "${GREEN}✓${NC} 前端文件已部署"
else
    echo -e "${RED}✗${NC} 前端文件未部署"
    ALL_OK=false
fi
echo ""

# 检查数据库连接
echo -e "${YELLOW}检查数据库连接...${NC}"
if docker exec ruoyi-mysql mysqladmin ping -h localhost --silent 2>/dev/null; then
    echo -e "${GREEN}✓${NC} MySQL连接正常"
    
    # 检查数据库是否存在
    DB_COUNT=$(docker exec ruoyi-mysql mysql -uroot -ppassword -e "SHOW DATABASES LIKE 'ry-%';" 2>/dev/null | grep -c "ry-" || echo "0")
    if [ "$DB_COUNT" -ge 3 ]; then
        echo -e "${GREEN}✓${NC} 数据库已创建 ($DB_COUNT 个)"
    else
        echo -e "${YELLOW}⚠${NC} 数据库可能未完全初始化"
    fi
else
    echo -e "${RED}✗${NC} MySQL连接失败"
    ALL_OK=false
fi
echo ""

# 检查Redis连接
echo -e "${YELLOW}检查Redis连接...${NC}"
if docker exec ruoyi-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓${NC} Redis连接正常"
else
    echo -e "${RED}✗${NC} Redis连接失败"
    ALL_OK=false
fi
echo ""

# 检查Nacos连接
echo -e "${YELLOW}检查Nacos连接...${NC}"
if curl -s "http://localhost:8848/nacos" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Nacos服务可访问"
    echo -e "  ${BLUE}  控制台: http://localhost:8848/nacos${NC}"
    echo -e "  ${BLUE}  默认账号: nacos/nacos${NC}"
else
    echo -e "${RED}✗${NC} Nacos服务不可访问"
    ALL_OK=false
fi
echo ""

# 检查服务日志（最近错误）
echo -e "${YELLOW}检查服务日志（最近错误）...${NC}"
for service in "${!SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        ERROR_COUNT=$(docker logs "$service" 2>&1 | grep -i "error\|exception\|failed" | tail -5 | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}⚠${NC} ${service} 有错误日志，请检查: docker logs ${service}"
        fi
    fi
done
echo ""

# 总结
echo -e "${BLUE}========================================${NC}"
if [ "$ALL_OK" = true ]; then
    echo -e "${GREEN}部署验证完成！所有服务正常${NC}"
    echo ""
    echo -e "${GREEN}访问地址:${NC}"
    echo -e "  ${GREEN}前端:${NC} http://localhost"
    echo -e "  ${GREEN}网关:${NC} http://localhost:8080"
    echo -e "  ${GREEN}Nacos:${NC} http://localhost:8848/nacos"
    echo -e "  ${GREEN}监控:${NC} http://localhost:9100"
    echo ""
    echo -e "${YELLOW}默认登录账号: admin/admin123${NC}"
else
    echo -e "${RED}部署验证发现问题，请检查上述错误${NC}"
    exit 1
fi
echo -e "${BLUE}========================================${NC}"

