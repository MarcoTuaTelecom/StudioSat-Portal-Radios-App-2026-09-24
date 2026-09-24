#!/usr/bin/env bash
set -Eeuo pipefail
VERSION="1.7.3"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/assets/vendor/hls.min.js}"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
URL1="https://cdn.jsdelivr.net/npm/hls.js@${VERSION}/dist/hls.min.js"
URL2="https://unpkg.com/hls.js@${VERSION}/dist/hls.min.js"
if curl -fsSL --connect-timeout 5 --max-time 60 "$URL1" -o "$TMP"; then SRC="$URL1"; elif curl -fsSL --connect-timeout 5 --max-time 60 "$URL2" -o "$TMP"; then SRC="$URL2"; else echo "FATAL=HLSJS_DOWNLOAD" >&2; exit 1; fi
SIZE="$(stat -c '%s' "$TMP")"; [[ "$SIZE" -gt 300000 ]] || { echo "FATAL=HLSJS_SIZE:$SIZE" >&2; exit 1; }
install -m 0644 "$TMP" "$OUT"
echo "HLSJS_VERSION=$VERSION"
echo "HLSJS_SOURCE=$SRC"
sha256sum "$OUT"
