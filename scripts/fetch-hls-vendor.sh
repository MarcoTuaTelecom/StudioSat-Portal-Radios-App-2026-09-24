#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.7.3"
EXPECTED_SHA256="a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/assets/vendor/hls.min.js}"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

URLS=(
  "https://cdn.jsdelivr.net/npm/hls.js@${VERSION}/dist/hls.min.js"
  "https://unpkg.com/hls.js@${VERSION}/dist/hls.min.js"
)

SRC=""
for url in "${URLS[@]}"; do
  if curl -fsSL --connect-timeout 5 --max-time 60 "$url" -o "$TMP"; then
    ACTUAL="$(sha256sum "$TMP" | awk '{print $1}')"
    if [[ "$ACTUAL" == "$EXPECTED_SHA256" ]]; then
      SRC="$url"
      break
    fi
    echo "WARN=HLSJS_SHA_MISMATCH SOURCE=$url ACTUAL=$ACTUAL" >&2
  fi
done

[[ -n "$SRC" ]] || {
  echo "FATAL=HLSJS_VERIFIED_DOWNLOAD_FAILED EXPECTED_SHA256=$EXPECTED_SHA256" >&2
  exit 1
}

SIZE="$(stat -c '%s' "$TMP")"
[[ "$SIZE" -gt 300000 ]] || {
  echo "FATAL=HLSJS_SIZE:$SIZE" >&2
  exit 1
}

install -m 0644 "$TMP" "$OUT"

FINAL="$(sha256sum "$OUT" | awk '{print $1}')"
[[ "$FINAL" == "$EXPECTED_SHA256" ]] || {
  echo "FATAL=HLSJS_POST_INSTALL_SHA:$FINAL" >&2
  exit 1
}

echo "HLSJS_VERSION=$VERSION"
echo "HLSJS_SOURCE=$SRC"
echo "HLSJS_SHA256=$FINAL"
