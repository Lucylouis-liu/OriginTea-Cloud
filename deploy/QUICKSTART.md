# 快速开始指南

## Windows 系统使用说明

### 方式一：使用 Git Bash（推荐）

1. **安装 Git for Windows**
   - 下载地址：https://git-scm.com/download/win
   - 安装时选择 "Git Bash Here" 选项

2. **运行脚本**
   ```bash
   # 在 deploy 目录右键选择 "Git Bash Here"
   
   # 添加执行权限（首次运行）
   chmod +x *.sh
   
   # 方式1: 一键部署
   ./deploy_all.sh
   
   # 方式2: 分步执行
   ./01_build_jar.sh
   ./02_build_web.sh
   ./03_build_mysql.sh
   ./04_build_nacos.sh
   ./05_build_redis.sh
   ./06_start.sh
   ./07_check.sh
   ```

### 方式二：使用 WSL（Windows Subsystem for Linux）

1. **安装 WSL**
   ```powershell
   # 在 PowerShell (管理员) 中执行
   wsl --install
   ```

2. **运行脚本**
   ```bash
   # 进入 WSL 环境
   wsl
   
   # 进入项目目录
   cd /mnt/e/05chayuan/OriginTea-Cloud/deploy
   
   # 添加执行权限
   chmod +x *.sh
   
   # 执行部署
   ./deploy_all.sh
   ```

### 方式三：使用 Docker Desktop 的 WSL2 后端

如果已安装 Docker Desktop 并配置为 WSL2 后端，可以直接在 WSL 中运行脚本。

---

## Linux/Mac 系统使用说明

```bash
# 进入部署目录
cd deploy

# 添加执行权限
chmod +x *.sh

# 一键部署
./deploy_all.sh

# 或分步执行
./01_build_jar.sh
./02_build_web.sh
./03_build_mysql.sh
./04_build_nacos.sh
./05_build_redis.sh
./06_start.sh
./07_check.sh
```

---

## 部署前检查清单

- [ ] Docker 已安装并运行
- [ ] Docker Compose 已安装
- [ ] 端口 80, 8080, 3306, 6379, 8848 未被占用
- [ ] 有足够的磁盘空间（至少 5GB）
- [ ] 网络连接正常（用于下载镜像和依赖）

---

## 常见问题

### 1. 权限被拒绝
```bash
# 添加执行权限
chmod +x *.sh
```

### 2. 路径问题（Windows）
在 Git Bash 中，Windows 路径会自动转换，无需特殊处理。

### 3. Docker 命令找不到
确保 Docker Desktop 正在运行，并且已添加到系统 PATH。

### 4. 端口被占用
```bash
# Windows 查看端口占用
netstat -ano | findstr :8080

# Linux/Mac 查看端口占用
lsof -i :8080
```

### 5. 镜像下载慢
配置 Docker 镜像加速器（参考 README.md）

---

## 部署后操作

1. **访问 Nacos 控制台**
   - 地址：http://localhost:8848/nacos
   - 账号：nacos/nacos
   - **重要**：添加 `application-dev.yml` 配置文件

2. **访问前端**
   - 地址：http://localhost
   - 账号：admin/admin123

3. **查看服务状态**
   ```bash
   cd docker_dev
   docker-compose ps
   ```

4. **查看日志**
   ```bash
   docker logs -f ruoyi-gateway
   ```

---

## 停止服务

```bash
cd docker_dev
docker-compose stop
```

## 重启服务

```bash
cd docker_dev
docker-compose restart
```

## 完全清理

```bash
cd docker_dev
docker-compose down -v
```

---

## 获取帮助

如遇问题，请查看：
- `README.md` - 详细脚本说明
- `DEPLOY.md` - 完整部署文档
- Docker 日志：`docker logs <容器名>`

