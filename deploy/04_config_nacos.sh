#!/bin/bash

# 04_config_nacos.sh - 自动配置 Nacos 所有配置信息

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

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}自动配置 Nacos 配置中心${NC}"
echo -e "${BLUE}========================================${NC}"

# Nacos 配置
NACOS_URL="http://localhost:8848"
NACOS_USERNAME="nacos"
NACOS_PASSWORD="nacos"
NACOS_GROUP="DEFAULT_GROUP"

# 检查 Nacos 是否可访问
echo -e "${YELLOW}检查 Nacos 服务...${NC}"
if ! curl -s "${NACOS_URL}/nacos" > /dev/null 2>&1; then
    echo -e "${RED}错误: 无法连接到 Nacos 服务 (${NACOS_URL})${NC}"
    echo -e "${YELLOW}请确保 Nacos 服务已启动${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Nacos 服务可访问${NC}"

# 检查 Python 是否可用
echo -e "${YELLOW}检查 Python 环境...${NC}"
PYTHON_CMD=""
PYTHON_VERSION=""

# 优先使用 python3
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 -c "import sys; print(sys.version_info.major)" 2>/dev/null || echo "0")
    if [ "$PYTHON_VERSION" = "3" ] || [ "$PYTHON_VERSION" = "2" ]; then
        PYTHON_CMD="python3"
        echo -e "${GREEN}✓ 找到 Python3${NC}"
    fi
fi

# 如果没有 python3，尝试 python
if [ -z "$PYTHON_CMD" ] && command -v python &> /dev/null; then
    PYTHON_VERSION=$(python -c "import sys; print(sys.version_info.major)" 2>/dev/null || echo "0")
    if [ "$PYTHON_VERSION" = "3" ] || [ "$PYTHON_VERSION" = "2" ]; then
        PYTHON_CMD="python"
        echo -e "${GREEN}✓ 找到 Python${NC}"
    fi
fi

if [ -z "$PYTHON_CMD" ]; then
    echo -e "${RED}错误: 需要 Python 来编码配置内容${NC}"
    echo -e "${YELLOW}请安装 Python 或手动在 Nacos 控制台配置${NC}"
    exit 1
fi

# 测试 Python 编码功能（兼容 Python 2 和 3）
PYTHON_IS_3=$($PYTHON_CMD -c "import sys; print(1 if sys.version_info[0] >= 3 else 0)" 2>/dev/null || echo "0")
if [ "$PYTHON_IS_3" = "1" ]; then
    # Python 3
    if ! $PYTHON_CMD -c "import urllib.parse" 2>/dev/null; then
        echo -e "${RED}错误: Python urllib.parse 模块不可用${NC}"
        echo -e "${YELLOW}Python 版本信息:${NC}"
        $PYTHON_CMD --version 2>&1 || true
        echo -e "${YELLOW}请检查 Python 安装是否完整${NC}"
        echo -e "${YELLOW}或者手动在 Nacos 控制台配置（参考 deploy/NACOS_CONFIG.md）${NC}"
        exit 1
    fi
    PYTHON_VERSION_INFO=$($PYTHON_CMD --version 2>&1)
    echo -e "${GREEN}✓ Python 3 环境检查通过 (${PYTHON_VERSION_INFO})${NC}"
else
    # Python 2 - 使用 urllib 而不是 urllib.parse
    if ! $PYTHON_CMD -c "import urllib" 2>/dev/null; then
        echo -e "${RED}错误: Python urllib 模块不可用${NC}"
        exit 1
    fi
    echo -e "${YELLOW}警告: 检测到 Python 2，将使用兼容模式${NC}"
fi

# 获取访问令牌
echo -e "${YELLOW}获取 Nacos 访问令牌...${NC}"
TOKEN_RESPONSE=$(curl -s -X POST "${NACOS_URL}/nacos/v1/auth/login" \
    -d "username=${NACOS_USERNAME}&password=${NACOS_PASSWORD}")

if echo "$TOKEN_RESPONSE" | grep -q "accessToken"; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
    echo -e "${GREEN}✓ 获取访问令牌成功${NC}"
