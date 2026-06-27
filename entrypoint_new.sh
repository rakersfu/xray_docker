#!/bin/sh
set -e

# ----------------------------------------------------
# 1. 环境变量 & 默认值（可在 docker run 时覆盖）
# ----------------------------------------------------
UUID=${UUID:-588db1b3-0b3f-48d9-98a2-c5574415a400}
PORT=${PORT:-443}
SERVERNAMES=${SERVERNAMES:-www.mysql.com}
SHORTIDS=${SHORTIDS:-b477209778}
WS_PATH=${WS_PATH:-/chat}
LISTEN_ADDR=${LISTEN_ADDR:-0.0.0.0}
LOG_LEVEL=${LOG_LEVEL:-info}          # debug | info | warning | error

# 伪装域名（TLS 服务器名 & WS 头部）
DOMAIN=${DOMAIN:-proxy.example.com}

# 证书路径（必须挂载到容器中）
CERT_FILE=${CERT_FILE:-/etc/ssl/cert.pem}
KEY_FILE=${KEY_FILE:-/etc/ssl/key.pem}

CONFIG_FILE="/app/config.json"

echo "[Init] Generating Xray configuration..."

# ----------------------------------------------------
# 2. 生成 config.json
# ----------------------------------------------------
cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": 2779,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "0c7b548e-fc9e-47d7-b307-453ee54201b0",
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "/vless-ws",
          "headers": {
            "Host": "lep.840505.xyz"
          }
        }
      }
    },
    {
      "port": "$PORT",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.mysql.com:443",
          "serverNames": [ "$SERVERNAMES" ],
          "privateKey": "8DJPb44ktCXws1IhQ3J4Q19GRPj0-mN6ruhxia2_8VM",
          "shortIds": [ "$SHORTIDS" ]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ],
  "log": {
    "loglevel": "info",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  }
}
EOF

# ----------------------------------------------------
# 3. 检查 config 是否生成成功
# ----------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Error] Failed to create config file at $CONFIG_FILE"
  exit 1
fi

echo "[Init] Config generated successfully. Starting Xray..."

# ----------------------------------------------------
# 4. 启动 Xray
# ----------------------------------------------------
# exec 把当前 shell 替换成 Xray，成为容器 PID 1
exec "$@"
