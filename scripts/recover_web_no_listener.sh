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

if [[ -f "$OVERRIDE_FILE" ]]; then
  rm -f "$OVERRIDE_FILE"
  echo "[INFO] 已删除故障注入覆盖文件：$OVERRIDE_FILE"
else
  echo "[WARN] 未找到故障注入覆盖文件，继续按正常配置恢复。"
fi

echo "[INFO] 正在恢复正常配置并重建服务..."
$COMPOSE_CMD up -d --build web nginx

sleep 8

echo "[INFO] 当前容器状态："
$COMPOSE_CMD ps | tee "$LOG_DIR/web-no-listener-recover-ps-$TIMESTAMP.log"

echo "[INFO] 检查 web 容器内 5000 端口..."
$COMPOSE_CMD exec -T web python - <<'PY' | tee "$LOG_DIR/web-no-listener-recover-port-$TIMESTAMP.log"
import socket

s = socket.socket()
s.settimeout(2)
code = s.connect_ex(("127.0.0.1", 5000))

if code == 0:
    print("[OK] 127.0.0.1:5000 已恢复监听")
else:
    print(f"[WARN] 127.0.0.1:5000 仍未监听，connect_ex={code}")
PY

STATUS_CODE="$(curl -I -s -o /dev/null -w '%{http_code}' --max-time 10 "$APP_URL" || true)"
echo "[INFO] 当前页面状态码：${STATUS_CODE:-000}" | tee "$LOG_DIR/web-no-listener-recover-http-$TIMESTAMP.log"

echo "[INFO] 导出 web 最近日志..."
$COMPOSE_CMD logs --tail=50 web | tee "$LOG_DIR/web-no-listener-recover-web-$TIMESTAMP.log"

if [[ "${STATUS_CODE:-000}" == "200" ]]; then
  echo "[OK] 故障恢复成功，页面已恢复访问。"
else
  echo "[WARN] 页面仍未恢复，请执行 health_check.sh 继续排查。"
fi