else
    echo -e "${RED}错误: 获取访问令牌失败${NC}"
    echo -e "${YELLOW}响应: $TOKEN_RESPONSE${NC}"
    exit 1
fi

# 配置 Nacos API 函数
publish_config() {
    local data_id=$1
    local content=$2
    local config_type=${3:-yaml}
    
    echo -e "${YELLOW}配置: ${data_id}...${NC}"
    
    # 创建临时文件存储配置内容
    local temp_file=$(mktemp 2>/dev/null || echo "/tmp/nacos_config_$$.tmp")
    printf '%s' "$content" > "$temp_file"
    
    # 检查文件是否创建成功
    if [ ! -f "$temp_file" ]; then
        echo -e "${RED}错误: 无法创建临时文件${NC}"
        return 1
    fi
    
    # 使用 Python 进行 URL 编码
    echo -e "${YELLOW}  正在编码配置内容...${NC}"
    
    local encoded_content=""
    local python_exit=1
    
    # 创建临时 Python 脚本文件（使用当前目录，避免路径问题）
    local script_dir=$(cd "$(dirname "$0")" && pwd)
    local python_encode_script="${script_dir}/nacos_encode_$$.py"
    
    # 创建 Python 编码脚本（使用 echo 逐行写入，避免 heredoc）
    echo 'import sys' > "$python_encode_script"
    echo 'import urllib.parse' >> "$python_encode_script"
    echo '' >> "$python_encode_script"
    echo 'temp_file = sys.argv[1]' >> "$python_encode_script"
    echo 'try:' >> "$python_encode_script"
    echo '    with open(temp_file, "r", encoding="utf-8") as f:' >> "$python_encode_script"
    echo '        content = f.read()' >> "$python_encode_script"
    echo '    encoded = urllib.parse.quote(content, safe="")' >> "$python_encode_script"
    echo '    sys.stdout.write(encoded)' >> "$python_encode_script"
    echo '    sys.stdout.flush()' >> "$python_encode_script"
    echo 'except Exception as e:' >> "$python_encode_script"
    echo '    sys.stderr.write("Error: " + str(e) + "\n")' >> "$python_encode_script"
    echo '    sys.exit(1)' >> "$python_encode_script"
    
    # 执行 Python 脚本（设置超时，避免卡住）
    encoded_content=$(timeout 10 $PYTHON_CMD "$python_encode_script" "$temp_file" 2>&1)
    python_exit=$?
    
    # 如果 timeout 命令不存在（Windows），直接执行
    if [ $python_exit -eq 127 ]; then
        encoded_content=$($PYTHON_CMD "$python_encode_script" "$temp_file" 2>&1)
        python_exit=$?
    fi
    
    # 清理临时文件
    rm -f "$python_encode_script" 2>/dev/null || true
    
    # 检查编码结果
    if [ $python_exit -ne 0 ] || [ -z "$encoded_content" ]; then
        echo -e "${RED}错误: URL 编码失败${NC}"
        if [ -n "$encoded_content" ] && echo "$encoded_content" | grep -q "Error"; then
            echo -e "${YELLOW}Python 错误: ${encoded_content}${NC}"
        fi
        rm -f "$temp_file" 2>/dev/null || true
        return 1
    fi
    
    # 清理配置临时文件
    rm -f "$temp_file" 2>/dev/null || true
    
    echo -e "${YELLOW}  正在发送配置到 Nacos...${NC}"
    
    # 使用 application/x-www-form-urlencoded 格式发送
    local response=$(curl -s -w "\n%{http_code}" -X POST "${NACOS_URL}/nacos/v1/cs/configs" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "dataId=${data_id}" \
        --data-urlencode "group=${NACOS_GROUP}" \
        -d "content=${encoded_content}" \
        -d "type=${config_type}" \
        -d "accessToken=${ACCESS_TOKEN}" 2>&1)
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)
    
    if [ "$http_code" = "200" ] && [ "$body" = "true" ]; then
        echo -e "${GREEN}✓ ${data_id} 配置成功${NC}"
        return 0
    else
        echo -e "${RED}✗ ${data_id} 配置失败 (HTTP ${http_code}): ${body}${NC}"
        return 1
    fi
}

