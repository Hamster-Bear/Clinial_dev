#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOCAL_APPS_DIR="${LOCAL_APPS_DIR:-$ROOT_DIR/apps}"
REMOTE_ROOT="${REMOTE_ROOT:-/opt/hamster-analysis/current}"
REMOTE_APPS_DIR="${REMOTE_APPS_DIR:-$REMOTE_ROOT/apps}"
IMAGE_NAME="${IMAGE_NAME:-autotfl-shiny-app:latest}"
BUNDLE_PREFIX="${BUNDLE_PREFIX:-autotfl-offline-bundle}"
SERVER_TARGET="${SERVER_TARGET:-}"
UPLOAD_METHOD="${UPLOAD_METHOD:-scp}"
SKIP_UPLOAD=0
SKIP_REMOTE_DEPLOY=0
SKIP_BASE_PULL=0
USE_LATEST_TAR=0

usage() {
  cat <<'EOF'
Usage: publish_release.sh [options]

Options:
  --server <user@host>          Remote SSH target
  --remote-root <path>          Remote project root, default /opt/hamster-analysis/current
  --remote-apps-dir <path>      Remote tar upload directory, default <remote-root>/apps
  --image-name <name:tag>       Application image, default autotfl-shiny-app:latest
  --bundle-prefix <prefix>      Bundle filename prefix, default autotfl-offline-bundle
  --upload-method <scp|rsync>   Upload method, default scp
  --skip-upload                 Build/save locally only
  --skip-remote-deploy          Upload but do not run remote deploy
  --skip-base-pull              Do not auto-pull missing base images
  --use-latest-tar              Skip build/save and use the latest tar file in local apps dir
  --help                        Show this help
EOF
}

log() {
  printf '[publish_release] %s\n' "$1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
    return 0
  fi

  openssl dgst -sha256 "$1" | awk '{print $NF}'
}

ensure_image() {
  local image="$1"
  if docker image inspect "$image" >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$SKIP_BASE_PULL" -eq 1 ]]; then
    echo "Missing image: $image"
    exit 1
  fi

  docker pull "$image"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --server)
      SERVER_TARGET="$2"
      shift 2
      ;;
    --remote-root)
      REMOTE_ROOT="$2"
      REMOTE_APPS_DIR="$2/apps"
      shift 2
      ;;
    --remote-apps-dir)
      REMOTE_APPS_DIR="$2"
      shift 2
      ;;
    --image-name)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --bundle-prefix)
      BUNDLE_PREFIX="$2"
      shift 2
      ;;
    --upload-method)
      UPLOAD_METHOD="$2"
      shift 2
      ;;
    --skip-upload)
      SKIP_UPLOAD=1
      shift
      ;;
    --skip-remote-deploy)
      SKIP_REMOTE_DEPLOY=1
      shift
      ;;
    --skip-base-pull)
      SKIP_BASE_PULL=1
      shift
      ;;
    --use-latest-tar)
      USE_LATEST_TAR=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ "$SKIP_UPLOAD" -eq 0 && -z "$SERVER_TARGET" ]]; then
  echo "Missing --server <user@host>"
  exit 1
fi

if [[ "$UPLOAD_METHOD" != "scp" && "$UPLOAD_METHOD" != "rsync" ]]; then
  echo "Unsupported --upload-method: $UPLOAD_METHOD"
  exit 1
fi

require_command docker
require_command ssh

if [[ "$SKIP_UPLOAD" -eq 0 && "$UPLOAD_METHOD" == "scp" ]]; then
  require_command scp
fi

if [[ "$SKIP_UPLOAD" -eq 0 && "$UPLOAD_METHOD" == "rsync" ]]; then
  require_command rsync
fi

mkdir -p "$LOCAL_APPS_DIR"

if [[ "$USE_LATEST_TAR" -eq 1 ]]; then
  # 查找本地 apps 目录下最新的 tar 包
  LATEST_TAR="$(find "$LOCAL_APPS_DIR" -maxdepth 1 -type f -name "${BUNDLE_PREFIX}*.tar" | sort | tail -n 1 || true)"
  if [[ -z "$LATEST_TAR" ]]; then
    log "错误: 启用 --use-latest-tar 但在 $LOCAL_APPS_DIR 找不到匹配的包。"
    exit 1
  fi
  BUNDLE_PATH="$LATEST_TAR"
  SHA_PATH="${BUNDLE_PATH}.sha256"
  SUMMARY_PATH="${BUNDLE_PATH}.summary.txt"
  
  log "复用本地最新离线镜像包: $BUNDLE_PATH"
  
  # 如果连 sha 或 summary 也没有，顺手补一个（一般打包时会生成）
  if [[ ! -f "$SHA_PATH" ]]; then
    SHA256_VALUE="$(hash_file "$BUNDLE_PATH")"
    printf '%s  %s\n' "$SHA256_VALUE" "$(basename "$BUNDLE_PATH")" > "$SHA_PATH"
  fi
  if [[ ! -f "$SUMMARY_PATH" ]]; then
    SIZE_BYTES="$(wc -c < "$BUNDLE_PATH" | tr -d ' ')"
    {
      printf 'bundle=%s\n' "$(basename "$BUNDLE_PATH")"
      printf 'note=generated_from_use_latest_tar\n'
      printf 'size_bytes=%s\n' "$SIZE_BYTES"
    } > "$SUMMARY_PATH"
  fi
