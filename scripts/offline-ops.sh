#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ -f "$SCRIPT_DIR/docker-compose.yml" ] || [ -f "$SCRIPT_DIR/docker-compose.server.yml" ]; then
  DEFAULT_TARGET="$SCRIPT_DIR"
else
  DEFAULT_TARGET=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
fi

ACTION=""
ACTION_FROM_ARGS=0
TARGET_DIR="$DEFAULT_TARGET"
COMPOSE_FILE=""
ENV_FILE=""
IMAGE_TAR=""
SKIP_IMAGE_LOAD=0
SKIP_DB_BACKUP=0
NO_RESTART=0
SKIP_START=0
NO_HEALTH_CHECK=0
ASSUME_YES=0
LOG_SERVICE=""

info() { printf '[INFO] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1"; }
fail() { printf '[ERROR] %s\n' "$1" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: offline-ops.sh [options]

Options:
  --action <name>          install|load|up|image|status|logs|stop|restart|backup|backup-volume|migrate|reset-db|uninstall
  --target <path>          Deployment root. Default: script directory, or its parent in repo mode
  --compose-file <path>    Compose file. Default: docker-compose.yml, fallback docker-compose.server.yml
  --env-file <path>        Env file. Default: .env, fallback deploy/alicloud/env/.env
  --image-tar <path>       Image tar path. Default: newest tar under images/ or apps/
  --skip-image-load        Do not run docker load
  --skip-db-backup         Do not run logical backup before reset-db
  --no-restart             Do not recreate app/nginx for action=image
  --skip-start             Do not start services for action=install/up
  --no-health-check        Skip PostgreSQL and HTTP checks
  --yes                    Confirm destructive actions
  --service <name>         Service for action=logs
  --help                   Show this help

Run without --action to use the interactive menu.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action) ACTION=${2:-}; ACTION_FROM_ARGS=1; shift 2 ;;
    --target) TARGET_DIR=${2:-}; shift 2 ;;
    --compose-file) COMPOSE_FILE=${2:-}; shift 2 ;;
    --env-file) ENV_FILE=${2:-}; shift 2 ;;
    --image-tar) IMAGE_TAR=${2:-}; shift 2 ;;
    --skip-image-load) SKIP_IMAGE_LOAD=1; shift ;;
    --skip-db-backup) SKIP_DB_BACKUP=1; shift ;;
    --no-restart) NO_RESTART=1; shift ;;
    --skip-start) SKIP_START=1; shift ;;
    --no-health-check) NO_HEALTH_CHECK=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --service) LOG_SERVICE=${2:-}; shift 2 ;;
    --help) usage; exit 0 ;;
    *) fail "未知参数：$1" ;;
  esac
done

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "缺少命令：$1"
}

detect_compose() {
  if docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
  else
    fail "未检测到 Docker Compose。"
  fi
}

