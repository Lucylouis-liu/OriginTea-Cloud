#!/bin/bash

# 03_build_mysql.sh - 创建MySQL容器并初始化数据库

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
SQL_DIR="$PROJECT_ROOT/sql"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}开始创建MySQL容器并初始化数据库...${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查docker-compose.yml文件
if [ ! -f "$DOCKER_DIR/docker-compose.yml" ]; then
    echo -e "${RED}错误: 未找到docker-compose.yml文件${NC}"
    exit 1
fi

# 检查SQL文件
SQL_FILES=(
    "ry_20250523.sql"
    "ry_config_20250902.sql"
    "quartz.sql"
    "ry_seata_20210128.sql"
)

for sql_file in "${SQL_FILES[@]}"; do
    if [ ! -f "$SQL_DIR/$sql_file" ]; then
        echo -e "${YELLOW}警告: SQL文件不存在: $sql_file${NC}"
    fi
done

# 进入docker目录
cd "$DOCKER_DIR"

# 停止并删除已存在的MySQL容器
echo -e "${YELLOW}检查并清理已存在的MySQL容器...${NC}"
docker-compose stop ruoyi-mysql 2>/dev/null || true
docker-compose rm -f ruoyi-mysql 2>/dev/null || true

# 启动MySQL容器
echo -e "${YELLOW}启动MySQL容器...${NC}"
docker-compose up -d ruoyi-mysql

# 等待MySQL启动
echo -e "${YELLOW}等待MySQL服务启动...${NC}"
sleep 15

# 检查MySQL是否就绪
MAX_RETRIES=60
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # 使用mysqladmin ping检查，不使用-h参数（在容器内直接连接）
    if docker exec ruoyi-mysql mysqladmin ping --silent 2>/dev/null; then
        echo -e "${GREEN}MySQL服务已就绪${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待MySQL启动... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: MySQL服务启动超时${NC}"
    echo -e "${YELLOW}查看MySQL日志: docker logs ruoyi-mysql${NC}"
    exit 1
fi

# 额外等待MySQL完全初始化（root用户和密码设置）
echo -e "${YELLOW}等待MySQL完全初始化...${NC}"
sleep 5

# 测试MySQL连接
MAX_RETRIES=30
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # 测试root用户连接
    if docker exec ruoyi-mysql mysql -uroot -ppassword -e "SELECT 1;" 2>/dev/null | grep -q "1"; then
        echo -e "${GREEN}MySQL连接测试成功${NC}"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo -e "${YELLOW}等待MySQL认证就绪... ($RETRY_COUNT/$MAX_RETRIES)${NC}"
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}错误: MySQL认证初始化超时${NC}"
    echo -e "${YELLOW}查看MySQL日志: docker logs ruoyi-mysql${NC}"
    exit 1
fi

# 创建数据库
echo -e "${YELLOW}创建数据库...${NC}"

# 分别创建每个数据库，避免heredoc中反引号的问题
create_database() {
    local db_name=$1
    docker exec ruoyi-mysql mysql -uroot -ppassword -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ 数据库 ${db_name} 创建成功${NC}"
        return 0
    else
        echo -e "${RED}✗ 数据库 ${db_name} 创建失败${NC}"
        return 1
    fi
}

# 创建 ry-cloud 数据库
create_database "ry-cloud"

# 创建 ry-config 数据库
create_database "ry-config"

# 创建 ry-seata 数据库
create_database "ry-seata"

# 验证数据库是否创建成功
echo -e "${YELLOW}验证数据库创建...${NC}"
sleep 2  # 等待一下确保数据库创建完成

