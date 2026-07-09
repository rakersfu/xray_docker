# ---------- Dockerfile (Xray Core) ----------
FROM alpine:3.20

ENV APP_BIN=/usr/local/bin
ENV APP_HOME=/app
ENV APP_LOGS=/app/logs

# 工作目录
WORKDIR $APP_HOME

# ① 版本号，可自行修改为想要的 Xray 版本
ARG XRAY_VERSION=26.3.27

# ② 创建无密码用户、安装必要工具、下载 Xray、解压
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    apk add --no-cache wget unzip ca-certificates && \
    wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip && \
    unzip Xray-linux-64.zip && \
    mv xray $APP_HOME/xray && \
    mv geo* $APP_HOME/ && \
    rm -f Xray-linux-64.zip && \
    rm -rf /var/cache/apk/*

# ③ 复制入口脚本
COPY *.sh $APP_BIN/
RUN chmod +x $APP_BIN/*.sh && \
    chown -R appuser:appgroup $APP_HOME

# ④ 设置用户
USER appuser

# ⑤ 暴露端口（按需修改）
EXPOSE 443 2779

# ⑥ 入口 + 默认命令
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["./xray", "run", "-config", "config.json"]