# 1. 配置共享配置 application-dev.yml
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}1. 配置共享配置 (application-dev.yml)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

APPLICATION_DEV_YML='# 共享配置（所有服务通用）
# 注意：网关服务不需要数据源配置，数据源配置在各服务的专用配置中

# Spring 自动配置排除（避免 Druid 自动配置冲突）
spring:
  autoconfigure:
    exclude: com.alibaba.druid.spring.boot.autoconfigure.DruidDataSourceAutoConfigure
  # Redis 配置（所有服务都需要）
  redis:
    host: ruoyi-redis
    port: 6379
    password: 
    timeout: 10s
    lettuce:
      pool:
        min-idle: 0
        max-idle: 8
        max-active: 8
        max-wait: -1ms

# Feign 配置
feign:
  sentinel:
    enabled: true
  okhttp:
    enabled: true
  httpclient:
    enabled: false
  client:
    config:
      default:
        connectTimeout: 10000
        readTimeout: 10000
  compression:
    request:
      enabled: true
      min-request-size: 8192
    response:
      enabled: true

# 暴露监控端点
management:
  endpoints:
    web:
      exposure:
        include: '\''*'\''

# Mybatis 配置（需要数据库的服务使用）
# 注意：同时配置 mybatis 和 mybatis-plus，确保兼容性
mybatis:
  type-aliases-package: com.ruoyi.**.domain
  mapper-locations: classpath*:mapper/**/*Mapper.xml
  configuration:
    map-underscore-to-camel-case: true
    cache-enabled: false
    call-setters-on-nulls: true
    jdbc-type-for-null: '\''null'\''
mybatis-plus:
  type-aliases-package: com.ruoyi.**.domain
  mapper-locations: classpath*:mapper/**/*Mapper.xml
  configuration:
    map-underscore-to-camel-case: true
    cache-enabled: false
    call-setters-on-nulls: true
    jdbc-type-for-null: '\''null'\''
'

publish_config "application-dev.yml" "$APPLICATION_DEV_YML" "yaml"

# 2. 配置网关服务 (ruoyi-gateway)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}2. 配置网关服务 (ruoyi-gateway)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

