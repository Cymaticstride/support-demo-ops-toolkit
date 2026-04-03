#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

APP_DIR="${APP_DIR:-../support-demo-platform}"
APP_URL="${APP_URL:-http://127.0.0.1:8080}"
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"
LOG_DIR="$ROOT_DIR/logs/drills"
OVERRIDE_FILE="docker-compose.ops-web-no-listener.yml"

if [[ ! -d "$APP_DIR" ]]; then
  echo "[ERROR] 找不到项目一目录：$APP_DIR"
  exit 1
fi

if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
  echo "[ERROR] 目标目录里没有 docker-compose.yml：$APP_DIR"
  exit 1
fi

mkdir -p "$LOG_DIR"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

cd "$APP_DIR"

cat > "$OVERRIDE_FILE" <<'EOF'
services:
  web:
    command:
      - sh
      - -c
      - |
        echo "[DRILL] web 容器已启动，但故意不启动 Flask，只保持进程存活"
        sleep infinity
EOF

echo "[INFO] 已生成故障注入覆盖文件：$OVERRIDE_FILE"
echo "[INFO] 正在注入故障：让 web 容器运行但不监听 5000 端口..."

$COMPOSE_CMD -f docker-compose.yml -f "$OVERRIDE_FILE" up -d db web nginx

sleep 5

echo "[INFO] 当前容器状态："
$COMPOSE_CMD ps | tee "$LOG_DIR/web-no-listener-ps-$TIMESTAMP.log"

echo "[INFO] 检查 web 容器内 5000 端口..."
$COMPOSE_CMD exec -T web python - <<'PY' | tee "$LOG_DIR/web-no-listener-port-$TIMESTAMP.log"
import socket

s = socket.socket()
s.settimeout(2)
code = s.connect_ex(("127.0.0.1", 5000))

if code == 0:
    print("[WARN] 127.0.0.1:5000 仍然在监听")
else:
    print(f"[OK] 127.0.0.1:5000 未监听，connect_ex={code}")
PY

STATUS_CODE="$(curl -I -s -o /dev/null -w '%{http_code}' --max-time 10 "$APP_URL" || true)"
echo "[INFO] 当前页面状态码：${STATUS_CODE:-000}" | tee "$LOG_DIR/web-no-listener-http-$TIMESTAMP.log"

echo "[INFO] 导出 Nginx 最近日志..."
$COMPOSE_CMD logs --tail=80 nginx | tee "$LOG_DIR/web-no-listener-nginx-$TIMESTAMP.log"

echo "[INFO] 导出 web 最近日志..."
$COMPOSE_CMD logs --tail=40 web | tee "$LOG_DIR/web-no-listener-web-$TIMESTAMP.log"

if [[ "${STATUS_CODE:-000}" != "200" ]]; then
  echo "[OK] 故障注入成功。当前页面已异常，可继续执行 health_check.sh 观察现象。"
else
  echo "[WARN] 页面仍返回 200，请检查故障是否真正生效。"
fi