else
  STAMP="$(date +%Y%m%d_%H%M%S)"
  BUNDLE_FILE="${BUNDLE_PREFIX}_${STAMP}.tar"
  BUNDLE_PATH="$LOCAL_APPS_DIR/$BUNDLE_FILE"
  SHA_PATH="${BUNDLE_PATH}.sha256"
  SUMMARY_PATH="${BUNDLE_PATH}.summary.txt"
  BASE_IMAGES=("postgres:14-alpine" "redis:7-alpine" "nginx:1.27-alpine")

  for image in "${BASE_IMAGES[@]}"; do
    ensure_image "$image"
  done

  log "构建应用镜像 $IMAGE_NAME"
  docker build -t "$IMAGE_NAME" "$ROOT_DIR"

  log "导出离线镜像包到 $BUNDLE_PATH (该过程可能需要几分钟，请耐心等待...)"

  # 启动一个后台监控循环，每 3 秒刷新一次文件大小
  (
    while true; do
      if [[ -f "$BUNDLE_PATH" ]]; then
        # 获取文件大小 (MB)
        size_mb=$(du -m "$BUNDLE_PATH" 2>/dev/null | awk '{print $1}')
        if [[ -n "$size_mb" ]]; then
          printf "\r\033[K[进度] 已导出: %s MB" "$size_mb"
        fi
      fi
      sleep 3
    done
  ) &
  MONITOR_PID=$!

  # 执行真正的打包命令
  docker save -o "$BUNDLE_PATH" "$IMAGE_NAME" "${BASE_IMAGES[@]}"

  # 打包完成后，杀掉监控进程并换行
  kill $MONITOR_PID 2>/dev/null || true
  wait $MONITOR_PID 2>/dev/null || true
  printf "\n"
  log "导出完成！"

  SHA256_VALUE="$(hash_file "$BUNDLE_PATH")"
  SIZE_BYTES="$(wc -c < "$BUNDLE_PATH" | tr -d ' ')"

  printf '%s  %s\n' "$SHA256_VALUE" "$(basename "$BUNDLE_PATH")" > "$SHA_PATH"

  {
    printf 'bundle=%s\n' "$(basename "$BUNDLE_PATH")"
    printf 'image=%s\n' "$IMAGE_NAME"
    printf 'created_at=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    printf 'sha256=%s\n' "$SHA256_VALUE"
    printf 'size_bytes=%s\n' "$SIZE_BYTES"
    printf 'local_apps_dir=%s\n' "$LOCAL_APPS_DIR"
    printf 'remote_root=%s\n' "$REMOTE_ROOT"
    printf 'remote_apps_dir=%s\n' "$REMOTE_APPS_DIR"
    printf 'base_images=%s\n' "${BASE_IMAGES[*]}"
  } > "$SUMMARY_PATH"

  log "摘要文件已生成: $SHA_PATH"
  log "说明文件已生成: $SUMMARY_PATH"
fi

if [[ "$SKIP_UPLOAD" -eq 1 ]]; then
  log "已跳过上传与远端部署"
  exit 0
fi

log "创建远端 apps 目录: $REMOTE_APPS_DIR"
ssh "$SERVER_TARGET" "mkdir -p '$REMOTE_ROOT' '$REMOTE_APPS_DIR'"

log "上传离线包到 $SERVER_TARGET:$REMOTE_APPS_DIR"
if [[ "$UPLOAD_METHOD" == "scp" ]]; then
  scp "$BUNDLE_PATH" "$SHA_PATH" "$SUMMARY_PATH" "$SERVER_TARGET:$REMOTE_APPS_DIR/"
else
  rsync -avP "$BUNDLE_PATH" "$SHA_PATH" "$SUMMARY_PATH" "$SERVER_TARGET:$REMOTE_APPS_DIR/"
fi

if [[ "$SKIP_REMOTE_DEPLOY" -eq 1 ]]; then
  log "已跳过远端导入与 compose 启动"
  exit 0
fi

REMOTE_BUNDLE_PATH="$REMOTE_APPS_DIR/$(basename "$BUNDLE_PATH")"

log "远端导入镜像并启动 compose"
ssh "$SERVER_TARGET" "cd '$REMOTE_ROOT' && bash deploy/alicloud/scripts/init_env.sh >/dev/null && bash deploy/alicloud/scripts/deploy_from_tar.sh '$REMOTE_BUNDLE_PATH'"