abs_path() {
  path=$1
  case "$path" in
    /*) printf '%s\n' "$path" ;;
    *) printf '%s/%s\n' "$TARGET_DIR" "$path" ;;
  esac
}

read_required() {
  prompt=$1
  default_value=${2:-}
  while :; do
    if [ -n "$default_value" ]; then
      printf '%s [%s]: ' "$prompt" "$default_value" >&2
    else
      printf '%s: ' "$prompt" >&2
    fi
    IFS= read -r value
    if [ -z "$value" ] && [ -n "$default_value" ]; then
      printf '%s\n' "$default_value"
      return
    fi
    if [ -n "$value" ]; then
      printf '%s\n' "$value"
      return
    fi
    printf '该项不能为空。\n' >&2
  done
}

read_yes_no() {
  prompt=$1
  default_value=${2:-n}
  while :; do
    if [ "$default_value" = "y" ]; then
      printf '%s [Y/n]: ' "$prompt" >&2
    else
      printf '%s [y/N]: ' "$prompt" >&2
    fi
    IFS= read -r value
    [ -n "$value" ] || value=$default_value
    case "$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')" in
      y|yes|1|true) return 0 ;;
      n|no|0|false) return 1 ;;
      *) printf '请输入 y 或 n。\n' >&2 ;;
    esac
  done
}

read_menu_choice() {
  printf '\nAutoTFL 离线部署/运维工具\n'
  printf '1. 首次部署 / 全量部署（保留已有 .env）\n'
  printf '2. 只加载离线镜像包\n'
  printf '3. 启动或更新全部服务\n'
  printf '4. 加载镜像并重建 app/nginx\n'
  printf '5. 查看服务状态\n'
  printf '6. 查看服务日志\n'
  printf '7. 停止服务\n'
  printf '8. 重启服务\n'
  printf '9. 备份 PostgreSQL 数据库 dump\n'
  printf '10. 备份 PostgreSQL 数据目录\n'
  printf '11. 执行 PostgreSQL 迁移 SQL\n'
  printf '12. 危险：重置 PostgreSQL 数据目录\n'
  printf '13. 危险：卸载并删除本地数据\n'
  printf '0. 退出\n\n'
  while :; do
    printf '请选择操作: '
    IFS= read -r choice
    case "$choice" in
      1) ACTION=install; return ;;
      2) ACTION=load; return ;;
      3) ACTION=up; return ;;
      4) ACTION=image; return ;;
      5) ACTION=status; return ;;
      6) ACTION=logs; return ;;
      7) ACTION=stop; return ;;
      8) ACTION=restart; return ;;
      9) ACTION=backup; return ;;
      10) ACTION=backup-volume; return ;;
      11) ACTION=migrate; return ;;
      12) ACTION=reset-db; return ;;
      13) ACTION=uninstall; return ;;
      0) exit 0 ;;
      *) printf '请输入 0-13。\n' ;;
    esac
  done
}

resolve_layout() {
  TARGET_DIR=$(abs_path "$TARGET_DIR")
  [ -d "$TARGET_DIR" ] || fail "目标目录不存在：$TARGET_DIR"

  if [ -z "$COMPOSE_FILE" ]; then
    if [ -f "$TARGET_DIR/docker-compose.yml" ]; then
      COMPOSE_FILE="$TARGET_DIR/docker-compose.yml"
    elif [ -f "$TARGET_DIR/docker-compose.server.yml" ]; then
      COMPOSE_FILE="$TARGET_DIR/docker-compose.server.yml"
    else
      fail "目标目录缺少 docker-compose.yml 或 docker-compose.server.yml：$TARGET_DIR"
    fi
  else
    COMPOSE_FILE=$(abs_path "$COMPOSE_FILE")
  fi
  [ -f "$COMPOSE_FILE" ] || fail "Compose 文件不存在：$COMPOSE_FILE"

  if [ -z "$ENV_FILE" ]; then
    if [ -f "$TARGET_DIR/.env" ] || [ -f "$TARGET_DIR/.env.example" ]; then
      ENV_FILE="$TARGET_DIR/.env"
      ENV_EXAMPLE="$TARGET_DIR/.env.example"
    else
      ENV_FILE="$TARGET_DIR/deploy/alicloud/env/.env"
      ENV_EXAMPLE="$TARGET_DIR/deploy/alicloud/env/.env.example"
    fi
  else
    ENV_FILE=$(abs_path "$ENV_FILE")
    ENV_EXAMPLE="$(dirname "$ENV_FILE")/.env.example"
  fi
}

compose_cmd() {
  if [ -f "$ENV_FILE" ]; then
    (cd "$TARGET_DIR" && $COMPOSE_CMD --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@")
  else
    (cd "$TARGET_DIR" && $COMPOSE_CMD -f "$COMPOSE_FILE" "$@")
  fi
}

env_value() {
  key=$1
  default_value=${2:-}
  if [ -f "$ENV_FILE" ]; then
    line=$(grep -E "^${key}=" "$ENV_FILE" | tail -n 1 || true)
    if [ -n "$line" ]; then
      line=${line#*=}
      line=${line%\"}
      line=${line#\"}
      line=${line%\'}
      line=${line#\'}
      printf '%s' "$line"
      return
    fi
  fi
  printf '%s' "$default_value"
}

random_value() {
  bytes=${1:-24}
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex "$bytes"
  elif [ -r /dev/urandom ]; then
    od -An -N "$bytes" -tx1 /dev/urandom | tr -d ' \n'
  else
    date +%s%N | sha256sum | awk '{print $1}'
  fi
}

ensure_env() {
  env_dir=$(dirname "$ENV_FILE")
  mkdir -p "$env_dir"

  if [ -f "$ENV_FILE" ]; then
    info "检测到已有 .env，保留现有配置：$ENV_FILE"
  else
    [ -f "$ENV_EXAMPLE" ] || fail "缺少 .env.example，无法生成 .env：$ENV_EXAMPLE"
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    warn "已从 .env.example 生成 .env：$ENV_FILE"
  fi

  if grep -q "CHANGE_ME\|__CHANGE_ME_" "$ENV_FILE" 2>/dev/null; then
    fail ".env 仍包含占位符，请先编辑后再部署：$ENV_FILE"
  fi
}

prepare_dirs() {
  data_path=$(data_root_path)
  mkdir -p "$data_path/postgres" "$data_path/redis" "$data_path/storage" "$TARGET_DIR/backups" "$TARGET_DIR/apps"
  info "数据目录：$data_path"
}

data_root_path() {
  data_root=$(env_value DATA_ROOT "./data")
  case "$data_root" in
    /*) printf '%s\n' "$data_root" ;;
    *) printf '%s/%s\n' "$TARGET_DIR" "$data_root" ;;
  esac
}

postgres_data_path() {
  printf '%s/postgres\n' "$(data_root_path)"
}

resolve_image_tar() {
  if [ -n "$IMAGE_TAR" ]; then
    IMAGE_TAR=$(abs_path "$IMAGE_TAR")
    [ -f "$IMAGE_TAR" ] || fail "镜像包不存在：$IMAGE_TAR"
    return
  fi

  IMAGE_TAR=$(find "$TARGET_DIR/images" "$TARGET_DIR/apps" -maxdepth 1 -type f \( -name "*.tar" -o -name "*.tar.gz" \) 2>/dev/null | sort | tail -n 1 || true)
  [ -n "$IMAGE_TAR" ] || fail "未找到离线镜像包：$TARGET_DIR/images 或 $TARGET_DIR/apps"
}

load_images() {
  if [ "$SKIP_IMAGE_LOAD" -eq 1 ]; then
    info "跳过镜像加载。"
    return
  fi
  resolve_image_tar
  info "加载 Docker 镜像包：$IMAGE_TAR"
  docker load -i "$IMAGE_TAR"
}

start_services() {
  if [ "$SKIP_START" -eq 1 ]; then
    info "跳过服务启动。"
    return
  fi
  compose_cmd up -d --pull never
}

restart_app_nginx() {
  if [ "$NO_RESTART" -eq 1 ]; then
    info "已指定 --no-restart，跳过 app/nginx 重建。"
    return
  fi
  compose_cmd up -d --pull never --force-recreate app nginx
}

wait_for_postgres() {
  [ "$NO_HEALTH_CHECK" -eq 0 ] || return
  info "等待 PostgreSQL 就绪。"
  count=0
  while [ "$count" -lt 60 ]; do
    if compose_cmd exec -T postgres pg_isready -U autotfl_user -d autotfl >/dev/null 2>&1; then
      info "PostgreSQL 已就绪。"
      return
    fi
    count=$((count + 1))
    sleep 2
  done
  fail "PostgreSQL 未在预期时间内就绪，请检查日志。"
}

verify_http() {
  [ "$NO_HEALTH_CHECK" -eq 0 ] || return
  command -v curl >/dev/null 2>&1 || { info "未检测到 curl，跳过 HTTP 验证。"; return; }

  web_port=$(env_value WEB_PORT "8080")
  ok=0
  for path in "/" "/app/"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${web_port}${path}" || true)
    case "$code" in
      2*|3*) info "HTTP 验证通过：http://localhost:${web_port}${path} -> $code"; ok=1 ;;
    esac
  done
  [ "$ok" -eq 1 ] || warn "HTTP 验证未通过；如使用 HTTPS/反代，请手工检查入口。"
}

backup_database() {
  ensure_env
  mkdir -p "$TARGET_DIR/backups"
  backup_path="$TARGET_DIR/backups/autotfl-db-$(date '+%Y%m%d-%H%M%S').sql"
  compose_cmd up -d --pull never postgres
  wait_for_postgres
  info "备份数据库：$backup_path"
  compose_cmd exec -T postgres pg_dump -U autotfl_user autotfl > "$backup_path"
  info "数据库备份完成。"
}

backup_database_volume() {
  ensure_env
  pg_path=$(postgres_data_path)
  [ -d "$pg_path" ] || fail "PostgreSQL 数据目录不存在：$pg_path"
  mkdir -p "$TARGET_DIR/backups"
  archive_path="$TARGET_DIR/backups/autotfl-postgres-volume-$(date '+%Y%m%d-%H%M%S').tar.gz"

  warn "物理目录备份需要短暂停止 app/postgres，避免备份到不一致的数据文件。"
  if [ "$ASSUME_YES" -ne 1 ] && ! read_yes_no "继续执行数据库目录备份" y; then
    info "已取消。"
    return
  fi

  compose_cmd stop app postgres >/dev/null 2>&1 || true
  info "打包 PostgreSQL 数据目录：$archive_path"
  (cd "$(dirname "$pg_path")" && tar -czf "$archive_path" "$(basename "$pg_path")")
  compose_cmd up -d --pull never postgres app nginx
  wait_for_postgres
  verify_http
  compose_cmd ps
  info "数据库目录备份完成。"
}

run_migrations() {
  ensure_env
  migration_dir="$TARGET_DIR/postgres/migrations"
  [ -d "$migration_dir" ] || fail "迁移目录不存在：$migration_dir"

  found=0
  compose_cmd up -d --pull never postgres
  wait_for_postgres

  container_id=$(compose_cmd ps -q postgres | tail -n 1)
  [ -n "$container_id" ] || fail "未找到 postgres 容器。"

  for sql_file in "$migration_dir"/*.sql; do
    [ -f "$sql_file" ] || continue
    found=1
    sql_base=$(basename "$sql_file")
    container_sql="/tmp/$sql_base"
    info "执行数据库迁移：$sql_base"
    docker cp "$sql_file" "$container_id:$container_sql"
    compose_cmd exec -T postgres psql -v ON_ERROR_STOP=1 -U autotfl_user -d autotfl -f "$container_sql"
    compose_cmd exec -T postgres rm -f "$container_sql" >/dev/null 2>&1 || true
  done

  [ "$found" -eq 1 ] || fail "迁移目录中没有 SQL 文件：$migration_dir"
  info "数据库迁移完成。"
}

reset_database_volume() {
  ensure_env
  pg_path=$(postgres_data_path)
  mkdir -p "$TARGET_DIR/backups"

  warn "该操作会停止 app/postgres，并重置 PostgreSQL 数据目录。"
  warn "旧目录不会直接删除，会移动到 backups/ 作为回退备份。"
  if [ "$ASSUME_YES" -ne 1 ] && ! read_yes_no "确认重置 PostgreSQL 数据目录" n; then
    info "已取消。"
    return
  fi

  if [ "$SKIP_DB_BACKUP" -eq 0 ]; then
    info "重置前执行逻辑备份；如数据库已损坏，可用 --skip-db-backup 跳过。"
    backup_database
  else
    warn "已跳过逻辑备份。"
  fi

  compose_cmd stop app postgres >/dev/null 2>&1 || true

  if [ -d "$pg_path" ]; then
    archive_dir="$TARGET_DIR/backups/postgres-volume-reset-$(date '+%Y%m%d-%H%M%S')"
    info "移动旧 PostgreSQL 数据目录到：$archive_dir"
    mv "$pg_path" "$archive_dir"
  fi

  mkdir -p "$pg_path"
  compose_cmd up -d --pull never postgres app nginx
  wait_for_postgres
  verify_http
  compose_cmd ps
  info "PostgreSQL 数据目录已重置。"
}

full_install() {
  ensure_env
  prepare_dirs
  load_images
  start_services
  wait_for_postgres
  verify_http
  compose_cmd ps
}

image_restart() {
  ensure_env
  load_images
  restart_app_nginx
  wait_for_postgres
  verify_http
  compose_cmd ps
}

stop_services() {
  compose_cmd down
}

restart_services() {
  compose_cmd restart
  wait_for_postgres
  verify_http
  compose_cmd ps
}

show_logs() {
  if [ -z "$LOG_SERVICE" ] && [ "$ACTION_FROM_ARGS" -eq 0 ]; then
    printf '日志服务名（留空查看全部）: ' >&2
    IFS= read -r LOG_SERVICE
  fi
  if [ -n "$LOG_SERVICE" ]; then
    compose_cmd logs -f --tail=100 "$LOG_SERVICE"
  else
    compose_cmd logs -f --tail=100
  fi
}

uninstall_all() {
  warn "该操作会停止服务，并删除 Compose volume。"
  if ! read_yes_no "确认执行卸载" n; then
    info "已取消。"
    return
  fi
  compose_cmd down -v
  data_root=$(env_value DATA_ROOT "")
  if [ -n "$data_root" ]; then
    data_path=$(data_root_path)
    if [ -d "$data_path" ] && read_yes_no "是否同时删除数据目录 $data_path" n; then
      rm -rf "$data_path"
    fi
  fi
  info "卸载完成。"
}

require_command docker
detect_compose
resolve_layout
[ -n "$ACTION" ] || read_menu_choice

case "$ACTION" in
  install) full_install ;;
  load) load_images ;;
  up) ensure_env; prepare_dirs; start_services; wait_for_postgres; verify_http; compose_cmd ps ;;
  image) image_restart ;;
  status) compose_cmd ps ;;
  logs) show_logs ;;
  stop) stop_services ;;
  restart) restart_services ;;
  backup) backup_database ;;
  backup-volume) backup_database_volume ;;
  migrate) run_migrations ;;
  reset-db) reset_database_volume ;;
  uninstall) uninstall_all ;;
  *) fail "未知操作：$ACTION" ;;
esac
