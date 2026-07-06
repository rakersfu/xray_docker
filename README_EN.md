# Xray VLESS-Reality Docker Container

A Docker container image based on [Xray-core](https://github.com/XTLS/Xray-core) implementing VLESS-over-TCP with Reality transport. Dynamically generates configuration via environment variables, enabling one-command deployment of a production-ready Reality node.

---

## Table of Contents

- [Features](#features)
- [Quick Start](#quick-start)
- [Environment Variables](#environment-variables)
- [Building the Image](#building-the-image)
- [Running the Container](#running-the-container)
- [Connection Information](#connection-information)
- [Network Configuration](#network-configuration)
- [DNS Strategy](#dns-strategy)
- [Routing Rules](#routing-rules)
- [Logging](#logging)
- [Security Recommendations](#security-recommendations)
- [FAQ](#faq)
- [File Structure](#file-structure)

---

## Features

| Feature | Description |
|---------|-------------|
| **VLESS + Reality** | Certificate-less TLS proxy based on the XTLS Reality protocol, designed to evade GFW fingerprint detection |
| **Auto Key Generation** | Automatically generates X25519 key pairs and UUIDs on container startup — no manual configuration required |
| **Full Env Var Overrides** | Port, listen address, spoof domain, certificate paths, and more can all be customized via environment variables |
| **Smart DNS** | Chinese DNS (223.5.5.5 Alibaba) prioritized for `.cn` domains; international DNS (1.1.1.1 / 8.8.8.8) as fallback |
| **Auto Split Tunneling** | China IPs/domains bypass the proxy; ads are blocked; all other traffic is proxied |
| **Lightweight** | Based on Alpine 3.20, minimal image size |
| **Non-root Execution** | Runs as a dedicated `appuser` to reduce security risk |

---

## Quick Start

```bash
# 1. Build the image (optional if using a pre-built image)
docker build -t xray-reality:latest .

# 2. Run the container
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="$(./xray uuid)" \
  -e PORT=443 \
  -e SHORTIDS=b477209778 \
  xray-reality:latest

# 3. View the generated connection link
docker logs xray-reality
```

Successful output looks like this:

```
[Init] Generating X25519 key pair...
[Info] PrivateKey = xxx...
[Info] Password   = xxx...
[Link] Reality VLESS:
vless://<UUID>@127.0.0.1:443?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=<Password>&sni=www.mysql.com&sid=b477209778#VLESS-Reality
```

---

## Environment Variables

All environment variables can be overridden at `docker run` time via the `-e` flag. Below is the complete list with defaults:

| Variable | Default | Required | Description |
|----------|---------|----------|-------------|
| `UUID` | Auto-generated | No | Unique user identifier. If not provided, the container calls `xray uuid` to generate a random one |
| `PORT` | `443` | No | Xray listen port inside the container (independent of the `-p` host-to-container port mapping) |
| `HOST` | `127.0.0.1` | No | Connection address shown in the generated VLESS link (typically your server's public IP or domain) |
| `SHORTIDS` | `b477209778` | No | Reality short ID for connection verification. Can be empty or customized |
| `LISTEN_ADDR` | `0.0.0.0` | No | Network interface address Xray binds to |
| `LOG_LEVEL` | `warning` | No | Log level: `debug` / `info` / `warning` / `error` / `none` |
| `DOMAIN` | `www.mysql.com` | No | Reality spoofed domain (SNI). Must match the client configuration exactly |
| `DESTHOST` | `443` | No | Spoofed destination port |
| `CERT_FILE` | `/etc/ssl/cert.pem` | No | TLS certificate path (only needed when security mode is `tls`) |
| `KEY_FILE` | `/etc/ssl/key.pem` | No | TLS private key path (only needed when security mode is `tls`) |
| `XRAY_VERSION` | `26.3.27` | No | Xray-core version at build time (only takes effect during `docker build`) |

### Usage Examples

#### Custom port and spoofed domain

```bash
docker run -d \
  --name xray-reality \
  -p 8443:8443 \
  -e PORT=8443 \
  -e DOMAIN=www.google.com \
  -e DESTHOST=443 \
  -e HOST="<your-server-public-ip>" \
  xray-reality:latest
```

#### Fixed UUID and secure short ID

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="a1b2c3d4-e5f6-7890-abcd-ef1234567890" \
  -e SHORTIDS="0123456789abcdef" \
  -e LOG_LEVEL=info \
  xray-reality:latest
```

#### Multi-port deployment (HTTP/WS fallback)

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

## Building the Image

### From Source

```bash
# Build with the default Xray version (26.3.27)
docker build -t xray-reality:latest .

# Build with a specific Xray version
docker build --build-arg XRAY_VERSION=26.3.27 -t xray-reality:v26.3.27 .
```

### Image Contents

During the build, the following are downloaded automatically:

- **Xray-core** Linux AMD64 binary
- **geoip.dat** — GeoIP rule set (used for IP-based split tunneling)
- **geosite.dat** — GeoSite rule set (used for domain-based split tunneling)

After building, the image contains:

```
/app/                          # Application directory
├── xray                       # Xray core binary
├── geoip.dat                  # GeoIP rules
├── geosite.dat                # GeoSite rules
└── config.json                # Runtime-generated configuration
/usr/local/bin/
└── entrypoint.sh              # Container entrypoint script
```

---

## Running the Container

### Basic Run

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  xray-reality:latest
```

### Production-Recommended Configuration

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

### Container Management

```bash
# View live logs
docker logs -f xray-reality

# Enter the container for debugging
docker exec -it xray-reality sh

# Restart the container
docker restart xray-reality

# Stop the container
docker stop xray-reality

# Remove the container
docker rm -f xray-reality
```

---

## Connection Information

On first startup, the container prints a complete VLESS Reality connection link in the logs, in the following format:

```
vless://<UUID>@<HOST>:<PORT>?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=<PublicKey>&sni=<SNI>&sid=<ShortId>#VLESS-Reality
```

### Field Descriptions

| Field | Value | Description |
|-------|-------|-------------|
| Protocol | `vless` | VLESS protocol |
| Address | `HOST` env var | Server public IP or domain |
| Port | `PORT` env var | Listen port inside the container |
| Flow | `xtls-rprx-vision` | XTLS Reality Vision mode |
| Transport | `tcp` | TCP transport |
| Security | `reality` | Reality secure transport |
| Public Key | `pbk` | X25519 public key (auto-generated by the container) |
| SNI | `sni` | Spoofed domain (`DOMAIN` env var) |
| Short ID | `sid` | Reality short ID (`SHORTIDS` env var) |

### Client Configuration (Clash Meta / Mihomo)

```yaml
proxies:
  - name: "VLESS-Reality"
    type: vless
    server: <your-server-ip>
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

### Client Configuration (sing-box)

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "vless-reality",
      "server": "<your-server-ip>",
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

## Network Configuration

### Port Reference

| Port | Purpose | Notes |
|------|---------|-------|
| `443` | VLESS-Reality main port | Default port, standard TLS port, less likely to be blocked |
| `2779` | Backup port | Exposed in the image but not used by default; mount as needed |

### Firewall Rules

Ensure the server firewall allows the corresponding port:

```bash
# iptables example
iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# firewalld example
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --reload

# ufw example
ufw allow 443/tcp
```

### Reverse Proxy (Optional)

If you need additional obfuscation via Nginx:

```nginx
server {
    listen 443 ssl http2;
    server_name www.mysql.com;  # Must match the DOMAIN env var

    ssl_certificate     /path/to/real_cert.pem;
    ssl_certificate_key /path/to/real_key.pem;

    location / {
        proxy_pass http://127.0.0.1:443;  # Points to the container port
        proxy_http_version 1.1;
        proxy_set_header Host "www.mysql.com";
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

> **Note:** Reality already provides TLS obfuscation, so an additional reverse proxy is usually unnecessary. Use only for special requirements.

---

## DNS Strategy

The container includes a three-layer DNS resolution strategy:

```
                    ┌─────────────┐
  Domain Query ────►│  DNS Router │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
         geosite:cn   Other domains  Private/IP
              │            │            │
       223.5.5.5 (Alibaba) 1.1.1.1     Direct
       Port 53, priority  8.8.8.8 (fallback)
```

- **Chinese domains** (`geosite:cn`) → Alibaba DNS `223.5.5.5` for faster resolution
- **International domains** → Cloudflare `1.1.1.1` / Google `8.8.8.8`
- **Private IPs** → Bypasses the proxy entirely, direct connection

---

## Routing Rules

Built-in intelligent split tunneling, all defined in the `routing` section of `config.json`:

| Rule | Match Condition | Action | Description |
|------|-----------------|--------|-------------|
| 1 | `geosite:cn` | `direct` | Chinese websites bypass the proxy |
| 2 | `geoip:cn` + `geoip:private` | `direct` | China IPs and private IPs bypass the proxy |
| 3 | `geosite:category-ads-all` | `block` | Ad domains are dropped |
| 4 | `0.0.0.0/0` + `::/0` (default) | `proxy` | All other traffic goes through the proxy |

### Outbound Definitions

| Tag | Protocol | Purpose |
|-----|----------|---------|
| `direct` | `freedom` | Direct outbound (sends requests unmodified) |
| `proxy` | `freedom` | Proxy outbound (marks traffic that should be proxied) |
| `block` | `blackhole` | Blackhole outbound (drops packets) |

---

## Logging

### Log Levels

Controlled via the `LOG_LEVEL` environment variable:

| Level | Use Case | Output |
|-------|----------|--------|
| `debug` | Development / debugging | Most detailed, including connect/disconnect events |
| `info` | Daily monitoring | Routine operational information |
| `warning` (default) | Production | Warnings and above |
| `error` | High-load | Errors only |
| `none` | Maximum performance | All logging disabled |

### Viewing Logs

```bash
# View container startup logs (includes the connection link)
docker logs xray-reality

# Follow logs in real time
docker logs -f xray-reality

# View the last 100 lines
docker logs --tail 100 xray-reality
```

### Xray Runtime Logs

Xray's own logs are output to the container's standard output. To persist logs to a file, mount a volume:

```bash
docker run -d \
  --name xray-reality \
  -v xray-logs:/app/logs \
  -e LOG_LEVEL=info \
  xray-reality:latest
```

---

## Security Recommendations

### 1. Rotate Keys Regularly

```bash
# Stop the old container
docker stop xray-reality && docker rm xray-reality

# Generate a new key pair
NEW_UUID=$(docker run --rm xray-reality:latest sh -c './xray uuid')
NEW_X25519=$(docker run --rm xray-reality:latest sh -c './xray x25519')

# Start with the new key
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e UUID="$NEW_UUID" \
  xray-reality:latest
```

### 2. Use Strong Short IDs

```bash
# Generate a random 16-hex-char short ID
-e SHORTIDS="$(openssl rand -hex 8)"
```

### 3. Restrict Access Sources

Allow proxy port access only from specific IP ranges via firewall:

```bash
iptables -A INPUT -p tcp --dport 443 -s 0.0.0.0/0 -j ACCEPT
# Or more strictly, allow only your client IP
```

### 4. Resource Limits

```bash
docker run -d \
  --name xray-reality \
  --memory 512m \
  --cpus 1.0 \
  --pids-limit 100 \
  -p 443:443 \
  xray-reality:latest
```

### 5. Keep Updated

Regularly rebuild the image to obtain the latest Xray version security patches:

```bash
docker build --no-cache -t xray-reality:latest .
docker restart xray-reality
```

---

## FAQ

### Q1: How to change the listen port?

Set the `PORT` environment variable and ensure the `docker run -p` mapping matches:

```bash
docker run -d -p 8443:8443 -e PORT=8443 xray-reality:latest
```

### Q2: Client cannot connect — how to troubleshoot?

Follow these steps:

1. **Check container status**: `docker ps | grep xray`
2. **View logs**: `docker logs xray-reality` — confirm no errors
3. **Verify port mapping**: `docker port xray-reality`
4. **Check firewall**: Ensure the server firewall allows the corresponding port
5. **Confirm SNI consistency**: The client's `sni` must match the server's `DOMAIN` environment variable
6. **Confirm short ID consistency**: The client's `sid` must match the server's `SHORTIDS` environment variable

### Q3: How to change the spoofed domain?

Modify the `DOMAIN` and `DESTHOST` environment variables:

```bash
docker run -d \
  --name xray-reality \
  -p 443:443 \
  -e DOMAIN=www.github.com \
  -e DESTHOST=443 \
  xray-reality:latest
```

> **Note:** After changing the spoofed domain, clients must also update their SNI configuration accordingly.

### Q4: Can I run multiple Reality instances simultaneously?

Yes. Use different ports for each container:

```bash
docker run -d --name xray-1 -p 443:443 -e PORT=443 xray-reality:latest
docker run -d --name xray-2 -p 8443:8443 -e PORT=8443 xray-reality:latest
```

### Q5: Too many logs affecting performance?

Set `LOG_LEVEL` to `warning` or `error`:

```bash
docker exec -it xray-reality sh -c 'sed -i "s/warning/error/" /app/config.json'
docker restart xray-reality
```

Or simply restart with the desired level:

```bash
docker run -d -e LOG_LEVEL=error xray-reality:latest
```

### Q6: How to back up and restore configuration?

Configuration is stored in `/app/config.json` inside the container:

```bash
# Backup
docker cp xray-reality:/app/config.json ./config.backup.json

# Restore
docker cp ./config.backup.json xray-reality:/app/config.json
docker restart xray-reality
```

### Q7: Does this support ARM architecture?

The current Dockerfile only packages the Linux AMD64 version of Xray. For ARM support, modify the download URL in the Dockerfile:

```dockerfile
# ARM64
wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-arm64-v8a.zip

# ARM32
wget -q https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-32.zip
```

---

## File Structure

```
.
├── Dockerfile              # Container build definition
├── entrypoint_new.sh       # Container entrypoint script (renamed to entrypoint.sh inside the image)
└── README.md               # This document
```

### File Responsibilities

| File | Responsibility |
|------|---------------|
| `Dockerfile` | Defines the base image (Alpine 3.20), installs dependencies, downloads the Xray binary, creates a non-root user, and exposes ports |
| `entrypoint_new.sh` | Initialization script executed on container startup: generates keys → resolves environment variables → dynamically generates `config.json` → prints the connection link → starts Xray |

### Entrypoint Script Execution Flow

```
Container Starts
  │
  ├─ 1. Generate X25519 key pair (PrivateKey + PublicKey/Password)
  │
  ├─ 2. Read environment variables (UUID, port, domain, etc.) with defaults
  │
  ├─ 3. Dynamically generate config.json (VLESS-Reality configuration)
  │
  ├─ 4. Validate that the config file was created successfully
  │
  ├─ 5. Print the VLESS Reality connection link
  │
  └─ 6. exec "$@" start the Xray process (takes over PID 1)
```

---

## License

This project is built on [Xray-core](https://github.com/XTLS/Xray-core) and follows its original license.

---

## Related Resources

- [Xray-core Documentation](https://xtls.github.io/)
- [Xray Releases](https://github.com/XTLS/Xray-core/releases)
- [Reality Protocol Introduction](https://xtls.github.io/features/reality/)
- [VLESS Protocol Specification](https://xtls.github.io/protocol/vless.html)
