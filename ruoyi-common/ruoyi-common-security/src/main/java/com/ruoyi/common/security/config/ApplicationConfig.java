package com.ruoyi.common.security.config;

import java.util.TimeZone;
import javax.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import com.ruoyi.common.core.utils.JwtUtils;

/**
 * 系统配置
 *
 * @author ruoyi
 */
@Configuration
public class ApplicationConfig
{
    private static final Logger log = LoggerFactory.getLogger(ApplicationConfig.class);

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

    /**
     * 时区配置
     */
    @Bean
    public Jackson2ObjectMapperBuilderCustomizer jacksonObjectMapperCustomization()
    {
        return jacksonObjectMapperBuilder -> jacksonObjectMapperBuilder.timeZone(TimeZone.getDefault());
    }
}
