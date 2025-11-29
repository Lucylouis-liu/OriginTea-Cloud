# 开发环境快速开始

## 一、首次部署

```bash
# 1. 初始化基础服务
cd deploy
./03_build_mysql.sh
./04_build_nacos.sh
./04_config_nacos.sh
./05_build_redis.sh

# 2. 编译所有服务
./01_build_jar.sh

# 3. 启动开发环境
./dev_start.sh
```

## 二、日常开发流程

### 修改代码后的操作

```bash
# 1. 只编译修改的服务（例如网关）
./01_build_jar.sh gateway

# 2. 重启对应服务
./dev_restart.sh gateway

# 3. 查看日志
docker logs -f ruoyi-gateway
```

## 三、常用命令

### 编译命令

```bash
# 编译所有服务
./01_build_jar.sh
./01_build_jar.sh all

# 只编译指定服务
./01_build_jar.sh gateway
./01_build_jar.sh gateway auth
./01_build_jar.sh system
```

### 服务管理

```bash
# 启动所有服务
./dev_start.sh

# 启动指定服务
./dev_start.sh ruoyi-gateway ruoyi-auth

# 重启服务（使用简化名称）
./dev_restart.sh gateway
./dev_restart.sh gateway auth system

# 查看服务状态
cd ../docker_dev
docker-compose -f docker-compose.dev.yml ps

# 查看日志
docker logs -f ruoyi-gateway
docker logs -f ruoyi-auth
```

### 停止服务

```bash
cd ../docker_dev
docker-compose -f docker-compose.dev.yml stop [服务名]
docker-compose -f docker-compose.dev.yml down  # 停止所有
```

## 四、服务名称对照表

| 简化名称 | 完整服务名 | 说明 |
|---------|-----------|------|
| gateway | ruoyi-gateway | 网关服务 |
| auth | ruoyi-auth | 认证服务 |
| system | ruoyi-modules-system | 系统服务 |
| gen | ruoyi-modules-gen | 代码生成服务 |
| job | ruoyi-modules-job | 定时任务服务 |
| file | ruoyi-modules-file | 文件服务 |
| monitor | ruoyi-visual-monitor | 监控服务 |

## 五、目录结构

```
docker_dev/
├── docker-compose.dev.yml          # 开发环境配置
├── ruoyi/
│   ├── gateway/
│   │   ├── jar/
│   │   │   └── ruoyi-gateway.jar   # JAR 文件（映射到容器）
│   │   └── logs/                   # 日志目录（映射到容器）
│   └── ...
```

## 六、开发环境优势

1. **快速迭代**: 修改代码后只需重新编译和重启，无需重建镜像
2. **按需编译**: 只编译修改的服务，节省时间
3. **日志查看**: 日志文件映射到本机，方便查看
4. **调试便利**: JAR 文件映射，可直接替换调试

## 七、注意事项

1. 首次启动前确保所有 JAR 文件已编译
2. 修改代码后记得重新编译对应服务
3. 重启服务前确保 JAR 文件已更新
4. 日志文件在 `docker_dev/ruoyi/[服务名]/logs/` 目录

## 八、故障排查

### JAR 文件不存在
```bash
# 检查 JAR 文件
ls -la docker_dev/ruoyi/gateway/jar/

# 重新编译
./01_build_jar.sh gateway
```

### 服务启动失败
```bash
# 查看日志
docker logs ruoyi-gateway

# 检查端口占用
netstat -an | grep 8080
```

### 服务未更新
```bash
# 确认 JAR 文件已更新
ls -lh docker_dev/ruoyi/gateway/jar/ruoyi-gateway.jar

# 强制重启
./dev_restart.sh gateway
```

## 九、完整示例

```bash
# 场景：修改了网关服务的代码

# 1. 修改代码
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

