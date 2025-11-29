# 部署脚本说明

本目录包含 OriginTea-Cloud 项目的 Docker 部署脚本。

## 脚本列表

### 1. 01_build_jar.sh
**功能**: 编译Java项目并复制JAR包到Docker目录

**说明**:
- 使用Docker容器环境（Maven镜像）编译项目，避免本地环境依赖
- 自动编译所有微服务模块
- 将编译好的JAR包复制到对应的Docker目录

**使用方法**:
```bash
./01_build_jar.sh
```

**输出目录**:
- `docker_dev/ruoyi/gateway/jar/ruoyi-gateway.jar`
- `docker_dev/ruoyi/auth/jar/ruoyi-auth.jar`
- `docker_dev/ruoyi/modules/system/jar/ruoyi-modules-system.jar`
- `docker_dev/ruoyi/modules/gen/jar/ruoyi-modules-gen.jar`
- `docker_dev/ruoyi/modules/job/jar/ruoyi-modules-job.jar`
- `docker_dev/ruoyi/modules/file/jar/ruoyi-modules-file.jar`
- `docker_dev/ruoyi/visual/monitor/jar/ruoyi-visual-monitor.jar`

---

### 2. 02_build_web.sh
**功能**: 构建前端项目并复制到Docker目录

**说明**:
- 自动检测本地Node.js环境，如果没有则使用Docker容器构建
- 安装npm依赖并构建生产版本
- 将构建好的前端文件复制到 `docker_dev/nginx/html/dist`

**使用方法**:
```bash
./02_build_web.sh
```

**输出目录**:
- `docker_dev/nginx/html/dist/`

---

### 3. 03_build_mysql.sh
**功能**: 创建MySQL容器并初始化数据库

**说明**:
- 启动MySQL容器（基于docker-compose.yml配置）
- 创建数据库：ry-cloud, ry-config, ry-seata
- 自动导入SQL脚本文件

**使用方法**:
```bash
./03_build_mysql.sh
```

**导入的SQL文件**:
- `sql/ry_20250523.sql` → ry-cloud
- `sql/ry_config_20250902.sql` → ry-config
- `sql/quartz.sql` → ry-cloud
- `sql/ry_seata_20210128.sql` → ry-seata

**数据库配置**:
- 用户名: root
- 密码: password
- 端口: 3306

---

### 4. 04_build_nacos.sh
**功能**: 创建Nacos容器并配置基础信息

**说明**:
- 启动Nacos容器（依赖MySQL）
- 等待Nacos服务就绪
- 提示可以运行配置脚本自动配置

**使用方法**:
```bash
./04_build_nacos.sh
```

**访问地址**:
- Nacos控制台: http://localhost:8848/nacos
- 默认用户名/密码: nacos/nacos

---

### 4.1. 04_config_nacos.sh
**功能**: 自动配置Nacos配置中心的所有配置信息

**说明**:
- 自动登录Nacos并获取访问令牌
- 自动添加所有必需的配置文件
- 配置数据库、Redis、各服务配置等

**使用方法**:
```bash
./04_config_nacos.sh
```

**配置的配置文件**:
1. `application-dev.yml` - 共享配置（数据库、Redis、MyBatis）
2. `ruoyi-gateway-dev.yml` - 网关服务配置
3. `ruoyi-auth-dev.yml` - 认证服务配置
4. `ruoyi-system-dev.yml` - 系统服务配置
5. `ruoyi-gen-dev.yml` - 代码生成服务配置
6. `ruoyi-job-dev.yml` - 定时任务服务配置
7. `ruoyi-file-dev.yml` - 文件服务配置
8. `ruoyi-visual-monitor-dev.yml` - 监控服务配置
9. `sentinel-ruoyi-gateway` - Sentinel网关规则

**注意**: 
- 需要先运行 `04_build_nacos.sh` 启动Nacos服务
- 配置完成后，应用服务会自动刷新配置
- 如需立即生效，可重启应用服务

---

### 5. 05_build_redis.sh
**功能**: 创建Redis容器

**说明**:
- 启动Redis容器
- 验证Redis服务是否就绪

**使用方法**:
```bash
./05_build_redis.sh
```

**配置**:
- 端口: 6379
- 无密码

---

### 6. 06_start.sh
**功能**: 启动所有应用服务

