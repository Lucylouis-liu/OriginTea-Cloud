package com.ruoyi.gateway.config;

import javax.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import com.ruoyi.common.core.utils.JwtUtils;

/**
 * JWT 配置类
 * 用于从配置文件读取 token.secret 并更新 JwtUtils.secret
 * 
 * @author ruoyi
 */
@Configuration
public class JwtConfig
{
    private static final Logger log = LoggerFactory.getLogger(JwtConfig.class);

    /**
     * 令牌密钥（从配置文件中读取，如果未配置则使用默认值）
     */
    @Value("${token.secret:abcdefghijklmnopqrstuvwxyz}")
    private String tokenSecret;

    /**
     * 初始化 JWT Secret（从配置文件读取）
     */
    @PostConstruct
    public void initJwtSecret()
    {
        if (tokenSecret != null && !tokenSecret.isEmpty())
        {
            String oldSecret = JwtUtils.secret;
            JwtUtils.secret = tokenSecret;
            log.info("JWT Secret 已更新: 旧值={}, 新值={}", oldSecret, tokenSecret);
        }
        else
        {
            log.warn("JWT Secret 配置为空，使用默认值: {}", JwtUtils.secret);
        }
    }
}

