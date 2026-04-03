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

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
TARGET_DIR="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$TARGET_DIR"

cd "$APP_DIR"

echo "[INFO] 检查数据库服务状态..."
$COMPOSE_CMD ps "$DB_SERVICE"

echo "[INFO] 开始导出数据库：$DB_NAME"
$COMPOSE_CMD exec -T "$DB_SERVICE" sh -c \
  "mysqldump -u$DB_USER -p$DB_PASSWORD --single-transaction --quick --routines --triggers $DB_NAME" \
  > "$TARGET_DIR/db.sql"

echo "[INFO] 保存容器状态信息..."
$COMPOSE_CMD ps > "$TARGET_DIR/compose_ps.txt"
date '+%F %T %Z' > "$TARGET_DIR/backup_time.txt"

echo "[OK] 备份完成：$TARGET_DIR"