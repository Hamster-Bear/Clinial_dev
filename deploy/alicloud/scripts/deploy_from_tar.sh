#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <image_tar_path>"
  exit 1
fi

IMAGE_TAR="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="$ROOT_DIR/deploy/alicloud/env/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE"
  exit 1
fi

docker load -i "$IMAGE_TAR"
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.server.yml" up -d --pull never
docker compose --env-file "$ENV_FILE" -f "$ROOT_DIR/docker-compose.server.yml" ps
