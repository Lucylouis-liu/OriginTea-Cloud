# 开发环境部署指南

## 概述

开发环境部署方案将容器中的 JAR 文件映射到本机，方便调试。修改代码后只需重新编译并重启对应服务即可，无需重新构建 Docker 镜像。

## 主要特性

1. **JAR 文件映射**: 使用 Docker volume 将 JAR 文件映射到本机，修改后可直接替换
2. **按需编译**: `01_build_jar.sh` 支持只编译指定的服务，提高开发效率
3. **快速重启**: `dev_restart.sh` 脚本快速重启服务
4. **日志映射**: 日志文件也映射到本机，方便查看

## 文件说明

- `docker-compose.dev.yml`: 开发环境 Docker Compose 配置
- `dev_start.sh`: 开发环境启动脚本
- `dev_restart.sh`: 开发环境服务重启脚本
- `01_build_jar.sh`: 编译脚本（已增强，支持按服务编译）

## 快速开始

### 1. 初始化基础服务

```bash
cd deploy
./03_build_mysql.sh    # 初始化 MySQL
./04_build_nacos.sh    # 启动 Nacos
./04_config_nacos.sh   # 配置 Nacos
./05_build_redis.sh    # 启动 Redis
```

### 2. 编译服务

#### 编译所有服务
```bash
./01_build_jar.sh
# 或
./01_build_jar.sh all
```

#### 只编译指定服务
```bash
# 只编译网关服务
./01_build_jar.sh gateway

# 只编译网关和认证服务
./01_build_jar.sh gateway auth

# 只编译系统服务
./01_build_jar.sh system
```

#### 可用服务名
- `gateway`: 网关服务
- `auth`: 认证服务
- `system`: 系统服务
- `gen`: 代码生成服务
- `job`: 定时任务服务
- `file`: 文件服务
- `monitor`: 监控服务

### 3. 启动开发环境

```bash
# 启动所有服务
./dev_start.sh

# 只启动指定服务
./dev_start.sh ruoyi-gateway ruoyi-auth
```

### 4. 开发调试流程

#### 修改代码后的操作步骤：

1. **重新编译修改的服务**
   ```bash
   ./01_build_jar.sh gateway  # 例如只编译网关服务
   ```

2. **重启对应服务**
   ```bash
   ./dev_restart.sh gateway   # 使用简化名称
   # 或
   ./dev_restart.sh ruoyi-gateway  # 使用完整服务名
   ```

3. **查看日志**
   ```bash
   docker logs -f ruoyi-gateway
   # 或直接查看本机日志文件
   tail -f ../docker_dev/ruoyi/gateway/logs/*.log
   ```

## 常用命令

### 查看服务状态
```bash
cd ../docker_dev
docker-compose -f docker-compose.dev.yml ps
```

### 查看服务日志
```bash
docker logs -f ruoyi-gateway
docker logs -f ruoyi-auth
```

### 停止服务
```bash
cd ../docker_dev
docker-compose -f docker-compose.dev.yml stop [服务名]
```

### 停止所有服务
```bash
cd ../docker_dev
docker-compose -f docker-compose.dev.yml down
```

### 重启单个服务
```bash
./dev_restart.sh gateway
```

### 重启多个服务
```bash
./dev_restart.sh gateway auth system
```

## 目录结构

```
docker_dev/
├── docker-compose.dev.yml          # 开发环境配置
├── ruoyi/
│   ├── gateway/
│   │   ├── jar/
│   │   │   └── ruoyi-gateway.jar   # JAR 文件（映射到容器）
│   │   └── logs/                   # 日志目录（映射到容器）
│   ├── auth/
│   │   ├── jar/
│   │   │   └── ruoyi-auth.jar
│   │   └── logs/
│   └── ...
```

## 开发环境 vs 生产环境

| 特性 | 开发环境 | 生产环境 |
|------|---------|---------|
| Docker Compose 文件 | `docker-compose.dev.yml` | `docker-compose.yml` |
| JAR 文件 | Volume 映射 | 构建到镜像中 |
| 编译方式 | 按需编译 | 全量编译 |
| 重启方式 | 快速重启 | 重建镜像 |
| 调试便利性 | 高 | 低 |

## 注意事项

1. **首次启动**: 确保所有服务的 JAR 文件都已编译，否则服务无法启动
2. **JAR 文件路径**: JAR 文件必须放在 `docker_dev/ruoyi/[服务名]/jar/` 目录下
3. **日志目录**: 日志会自动创建在 `docker_dev/ruoyi/[服务名]/logs/` 目录
4. **端口冲突**: 确保端口未被占用
5. **Windows 路径**: 在 Windows 上使用 Git Bash 时，路径会自动转换

## 故障排查

### 服务启动失败

1. 检查 JAR 文件是否存在
   ```bash
   ls -la docker_dev/ruoyi/gateway/jar/
   ```

2. 检查服务日志
   ```bash
   docker logs ruoyi-gateway
   ```

3. 检查端口是否被占用
   ```bash
   netstat -an | grep 8080
   ```

### 编译失败

1. 检查 Maven 依赖
   ```bash
   ./01_build_jar.sh gateway
   ```

2. 清理并重新编译
   ```bash
   mvn clean
   ./01_build_jar.sh gateway
   ```

### JAR 文件未更新

1. 确认编译成功
   ```bash
   ls -lh docker_dev/ruoyi/gateway/jar/ruoyi-gateway.jar
   ```

2. 重启服务
   ```bash
   ./dev_restart.sh gateway
   ```

## 最佳实践

1. **增量编译**: 只编译修改的服务，节省时间
2. **日志监控**: 使用 `docker logs -f` 实时查看日志
3. **版本控制**: 将 `docker_dev/ruoyi/*/jar/` 目录添加到 `.gitignore`
4. **定期清理**: 定期清理旧的日志文件

## 示例工作流

```bash
# 1. 修改了网关服务的代码
vim ruoyi-gateway/src/main/java/...

# 2. 只编译网关服务
./01_build_jar.sh gateway

# 3. 重启网关服务
./dev_restart.sh gateway

# 4. 查看日志确认
docker logs -f ruoyi-gateway

# 5. 测试功能
curl http://localhost:8080/...
```

## 相关脚本

- `01_build_jar.sh`: 编译脚本（支持按服务编译）
- `dev_start.sh`: 开发环境启动脚本
- `dev_restart.sh`: 服务重启脚本
- `06_start.sh`: 生产环境启动脚本
- `07_check.sh`: 服务检查脚本

