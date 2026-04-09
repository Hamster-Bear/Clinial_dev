#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_DIR="$ROOT_DIR/deploy/alicloud/env"
EXAMPLE_FILE="$ENV_DIR/.env.example"
TARGET_FILE="$ENV_DIR/.env"
APPS_DIR="$ROOT_DIR/apps"

mkdir -p "$ENV_DIR"
mkdir -p "$APPS_DIR"

if [[ ! -f "$TARGET_FILE" ]]; then
  cp "$EXAMPLE_FILE" "$TARGET_FILE"
fi

if grep -q "__CHANGE_ME_DB_PASSWORD__" "$TARGET_FILE"; then
  DB_PASSWORD="$(openssl rand -base64 24 | tr -d '\n')"
  sed -i "s|__CHANGE_ME_DB_PASSWORD__|$DB_PASSWORD|g" "$TARGET_FILE"
fi

echo "$TARGET_FILE"
