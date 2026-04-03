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
BAD_CONF_PATH="/etc/nginx/conf.d/00-ops-bad.conf"

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

echo "[INFO] 删除临时错误配置..."
$COMPOSE_CMD exec -T nginx sh -c "rm -f $BAD_CONF_PATH"

echo "[INFO] 检查 Nginx 配置语法..."
$COMPOSE_CMD exec -T nginx nginx -t

echo "[INFO] 重新加载 Nginx..."
$COMPOSE_CMD exec -T nginx nginx -s reload

sleep 3

STATUS_CODE="$(curl -I -s -o /dev/null -w '%{http_code}' --max-time 10 "$APP_URL" || true)"
echo "[INFO] 当前页面状态码：${STATUS_CODE:-000}" | tee "$LOG_DIR/nginx-bad-upstream-recover-http-$TIMESTAMP.log"

echo "[INFO] 导出 Nginx 最近日志..."
$COMPOSE_CMD logs --tail=50 nginx | tee "$LOG_DIR/nginx-bad-upstream-recover-nginx-$TIMESTAMP.log"

if [[ "${STATUS_CODE:-000}" == "200" ]]; then
  echo "[OK] 故障恢复成功，页面已恢复访问。"
else
  echo "[WARN] 页面仍未恢复，请执行 health_check.sh 继续排查。"
fi