# OriginTea-Cloud 项目部署指南

## 项目概述

本项目是基于 RuoYi-Cloud v3.6.6 的微服务架构系统，采用前后端分离模式：
- **后端**：Spring Boot 2.7.18 + Spring Cloud 2021.0.9 + Spring Cloud Alibaba 2021.0.6.1
- **前端**：Vue 2.6.12 + Element UI 2.15.14
- **注册中心/配置中心**：Nacos
- **缓存**：Redis
- **数据库**：MySQL 5.7
- **网关**：Spring Cloud Gateway
- **监控**：Spring Boot Admin

## 系统架构

```
┌─────────────┐
│   Nginx     │ (80端口 - 前端)
└──────┬──────┘
       │
┌──────▼──────┐
│   Gateway   │ (8080端口 - 网关)
└──────┬──────┘
       │
   ┌───┴───┬──────────┬──────────┬──────────┐
   │       │          │          │          │
┌──▼──┐ ┌─▼───┐  ┌───▼───┐ ┌───▼───┐ ┌───▼───┐
│Auth │ │System│ │  Gen  │ │  Job  │ │ File  │
│9200 │ │ 9201 │ │ 9202  │ │ 9203  │ │ 9300  │
└─────┘ └──────┘ └───────┘ └───────┘ └───────┘
   │       │          │          │          │
   └───┬───┴──────────┴──────────┴──────────┘
       │
   ┌───┴────┬──────────┬──────────┐
   │        │          │          │
┌─▼───┐ ┌──▼──┐  ┌────▼────┐
│Redis│ │MySQL│  │  Nacos  │
│6379 │ │3306 │  │  8848   │
└─────┘ └─────┘  └─────────┘
```

## 环境要求

### 基础环境
- **JDK**: 1.8 或以上
- **Maven**: 3.6 或以上
- **Node.js**: 8.9 或以上（前端开发需要）
- **npm**: 3.0.0 或以上
- **MySQL**: 5.7 或以上
- **Redis**: 5.0 或以上
- **Nacos**: 2.0 或以上

### Docker 环境（可选，用于 Docker 部署）
- **Docker**: 20.10 或以上
- **Docker Compose**: 1.29 或以上

## 部署方式一：Docker 部署（推荐生产环境）

### 1. 准备工作

#### 1.1 安装 Docker 和 Docker Compose
确保已安装 Docker 和 Docker Compose，并验证版本：
```bash
docker --version
docker-compose --version
```

#### 1.2 构建项目
在项目根目录执行打包命令：
```bash
# Windows
bin\package.bat

# Linux/Mac
mvn clean package -Dmaven.test.skip=true
```

#### 1.3 构建前端
```bash
cd ruoyi-ui

# Windows
bin\package.bat

# Linux/Mac
npm install --registry=https://registry.npmmirror.com
npm run build:prod
```

将构建好的前端文件复制到 Docker 目录：
```bash
# 将 ruoyi-ui/dist 目录下的文件复制到 docker_dev/nginx/html/dist 目录
```

#### 1.4 准备 JAR 包
将打包好的 JAR 文件复制到对应的 Docker 目录：
- `ruoyi-gateway/target/ruoyi-gateway.jar` → `docker_dev/ruoyi/gateway/jar/`
- `ruoyi-auth/target/ruoyi-auth.jar` → `docker_dev/ruoyi/auth/jar/`
- `ruoyi-modules/ruoyi-system/target/ruoyi-modules-system.jar` → `docker_dev/ruoyi/modules/system/jar/`
- `ruoyi-modules/ruoyi-gen/target/ruoyi-modules-gen.jar` → `docker_dev/ruoyi/modules/gen/jar/`
- `ruoyi-modules/ruoyi-job/target/ruoyi-modules-job.jar` → `docker_dev/ruoyi/modules/job/jar/`
- `ruoyi-modules/ruoyi-file/target/ruoyi-modules-file.jar` → `docker_dev/ruoyi/modules/file/jar/`
- `ruoyi-visual/ruoyi-monitor/target/ruoyi-visual-monitor.jar` → `docker_dev/ruoyi/visual/monitor/jar/`

### 2. 初始化数据库

#### 2.1 创建数据库
```sql
CREATE DATABASE `ry-cloud` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE `ry-config` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE `ry-seata` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

#### 2.2 导入 SQL 脚本
按顺序执行以下 SQL 文件：
```bash
# 1. 主数据库
mysql -uroot -p ry-cloud < sql/ry_20250523.sql

# 2. 配置数据库（Nacos 使用）
mysql -uroot -p ry-config < sql/ry_config_20250902.sql

# 3. 定时任务数据库
mysql -uroot -p ry-cloud < sql/quartz.sql

