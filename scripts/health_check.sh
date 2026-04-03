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

if [[ ! -d "$APP_DIR" ]]; then
  echo "[ERROR] 找不到项目一目录：$APP_DIR"
  exit 1
fi

cd "$APP_DIR"

echo "========== 1. 容器状态 =========="
$COMPOSE_CMD ps || true

echo

echo "========== 2. 本机监听端口 =========="
ss -lntp | grep -E ':8080|:3307' || echo "[WARN] 暂未发现 8080 或 3307 的监听记录"

echo

echo "========== 3. HTTP 连通性 =========="
if curl -I --max-time 10 "$APP_URL"; then
  echo "[OK] HTTP 检查通过"
else
  echo "[WARN] HTTP 检查失败"
fi

echo

echo "========== 4. Nginx 配置检查 =========="
if $COMPOSE_CMD exec -T nginx nginx -t; then
  echo "[OK] Nginx 配置正常"
else
  echo "[WARN] Nginx 配置检查失败"
fi

echo

echo "========== 5. web 容器内 5000 端口检查 =========="
WEB_CID="$($COMPOSE_CMD ps -q web || true)"

if [[ -z "$WEB_CID" ]]; then
  echo "[WARN] 未找到 web 容器"
else
  if docker inspect -f '{{.State.Running}}' "$WEB_CID" 2>/dev/null | grep -q true; then
    $COMPOSE_CMD exec -T web python - <<'PY'
import socket

s = socket.socket()
s.settimeout(2)
code = s.connect_ex(("127.0.0.1", 5000))

if code == 0:
    print("[OK] web 容器内 127.0.0.1:5000 正在监听")
else:
    print(f"[WARN] web 容器内 127.0.0.1:5000 未监听，connect_ex={code}")
PY
  else
    echo "[WARN] web 容器当前未运行，无法执行容器内端口检查"
  fi
fi

echo

echo "========== 6. 最近日志（web） =========="
$COMPOSE_CMD logs --tail=20 web || true

echo

echo "========== 7. 最近日志（nginx） =========="
$COMPOSE_CMD logs --tail=20 nginx || true