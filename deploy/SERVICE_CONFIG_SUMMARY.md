# 服务配置总结

## 服务配置概览

### 1. 共享配置 (application-dev.yml)
- **用途**: 所有服务共享的配置
- **包含内容**:
  - Redis 配置
  - MyBatis 配置（需要数据库的服务使用）
- **注意**: 不包含数据源配置，因为网关和认证服务不需要数据库

### 2. 网关服务 (ruoyi-gateway)
- **应用名称**: `ruoyi-gateway`
- **Nacos DataId**: `ruoyi-gateway-dev.yml`
- **数据库**: ❌ 不需要（已排除 DataSourceAutoConfiguration）
- **配置内容**: 路由规则
- **路由服务名称**:
  - `ruoyi-system` (系统服务)
  - `ruoyi-gen` (代码生成服务)
  - `ruoyi-job` (定时任务服务)
  - `ruoyi-file` (文件服务)
  - `ruoyi-auth` (认证服务)

### 3. 认证服务 (ruoyi-auth)
- **应用名称**: `ruoyi-auth`
- **Nacos DataId**: `ruoyi-auth-dev.yml`
- **数据库**: ❌ 不需要（已排除 DataSourceAutoConfiguration）
- **配置内容**: JWT 配置

### 4. 系统服务 (ruoyi-system)
- **应用名称**: `ruoyi-system`
- **Nacos DataId**: `ruoyi-system-dev.yml`
- **数据库**: ✅ 需要
- **数据源类型**: `dynamic-datasource` (多数据源)
- **配置格式**: 
  ```yaml
  spring:
    datasource:
      dynamic:
        primary: master
        strict: false
        datasource:
          master:
            url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?...
            username: root
            password: password
            driver-class-name: com.mysql.cj.jdbc.Driver
            type: com.alibaba.druid.pool.DruidDataSource
            druid:
              initialSize: 10
              minIdle: 10
              maxActive: 20
              # ... 其他 Druid 配置
  ```
- **重要**: 必须使用 `spring.datasource.dynamic` 格式，不能使用 `spring.datasource.druid`

### 5. 代码生成服务 (ruoyi-gen)
- **应用名称**: `ruoyi-gen`
- **Nacos DataId**: `ruoyi-gen-dev.yml`
- **数据库**: ✅ 需要
- **数据源类型**: `HikariCP` (Spring Boot 默认)
- **配置格式**:
  ```yaml
  spring:
    datasource:
      driver-class-name: com.mysql.cj.jdbc.Driver
      url: jdbc:mysql://ruoyi-mysql:3306/ry-cloud?...
      username: root
      password: password
      hikari:
        minimum-idle: 5
        maximum-pool-size: 20
        # ... 其他 HikariCP 配置
  ```

### 6. 定时任务服务 (ruoyi-job)
- **应用名称**: `ruoyi-job`
- **Nacos DataId**: `ruoyi-job-dev.yml`
- **数据库**: ✅ 需要
- **数据源类型**: `HikariCP` (Spring Boot 默认)
- **配置格式**: 与 `ruoyi-gen` 相同

### 7. 文件服务 (ruoyi-file)
- **应用名称**: `ruoyi-file`
- **Nacos DataId**: `ruoyi-file-dev.yml`
- **数据库**: ❌ 不需要（已排除 DataSourceAutoConfiguration）
- **配置内容**: 文件路径配置

### 8. 监控服务 (ruoyi-visual-monitor)
- **应用名称**: `ruoyi-visual-monitor`
- **Nacos DataId**: `ruoyi-visual-monitor-dev.yml`
- **数据库**: ❌ 不需要
- **配置内容**: Spring Boot Admin 配置

## 关键配置要点

### 数据源配置差异

1. **system 服务** (使用 `ruoyi-common-datasource`):
   - 必须使用 `spring.datasource.dynamic` 格式
   - 需要配置 `primary: master`
   - 使用 Druid 连接池

2. **gen 和 job 服务** (不使用 `ruoyi-common-datasource`):
   - 使用标准的 `spring.datasource` 格式
   - 使用 HikariCP 连接池（Spring Boot 默认）

3. **gateway、auth、file 服务**:
   - 不需要数据源配置
   - 已排除 `DataSourceAutoConfiguration`

### MyBatis 配置

所有需要数据库的服务都需要配置 `mapper-locations`:
```yaml
mybatis:
  mapper-locations: classpath*:mapper/**/*Mapper.xml
mybatis-plus:
  mapper-locations: classpath*:mapper/**/*Mapper.xml
```

### 数据库地址

所有服务必须使用 Docker 服务名：
- ✅ `jdbc:mysql://ruoyi-mysql:3306/ry-cloud`
- ❌ `jdbc:mysql://127.0.0.1:3306/ry-cloud` (容器内无法访问)
- ❌ `jdbc:mysql://localhost:3306/ry-cloud` (容器内无法访问)

### Redis 地址

所有服务必须使用 Docker 服务名：
- ✅ `host: ruoyi-redis`
- ❌ `host: 127.0.0.1` (容器内无法访问)
- ❌ `host: localhost` (容器内无法访问)

## 常见错误及解决方案

### 错误1: `dynamic-datasource can not find primary datasource`
**原因**: system 服务的数据源配置格式错误
**解决**: 使用 `spring.datasource.dynamic` 格式，而不是 `spring.datasource.druid`

### 错误2: `ClassNotFoundException: com.alibaba.druid.pool.DruidDataSource`
**原因**: 服务没有 `ruoyi-common-datasource` 依赖，但配置了 Druid
**解决**: 对于 gen 和 job 服务，使用 HikariCP 配置

### 错误3: `Invalid bound statement (not found)`
**原因**: MyBatis Mapper XML 文件未找到
**解决**: 确保配置了 `mapper-locations: classpath*:mapper/**/*Mapper.xml`

### 错误4: 网关无法路由到服务
**原因**: 网关路由配置中的服务名称与实际注册的服务名称不匹配
**解决**: 确保路由 URI 使用正确的服务名称（如 `lb://ruoyi-system` 而不是 `lb://ruoyi-modules-system`）

## 配置验证

运行配置脚本后，可以使用以下命令验证：

```bash
# 检查 Nacos 配置
./check_nacos_config.sh

# 检查服务日志
docker logs -f ruoyi-modules-system
docker logs -f ruoyi-modules-gen
docker logs -f ruoyi-modules-job
```

## 配置更新流程

1. 修改 `deploy/04_config_nacos.sh` 脚本
2. 运行配置脚本: `./04_config_nacos.sh`
3. 重启相关服务: `docker-compose restart <service-name>`
4. 检查服务日志确认配置已生效

