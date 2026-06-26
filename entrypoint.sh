#!/bin/sh
set -e

# ==========================================
# 1. 读取环境变量，提供默认值
# ==========================================
UUID=${UUID:-588db1b3-0b3f-48d9-98a2-c5574415a400}
PORT=${PORT:-443}
WS_PATH=${WS_PATH:-/0ecc78fc}
LISTEN_ADDR=${LISTEN_ADDR:-0.0.0.0}
LOG_LEVEL=${LOG_LEVEL:-info}   # 选项：debug, info, warning, error
CONFIG_FILE="/app/config.json"

echo "[Init] Generating Xray configuration..."

# ==========================================
# 2. 生成 config.json
# ==========================================
cat > "$CONFIG_FILE" <<EOF
{
  "log": {
    "loglevel": "$LOG_LEVEL",
    "access": "/dev/stdout",
    "error": "/dev/stderr"
  },
  "inbounds": [
    {
      "port": $PORT,
      "listen": "$LISTEN_ADDR",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "security": "auto"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# 检查生成是否成功
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[Error] Failed to create config file at $CONFIG_FILE"
  exit 1
fi

echo "[Init] Config generated successfully. Starting Xray..."

# ==========================================
# 3. 启动 Xray
# ==========================================
# exec 把当前 shell 替换成 Xray，成为容器 PID 1
exec "$@"
