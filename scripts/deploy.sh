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

if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
  echo "[ERROR] 目标目录里没有 docker-compose.yml：$APP_DIR"
  exit 1
fi

echo "[INFO] 目标项目目录：$APP_DIR"
cd "$APP_DIR"

echo "[INFO] 开始构建并启动服务..."
$COMPOSE_CMD up -d --build

echo "[INFO] 当前容器状态："
$COMPOSE_CMD ps

echo "[INFO] 等待服务稳定..."
sleep 5

echo "[INFO] 检查页面连通性：$APP_URL"
if curl -I --max-time 10 "$APP_URL" >/dev/null 2>&1; then
  echo "[OK] 页面可访问，部署完成。"
else
  echo "[WARN] 容器已启动，但页面暂时无法访问，请执行 health_check.sh 进一步排查。"
fi