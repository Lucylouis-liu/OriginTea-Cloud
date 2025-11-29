#!/bin/bash

# check_nacos_config.sh - 检查 Nacos 配置文件中的 Redis 和 MySQL 连接配置

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}检查 Nacos 配置文件${NC}"
echo -e "${GREEN}========================================${NC}"

# Nacos 配置
NACOS_URL="http://localhost:8848"
NACOS_USERNAME="nacos"
NACOS_PASSWORD="nacos"

# 检查 Nacos 服务是否可访问
echo -e "${YELLOW}1. 检查 Nacos 服务...${NC}"
if ! curl -s "$NACOS_URL" > /dev/null 2>&1; then
    echo -e "${RED}✗ Nacos 服务不可访问${NC}"
    echo -e "${YELLOW}请确保 Nacos 容器正在运行: docker ps | grep ruoyi-nacos${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Nacos 服务可访问${NC}"

# 获取访问令牌
echo -e "${YELLOW}2. 获取 Nacos 访问令牌...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "${NACOS_URL}/nacos/v1/auth/login" \
    -d "username=${NACOS_USERNAME}&password=${NACOS_PASSWORD}")

if echo "$TOKEN_RESPONSE" | grep -q "accessToken"; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 获取访问令牌成功${NC}"
else
    echo -e "${RED}✗ 获取访问令牌失败${NC}"
    exit 1
fi

# 检查配置函数
check_config() {
    local data_id=$1
    local group=${2:-DEFAULT_GROUP}
    
    echo -e "${YELLOW}检查配置: ${data_id} (${group})${NC}"
    
    local response=$(curl -s -X GET "${NACOS_URL}/nacos/v1/cs/configs" \
        -d "dataId=${data_id}" \
        -d "group=${group}" \
        -d "accessToken=${ACCESS_TOKEN}")
    
    if [ -z "$response" ] || echo "$response" | grep -q "error"; then
        echo -e "${RED}✗ 配置不存在或获取失败${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ 配置存在${NC}"
    
    # 检查 MySQL 配置
    if echo "$response" | grep -q "jdbc:mysql://"; then
        local mysql_url=$(echo "$response" | grep -o "jdbc:mysql://[^?]*" | head -1)
        local mysql_host=$(echo "$mysql_url" | cut -d'/' -f3 | cut -d':' -f1)
        local mysql_port=$(echo "$mysql_url" | cut -d'/' -f3 | cut -d':' -f2)
        local mysql_db=$(echo "$mysql_url" | cut -d'/' -f4)
        local mysql_user=$(echo "$response" | grep -A 10 "datasource:" | grep "username:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" | tr -d ' ')
        local mysql_password=$(echo "$response" | grep -A 10 "datasource:" | grep "password:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" | tr -d ' ')
        
        echo -e "${BLUE}  MySQL 配置:${NC}"
        echo -e "${BLUE}    主机: ${mysql_host}${NC}"
        echo -e "${BLUE}    端口: ${mysql_port}${NC}"
        echo -e "${BLUE}    数据库: ${mysql_db}${NC}"
        if [ -n "$mysql_user" ]; then
            echo -e "${BLUE}    用户: ${mysql_user}${NC}"
        fi
        if [ -n "$mysql_password" ]; then
            echo -e "${BLUE}    密码: ${mysql_password}${NC}"
        fi
        
        # 验证配置
        if [ "$mysql_host" = "ruoyi-mysql" ]; then
            echo -e "${GREEN}  ✓ MySQL 主机名配置正确${NC}"
        else
            echo -e "${RED}  ⚠ 警告: MySQL 主机名不是 'ruoyi-mysql' (当前: ${mysql_host})${NC}"
        fi
        if [ "$mysql_port" = "3306" ]; then
            echo -e "${GREEN}  ✓ MySQL 端口配置正确${NC}"
        else
            echo -e "${RED}  ⚠ 警告: MySQL 端口不是 '3306' (当前: ${mysql_port})${NC}"
        fi
        if [ "$mysql_db" = "ry-cloud" ]; then
            echo -e "${GREEN}  ✓ 数据库名称配置正确${NC}"
        else
            echo -e "${YELLOW}  ⚠ 数据库名称: ${mysql_db}${NC}"
        fi
    fi
    
    # 检查 Redis 配置
    if echo "$response" | grep -q "redis:"; then
        local redis_host=$(echo "$response" | grep -A 10 "redis:" | grep "host:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" | tr -d ' ')
        local redis_port=$(echo "$response" | grep -A 10 "redis:" | grep "port:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" | tr -d ' ')
        local redis_password=$(echo "$response" | grep -A 10 "redis:" | grep "password:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'" | tr -d ' ')
        
        if [ -n "$redis_host" ]; then
            echo -e "${BLUE}  Redis 配置:${NC}"
            echo -e "${BLUE}    主机: ${redis_host}${NC}"
            if [ -n "$redis_port" ]; then
                echo -e "${BLUE}    端口: ${redis_port}${NC}"
            fi
            if [ -n "$redis_password" ]; then
                echo -e "${BLUE}    密码: ${redis_password}${NC}"
            else
                echo -e "${BLUE}    密码: (空)${NC}"
            fi
            
            # 验证配置
            if [ "$redis_host" = "ruoyi-redis" ]; then
                echo -e "${GREEN}  ✓ Redis 主机名配置正确${NC}"
            else
                echo -e "${RED}  ⚠ 警告: Redis 主机名不是 'ruoyi-redis' (当前: ${redis_host})${NC}"
            fi
            if [ -n "$redis_port" ]; then
                if [ "$redis_port" = "6379" ]; then
                    echo -e "${GREEN}  ✓ Redis 端口配置正确${NC}"
                else
                    echo -e "${RED}  ⚠ 警告: Redis 端口不是 '6379' (当前: ${redis_port})${NC}"
                fi
            fi
        fi
    fi
    
    return 0
}

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}3. 检查共享配置 (application-dev.yml)${NC}"
echo -e "${NC}----------------------------------------${NC}"
check_config "application-dev.yml"

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}4. 检查系统服务配置 (ruoyi-system-dev.yml)${NC}"
echo -e "${NC}----------------------------------------${NC}"
check_config "ruoyi-system-dev.yml"

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}5. 检查代码生成服务配置 (ruoyi-gen-dev.yml)${NC}"
echo -e "${NC}----------------------------------------${NC}"
check_config "ruoyi-gen-dev.yml"

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}6. 检查定时任务服务配置 (ruoyi-job-dev.yml)${NC}"
echo -e "${NC}----------------------------------------${NC}"
check_config "ruoyi-job-dev.yml"

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}7. 检查 Nacos 自身 MySQL 配置${NC}"
echo -e "${NC}----------------------------------------${NC}"