GATEWAY_YML='# 网关服务配置
server:
  port: 8080

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  # Redis 配置（网关需要 Redis 存储验证码等）
  redis:
    host: ruoyi-redis
    port: 6379
    password: 
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
    gateway:
      discovery:
        locator:
          enabled: true
          lower-case-service-id: true
      routes:
        # 认证中心
        - id: ruoyi-auth
          uri: lb://ruoyi-auth
          predicates:
            - Path=/auth/**
          filters:
            # 验证码处理（需要缓存请求体）
            - CacheRequestBody
            - ValidateCodeFilter
            - StripPrefix=1
        # 系统模块
        - id: ruoyi-modules-system
          uri: lb://ruoyi-system
          predicates:
            - Path=/system/**
          filters:
            - StripPrefix=1
        # 代码生成
        # 兼容原始配置与前端请求：/code/gen/**
        - id: ruoyi-modules-gen
          uri: lb://ruoyi-gen
          predicates:
            - Path=/code/**
          filters:
            - StripPrefix=1
        # 定时任务
        - id: ruoyi-modules-job
          uri: lb://ruoyi-job
          predicates:
            - Path=/schedule/**
          filters:
            - StripPrefix=1
        # 文件服务
        - id: ruoyi-modules-file
          uri: lb://ruoyi-file
          predicates:
            - Path=/file/**
          filters:
            - StripPrefix=1

# JWT 配置（必须与认证服务保持一致）
token:
  # 令牌自定义标识
  header: Authorization
  # 令牌密钥（必须与认证服务相同）
  secret: abcdefghijklmnopqrstuvwxyz
  # 令牌有效期（默认30分钟）
  expireTime: 30

# 安全配置
security:
  # 验证码配置
  captcha:
    # 验证码开关
    enabled: true
    # 验证码类型（math 数组计算 char 字符）
    type: char
  # 防止XSS攻击
  xss:
    enabled: true
    excludeUrls:
      - /system/notice
  # 网关白名单配置（不需要 token 验证的路径）
  ignore:
    whites:
      - /auth/login
      - /auth/register
      - /auth/logout
      - /code
      - /*/v2/api-docs
      - /*/v3/api-docs
      - /csrf
      - /actuator/**
      - /swagger-ui/**
      - /swagger-resources/**
      - /webjars/**

# SpringDoc 配置
springdoc:
  webjars:
    # 访问前缀
    prefix:
'

publish_config "ruoyi-gateway-dev.yml" "$GATEWAY_YML" "yaml"

# 3. 配置认证服务 (ruoyi-auth)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}3. 配置认证服务 (ruoyi-auth)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

AUTH_YML='# 认证服务配置
server:
  port: 9200

# 注意：认证服务不需要数据库连接（已排除 DataSourceAutoConfiguration）

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848

# JWT 配置
token:
  # 令牌自定义标识
  header: Authorization
  # 令牌密钥
  secret: abcdefghijklmnopqrstuvwxyz
  # 令牌有效期（默认30分钟）
  expireTime: 30
'

publish_config "ruoyi-auth-dev.yml" "$AUTH_YML" "yaml"

# 4. 配置系统服务 (ruoyi-modules-system)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}4. 配置系统服务 (ruoyi-modules-system)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

SYSTEM_YML='# 系统服务配置
server:
  port: 9201

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
  # 数据源配置（使用 dynamic-datasource 多数据源）
  datasource:
    dynamic:
      # 设置默认数据源或者数据源组，默认值即为 master
      primary: master
      # 严格匹配数据源，默认 false，true 未匹配到指定数据源时抛异常，false 使用默认数据源
      strict: false
      datasource:
        # 主库数据源
        master:
          url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8
          username: root
          password: password
          driver-class-name: com.mysql.cj.jdbc.Driver
          type: com.alibaba.druid.pool.DruidDataSource
          druid:
            # 初始连接数
            initialSize: 10
            # 最小连接池数量
            minIdle: 10
            # 最大连接池数量
            maxActive: 20
            # 配置获取连接等待超时的时间
            maxWait: 60000
            # 配置间隔多久才进行一次检测，检测需要关闭的空闲连接，单位是毫秒
            timeBetweenEvictionRunsMillis: 60000
            # 配置一个连接在池中最小生存的时间，单位是毫秒
            minEvictableIdleTimeMillis: 300000
            # 配置一个连接在池中最大生存的时间，单位是毫秒
            maxEvictableIdleTimeMillis: 900000
            # 配置检测连接是否有效
            validationQuery: SELECT 1 FROM DUAL
            testWhileIdle: true
            testOnBorrow: false
            testOnReturn: false

# SpringDoc 配置
springdoc:
  gatewayUrl: http://localhost:8080/${spring.application.name}
  api-docs:
    # 是否开启接口文档
    enabled: true
  info:
    # 标题
    title: '\''系统模块接口文档'\''
    # 描述
    description: '\''系统模块接口描述'\''
    # 作者信息
    contact:
      name: RuoYi
      url: https://ruoyi.vip
'

publish_config "ruoyi-system-dev.yml" "$SYSTEM_YML" "yaml"

# 5. 配置代码生成服务 (ruoyi-modules-gen)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}5. 配置代码生成服务 (ruoyi-modules-gen)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

GEN_YML='# 代码生成服务配置
server:
  port: 9202

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
  # 数据源配置（使用 HikariCP，Spring Boot 默认连接池）
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8
    username: root
    password: password
    hikari:
      # 最小空闲连接数
      minimum-idle: 5
      # 最大连接池大小
      maximum-pool-size: 20
      # 连接超时时间（毫秒）
      connection-timeout: 30000
      # 空闲连接最大存活时间（毫秒）
      idle-timeout: 600000
      # 连接最大存活时间（毫秒）
      max-lifetime: 1800000
      # 连接测试查询
      connection-test-query: SELECT 1

# MyBatis 配置（确保扫描到 Mapper XML 文件）
mybatis:
  mapper-locations: classpath*:mapper/**/*Mapper.xml
