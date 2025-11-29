# Nacos 配置说明

## 重要提示

应用服务的数据库和 Redis 配置需要在 **Nacos 配置中心** 中配置，而不是在本地配置文件中。

## 配置步骤

### 1. 访问 Nacos 控制台

- 地址：http://localhost:8848/nacos
- 默认用户名：`nacos`
- 默认密码：`nacos`

### 2. 添加配置文件

在 Nacos 控制台的 **配置管理** -> **配置列表** 中，点击 **+** 按钮添加配置：

#### 配置信息

- **Data ID**: `application-dev.yml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`

#### 配置内容

```yaml
# 共享配置（所有服务通用）
# 注意：网关服务不需要数据源配置，数据源配置在各服务的专用配置中

# Redis 配置（所有服务都需要）
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

# Mybatis 配置（需要数据库的服务使用）
mybatis-plus:
  type-aliases-package: com.ruoyi.**.domain
  configuration:
    map-underscore-to-camel-case: true
    cache-enabled: false
    call-setters-on-nulls: true
    jdbc-type-for-null: 'null'
```

**注意**：数据源配置已从共享配置中移除，因为网关服务不需要数据库连接。数据源配置现在位于各个需要数据库的服务的专用配置中（如 `ruoyi-auth-dev.yml`、`ruoyi-system-dev.yml` 等）。

#### 系统服务配置 (ruoyi-system-dev.yml)

系统服务使用 `dynamic-datasource` 多数据源，需要特殊配置格式：

- **Data ID**: `ruoyi-system-dev.yml`
- **Group**: `DEFAULT_GROUP`
- **配置格式**: `YAML`

```yaml
# 系统服务配置
server:
  port: 9201

# 数据源配置（使用 dynamic-datasource 多数据源）
spring:
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
```

### 3. 关键配置说明

#### 数据库地址

**重要**：在 Docker 容器环境中，必须使用 Docker 服务名作为主机地址：

- ✅ **正确**: `jdbc:mysql://ruoyi-mysql:3306/ry-cloud`
- ❌ **错误**: `jdbc:mysql://127.0.0.1:3306/ry-cloud` (容器内无法访问)
- ❌ **错误**: `jdbc:mysql://localhost:3306/ry-cloud` (容器内无法访问)

#### Redis 地址

同样需要使用 Docker 服务名：

- ✅ **正确**: `host: ruoyi-redis`
- ❌ **错误**: `host: 127.0.0.1` (容器内无法访问)
- ❌ **错误**: `host: localhost` (容器内无法访问)

### 4. 验证配置

配置添加后，重启应用服务，检查日志确认配置已加载：

```bash
# 查看服务日志
docker logs -f ruoyi-modules-system
```

如果看到数据库连接成功，说明配置正确。

### 5. 常见问题

#### 问题1：连接被拒绝 (Connection refused)

**原因**：数据库地址配置错误，使用了 `127.0.0.1` 或 `localhost`

**解决**：确保使用 Docker 服务名 `ruoyi-mysql` 和 `ruoyi-redis`

#### 问题2：找不到数据库 (Unknown database)

**原因**：数据库未创建或 SQL 未导入

**解决**：执行 `./03_build_mysql.sh` 脚本初始化数据库

#### 问题3：配置不生效

**原因**：配置格式错误或 Data ID/Group 不正确

**解决**：
- 检查配置格式是否为 YAML
- 确认 Data ID 为 `application-dev.yml`
- 确认 Group 为 `DEFAULT_GROUP`
- 重启应用服务

### 6. 配置更新

如果需要修改配置：

1. 在 Nacos 控制台编辑配置
2. 点击 **发布**
3. 应用服务会自动刷新配置（如果启用了配置刷新）

或者重启应用服务：

```bash
docker-compose restart ruoyi-modules-system
```

## 快速配置脚本

可以使用以下命令快速验证配置是否存在：

```bash
# 检查 Nacos 中是否有配置
curl -s "http://localhost:8848/nacos/v1/cs/configs?dataId=application-dev.yml&group=DEFAULT_GROUP" | head -20
```

如果有输出，说明配置已存在。

