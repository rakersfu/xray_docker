# xray_docker

Xray (XTLS/Xray-core) 的轻量级 Docker 设置，提供了常见配置（WS+TLS 和 XHTTP+Reality）的开箱即用入口脚本。此仓库为希望轻松运行容器化 Xray 的用户提供了简单解决方案，官方地址为https://github.com/rakersfu/xray_docker。

## 这是什么

一个简单的容器化 Xray 运行时，可下载 Xray-core 二进制文件，在容器启动时从环境变量生成配置，然后运行 Xray。它针对希望以简单方式运行 Xray 的用户。

## 内容

- Dockerfile - 从 Alpine 构建镜像，下载 Xray-core，并安装入口脚本。
- entrypoint.sh - 为 WS+TLS 入站生成 config.json（vless over ws+tls）。当你有 TLS 证书并想要 WS 传输时使用。
- entrypoint_new.sh - 为 XHTTP 和 Reality 传输生成 config.json（XHTTP 入站 + vless-reality 入站）。它还生成 X25519 密钥并打印 vless:// 链接。
- docker-compose.yml - 运行镜像的示例 compose 服务。
- .github/workflows/push_to_dockerhub.yml - GitHub Actions 工作流（将镜像推送到 Docker Hub）。

## 工作原理（运行时）

容器启动时，镜像运行入口脚本（安装在 /usr/local/bin/entrypoint.sh）。入口脚本读取环境变量，在 `/app` 中生成适当的 `config.json`，然后运行 Xray。

- Dockerfile ENTRYPOINT: `/usr/local/bin/entrypoint.sh`
- Dockerfile CMD: `./xray run -config config.json`

Dockerfile 默认将 `entrypoint_new.sh` 复制到 `/usr/local/bin/entrypoint.sh`；仓库中的 `entrypoint.sh` 提供了另一个 WS+TLS 配置示例。

## 本地构建

在本地构建 Docker 镜像（根据需要替换标签）：

```bash
# 从仓库根目录
docker build -t xray-local:latest .
```

运行容器（使用 entrypoint_new.sh 行为的示例）：

```bash
docker run -d \
  --name xray \
  -p 443:443 \
  -p 2779:2779 \
  -v $(pwd)/logs:/var/log/xray \
  -e HOST=127.0.0.1 \
  -e DOMAIN=www.mysql.com \
  -e UUID= \
  xray-local:latest
```

入口脚本将在 `/app/config.json` 生成 `config.json`，然后执行默认 CMD 启动 Xray。

## 使用 docker-compose

包含的 `docker-compose.yml` 引用镜像 `xiongli870110/xray:1.0.2`。要使用本地构建的镜像，请修改 compose 文件的 `image` 行以引用 `xray-local:latest` 或在本地构建它。

使用以下命令启动：

```bash
docker compose up -d
```

## 环境变量

入口脚本从环境变量生成配置。`entrypoint_new.sh`（XHTTP + Reality）使用的关键变量：

- UUID - 客户端 UUID；如果为空，脚本将调用 `./xray uuid` 生成一个
- PORT - Reality/TLS 监听端口（默认值：443）
- XHTTPPORT - XHTTP 监听端口（默认值：2779）
- DESTHOST - Reality `dest` 的目标主机/端口（默认值：443）
- SHORTIDS - Reality `shortIds` 数组（默认值：`b477209778`）
- HOST - 在生成的连接链接和 XHTTP 主机头中使用的主机（默认值：`127.0.0.1`）
- XHTTP_PATH - XHTTP 路径（默认为 UUID 的值）
- LISTEN_ADDR - 绑定监听套接字的地址（默认值：`0.0.0.0`）
- LOG_LEVEL - Xray 日志级别（默认值：`info`）
- DOMAIN - 用于 Reality 中 SNI/serverNames 的虚假域名
- CERT_FILE, KEY_FILE - （为基于 TLS 的入口提供）如果使用 `entrypoint.sh`（WS+TLS），则为证书/密钥路径

注意：
- 入口脚本会打印 vless:// 链接到容器日志，以便你可以在启动后复制它们（entrypoint_new.sh 会打印 XHTTP 和 Reality 链接）。
- `entrypoint.sh`（WS+TLS）期望 TLS 证书和密钥挂载到容器中（默认值：`/etc/ssl/cert.pem` 和 `/etc/ssl/key.pem`）。

## 端口

- 443 - 默认情况下由两个脚本中的 Reality/TLS 入站使用
- 2779 - entrypoint_new.sh 使用的示例 XHTTP 入站端口

使用环境变量或 Docker 端口映射调整这些端口。

## 卷

- /var/log/xray（容器）-> 建议挂载主机目录（例如 `./logs`），具有写入权限，以便 Xray 可以在配置后写入日志。
- 如果使用 `entrypoint.sh`（WS+TLS）和 TLS 证书，请将证书挂载到 `/etc/ssl/cert.pem` 和 `/etc/ssl/key.pem`，如 compose 文件所指定的那样。

## 安全性和注意事项

- 仓库的脚本生成并打印私钥和密码（entrypoint_new.sh）。将容器日志视为敏感信息。
- Reality 传输使用生成的 X25519 私钥和 shortid 列表。确保你的使用符合你的威胁模型和平台政策。
- 如果在公共主机上公开端口，请确保主机安全并适当配置防火墙。

## 入口脚本之间的区别

- entrypoint.sh：生成配置单个 vless 入站（WebSocket + TLS 上的 vless）的 `config.json`。期望挂载 TLS 证书，适用于你控制证书文件的情况。
- entrypoint_new.sh：生成 `config.json`，其中包含两个入站：一个 XHTTP vless 入站（无安全性）和一个 vless-reality 入站（安全性：reality）。它调用 `./xray x25519` 生成 Reality 密钥。

## 故障排除

- 如果容器立即退出，检查容器日志：

```bash
docker logs xray
```

- 如果找不到 `./xray` 或权限被拒绝，请确保 Dockerfile 获取了 Xray 并将二进制文件移动到 `/app/xray`，并且二进制文件具有执行权限。

## 贡献

欢迎贡献：为改进而打开 issue 或 PR。如果你更改入口行为或默认端口，请相应地更新 README。

## 许可证

此仓库中不包含许可证文件。如果你打算重用或分发这个，请添加适当的 LICENSE 文件。