# 4. 分布式事务数据库（如果使用 Seata）
mysql -uroot -p ry-seata < sql/ry_seata_20210128.sql
```

### 3. 配置 Nacos

#### 3.1 启动基础服务
```bash
cd docker_dev

# 启动 MySQL、Redis、Nacos
docker-compose up -d ruoyi-mysql ruoyi-redis ruoyi-nacos
```

#### 3.2 访问 Nacos 控制台
- 地址：http://localhost:8848/nacos
- 默认用户名：nacos
- 默认密码：nacos

#### 3.3 在 Nacos 中配置应用配置
需要在 Nacos 配置中心添加以下配置文件（格式：YAML）：

**application-dev.yml**（共享配置）：
```yaml
# 数据源配置
spring:
  datasource:
    type: com.alibaba.druid.pool.DruidDataSource
    driverClassName: com.mysql.cj.jdbc.Driver
    druid:
      # 主库数据源
      master:
        url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?useUnicode=true&characterEncoding=utf8&zeroDateTimeBehavior=convertToNull&useSSL=true&serverTimezone=GMT%2B8
        username: root
        password: password
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

# Redis 配置
spring:
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

# Mybatis 配置
mybatis-plus:
  type-aliases-package: com.ruoyi.**.domain
  configuration:
    map-underscore-to-camel-case: true
    cache-enabled: false
    call-setters-on-nulls: true
    jdbc-type-for-null: 'null'
```

### 4. 启动所有服务

#### 4.1 使用 Docker Compose 启动
```bash
cd docker_dev

# 启动所有服务
docker-compose up -d

# 或者分步启动
# 1. 启动基础服务
docker-compose up -d ruoyi-mysql ruoyi-redis ruoyi-nacos

# 2. 等待基础服务启动完成后，启动应用服务
docker-compose up -d ruoyi-gateway ruoyi-auth ruoyi-modules-system ruoyi-modules-gen ruoyi-modules-job ruoyi-modules-file ruoyi-visual-monitor

# 3. 启动前端
docker-compose up -d ruoyi-nginx
```

#### 4.2 使用部署脚本（Linux）
```bash
cd docker_dev

# 开启防火墙端口（如果需要）
sh deploy.sh port

# 启动基础环境
sh deploy.sh base

# 启动应用模块
sh deploy.sh modules
```

### 5. 验证部署

#### 5.1 检查服务状态
```bash
docker-compose ps
```

#### 5.2 查看服务日志
```bash
# 查看所有服务日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f ruoyi-gateway
docker-compose logs -f ruoyi-auth
docker-compose logs -f ruoyi-modules-system
```

#### 5.3 访问服务
- **前端地址**：http://localhost
- **网关地址**：http://localhost:8080
- **Nacos 控制台**：http://localhost:8848/nacos
- **监控中心**：http://localhost:9100
- **Sentinel 控制台**：http://localhost:8718 （默认账号/密码：sentinel/sentinel）

### 6. 停止和清理

```bash
cd docker_dev

# 停止所有服务
docker-compose stop

# 停止并删除容器
docker-compose down

# 停止并删除容器和卷（包括数据）
docker-compose down -v
```

## 部署方式二：本地开发部署

### 1. 环境准备

#### 1.1 安装并启动 MySQL
```bash
# 创建数据库
mysql -uroot -p
CREATE DATABASE `ry-cloud` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE `ry-config` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE `ry-seata` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

# 导入 SQL
mysql -uroot -p ry-cloud < sql/ry_20250523.sql
mysql -uroot -p ry-config < sql/ry_config_20250902.sql
mysql -uroot -p ry-cloud < sql/quartz.sql
mysql -uroot -p ry-seata < sql/ry_seata_20210128.sql
```

#### 1.2 安装并启动 Redis
```bash
# Windows
# 下载 Redis for Windows 或使用 WSL

# Linux/Mac
redis-server

# 验证
redis-cli ping
```

#### 1.3 安装并启动 Nacos
```bash
# 下载 Nacos：https://github.com/alibaba/nacos/releases
# 解压后进入 bin 目录

# Windows
startup.cmd -m standalone

# Linux/Mac
sh startup.sh -m standalone

# 访问控制台：http://localhost:8848/nacos
# 默认用户名/密码：nacos/nacos
```

### 2. 配置 Nacos

#### 2.1 修改 Nacos 数据源配置
编辑 `nacos/conf/application.properties`：
```properties
spring.datasource.platform=mysql
db.num=1
db.url.0=jdbc:mysql://127.0.0.1:3306/ry-config?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=UTC
db.user=root
db.password=你的MySQL密码
```

#### 2.2 在 Nacos 控制台添加配置
访问 http://localhost:8848/nacos，在配置管理中添加 `application-dev.yml`（参考 Docker 部署中的配置内容）

### 3. 编译后端项目

```bash
# 在项目根目录执行
mvn clean package -Dmaven.test.skip=true

