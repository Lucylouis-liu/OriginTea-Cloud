#!/bin/bash

# dev_restart.sh - 开发环境重启脚本
# 快速重启指定服务，用于调试

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

# 定义服务名映射（简化名称到完整服务名）
declare -A SERVICE_MAP=(
    ["gateway"]="ruoyi-gateway"
    ["auth"]="ruoyi-auth"
    ["system"]="ruoyi-modules-system"
    ["gen"]="ruoyi-modules-gen"
    ["job"]="ruoyi-modules-job"
    ["file"]="ruoyi-modules-file"
    ["monitor"]="ruoyi-visual-monitor"
)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开发环境服务重启${NC}"
echo -e "${GREEN}========================================${NC}"

if [ $# -eq 0 ]; then
    echo -e "${YELLOW}用法: $0 [服务名...]${NC}"
    echo -e "${YELLOW}可用服务: gateway, auth, system, gen, job, file, monitor${NC}"
    echo -e "${YELLOW}示例: $0 gateway auth${NC}"
    exit 1
fi

cd "$DOCKER_DIR"

# 处理每个服务
for service_arg in "$@"; do
    # 检查是否是简化名称
    if [[ -n "${SERVICE_MAP[$service_arg]}" ]]; then
        service="${SERVICE_MAP[$service_arg]}"
    else
        # 直接使用完整服务名
        service="$service_arg"
    fi
    
    echo -e "${BLUE}重启服务: ${service}...${NC}"
    docker-compose -f docker-compose.dev.yml restart "$service" || {
        echo -e "${YELLOW}服务 ${service} 未运行，尝试启动...${NC}"
        docker-compose -f docker-compose.dev.yml up -d "$service"
    }
    sleep 2
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}服务重启完成！${NC}"
echo -e "${GREEN}========================================${NC}"

