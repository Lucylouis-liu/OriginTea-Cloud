package com.ruoyi.gateway.filter;

import java.nio.charset.StandardCharsets;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cloud.gateway.filter.GatewayFilter;
import org.springframework.cloud.gateway.filter.factory.AbstractGatewayFilterFactory;
import org.springframework.core.io.buffer.DataBuffer;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.server.reactive.ServerHttpRequest;
import org.springframework.http.server.reactive.ServerHttpRequestDecorator;
import org.springframework.stereotype.Component;
import com.alibaba.fastjson2.JSON;
import com.alibaba.fastjson2.JSONObject;
import com.ruoyi.common.core.utils.ServletUtils;
import com.ruoyi.common.core.utils.StringUtils;
import com.ruoyi.gateway.config.properties.CaptchaProperties;
import com.ruoyi.gateway.service.ValidateCodeService;
import reactor.core.publisher.Flux;

/**
 * 验证码过滤器
 *
 * @author ruoyi
 */
@Component
public class ValidateCodeFilter extends AbstractGatewayFilterFactory<Object>
{
    private final static String[] VALIDATE_URL = new String[] { "/auth/login", "/auth/register" };

    @Autowired
    private ValidateCodeService validateCodeService;

    @Autowired
    private CaptchaProperties captchaProperties;

    private static final String CODE = "code";

    private static final String UUID = "uuid";

    @Override
    public GatewayFilter apply(Object config)
    {
        return (exchange, chain) -> {
            ServerHttpRequest request = exchange.getRequest();

            // 非登录/注册请求或验证码关闭，不处理
            if (!StringUtils.equalsAnyIgnoreCase(request.getURI().getPath(), VALIDATE_URL) || !captchaProperties.getEnabled())
            {
                return chain.filter(exchange);
            }

            // 使用响应式方式读取请求体
            return DataBufferUtils.join(request.getBody())
                .flatMap(dataBuffer -> {
                    byte[] bytes = new byte[dataBuffer.readableByteCount()];
                    dataBuffer.read(bytes);
                    DataBufferUtils.release(dataBuffer);
                    String bodyStr = new String(bytes, StandardCharsets.UTF_8);
                    
                    try
                    {
                        JSONObject obj = JSON.parseObject(bodyStr);
                        String code = obj.getString(CODE);
                        String uuid = obj.getString(UUID);
                        
                        // 验证验证码
                        validateCodeService.checkCaptcha(code, uuid);
                        
                        // 重新构建请求，因为请求体已被读取
                        ServerHttpRequestDecorator decorator = new ServerHttpRequestDecorator(request) {
                            @Override
                            public Flux<DataBuffer> getBody() {
                                if (bodyStr.length() > 0) {
                                    DataBuffer buffer = exchange.getResponse().bufferFactory().wrap(bodyStr.getBytes());
                                    return Flux.just(buffer);
                                }
                                return Flux.empty();
                            }
                        };
                        
                        return chain.filter(exchange.mutate().request(decorator).build());
                    }
                    catch (Exception e)
                    {
                        return ServletUtils.webFluxResponseWriter(exchange.getResponse(), e.getMessage());
                    }
                })
                .onErrorResume(e -> {
                    return ServletUtils.webFluxResponseWriter(exchange.getResponse(), e.getMessage());
                });
        };
    }
}
