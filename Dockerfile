FROM superng6/alpine:3.21 AS builder

# 安装构建工具和必要依赖
RUN apk add --no-cache curl wget unzip bash

# 下载静态编译的 aria2c 和 AriaNg
RUN ARIANG_VER=$(wget -qO- https://api.github.com/repos/mayswind/AriaNg/tags | grep 'name' | cut -d\" -f4 | head -1) \
    && wget -P /tmp https://github.com/mayswind/AriaNg/releases/download/${ARIANG_VER}/AriaNg-${ARIANG_VER}.zip \
    && unzip /tmp/AriaNg-${ARIANG_VER} -d /tmp/ariang \
    && curl -fsSL https://git.io/docker-aria2c.sh | bash

# -------------------------------
# Final Stage: Main Container
# -------------------------------
FROM superng6/alpine:3.21

# 设置镜像信息
LABEL maintainer="NG6 <https://github.com/SuperNG6/docker-aria2>"

# 环境变量（可扩展）
ENV TZ=Asia/Shanghai \
    UT=true \
    SECRET=yourtoken \
    CACHE=128M \
    QUIET=true \
    SMD=true \
    RUT=true \
    PORT=6800 \
    WEBUI=true \
    WEBUI_PORT=8080 \
    BTPORT=32516 \
    PUID=1026 \
    PGID=100

# 拷贝文件
COPY root/ /
COPY darkhttpd/ /etc/cont-init.d/
COPY --from=builder /tmp/ariang /www/ariang
COPY --from=builder /usr/local/bin/aria2c /usr/local/bin/aria2c

# 安装必要工具和依赖
RUN apk add --no-cache \
        darkhttpd \
        curl \
        jq \
        findutils \
    && chmod a+x /usr/local/bin/aria2c \
    && ARIANG_VER=$(wget -qO- https://api.github.com/repos/mayswind/AriaNg/tags | grep 'name' | cut -d\" -f4 | head -1) \
    && echo "docker-aria2-$(date +"%Y-%m-%d")" > /aria2/build-date \
    && echo "docker-ariang-$ARIANG_VER" >> /aria2/build-date \
    && rm -rf /var/cache/apk/* /tmp/*

# 设置卷
VOLUME ["/config", "/downloads", "/www"]

# 暴露端口
EXPOSE 8080 6800 32516 32516/udp