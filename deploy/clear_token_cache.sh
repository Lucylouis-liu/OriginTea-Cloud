#!/bin/bash

# clear_token_cache.sh - 清除 Redis 中的 token 缓存
# 用于解决 JWT 签名不匹配问题

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}清除 Redis Token 缓存${NC}"
echo -e "${GREEN}========================================${NC}"

# 检查 Redis 容器
if ! docker ps --format "{{.Names}}" | grep -q "^ruoyi-redis$"; then
    echo -e "${RED}错误: Redis 容器未运行${NC}"
    exit 1
fi

echo -e "${BLUE}正在清除 Redis 中的 token 缓存...${NC}"

# 清除所有 token 相关的 key
# RuoYi 的 token key 格式是: login_tokens:*
TOKEN_PATTERN="login_tokens:*"

# 获取所有匹配的 key
KEYS=$(docker exec ruoyi-redis redis-cli --raw KEYS "$TOKEN_PATTERN" 2>/dev/null || echo "")

if [ -z "$KEYS" ] || [ "$KEYS" == "" ]; then
    echo -e "${YELLOW}未找到 token 缓存${NC}"
else
    # 统计 key 数量
    KEY_COUNT=$(echo "$KEYS" | grep -v "^$" | wc -l)
    if [ "$KEY_COUNT" -gt 0 ]; then
        echo -e "${BLUE}找到 ${KEY_COUNT} 个 token 缓存，正在清除...${NC}"
        
        # 删除所有匹配的 key
        echo "$KEYS" | grep -v "^$" | while read -r key; do
            if [ -n "$key" ]; then
                docker exec ruoyi-redis redis-cli DEL "$key" > /dev/null 2>&1
            fi
        done
        
        echo -e "${GREEN}✓ Token 缓存已清除 (${KEY_COUNT} 个)${NC}"
    else
        echo -e "${YELLOW}未找到 token 缓存${NC}"
    fi
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Token 缓存清除完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}提示:${NC}"
echo -e "${YELLOW}1. 请清除浏览器缓存和 localStorage${NC}"
echo -e "${YELLOW}2. 重新登录获取新的 token${NC}"
echo -e "${YELLOW}3. 如果问题仍然存在，请检查 Nacos 配置中的 token.secret 是否正确${NC}"