mybatis-plus:
  mapper-locations: classpath*:mapper/**/*Mapper.xml

# 代码生成配置
gen:
  # 作者
  author: ruoyi
  # 默认生成包路径 system 需改成自己的模块名称
  packageName: com.ruoyi.system
  # 自动去除表前缀，默认是false
  autoRemovePre: false
  # 表前缀(生成类名不会包含表前缀)
  tablePrefix: sys_
  # 是否允许生成文件覆盖到本地（自定义路径），默认不允许
  allowOverwrite: false

# SpringDoc 配置
springdoc:
  gatewayUrl: http://localhost:8080/${spring.application.name}
  api-docs:
    # 是否开启接口文档
    enabled: true
  info:
    # 标题
    title: '\''代码生成接口文档'\''
    # 描述
    description: '\''代码生成接口描述'\''
    # 作者信息
    contact:
      name: RuoYi
      url: https://ruoyi.vip
'

publish_config "ruoyi-gen-dev.yml" "$GEN_YML" "yaml"

# 6. 配置定时任务服务 (ruoyi-modules-job)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}6. 配置定时任务服务 (ruoyi-modules-job)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

JOB_YML='# 定时任务服务配置
server:
  port: 9203

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
  # 数据源配置（使用 HikariCP，Spring Boot 默认连接池）
  datasource:
    driver-class-name: com.mysql.cj.jdbc.Driver
    url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=false&serverTimezone=GMT%2B8
    username: root
    password: password
    hikari:
      # 最小空闲连接数
      minimum-idle: 5
      # 最大连接池大小
      maximum-pool-size: 20
      # 连接超时时间（毫秒）
      connection-timeout: 30000
      # 空闲连接最大存活时间（毫秒）
      idle-timeout: 600000
      # 连接最大存活时间（毫秒）
      max-lifetime: 1800000
      # 连接测试查询
      connection-test-query: SELECT 1

# MyBatis 配置（确保扫描到 Mapper XML 文件）
mybatis:
  mapper-locations: classpath*:mapper/**/*Mapper.xml
mybatis-plus:
  mapper-locations: classpath*:mapper/**/*Mapper.xml

# 定时任务配置
xxl:
  job:
    admin:
      addresses: http://127.0.0.1:9090/xxl-job-admin
    executor:
      appname: ruoyi-job
      address: 
      ip: 
      port: 9999
      logpath: /data/applogs/xxl-job/jobhandler
      logretentiondays: 30
    accessToken: 

# SpringDoc 配置
springdoc:
  gatewayUrl: http://localhost:8080/${spring.application.name}
  api-docs:
    # 是否开启接口文档
    enabled: true
  info:
    # 标题
    title: '\''定时任务接口文档'\''
    # 描述
    description: '\''定时任务接口描述'\''
    # 作者信息
    contact:
      name: RuoYi
      url: https://ruoyi.vip
'

publish_config "ruoyi-job-dev.yml" "$JOB_YML" "yaml"

# 7. 配置文件服务 (ruoyi-modules-file)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}7. 配置文件服务 (ruoyi-modules-file)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

FILE_YML='# 文件服务配置
server:
  port: 9300

# 注意：文件服务不需要数据库连接（已排除 DataSourceAutoConfiguration）

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848

# 文件路径 示例（ Windows配置D:/ruoyi/uploadPath，Linux配置 /home/ruoyi/uploadPath）
file:
  # 资源映射路径前缀（用于访问上传的文件）
  prefix: /profile
  # 上传文件存储在本地的根路径
  path: /home/ruoyi/uploadPath
  # 域名或本机访问地址
  domain: http://localhost:9300

# Referer 防盗链配置（可选，默认不启用）
referer:
  # 是否启用防盗链过滤器（true启用，false不启用）
  enabled: false
  # 允许的域名列表（逗号分隔），仅在 enabled=true 时生效
  allowed-domains: localhost,127.0.0.1