# 或者使用脚本
# Windows
bin\package.bat

# Linux/Mac
mvn clean package -Dmaven.test.skip=true
```

### 4. 启动后端服务

**注意**：需要按以下顺序启动服务：

#### 4.1 启动网关服务（ruoyi-gateway）
```bash
# Windows
bin\run-gateway.bat

# Linux/Mac
cd ruoyi-gateway/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-gateway.jar
```

#### 4.2 启动认证服务（ruoyi-auth）
```bash
# Windows
bin\run-auth.bat

# Linux/Mac
cd ruoyi-auth/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-auth.jar
```

#### 4.3 启动系统服务（ruoyi-modules-system）
```bash
# Windows
bin\run-modules-system.bat

# Linux/Mac
cd ruoyi-modules/ruoyi-system/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-modules-system.jar
```

#### 4.4 启动代码生成服务（ruoyi-modules-gen）
```bash
# Windows
bin\run-modules-gen.bat

# Linux/Mac
cd ruoyi-modules/ruoyi-gen/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-modules-gen.jar
```

#### 4.5 启动定时任务服务（ruoyi-modules-job）
```bash
# Windows
bin\run-modules-job.bat

# Linux/Mac
cd ruoyi-modules/ruoyi-job/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-modules-job.jar
```

#### 4.6 启动文件服务（ruoyi-modules-file）
```bash
# Windows
bin\run-modules-file.bat

# Linux/Mac
cd ruoyi-modules/ruoyi-file/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-modules-file.jar
```

#### 4.7 启动监控服务（ruoyi-visual-monitor）
```bash
# Windows
bin\run-monitor.bat

# Linux/Mac
cd ruoyi-visual/ruoyi-monitor/target
java -Xms512m -Xmx1024m -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=512m -jar ruoyi-visual-monitor.jar
```

### 5. 启动前端项目

```bash
cd ruoyi-ui

# 安装依赖（首次运行）
npm install --registry=https://registry.npmmirror.com

# 开发模式运行
npm run dev

# 生产模式构建
npm run build:prod
```

前端开发服务器默认运行在：http://localhost:80

### 6. 验证部署

访问以下地址验证服务是否正常：
- **前端**：http://localhost:80
- **网关**：http://localhost:8080
- **Nacos**：http://localhost:8848/nacos
- **监控中心**：http://localhost:9100

默认登录账号：
- 用户名：admin
- 密码：admin123

## 常见问题

### 1. 服务启动失败
- 检查 Nacos 是否正常启动
- 检查 MySQL 和 Redis 连接配置
- 查看服务日志排查错误

### 2. 前端无法访问后端
- 检查网关服务是否启动
- 检查 Nginx 配置（Docker 部署）
- 检查前端 API 地址配置

### 3. 数据库连接失败
- 检查数据库是否启动
- 检查数据库用户名密码
- 检查数据库是否已创建并导入 SQL

### 4. Nacos 配置不生效
- 检查 Nacos 数据源配置
- 检查配置文件的 Data ID 和 Group 是否正确
- 检查服务是否已注册到 Nacos

### 5. Redis 连接失败
- 检查 Redis 是否启动
- 检查 Redis 密码配置
- 检查防火墙端口是否开放

## 端口说明

| 服务 | 端口 | 说明 |
|------|------|------|
| Nginx | 80 | 前端访问端口 |
| Gateway | 8080 | 网关端口 |
| Auth | 9200 | 认证服务端口 |
| System | 9201 | 系统服务端口 |
| Gen | 9202 | 代码生成服务端口 |
| Job | 9203 | 定时任务服务端口 |
| File | 9300 | 文件服务端口 |
| Monitor | 9100 | 监控中心端口 |
| Nacos | 8848 | Nacos 控制台端口 |
| MySQL | 3306 | MySQL 数据库端口 |
| Redis | 6379 | Redis 缓存端口 |

## 生产环境建议

1. **安全配置**
   - 修改默认密码
   - 配置 HTTPS
   - 限制 Nacos 访问权限
   - 配置防火墙规则

2. **性能优化**
   - 调整 JVM 参数
   - 配置数据库连接池
   - 配置 Redis 集群
   - 使用 Nginx 负载均衡

3. **监控告警**
   - 配置服务监控
   - 设置日志收集
   - 配置告警规则

4. **备份策略**
   - 定期备份数据库
   - 备份配置文件
   - 备份上传文件

## 技术支持

如有问题，请参考：
- 官方文档：http://doc.ruoyi.vip
- 在线演示：http://ruoyi.vip
- GitHub Issues：https://gitee.com/y_project/RuoYi-Cloud/issues

