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

echo "[INFO] 确保服务已启动..."
$COMPOSE_CMD up -d

echo "[INFO] 注入 Nginx 错误上游配置..."
$COMPOSE_CMD exec -T nginx sh -c "cat > $BAD_CONF_PATH" <<'EOF'
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://web:5999;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

echo "[INFO] 检查 Nginx 配置语法..."
$COMPOSE_CMD exec -T nginx nginx -t

echo "[INFO] 重新加载 Nginx..."
$COMPOSE_CMD exec -T nginx nginx -s reload

sleep 3

STATUS_CODE="$(curl -I -s -o /dev/null -w '%{http_code}' --max-time 10 "$APP_URL" || true)"
echo "[INFO] 当前页面状态码：${STATUS_CODE:-000}" | tee "$LOG_DIR/nginx-bad-upstream-http-$TIMESTAMP.log"

echo "[INFO] 导出 Nginx 最近日志..."
$COMPOSE_CMD logs --tail=80 nginx | tee "$LOG_DIR/nginx-bad-upstream-nginx-$TIMESTAMP.log"

echo "[INFO] 导出 web 最近日志..."
$COMPOSE_CMD logs --tail=40 web | tee "$LOG_DIR/nginx-bad-upstream-web-$TIMESTAMP.log"

if [[ "${STATUS_CODE:-000}" == "502" ]]; then
  echo "[OK] 故障注入成功。页面已返回 502。"
else
  echo "[WARN] 当前不是 502，请继续执行 health_check.sh 观察详细现象。"
fi