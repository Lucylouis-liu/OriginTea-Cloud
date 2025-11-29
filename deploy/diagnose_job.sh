#!/bin/bash

# diagnose_job.sh - 诊断 job 服务的 MyBatis Mapper 问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}诊断 job 服务 MyBatis Mapper 问题${NC}"
echo -e "${GREEN}========================================${NC}"

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 1. 检查 JAR 包是否存在
echo -e "${YELLOW}1. 检查 JAR 包...${NC}"
JAR_FILE="$PROJECT_ROOT/docker_dev/ruoyi/modules/job/jar/ruoyi-modules-job.jar"
if [ -f "$JAR_FILE" ]; then
    echo -e "${GREEN}✓ JAR 包存在: $JAR_FILE${NC}"
    JAR_SIZE=$(stat -f%z "$JAR_FILE" 2>/dev/null || stat -c%s "$JAR_FILE" 2>/dev/null || echo "unknown")
    echo -e "${BLUE}  JAR 包大小: ${JAR_SIZE} 字节${NC}"
else
    echo -e "${RED}✗ JAR 包不存在: $JAR_FILE${NC}"
    exit 1
fi

# 2. 检查 JAR 包中是否包含 Mapper XML 文件
echo -e "${YELLOW}2. 检查 JAR 包中的 Mapper XML 文件...${NC}"
if command -v unzip &> /dev/null; then
    MAPPER_FILES=$(unzip -l "$JAR_FILE" 2>/dev/null | grep -i "mapper.*\.xml" | head -10)
    if [ -n "$MAPPER_FILES" ]; then
        echo -e "${GREEN}✓ 找到 Mapper XML 文件:${NC}"
        echo "$MAPPER_FILES" | while read -r line; do
            echo -e "${BLUE}  $line${NC}"
        done
    else
        echo -e "${RED}✗ JAR 包中未找到 Mapper XML 文件${NC}"
        echo -e "${YELLOW}  这可能是问题的根源！${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 未安装 unzip，跳过 JAR 包内容检查${NC}"
fi

# 3. 检查 Nacos 配置
echo -e "${YELLOW}3. 检查 Nacos 配置...${NC}"
NACOS_URL="http://localhost:8848"
NACOS_USERNAME="nacos"
NACOS_PASSWORD="nacos"

# 获取访问令牌
TOKEN_RESPONSE=$(curl -s -X POST "${NACOS_URL}/nacos/v1/auth/login" \
    -d "username=${NACOS_USERNAME}&password=${NACOS_PASSWORD}")

if echo "$TOKEN_RESPONSE" | grep -q "accessToken"; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 获取 Nacos 访问令牌成功${NC}"
    
    # 检查共享配置
    echo -e "${YELLOW}  检查共享配置 (application-dev.yml)...${NC}"
    SHARED_CONFIG=$(curl -s -X GET "${NACOS_URL}/nacos/v1/cs/configs" \
        -d "dataId=application-dev.yml" \
        -d "group=DEFAULT_GROUP" \
        -d "accessToken=${ACCESS_TOKEN}")
    
    if echo "$SHARED_CONFIG" | grep -q "mapper-locations"; then
        echo -e "${GREEN}  ✓ 共享配置中包含 mapper-locations${NC}"
        echo "$SHARED_CONFIG" | grep -A 2 "mapper-locations" | head -3 | while read -r line; do
            echo -e "${BLUE}    $line${NC}"
        done
    else
        echo -e "${RED}  ✗ 共享配置中未找到 mapper-locations${NC}"
    fi
    
    # 检查 job 服务配置
    echo -e "${YELLOW}  检查 job 服务配置 (ruoyi-job-dev.yml)...${NC}"
    JOB_CONFIG=$(curl -s -X GET "${NACOS_URL}/nacos/v1/cs/configs" \
        -d "dataId=ruoyi-job-dev.yml" \
        -d "group=DEFAULT_GROUP" \
        -d "accessToken=${ACCESS_TOKEN}")
    
    if echo "$JOB_CONFIG" | grep -q "mapper-locations"; then
        echo -e "${GREEN}  ✓ job 服务配置中包含 mapper-locations${NC}"
        echo "$JOB_CONFIG" | grep -A 2 "mapper-locations" | head -3 | while read -r line; do
            echo -e "${BLUE}    $line${NC}"
        done
    else
        echo -e "${RED}  ✗ job 服务配置中未找到 mapper-locations${NC}"
    fi
else
    echo -e "${RED}✗ 无法获取 Nacos 访问令牌${NC}"
fi

# 4. 检查容器状态
echo -e "${YELLOW}4. 检查容器状态...${NC}"
if docker ps -a --format '{{.Names}}' | grep -q "^ruoyi-modules-job$"; then
    CONTAINER_STATUS=$(docker ps -a --filter "name=ruoyi-modules-job" --format "{{.Status}}")
    echo -e "${BLUE}  容器状态: ${CONTAINER_STATUS}${NC}"
    
    if echo "$CONTAINER_STATUS" | grep -q "Up"; then
        echo -e "${GREEN}  ✓ 容器正在运行${NC}"
    else
        echo -e "${YELLOW}  ⚠ 容器未运行${NC}"
    fi
else
    echo -e "${RED}  ✗ 容器不存在${NC}"
fi

# 5. 检查 Mapper XML 文件在源码中的位置
echo -e "${YELLOW}5. 检查源码中的 Mapper XML 文件...${NC}"
MAPPER_SOURCE="$PROJECT_ROOT/ruoyi-modules/ruoyi-job/src/main/resources/mapper/job/SysJobMapper.xml"
if [ -f "$MAPPER_SOURCE" ]; then
    echo -e "${GREEN}✓ 源码中存在 Mapper XML 文件: $MAPPER_SOURCE${NC}"
    FILE_SIZE=$(stat -f%z "$MAPPER_SOURCE" 2>/dev/null || stat -c%s "$MAPPER_SOURCE" 2>/dev/null || echo "unknown")
    echo -e "${BLUE}  文件大小: ${FILE_SIZE} 字节${NC}"
    
    # 检查文件内容
    if grep -q "selectJobAll" "$MAPPER_SOURCE"; then
        echo -e "${GREEN}  ✓ 文件中包含 selectJobAll 方法${NC}"
    else
        echo -e "${RED}  ✗ 文件中未找到 selectJobAll 方法${NC}"
    fi
else
    echo -e "${RED}✗ 源码中不存在 Mapper XML 文件: $MAPPER_SOURCE${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}诊断完成！${NC}"
echo -e "${GREEN}========================================${NC}"

