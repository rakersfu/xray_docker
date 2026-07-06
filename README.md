# Xray VLESS-Reality Docker 容器

基于 Alpine Linux 的 [Xray-core](https://github.com/XTLS/Xray-core) VLESS-over-TCP + Reality 代理容器镜像，支持通过环境变量动态生成配置，一键部署生产可用的 Reality 节点。

---

## 目录

- [功能特性](#功能特性)
- [快速开始](#快速开始)
- [环境变量](#环境变量)
- [构建镜像](#构建镜像)
- [运行容器](#运行容器)
- [连接信息](#连接信息)
- [网络配置](#网络配置)
- [DNS 策略](#dns-策略)
- [路由规则](#路由规则)
- [日志](#日志)
- [安全建议](#安全建议)
- [常见问题](#常见问题)
- [文件结构](#文件结构)

---

## 功能特性

| 特性 | 说明 |
|------|------|
| **VLESS + Reality** | 基于 XTLS Reality 协议的无证书 TLS 代理，绕过 GFW 指纹检测 |
| **自动密钥生成** | 容器启动时自动生成 X25519 密钥对和 UUID，无需手动配置 |
| **全环境变量覆盖** | 端口、监听地址、伪装域名、证书路径等均可通过环境变量定制 |
| **智能 DNS** | 国内 DNS（223.5.5.5 阿里）优先解析 `.cn` 域名，国际 DNS（1.1.1.1 / 8.8.8.8）兜底 |
| **自动分流** | 中国 IP/域名直连，广告拦截，其余流量走代理 |
| **轻量级** | 基于 Alpine 3.20，镜像体积小巧 |
| **非 root 运行** | 以独立用户 `appuser` 运行，降低安全风险 |

---

## 快速开始

```bash
# 1. 构建镜像（可选，也可使用预编译镜像）
docker build -t xray-reality:latest .

# 2. 运行容器
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="$(./xray uuid)" \
  -e PORT=443 \
  -e SHORTIDS=b477209778 \
  xray-reality:latest

# 3. 查看生成的连接链接
docker logs xray-reality
```

输出类似如下内容即为成功：

```
[Init] Generating X25519 key pair...
[Info] PrivateKey = xxx...
[Info] Password   = xxx...
[Link] Reality VLESS:
vless://<UUID>@127.0.0.1:443?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=<Password>&sni=www.mysql.com&sid=b477209778#VLESS-Reality
```

---

## 环境变量

所有环境变量均可在 `docker run` 时通过 `-e` 参数覆盖。下表列出了全部可用变量及其默认值：

| 变量名 | 默认值 | 必填 | 说明 |
|--------|--------|------|------|
| `UUID` | 自动生成 | 否 | 用户唯一标识。若未提供，容器将调用 `xray uuid` 自动生成随机 UUID |
| `PORT` | `443` | 否 | 容器内 Xray 监听端口（`-p` 映射到宿主机的端口与此无关） |
| `HOST` | `127.0.0.1` | 否 | 客户端填写的连接地址（仅用于生成 VLESS 链接展示） |
| `SHORTIDS` | `b477209778` | 否 | Reality 短 ID，用于验证连接。可留空或自定义 |
| `LISTEN_ADDR` | `0.0.0.0` | 否 | Xray 绑定的网络接口地址 |
| `LOG_LEVEL` | `warning` | 否 | 日志级别：`debug` / `info` / `warning` / `error` / `none` |
| `DOMAIN` | `www.mysql.com` | 否 | Reality 伪装目标域名（SNI），客户端和服务器必须一致 |
| `DESTHOST` | `443` | 否 | 伪装目标的端口号 |
| `CERT_FILE` | `/etc/ssl/cert.pem` | 否 | TLS 证书路径（仅 Security 模式为 `tls` 时需要） |
| `KEY_FILE` | `/etc/ssl/key.pem` | 否 | TLS 私钥路径（仅 Security 模式为 `tls` 时需要） |
| `XRAY_VERSION` | `26.3.27` | 否 | 构建时 Xray-core 版本号（仅在 `docker build` 阶段生效） |

### 使用示例

#### 自定义端口和伪装域名

```bash
docker run -d \
  --name xray-reality \
  -p 8443:8443 \
  -e PORT=8443 \
  -e DOMAIN=www.google.com \
  -e DESTHOST=443 \
  -e HOST="<你的服务器公网IP>" \
  xray-reality:latest
```

#### 固定 UUID 和安全短 ID

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="a1b2c3d4-e5f6-7890-abcd-ef1234567890" \
  -e SHORTIDS="0123456789abcdef" \
  -e LOG_LEVEL=info \
  xray-reality:latest
```

#### 多端口部署（HTTP/WS 备用）

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -p 80:80 \
  -p 8080:8080 \
  -e PORT=443 \
  xray-reality:latest
```

---

## 构建镜像

### 从源码构建

```bash
# 使用默认 Xray 版本（26.3.27）
docker build -t xray-reality:latest .

# 指定 Xray 版本
docker build --build-arg XRAY_VERSION=26.3.27 -t xray-reality:v26.3.27 .
```

### 镜像组成

构建过程中会自动下载以下内容：

- **Xray-core** Linux AMD64 二进制文件
- **geoip.dat** — GeoIP 规则集（用于 IP 分流）
- **geosite.dat** — GeoSite 规则集（用于域名分流）

构建完成后镜像包含：

```
/app/                          # 应用目录
├── xray                       # Xray 核心二进制
├── geoip.dat                  # GeoIP 规则
├── geosite.dat                # GeoSite 规则
└── config.json                # 运行时生成的配置文件
/usr/local/bin/
└── entrypoint.sh              # 容器入口脚本
```

---

## 运行容器

### 基本运行

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  xray-reality:latest
```

### 生产环境推荐配置

```bash
docker run -d \
  --name xray-reality \
  --restart unless-stopped \
  --memory 256m \
  --cpus 0.5 \
  -p 443:443 \
  -e LOG_LEVEL=warning \
  -e SHORTIDS="$(openssl rand -hex 8)" \
  xray-reality:latest
```

### 后台管理

```bash
# 查看实时日志
docker logs -f xray-reality

# 进入容器调试
docker exec -it xray-reality sh

# 重启容器
docker restart xray-reality

# 停止容器
docker stop xray-reality

# 删除容器
docker rm -f xray-reality
```

---

## 连接信息

容器首次启动后，会在日志中打印完整的 VLESS Reality 连接链接，格式如下：

```
vless://<UUID>@<HOST>:<PORT>?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=<PublicKey>&sni=<SNI>&sid=<ShortId>#VLESS-Reality
```

### 各字段含义

| 字段 | 值 | 说明 |
|------|-----|------|
| 协议 | `vless` | VLESS 协议 |
| 地址 | `HOST` 环境变量值 | 服务器公网 IP 或域名 |
| 端口 | `PORT` 环境变量值 | 容器内监听端口 |
| 流控 | `xtls-rprx-vision` | XTLS Reality Vision 模式 |
| 传输 | `tcp` | TCP 传输 |
| 加密 | `reality` | Reality 安全传输 |
| 公钥 | `pbk` | X25519 公钥（由容器自动生成） |
| SNI | `sni` | 伪装域名（`DOMAIN` 环境变量值） |
| 短 ID | `sid` | Reality 短 ID（`SHORTIDS` 环境变量值） |

### 客户端配置（以 Clash Meta / Mihomo 为例）

```yaml
proxies:
  - name: "VLESS-Reality"
    type: vless
    server: <你的服务器IP>
    port: 443
    uuid: <UUID>
    network: tcp
    tls: true
    udp: true
    flow: xtls-rprx-vision
    reality-opts:
      public-key: <PublicKey>
      short-id: <ShortId>
    client-fingerprint: chrome
```

### 客户端配置（sing-box）

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-reality",
      "server": "<你的服务器IP>",
      "server_port": 443,
      "uuid": "<UUID>",
      "packet_encoding": "xudp",
      "flow": "xtls-rprx-vision",
      "transport": {
        "type": "tcp"
      },
      "tls": {
        "enabled": true,
        "reality": {
          "enabled": true,
          "public_key": "<PublicKey>",
          "short_id": "<ShortId>"
        }
      }
    }
  ]
}
```

---

## 网络配置

### 端口说明

| 端口 | 用途 | 备注 |
|------|------|------|
| `443` | VLESS-Reality 主端口 | 默认端口，TLS 标准端口，不易被封锁 |
| `2779` | 备用端口 | 镜像暴露但未默认使用，可按需挂载 |

### 防火墙规则

确保服务器防火墙放行对应端口：

```bash
# iptables 示例
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# firewalld 示例
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# ufw 示例
ufw allow 443/tcp
```

### 反向代理（可选）

如需配合 Nginx 做额外伪装：

```nginx
server {
    listen 443 ssl http2;
    server_name www.mysql.com;  # 与 DOMAIN 环境变量一致

    ssl_certificate     /path/to/real_cert.pem;
    ssl_certificate_key /path/to/real_key.pem;

    location / {
        proxy_pass http://127.0.0.1:443;  # 指向容器内端口
        proxy_http_version 1.1;
        proxy_set_header Host "www.mysql.com";
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

> **注意：** Reality 本身已经提供了 TLS 伪装，通常不需要额外反代。仅在特殊需求下使用。

---

## DNS 策略

容器内置三层 DNS 解析策略：

```
                    ┌─────────────┐
  域名查询 ────────►│  DNS 路由器  │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         geosite:cn   其他域名     私有/IP
              │            │            │
       223.5.5.5 (阿里)  1.1.1.1      直连
       端口 53, 优先    8.8.8.8 (兜底)
```

- **中国域名**（`geosite:cn`）→ 使用阿里 DNS `223.5.5.5`，解析更快
- **国际域名** → 使用 Cloudflare `1.1.1.1` / Google `8.8.8.8`
- **私有 IP** → 不走代理，直接连接

---

## 路由规则

内置智能分流，所有规则在 `config.json` 的 `routing` 段定义：

| 规则 | 匹配条件 | 动作 | 说明 |
|------|----------|------|------|
| 1 | `geosite:cn` | `direct`（直连） | 中国网站不经代理 |
| 2 | `geoip:cn` + `geoip:private` | `direct`（直连） | 中国 IP 和私有 IP 不经代理 |
| 3 | `geosite:category-ads-all` | `block`（拦截） | 广告域名直接丢弃 |
| 4 | `0.0.0.0/0` + `::/0`（默认） | `proxy`（代理） | 其余所有流量走代理 |

### 出站定义

| 标签 | 协议 | 作用 |
|------|------|------|
| `direct` | `freedom` | 直连出站（无修改地发出请求） |
| `proxy` | `freedom` | 代理出站（标记为需代理的流量） |
| `block` | `blackhole` | 黑洞出站（丢弃数据包） |

---

## 日志

### 日志级别

通过 `LOG_LEVEL` 环境变量控制：

| 级别 | 适用场景 | 输出内容 |
|------|----------|----------|
| `debug` | 开发调试 | 最详细信息，包括连接建立/断开 |
| `info` | 日常监控 | 常规运行信息 |
| `warning`（默认） | 生产环境 | 警告及以上级别 |
| `error` | 高负载 | 仅错误信息 |
| `none` | 极致性能 | 关闭所有日志 |

### 查看日志

```bash
# 查看容器启动日志（含连接链接）
docker logs xray-reality

# 实时跟踪日志
docker logs -f xray-reality

# 查看最近 100 行
docker logs --tail 100 xray-reality
```

### Xray 运行时日志

Xray 自身的日志会输出到容器的标准输出。如果需要持久化到文件，可以挂载卷：

```bash
docker run -d \
  --name xray-reality \
  -v xray-logs:/app/logs \
  -e LOG_LEVEL=info \
  xray-reality:latest
```

---

## 安全建议

### 1. 定期轮换密钥

```bash
# 停止旧容器
docker stop xray-reality && docker rm xray-reality

# 生成新密钥对
NEW_UUID=$(docker run --rm xray-reality:latest sh -c './xray uuid')
NEW_X25519=$(docker run --rm xray-reality:latest sh -c './xray x25519')

# 用新密钥启动
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="$NEW_UUID" \
  xray-reality:latest
```

### 2. 使用强 Short ID

```bash
# 生成随机 16 进制短 ID
-e SHORTIDS="$(openssl rand -hex 8)"
```

### 3. 限制访问来源

通过防火墙仅允许特定 IP 段访问代理端口：

```bash
iptables -A INPUT -p tcp --dport 443 -s 0.0.0.0/0 -j ACCEPT
# 或者更严格的方式，只放行你的客户端 IP
```

### 4. 资源限制

```bash
docker run -d \
  --name xray-reality \
  --memory 512m \
  --cpus 1.0 \
  --pids-limit 100 \
  -p 443:443 \
  xray-reality:latest
```

### 5. 保持更新

定期重建镜像以获取最新 Xray 版本的安全补丁：

```bash
docker build --no-cache -t xray-reality:latest .
docker restart xray-reality
```

---

## 常见问题

### Q1: 如何修改监听端口？

设置 `PORT` 环境变量，并确保 `docker run -p` 映射一致：

```bash
docker run -d -p 8443:8443 -e PORT=8443 xray-reality:latest
```

### Q2: 客户端连接不上怎么办？

排查步骤：

1. **检查容器状态**：`docker ps | grep xray`
2. **查看日志**：`docker logs xray-reality`，确认无报错
3. **确认端口映射**：`docker port xray-reality`
4. **检查防火墙**：确保服务器防火墙放行了对应端口
5. **确认 SNI 一致**：客户端 `sni` 必须与服务端 `DOMAIN` 环境变量一致
6. **确认短 ID 一致**：客户端 `sid` 必须与服务端 `SHORTIDS` 一致

### Q3: 如何更换伪装域名？

修改 `DOMAIN` 和 `DESTHOST` 环境变量：

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e DOMAIN=www.github.com \
  -e DESTHOST=443 \
  xray-reality:latest
```

> **注意：** 更换伪装域名后，客户端也必须同步修改 SNI 配置。

### Q4: 能否同时跑多个 Reality 实例？

可以。每个容器使用不同的端口：

```bash
docker run -d --name xray-1 -p 443:443 -e PORT=443 xray-reality:latest
docker run -d --name xray-2 -p 8443:8443 -e PORT=8443 xray-reality:latest
```

### Q5: 日志太多影响性能？

将 `LOG_LEVEL` 设为 `warning` 或 `error`：

```bash
docker exec -it xray-reality sh -c 'sed -i "s/warning/error/" /app/config.json'
docker restart xray-reality
```

或直接重新运行容器：

```bash
docker run -d -e LOG_LEVEL=error xray-reality:latest
```

### Q6: 如何备份和恢复配置？

配置存储在容器内的 `/app/config.json`，可通过以下方式持久化：

```bash
# 备份
docker cp xray-reality:/app/config.json ./config.backup.json

# 恢复
docker cp ./config.backup.json xray-reality:/app/config.json
docker restart xray-reality
```

### Q7: 支持 ARM 架构吗？

当前 Dockerfile 仅打包了 Linux AMD64 版本的 Xray。如需 ARM 支持，请修改 Dockerfile 中的下载 URL：

```dockerfile
# ARM64
wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-arm64-v8a.zip

# ARM32
wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-32.zip
```

---

## 文件结构

```
.
├── Dockerfile              # 容器构建定义
├── entrypoint_new.sh       # 容器入口脚本（重命名为 entrypoint.sh 嵌入镜像）
└── README.md               # 本文档
```

### 各文件职责

| 文件 | 职责 |
|------|------|
| `Dockerfile` | 定义基础镜像（Alpine 3.20）、安装依赖、下载 Xray 二进制、创建非 root 用户、暴露端口 |
| `entrypoint_new.sh` | 容器启动时执行的初始化脚本：生成密钥 → 解析环境变量 → 动态生成 `config.json` → 打印连接链接 → 启动 Xray |

### 入口脚本执行流程

```
容器启动
  │
  ├─ 1. 生成 X25519 密钥对（PrivateKey + PublicKey/Password）
  │
  ├─ 2. 读取环境变量（UUID、端口、域名等），使用默认值
  │
  ├─ 3. 动态生成 config.json（VLESS-Reality 配置）
  │
  ├─ 4. 验证配置文件生成成功
  │
  ├─ 5. 打印 VLESS Reality 连接链接
  │
  └─ 6. exec "$@" 启动 Xray 进程（接管 PID 1）
```

---

## 许可证

本项目基于 [Xray-core](https://github.com/XTLS/Xray-core) 构建，遵循其原始许可证。

---

## 相关资源

- [Xray-core 官方文档](https://xtls.github.io/)
- [Xray Release 页面](https://github.com/XTLS/Xray-core/releases)
- [Reality 协议介绍](https://xtls.github.io/features/reality/)
- [VLESS 协议说明](https://xtls.github.io/protocol/vless.html)