# FastDFS 配置（可选，如果使用本地存储则不需要）
fdfs:
  # FastDFS 访问域名（如果使用 FastDFS 存储，请配置实际的域名）
  domain: http://localhost:8080

# Minio 配置（可选，如果使用本地存储则不需要）
minio:
  # Minio 服务地址
  url: http://localhost:9000
  # 访问密钥
  accessKey: minioadmin
  # 秘密密钥
  secretKey: minioadmin
  # 存储桶名称
  bucketName: ruoyi
'

publish_config "ruoyi-file-dev.yml" "$FILE_YML" "yaml"

# 8. 配置监控服务 (ruoyi-visual-monitor)
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}8. 配置监控服务 (ruoyi-visual-monitor)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

MONITOR_YML='# 监控服务配置
server:
  port: 9100

# Nacos 配置（覆盖 bootstrap.yml 中的配置）
spring:
  cloud:
    nacos:
      discovery:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
      config:
        # 使用 Docker 服务名
        server-addr: ruoyi-nacos:8848
  # Spring Security 配置（监控中心登录）
  security:
    user:
      name: ruoyi
      password: 123456
  # Spring Boot Admin 配置
  boot:
    admin:
      ui:
        title: 若依服务状态监控
      client:
        url: http://localhost:9100
        instance:
          prefer-ip: true
'

# 注意：根据 bootstrap.yml，应用名称是 ruoyi-monitor，但实际服务名是 ruoyi-visual-monitor
# 为了兼容，同时配置两个名称
publish_config "ruoyi-monitor-dev.yml" "$MONITOR_YML" "yaml"
publish_config "ruoyi-visual-monitor-dev.yml" "$MONITOR_YML" "yaml"

# 9. 配置 Sentinel 规则（网关）
echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}9. 配置 Sentinel 规则 (sentinel-ruoyi-gateway)${NC}"
echo -e "${BLUE}----------------------------------------${NC}"

SENTINEL_GATEWAY_JSON='[
  {
    "resource": "ruoyi-auth",
    "resourceMode": 0,
    "grade": 1,
    "count": 1000,
    "intervalSec": 1
  },
  {
    "resource": "ruoyi-modules-system",
    "resourceMode": 0,
    "grade": 1,
    "count": 1000,
    "intervalSec": 1
  }
]'

publish_config "sentinel-ruoyi-gateway" "$SENTINEL_GATEWAY_JSON" "json"

# 总结
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Nacos 配置完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}已配置的配置文件:${NC}"
echo -e "  1. ${GREEN}application-dev.yml${NC} - 共享配置（数据库、Redis、MyBatis）"
echo -e "  2. ${GREEN}ruoyi-gateway-dev.yml${NC} - 网关服务配置"
echo -e "  3. ${GREEN}ruoyi-auth-dev.yml${NC} - 认证服务配置"
echo -e "  4. ${GREEN}ruoyi-system-dev.yml${NC} - 系统服务配置"
echo -e "  5. ${GREEN}ruoyi-gen-dev.yml${NC} - 代码生成服务配置"
echo -e "  6. ${GREEN}ruoyi-job-dev.yml${NC} - 定时任务服务配置"
echo -e "  7. ${GREEN}ruoyi-file-dev.yml${NC} - 文件服务配置"
echo -e "  8. ${GREEN}ruoyi-visual-monitor-dev.yml${NC} - 监控服务配置"
echo -e "  9. ${GREEN}sentinel-ruoyi-gateway${NC} - Sentinel 网关规则"
echo ""
echo -e "${YELLOW}访问 Nacos 控制台查看配置:${NC}"
echo -e "  ${BLUE}地址: http://localhost:8848/nacos${NC}"
echo -e "  ${BLUE}用户名: nacos${NC}"
echo -e "  ${BLUE}密码: nacos${NC}"
echo ""
echo -e "${YELLOW}注意: 配置已更新，应用服务会自动刷新配置${NC}"
echo -e "${YELLOW}如需立即生效，请重启应用服务${NC}"
echo -e "${BLUE}========================================${NC}"

