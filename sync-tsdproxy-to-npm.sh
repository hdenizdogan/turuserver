#!/bin/sh
set -e

# === Hardcoded NPM container name ===
NPM_CONTAINER="npm"

# === Resolve script directory ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# === Load environment ===
ENV_FILE="$SCRIPT_DIR/.env"
MAP_FILE="$SCRIPT_DIR/npm-tsdproxy-map.conf"

[ -f "$ENV_FILE" ] || { echo "❌ Missing .env file"; exit 1; }
[ -f "$MAP_FILE" ] || { echo "❌ Missing npm-tsdproxy-map.conf"; exit 1; }

. "$ENV_FILE"

: "${TSD_BASE:?TSD_BASE not set}"
: "${NPM_BASE:?NPM_BASE not set}"

UPDATED=0

while IFS='=' read -r SERVICE NPM_ID || [ -n "$SERVICE" ]; do
  [ -z "$SERVICE" ] && continue

  case "$SERVICE" in
    \#*) continue ;;
  esac

  SRC_DIR="$TSD_BASE/$SERVICE/certs"

  SRC_CERT="$(ls "$SRC_DIR"/*.crt 2>/dev/null | head -n1 || true)"
  SRC_KEY="$(ls "$SRC_DIR"/*.key 2>/dev/null | head -n1 || true)"

  if [ ! -f "$SRC_CERT" ] || [ ! -f "$SRC_KEY" ]; then
    echo "⚠️  Missing cert for $SERVICE — skipping"
    continue
  fi

  DST_DIR="$NPM_BASE/custom_ssl/$NPM_ID"
  DST_CERT="$DST_DIR/fullchain.pem"
  DST_KEY="$DST_DIR/privkey.pem"

  mkdir -p "$DST_DIR"

  if ! cmp -s "$SRC_CERT" "$DST_CERT" 2>/dev/null || \
     ! cmp -s "$SRC_KEY" "$DST_KEY" 2>/dev/null; then

    cp "$SRC_CERT" "$DST_CERT"
    cp "$SRC_KEY" "$DST_KEY"

    chmod 644 "$DST_CERT"
    chmod 600 "$DST_KEY"

    echo "✅ Updated cert for $SERVICE"
    UPDATED=1
  fi

done < "$MAP_FILE"

if [ "$UPDATED" -eq 1 ]; then
  echo "🔄 Restarting NPM container"
  docker restart "$NPM_CONTAINER"
else
  echo "ℹ️  No certificate changes detected"
fi