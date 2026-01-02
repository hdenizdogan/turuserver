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
    echo "⚠️  Missing cert for $DOMAIN — skipping"
    continue
  fi

  mkdir -p "$DST_DIR"

  if ! cmp -s "$SRC_CERT" "$DST_DIR/fullchain.pem" 2>/dev/null || \
     ! cmp -s "$SRC_KEY" "$DST_DIR/privkey.pem" 2>/dev/null; then

    cp "$SRC_CERT" "$DST_DIR/fullchain.pem"
    cp "$SRC_KEY" "$DST_DIR/privkey.pem"

    chmod 644 "$DST_DIR/fullchain.pem"
    chmod 600 "$DST_DIR/privkey.pem"

    echo "✅ Updated cert for $DOMAIN"
    UPDATED=1
  fi
done < "$MAP_FILE"

if [ "$UPDATED" -eq 1 ]; then
  echo "🔄 Restarting NPM container"
  docker restart "$NPM_CONTAINER"
else
  echo "ℹ️  No certificate changes detected"
fi