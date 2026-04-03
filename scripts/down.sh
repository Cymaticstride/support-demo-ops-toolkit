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
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "[ERROR] 找不到项目一目录：$APP_DIR"
  exit 1
fi

cd "$APP_DIR"

echo "[INFO] 正在关闭并移除容器..."
$COMPOSE_CMD down

echo "[OK] 服务已关闭。"