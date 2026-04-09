#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/alicloud/env/.env"
APPS_DIR="${APPS_DIR:-$ROOT_DIR/apps}"

resolve_tar_path() {
  local input="${1:-}"
  local latest_tar=""

  if [[ -z "$input" ]]; then
    latest_tar="$(find "$APPS_DIR" -maxdepth 1 -type f -name "*.tar" | sort | tail -n 1 || true)"
    if [[ -n "$latest_tar" ]]; then
      printf '%s\n' "$latest_tar"
      return 0
    fi
    return 1
  fi

  if [[ -f "$input" ]]; then
    printf '%s\n' "$input"
    return 0
  fi

  if [[ -f "$ROOT_DIR/$input" ]]; then
    printf '%s\n' "$ROOT_DIR/$input"
    return 0
  fi

  if [[ -f "$APPS_DIR/$input" ]]; then
    printf '%s\n' "$APPS_DIR/$input"
    return 0
  fi

  return 1
}

mkdir -p "$APPS_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

IMAGE_TAR="$(resolve_tar_path "${1:-}")" || {
  echo "Usage: $0 <image_tar_path_or_basename>"
  echo "No tar file found in $APPS_DIR"
  exit 1
}

docker load -i "$IMAGE_TAR"
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.server.yml" up -d --pull never
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.server.yml" ps
