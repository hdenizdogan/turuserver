#!/bin/sh
set -eu

log() {
  [ "${VERBOSE:-0}" = "1" ] && echo "$@"
}

info() {
  echo "$@"
}

ENV_FILE="./.env"
MAP_FILE="./npm-tsdproxy-map.conf"

[ -f "$ENV_FILE" ] || { echo "❌ Missing .env"; exit 1; }
[ -f "$MAP_FILE" ] || { echo "❌ Missing npm-tsdproxy-map.conf"; exit 1; }

. "$ENV_FILE"

: "${TSD_BASE:?Missing TSD_BASE}"
: "${NPM_BASE:?Missing NPM_BASE}"

NPM_CONTAINER="npm"
changed=0

while IFS='=' read -r SERVICE NPM_ID || [ -n "$SERVICE" ]; do
  [ -z "$SERVICE" ] && continue

  case "$SERVICE" in
    \#*) continue ;;
  esac

  SRC_DIR="$TSD_BASE/$SERVICE/certs"
  SRC_CERT="$(ls "$SRC_DIR"/*.crt 2>/dev/null | head -n1 || true)"
  SRC_KEY="$(ls "$SRC_DIR"/*.key 2>/dev/null | head -n1 || true)"

  if [ ! -f "$SRC_CERT" ] || [ ! -f "$SRC_KEY" ]; then
    log "⚠️  Missing cert for $SERVICE"
    continue
  fi

  DST_DIR="$NPM_BASE/custom_ssl/$NPM_ID"
  DST_CERT="$DST_DIR/fullchain.pem"
  DST_KEY="$DST_DIR/privkey.pem"

  mkdir -p "$DST_DIR"

  if [ ! -f "$DST_CERT" ] \
     || ! cmp -s "$SRC_CERT" "$DST_CERT" \
     || ! cmp -s "$SRC_KEY" "$DST_KEY"; then
    log "🔄 Updating certificate for $SERVICE"
    cp "$SRC_CERT" "$DST_CERT"
    cp "$SRC_KEY" "$DST_KEY"
    chmod 644 "$DST_CERT"
    chmod 600 "$DST_KEY"
    changed=1
  else
    log "✅ $SERVICE unchanged"
  fi
done < "$MAP_FILE"

if [ "$changed" -eq 1 ]; then
  info "♻️  Reloading NPM"
  docker exec "$NPM_CONTAINER" nginx -s reload >/dev/null 2>&1 || true
else
  info "ℹ️  No certificate changes detected"
fi

exit 0