# 检查 Nacos 容器的配置文件
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-nacos$"; then
    echo -e "${YELLOW}检查 Nacos 容器配置文件...${NC}"
    
    # 读取 Nacos 配置文件
    if nacos_config=$(docker exec ruoyi-nacos cat /home/nacos/conf/application.properties 2>/dev/null); then
        if echo "$nacos_config" | grep -q "db.url.0"; then
            nacos_mysql_url=$(echo "$nacos_config" | grep "db.url.0" | cut -d'=' -f2 | tr -d ' ')
            nacos_mysql_user=$(echo "$nacos_config" | grep "^db.user" | cut -d'=' -f2 | tr -d ' ')
            nacos_mysql_password=$(echo "$nacos_config" | grep "^db.password" | cut -d'=' -f2 | tr -d ' ')
            
            echo -e "${GREEN}✓ Nacos MySQL 配置:${NC}"
            echo -e "${BLUE}    URL: ${nacos_mysql_url}${NC}"
            echo -e "${BLUE}    用户: ${nacos_mysql_user}${NC}"
            echo -e "${BLUE}    密码: ${nacos_mysql_password}${NC}"
            
            # 验证配置
            if echo "$nacos_mysql_url" | grep -q "ruoyi-mysql:3306"; then
                echo -e "${GREEN}  ✓ MySQL 主机和端口配置正确${NC}"
            else
                echo -e "${RED}  ⚠ 警告: MySQL 主机或端口配置可能不正确${NC}"
            fi
            
            if echo "$nacos_mysql_url" | grep -q "ry-config"; then
                echo -e "${GREEN}  ✓ 数据库名称配置正确 (ry-config)${NC}"
            else
                echo -e "${RED}  ⚠ 警告: 数据库名称不是 'ry-config'${NC}"
            fi
        else
            echo -e "${YELLOW}⚠ 配置文件中未找到 db.url.0${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ 无法读取 Nacos 配置文件${NC}"
    fi
else
    echo -e "${RED}✗ Nacos 容器未运行${NC}"
fi

echo -e "${NC}----------------------------------------${NC}"
echo -e "${YELLOW}8. 验证 Docker 服务连接${NC}"
echo -e "${NC}----------------------------------------${NC}"

# 检查 MySQL 容器
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-mysql$"; then
    echo -e "${GREEN}✓ MySQL 容器正在运行${NC}"
    
    # 测试 MySQL 连接
    if docker exec ruoyi-mysql mysql -uroot -ppassword -e "SELECT 1;" 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}  ✓ MySQL 连接测试成功${NC}"
    else
        echo -e "${RED}  ✗ MySQL 连接测试失败${NC}"
    fi
else
    echo -e "${RED}✗ MySQL 容器未运行${NC}"
fi

# 检查 Redis 容器
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-redis$"; then
    echo -e "${GREEN}✓ Redis 容器正在运行${NC}"
    
    # 测试 Redis 连接
    if docker exec ruoyi-redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo -e "${GREEN}  ✓ Redis 连接测试成功${NC}"
    else
        echo -e "${RED}  ✗ Redis 连接测试失败${NC}"
    fi
else
    echo -e "${RED}✗ Redis 容器未运行${NC}"
fi

# 检查服务容器网络连接
echo -e "${YELLOW}9. 检查服务容器网络连接${NC}"
if docker ps --format '{{.Names}}' | grep -q "^ruoyi-modules-system$"; then
    echo -e "${YELLOW}测试从服务容器访问 MySQL...${NC}"
    if docker exec ruoyi-modules-system sh -c "getent hosts ruoyi-mysql" 2>/dev/null | grep -q "ruoyi-mysql"; then
        echo -e "${GREEN}  ✓ 服务容器可以解析 ruoyi-mysql 主机名${NC}"
    else
        echo -e "${RED}  ✗ 服务容器无法解析 ruoyi-mysql 主机名${NC}"
    fi
    
    echo -e "${YELLOW}测试从服务容器访问 Redis...${NC}"
    if docker exec ruoyi-modules-system sh -c "getent hosts ruoyi-redis" 2>/dev/null | grep -q "ruoyi-redis"; then
        echo -e "${GREEN}  ✓ 服务容器可以解析 ruoyi-redis 主机名${NC}"
    else
        echo -e "${RED}  ✗ 服务容器无法解析 ruoyi-redis 主机名${NC}"
    fi
else
    echo -e "${YELLOW}⚠ 系统服务容器未运行，跳过网络连接测试${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}配置检查完成！${NC}"
echo -e "${GREEN}========================================${NC}"

