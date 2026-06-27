#!/bin/sh
set -e

# --------------------------------------------------
# 1. 先执行 xray x25519，提取 PrivateKey 与 Password
# --------------------------------------------------
echo "[Init] Generating X25519 key pair..."

XRAY_OUT=$(./xray x25519)            # 只执行一次
PRIVATE_KEY=$(echo "$XRAY_OUT" | awk -F': ' '/PrivateKey/ {print $2}')
PASSWORD=$(echo "$XRAY_OUT" | awk -F': ' '/Password/ {print $2}')
echo "[Info] PrivateKey = $PRIVATE_KEY"
echo "[Info] Password   = $PASSWORD"

# ----------------------------------------------------
# 2. 环境变量 & 默认值（可在 docker run 时覆盖）
# ----------------------------------------------------
# 如果用户传入了 UUID，就使用它；否则调用 xray uuid
if [ -z "${UUID}" ]; then
  UUID=$(./xray uuid)
  echo "[Info] Generated random UUID: $UUID"
fi
PORT=${PORT:-443}
XHTTPPORT=${XHTTPPORT:-2779}
DESTHOST=${DESTHOST:-443}
SERVERNAMES=${SERVERNAMES:-www.mysql.com}
SHORTIDS=${SHORTIDS:-b477209778}
HOST=${HOST:-lep.840505.xyz}
XHTTP_PATH=${XHTTP_PATH:-/vless-xhttp}
LISTEN_ADDR=${LISTEN_ADDR:-0.0.0.0}
LOG_LEVEL=${LOG_LEVEL:-info}

# 伪装域名
DOMAIN=${DOMAIN:-www.mysql.com}

# security现在为reality，不用配置，如果为tls才需要
CERT_FILE=${CERT_FILE:-/etc/ssl/cert.pem}
KEY_FILE=${KEY_FILE:-/etc/ssl/key.pem}

CONFIG_FILE="/app/config.json"

echo "[Init] Generating Xray configuration..."

# ----------------------------------------------------
# 3. 生成 config.json
# ----------------------------------------------------
cat > "$CONFIG_FILE" <<EOF
{
  "inbounds": [
    {
      "port": "$XHTTPPORT",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "user@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "path": "$XHTTP_PATH",
          "host": "$HOST"
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
          "dest": "$DOMAIN:$DESTHOST",
          "serverNames": [ "$DOMAIN" ],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": [ "$SHORTIDS" ]
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ],
  "log": {
    "loglevel": "$LOG_LEVEL",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  }
}
EOF

# ----------------------------------------------------
# 4. 检查 config 是否生成成功
# ----------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Error] Failed to create config file at $CONFIG_FILE"
  exit 1
fi

echo "[Init] Config generated successfully. Starting Xray..."

# ----------------------------------------------------
# 5. 生成 vless:// 链接并打印
# ----------------------------------------------------
XHTTP_LINK="vless://${UUID}@${HOST}:${XHTTPPORT}?type=xhttp&security=none&path=${XHTTP_PATH}&host=${HOST}#VLESS-XHTTP"
REALITY_LINK="vless://${UUID}@${HOST}:${PORT}?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=${PASSWORD}&sni=${DOMAIN}&sid=${SHORTIDS}#VLESS-Reality"

echo "[Link] WebSocket VLESS:"
echo "$XHTTP_LINK"
echo "[Link] Reality VLESS:"
echo "$REALITY_LINK"

# ----------------------------------------------------
# 6. 启动 Xray
# ----------------------------------------------------
exec "$@"
