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
DB_SERVICE="${DB_SERVICE:-db}"
DB_NAME="${DB_NAME:-support_demo}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${DB_PASSWORD:-123456}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"

if [[ "$APP_DIR" != /* ]]; then
  APP_DIR="$ROOT_DIR/$APP_DIR"
fi

if [[ "$BACKUP_DIR" != /* ]]; then
  BACKUP_DIR="$ROOT_DIR/$BACKUP_DIR"
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "[ERROR] 找不到项目一目录：$APP_DIR"
  exit 1
fi

if [[ ! -f "$APP_DIR/docker-compose.yml" ]]; then
  echo "[ERROR] 目标目录里没有 docker-compose.yml：$APP_DIR"
  exit 1
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "[ERROR] 备份目录不存在：$BACKUP_DIR"
  exit 1
fi

BACKUP_NAME="${1:-latest}"

if [[ "$BACKUP_NAME" == "latest" ]]; then
  SOURCE_DIR="$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1)"
else
  SOURCE_DIR="$BACKUP_DIR/$BACKUP_NAME"
fi

if [[ -z "${SOURCE_DIR:-}" || ! -d "$SOURCE_DIR" ]]; then
  echo "[ERROR] 找不到可用备份目录。"
  exit 1
fi

BACKUP_FILE="$SOURCE_DIR/db.sql"
if [[ ! -f "$BACKUP_FILE" ]]; then
  echo "[ERROR] 备份文件不存在：$BACKUP_FILE"
  exit 1
fi

cd "$APP_DIR"

echo "[INFO] 使用备份目录：$SOURCE_DIR"

echo "[INFO] 确保数据库服务已启动..."
$COMPOSE_CMD up -d "$DB_SERVICE"

echo "[INFO] 暂停 web / nginx 服务..."
$COMPOSE_CMD stop web nginx || true

echo "[INFO] 重建数据库：$DB_NAME"
$COMPOSE_CMD exec -T "$DB_SERVICE" sh -c \
  "mysql -u$DB_USER -p$DB_PASSWORD -e \"DROP DATABASE IF EXISTS \\\`$DB_NAME\\\`; CREATE DATABASE \\\`$DB_NAME\\\`;\""

echo "[INFO] 导入备份数据..."
$COMPOSE_CMD exec -T "$DB_SERVICE" sh -c \
  "mysql -u$DB_USER -p$DB_PASSWORD $DB_NAME" \
  < "$BACKUP_FILE"

echo "[INFO] 重新启动 web / nginx 服务..."
$COMPOSE_CMD start web nginx || true

echo "[INFO] 等待服务恢复..."
sleep 5

echo "[INFO] 当前容器状态："
$COMPOSE_CMD ps

echo "[INFO] 检查页面连通性：$APP_URL"
if curl -I --max-time 10 "$APP_URL" >/dev/null 2>&1; then
  echo "[OK] 恢复完成，页面可访问。"
else
  echo "[WARN] 数据已恢复，但页面暂时不可访问，请执行 health_check.sh 排查。"
fi