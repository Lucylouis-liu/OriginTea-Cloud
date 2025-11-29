package com.ruoyi.gateway.config.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.cloud.context.config.annotation.RefreshScope;
import org.springframework.context.annotation.Configuration;

/**
 * 验证码配置
 * 
 * @author ruoyi
 */
@Configuration
@RefreshScope
@ConfigurationProperties(prefix = "security.captcha")
public class CaptchaProperties
{
    /**
     * 验证码开关（默认开启）
     */
    private Boolean enabled = true;

    /**
     * 验证码类型（math 数组计算 char 字符，默认 char）
     */
    private String type = "char";

    public Boolean getEnabled()
    {
        return enabled != null ? enabled : true;
    }

    public void setEnabled(Boolean enabled)
    {
        this.enabled = enabled;
    }

    public String getType()
    {
        return type != null ? type : "char";
    }

    public void setType(String type)
    {
        this.type = type;
    }
}
