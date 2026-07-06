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
SHORTIDS=${SHORTIDS:-b477209778}
LISTEN_ADDR=${LISTEN_ADDR:-0.0.0.0}
LOG_LEVEL=${LOG_LEVEL:-warning}

# 伪装域名及端口
DESTDOMAIN=${DOMAIN:-www.mysql.com}
DESTPORT=${DESTHOST:-443}

# security现在为reality，不用配置，如果为tls才需要
CERT_FILE=${CERT_FILE:-/etc/ssl/cert.pem}
KEY_FILE=${KEY_FILE:-/etc/ssl/key.pem}

CONFIG_FILE="$APP_HOME/config.json"

echo "[Init] Generating Xray configuration..."

# ----------------------------------------------------
# 3. 生成 config.json
# ----------------------------------------------------
cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "$LOG_LEVEL"
  },
  "dns": {
    "servers": [
      "1.1.1.1",
      "8.8.8.8",
      {
        "address": "223.5.5.5",
        "port": 53,
        "domains": ["geosite:cn"]
      }
    ]
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "listen": "$LISTEN_ADDR",
      "port": $PORT,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision",
            "email": "user1@example.com"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "$DESTDOMAIN:$DESTPORT",
          "xver": 0,
          "serverNames": ["$DESTDOMAIN"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["&SHORTIDS", ""]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "proxy",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "domain": ["geosite:cn"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "ip": ["geoip:cn", "geoip:private"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:category-ads-all"],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": ["0.0.0.0/0", "::/0"],
        "outboundTag": "proxy"
      }
    ]
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
REALITY_LINK="vless://${UUID}@${HOST}:${PORT}?type=tcp&security=reality&flow=xtls-rprx-vision&pbk=${PASSWORD}&sni=${DESTDOMAIN}&sid=${SHORTIDS}#VLESS-Reality"

echo "[Link] Reality VLESS:"
echo "$REALITY_LINK"

# ----------------------------------------------------
# 6. 启动 Xray
# ----------------------------------------------------
exec "$@"