**说明**:
- 检查基础服务（MySQL、Redis、Nacos）是否运行
- 按依赖顺序启动所有微服务
- 显示服务状态和访问地址

**使用方法**:
```bash
./06_start.sh
```

**启动顺序**:
1. ruoyi-gateway (网关)
2. ruoyi-auth (认证服务)
3. ruoyi-modules-system (系统服务)
4. ruoyi-modules-gen (代码生成)
5. ruoyi-modules-job (定时任务)
6. ruoyi-modules-file (文件服务)
7. ruoyi-visual-monitor (监控服务)
8. ruoyi-nginx (前端)

---

### 7. 07_check.sh
**功能**: 验证所有部署状态

**说明**:
- 检查所有容器运行状态
- 检查端口是否可访问
- 检查JAR文件和前端文件
- 检查数据库和Redis连接
- 检查服务日志错误

**使用方法**:
```bash
./07_check.sh
```

**检查项**:
- ✓ 容器运行状态
- ✓ 端口可访问性
- ✓ JAR文件存在性
- ✓ 前端文件部署
- ✓ 数据库连接
- ✓ Redis连接
- ✓ Nacos服务
- ⚠ 服务错误日志

---

## 完整部署流程

### 方式一：按顺序执行所有脚本

```bash
# 1. 编译后端
./01_build_jar.sh

# 2. 构建前端
./02_build_web.sh

# 3. 创建MySQL并初始化
./03_build_mysql.sh

# 4. 创建Nacos
./04_build_nacos.sh

# 5. 创建Redis
./05_build_redis.sh

# 6. 启动所有服务
./06_start.sh

# 7. 验证部署
./07_check.sh
```

### 方式二：一键部署脚本（可选）

可以创建一个 `deploy_all.sh` 脚本自动执行所有步骤：

```bash
#!/bin/bash
set -e

echo "开始完整部署流程..."

./01_build_jar.sh
./02_build_web.sh
./03_build_mysql.sh
./04_build_nacos.sh
./05_build_redis.sh

echo "等待基础服务就绪..."
sleep 10

./06_start.sh
sleep 10

./07_check.sh

echo "部署完成！"
```

---

## 环境要求

- **Docker**: 20.10 或以上
- **Docker Compose**: 1.29 或以上
- **Git Bash** 或 **WSL** (Windows系统)
- **网络连接** (用于下载Docker镜像和npm包)

---

## 常见问题

### 1. 脚本执行权限
如果遇到权限问题，需要添加执行权限：
```bash
chmod +x *.sh
```

### 2. Windows系统
在Windows系统上，可以使用以下方式运行：
- Git Bash
- WSL (Windows Subsystem for Linux)
- 或者将脚本转换为 `.bat` 文件

### 3. Docker镜像下载慢
可以配置Docker镜像加速器，编辑 `/etc/docker/daemon.json`:
```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
```

### 4. 端口冲突
如果端口被占用，可以：
- 修改 `docker_dev/docker-compose.yml` 中的端口映射
- 停止占用端口的服务

### 5. Nacos配置
启动Nacos后，需要在控制台添加 `application-dev.yml` 配置，参考 `DEPLOY.md` 中的配置内容。

---

## 服务访问地址

部署成功后，可以通过以下地址访问：

- **前端**: http://localhost
- **网关**: http://localhost:8080
- **Nacos控制台**: http://localhost:8848/nacos
- **监控中心**: http://localhost:9100

**默认登录账号**:
- 用户名: admin
- 密码: admin123

---

## 停止服务

停止所有服务：
```bash
cd docker_dev
docker-compose stop
```

停止并删除容器：
```bash
cd docker_dev
docker-compose down
```

停止并删除容器和数据卷：
```bash
cd docker_dev
docker-compose down -v
```

---

## 查看日志

查看所有服务日志：
```bash
cd docker_dev
docker-compose logs -f
```

查看特定服务日志：
```bash
docker logs -f ruoyi-gateway
docker logs -f ruoyi-auth
docker logs -f ruoyi-modules-system
```

---

## 重新部署

如果需要重新部署：

1. 停止所有服务
2. 删除旧容器和数据（可选）
3. 重新执行部署脚本

```bash
cd docker_dev
docker-compose down -v

cd ../deploy
./01_build_jar.sh
./02_build_web.sh
./03_build_mysql.sh
./04_build_nacos.sh
./05_build_redis.sh
./06_start.sh
./07_check.sh
```

