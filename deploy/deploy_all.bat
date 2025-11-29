@echo off
REM deploy_all.bat - Windows一键部署脚本

echo ========================================
echo OriginTea-Cloud 一键部署脚本
echo ========================================
echo.

REM 检查Docker
where docker >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 未安装Docker，请先安装Docker
    exit /b 1
)

where docker-compose >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 未安装Docker Compose，请先安装Docker Compose
    exit /b 1
)

echo [信息] Docker环境检查通过
echo.

REM 获取脚本所在目录
cd /d "%~dp0"

REM 执行部署步骤
echo [步骤 1/7] 编译Java项目...
call 01_build_jar.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] Java项目编译失败
    exit /b 1
)
echo.

echo [步骤 2/7] 构建前端项目...
call 02_build_web.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 前端项目构建失败
    exit /b 1
)
echo.

echo [步骤 3/7] 创建MySQL并初始化数据库...
call 03_build_mysql.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] MySQL初始化失败
    exit /b 1
)
echo.

echo [步骤 4/7] 创建Nacos容器...
call 04_build_nacos.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] Nacos创建失败
    exit /b 1
)
echo.

echo [步骤 5/7] 创建Redis容器...
call 05_build_redis.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] Redis创建失败
    exit /b 1
)
echo.

echo [信息] 等待基础服务就绪...
timeout /t 15 /nobreak >nul

echo [步骤 6/7] 启动所有应用服务...
call 06_start.bat
if %ERRORLEVEL% NEQ 0 (
    echo [错误] 服务启动失败
    exit /b 1
)
echo.

echo [信息] 等待应用服务启动...
timeout /t 15 /nobreak >nul

echo [步骤 7/7] 验证部署状态...
call 07_check.bat
echo.

echo ========================================
echo 部署完成！
echo ========================================
echo.
echo 访问地址:
echo   前端: http://localhost
echo   网关: http://localhost:8080
echo   Nacos: http://localhost:8848/nacos
echo   监控: http://localhost:9100
echo.
echo 默认登录账号: admin/admin123
echo.
echo 注意: 请在Nacos控制台添加application-dev.yml配置
echo ========================================
pause

