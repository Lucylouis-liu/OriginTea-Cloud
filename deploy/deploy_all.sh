#!/bin/bash

# deploy_all.sh - 一键完整部署脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OriginTea-Cloud 一键部署脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: 未安装Docker，请先安装Docker${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}错误: 未安装Docker Compose，请先安装Docker Compose${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker环境检查通过${NC}"
echo ""

# 执行部署步骤
echo -e "${YELLOW}步骤 1/7: 编译Java项目...${NC}"
cd "$SCRIPT_DIR"
./01_build_jar.sh
echo ""

echo -e "${YELLOW}步骤 2/7: 构建前端项目...${NC}"
./02_build_web.sh
echo ""

echo -e "${YELLOW}步骤 3/7: 创建MySQL并初始化数据库...${NC}"
./03_build_mysql.sh
echo ""

echo -e "${YELLOW}步骤 4/7: 创建Nacos容器...${NC}"
./04_build_nacos.sh
echo ""

echo -e "${YELLOW}步骤 4.1/7: 配置Nacos配置中心...${NC}"
./04_config_nacos.sh
echo ""

echo -e "${YELLOW}步骤 5/7: 创建Redis容器...${NC}"
./05_build_redis.sh
echo ""

echo -e "${YELLOW}等待基础服务就绪...${NC}"
sleep 15

echo -e "${YELLOW}步骤 6/7: 启动所有应用服务...${NC}"
./06_start.sh
echo ""

echo -e "${YELLOW}等待应用服务启动...${NC}"
sleep 15

echo -e "${YELLOW}步骤 7/7: 验证部署状态...${NC}"
./07_check.sh
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}部署完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}访问地址:${NC}"
echo -e "  ${GREEN}前端:${NC} http://localhost"
echo -e "  ${GREEN}网关:${NC} http://localhost:8080"
echo -e "  ${GREEN}Nacos:${NC} http://localhost:8848/nacos"
echo -e "  ${GREEN}监控:${NC} http://localhost:9100"
echo ""
echo -e "${YELLOW}默认登录账号: admin/admin123${NC}"
echo ""
echo -e "${YELLOW}注意: 请在Nacos控制台添加application-dev.yml配置${NC}"
echo -e "${BLUE}========================================${NC}"

