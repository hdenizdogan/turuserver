#!/bin/sh
set -e

# === Hardcoded container name ===
NPM_CONTAINER="npm"

# === Resolve script directory ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# === Load environment ===
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌ Missing .env file at $ENV_FILE"
  exit 1
fi

# shellcheck disable=SC1090
. "$ENV_FILE"

# === Validate required vars ===
: "${TSD_BASE:?TSD_BASE not set in .env}"
: "${NPM_BASE:?NPM_BASE not set in .env}"

MAP_FILE="$SCRIPT_DIR/npm-tsdproxy-map.conf"

UPDATED=0

while IFS='=' read -r DOMAIN NPM_ID; do
  [ -z "$DOMAIN" ] && continue

  SERVICE="${DOMAIN%%.*}"
  SRC_DIR="$TSD_BASE/$SERVICE/certs"

  SRC_CERT="$SRC_DIR/$DOMAIN.crt"
  SRC_KEY="$SRC_DIR/$DOMAIN.key"

  DST_DIR="$NPM_BASE/$NPM_ID"

  if [ ! -f "$SRC_CERT" ] || [ ! -f "$SRC_KEY" ]; then
    echo "⚠️  Missi