DB_COUNT=$(docker exec ruoyi-mysql mysql -uroot -ppassword -e "SHOW DATABASES LIKE 'ry-%';" 2>/dev/null | grep -c "ry-" || echo "0")
if [ "$DB_COUNT" -lt 3 ]; then
    echo -e "${YELLOW}警告: 只找到 $DB_COUNT 个数据库，尝试重新创建缺失的数据库...${NC}"
    # 检查并创建缺失的数据库
    for db in "ry-cloud" "ry-config" "ry-seata"; do
        if ! docker exec ruoyi-mysql mysql -uroot -ppassword -e "USE \`${db}\`;" 2>/dev/null; then
            echo -e "${YELLOW}重新创建数据库: ${db}${NC}"
            create_database "${db}"
        fi
    done
    # 再次验证
    DB_COUNT=$(docker exec ruoyi-mysql mysql -uroot -ppassword -e "SHOW DATABASES LIKE 'ry-%';" 2>/dev/null | grep -c "ry-" || echo "0")
    if [ "$DB_COUNT" -lt 3 ]; then
        echo -e "${RED}错误: 数据库创建不完整，只找到 $DB_COUNT 个数据库${NC}"
        echo -e "${YELLOW}已创建的数据库:${NC}"
        docker exec ruoyi-mysql mysql -uroot -ppassword -e "SHOW DATABASES LIKE 'ry-%';" 2>/dev/null || true
        exit 1
    fi
fi
echo -e "${GREEN}✓ 所有数据库创建成功 (找到 $DB_COUNT 个数据库)${NC}"

# 导入SQL文件
echo -e "${YELLOW}导入SQL文件...${NC}"

# 导入主数据库
if [ -f "$SQL_DIR/ry_20250523.sql" ]; then
    echo -e "${YELLOW}导入 ry_20250523.sql 到 ry-cloud 数据库...${NC}"
    # 确保数据库存在
    docker exec ruoyi-mysql mysql -uroot -ppassword -e 'CREATE DATABASE IF NOT EXISTS `ry-cloud` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' 2>/dev/null
    docker exec -i ruoyi-mysql mysql -uroot -ppassword 'ry-cloud' < "$SQL_DIR/ry_20250523.sql"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ry_20250523.sql 导入成功${NC}"
    else
        echo -e "${RED}✗ ry_20250523.sql 导入失败${NC}"
    fi
fi

# 导入配置数据库
if [ -f "$SQL_DIR/ry_config_20250902.sql" ]; then
    echo -e "${YELLOW}导入 ry_config_20250902.sql 到 ry-config 数据库...${NC}"
    # 确保数据库存在（使用反引号引用包含连字符的数据库名）
    docker exec ruoyi-mysql mysql -uroot -ppassword -e 'CREATE DATABASE IF NOT EXISTS `ry-config` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' 2>/dev/null
    docker exec -i ruoyi-mysql mysql -uroot -ppassword 'ry-config' < "$SQL_DIR/ry_config_20250902.sql"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ry_config_20250902.sql 导入成功${NC}"
    else
        echo -e "${RED}✗ ry_config_20250902.sql 导入失败${NC}"
    fi
fi

# 导入定时任务数据库
if [ -f "$SQL_DIR/quartz.sql" ]; then
    echo -e "${YELLOW}导入 quartz.sql 到 ry-cloud 数据库...${NC}"
    # 确保数据库存在
    docker exec ruoyi-mysql mysql -uroot -ppassword -e 'CREATE DATABASE IF NOT EXISTS `ry-cloud` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' 2>/dev/null
    docker exec -i ruoyi-mysql mysql -uroot -ppassword 'ry-cloud' < "$SQL_DIR/quartz.sql"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ quartz.sql 导入成功${NC}"
    else
        echo -e "${RED}✗ quartz.sql 导入失败${NC}"
    fi
fi

# 导入分布式事务数据库
if [ -f "$SQL_DIR/ry_seata_20210128.sql" ]; then
    echo -e "${YELLOW}导入 ry_seata_20210128.sql 到 ry-seata 数据库...${NC}"
    # 确保数据库存在
    docker exec ruoyi-mysql mysql -uroot -ppassword -e 'CREATE DATABASE IF NOT EXISTS `ry-seata` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;' 2>/dev/null
    docker exec -i ruoyi-mysql mysql -uroot -ppassword 'ry-seata' < "$SQL_DIR/ry_seata_20210128.sql"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ry_seata_20210128.sql 导入成功${NC}"
    else
        echo -e "${RED}✗ ry_seata_20210128.sql 导入失败${NC}"
    fi
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}MySQL容器创建和数据库初始化完成！${NC}"
echo -e "${GREEN}========================================${NC}"

