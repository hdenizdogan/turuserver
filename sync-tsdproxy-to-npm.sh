#!/bin/sh
set -eu

# ===============================
# Load environment
# ===============================
ENV_FILE="./.env"
MAP_FILE="./npm-tsdproxy-map.conf"

[ -f "$ENV_FILE" ] || exit 1
[ -f "$MAP_FILE" ] || exit 1

. "$ENV_FILE"

# Required vars from .env
: "${TSD_BASE:?Missing TSD_BASE}"
: "${NPM_BASE:?Missing NPM_BASE}"

# Hardcoded NPM container name (as requested)
NPM_CONTAINER="npm"

changed=0

# ===============================
# Iterate mappings
# ===============================
while IFS='=' read -r SERVICE NPM_ID; do
  # skip empty lines / comments
  [ -z "$SERVICE" ] && continue
  echo "$SERVICE" | grep -q '^#' && continue

  SRC_DIR="$TSD_BASE/$SERVICE/certs"

  # tsdproxy cert naming
  SRC_CERT="$(ls "$SRC_DIR"/*.crt 2>/dev/null | head -n1 || true)"
  SRC_KEY="$(ls "$SRC_DIR"/*.key 2>/dev/null | head -n1 || true)"

  [ -f "$SRC_CERT" ] || continue
  [ -f "$SRC_KEY" ] || continue

  DST_DIR="$NPM_BASE/custom_ssl/$NPM_ID"
  DST_CERT="$DST_DIR/fullchain.pem"
  DST_KEY="$DST_DIR/privkey.pem"

  mkdir -p "$DST_DIR"

  # Compare certs
  if [ ! -f "$DST_CERT" ] || ! cmp -s "$SRC_CERT" "$DST_CERT" || ! cmp -s "$SRC_KEY" "$DST_KEY"; then
    cp "$SRC_CERT" "$DST_CERT"
    cp "$SRC_KEY" "$DST_KEY"
    chmod 644 "$DST_CERT"
    chmod 600 "$DST_KEY"
    changed=1
  fi

done < "$MAP_FILE"

# ===============================
# Reload NPM if needed
# ===============================
if [ "$changed" -eq 1 ]; then
  docker exec "$NPM_CONTAINER" nginx -s reload >/dev/null 2>&1 || true
fi

exit 0
