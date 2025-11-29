#!/bin/bash

# diagnose_nacos_connection.sh - 诊断 Nacos 连接问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}诊断 Nacos 连接问题${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. 检查 Nacos 容器状态
echo -e "\n${YELLOW}1. 检查 Nacos 容器状态...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-nacos$"; then
    echo -e "${GREEN}✓ Nacos 容器正在运行${NC}"
    NACOS_STATUS=$(docker ps --filter "name=ruoyi-nacos" --format "{{.Status}}")
    echo -e "  状态: ${NACOS_STATUS}"
else
    echo -e "${RED}✗ Nacos 容器未运行${NC}"
    echo -e "${YELLOW}请先启动 Nacos: ./04_build_nacos.sh${NC}"
    exit 1
fi

# 2. 检查 Nacos HTTP 端口
echo -e "\n${YELLOW}2. 检查 Nacos HTTP 端口 (8848)...${NC}"
if curl -s "http://localhost:8848/nacos" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nacos HTTP 服务可访问${NC}"
else
    echo -e "${RED}✗ Nacos HTTP 服务不可访问${NC}"
    echo -e "${YELLOW}请检查 Nacos 日志: docker logs ruoyi-nacos${NC}"
fi

# 3. 检查 Nacos gRPC 端口
echo -e "\n${YELLOW}3. 检查 Nacos gRPC 端口 (9848)...${NC}"
if docker exec ruoyi-nacos sh -c "netstat -an 2>/dev/null | grep -q ':9848.*LISTEN'" 2>/dev/null; then
    echo -e "${GREEN}✓ Nacos gRPC 端口正在监听${NC}"
else
    echo -e "${RED}✗ Nacos gRPC 端口未监听${NC}"
    echo -e "${YELLOW}Nacos 可能还在启动中，请稍候...${NC}"
fi

# 4. 检查 Nacos 服务注册 API
echo -e "\n${YELLOW}4. 检查 Nacos 服务注册 API...${NC}"
if curl -s "http://localhost:8848/nacos/v1/ns/service/list?pageNo=1&pageSize=1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Nacos 服务注册 API 可访问${NC}"
else
    echo -e "${RED}✗ Nacos 服务注册 API 不可访问${NC}"
fi

# 5. 检查应用服务容器中的环境变量
echo -e "\n${YELLOW}5. 检查应用服务容器中的 Nacos 环境变量...${NC}"
SERVICES=("ruoyi-gateway" "ruoyi-auth" "ruoyi-modules-system")

for service in "${SERVICES[@]}"; do
    if docker ps --format '{{.Names}}' | grep -q "^${service}$"; then
        echo -e "\n${BLUE}检查 ${service}...${NC}"
        DISCOVERY_ADDR=$(docker exec "${service}" sh -c 'echo $SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR' 2>/dev/null || echo "")
        CONFIG_ADDR=$(docker exec "${service}" sh -c 'echo $SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR' 2>/dev/null || echo "")
        
        if [ -n "$DISCOVERY_ADDR" ]; then
            echo -e "  ${GREEN}✓ SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR=${DISCOVERY_ADDR}${NC}"
        else
            echo -e "  ${RED}✗ SPRING_CLOUD_NACOS_DISCOVERY_SERVER_ADDR 未设置${NC}"
        fi
        
        if [ -n "$CONFIG_ADDR" ]; then
            echo -e "  ${GREEN}✓ SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR=${CONFIG_ADDR}${NC}"
        else
            echo -e "  ${RED}✗ SPRING_CLOUD_NACOS_CONFIG_SERVER_ADDR 未设置${NC}"
        fi
    else
        echo -e "\n${YELLOW}${service} 容器未运行，跳过检查${NC}"
    fi
done

# 6. 测试从容器内访问 Nacos
echo -e "\n${YELLOW}6. 测试从容器内访问 Nacos...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-auth$"; then
    echo -e "${BLUE}从 ruoyi-auth 容器测试连接...${NC}"
    if docker exec ruoyi-auth sh -c "ping -c 1 ruoyi-nacos > /dev/null 2>&1" 2>/dev/null; then
        echo -e "${GREEN}✓ 可以 ping 通 ruoyi-nacos${NC}"
    else
        echo -e "${RED}✗ 无法 ping 通 ruoyi-nacos${NC}"
        echo -e "${YELLOW}请检查 docker-compose.yml 中的 links 配置${NC}"
    fi
    
    # 测试 HTTP 连接
    if docker exec ruoyi-auth sh -c "wget -q -O- http://ruoyi-nacos:8848/nacos/v1/ns/service/list?pageNo=1&pageSize=1 2>/dev/null" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 可以从容器内访问 Nacos HTTP API${NC}"
    else
        echo -e "${RED}✗ 无法从容器内访问 Nacos HTTP API${NC}"
        echo -e "${YELLOW}请检查网络连接和防火墙设置${NC}"
    fi
else
    echo -e "${YELLOW}ruoyi-auth 容器未运行，跳过测试${NC}"
fi

# 7. 检查 Nacos 日志中的错误
echo -e "\n${YELLOW}7. 检查 Nacos 日志中的错误...${NC}"
ERROR_COUNT=$(docker logs ruoyi-nacos 2>&1 | grep -i "error\|exception\|failed" | wc -l)
if [ "$ERROR_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}发现 ${ERROR_COUNT} 个可能的错误/异常${NC}"
    echo -e "${YELLOW}最近的错误日志:${NC}"
    docker logs ruoyi-nacos 2>&1 | grep -i "error\|exception\|failed" | tail -5
else
    echo -e "${GREEN}✓ 未发现明显的错误${NC}"
fi

# 8. 检查应用服务日志
echo -e "\n${YELLOW}8. 检查应用服务日志中的 Nacos 连接错误...${NC}"
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-auth$"; then
    NACOS_ERROR=$(docker logs ruoyi-auth 2>&1 | grep -i "nacos\|not connected\|connection refused" | tail -3)
    if [ -n "$NACOS_ERROR" ]; then
        echo -e "${RED}发现 Nacos 连接错误:${NC}"
        echo -e "${RED}${NACOS_ERROR}${NC}"
    else
        echo -e "${GREEN}✓ 未发现 Nacos 连接错误${NC}"
    fi
fi

# 总结
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}诊断完成${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}如果发现问题，建议:${NC}"
echo -e "  1. 确保 Nacos 容器完全启动: docker logs ruoyi-nacos"
echo -e "  2. 检查 docker-compose.yml 中的环境变量配置"
echo -e "  3. 重启服务: docker-compose restart <service-name>"
echo -e "  4. 如果问题持续，尝试重新启动 Nacos: docker-compose restart ruoyi-nacos"

