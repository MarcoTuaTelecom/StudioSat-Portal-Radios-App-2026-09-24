#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo FATAL=ROOT >&2; exit 1; }
TS="$(date -u +%Y%m%dT%H%M%SZ)"; DEST="/var/backups/studiosat/WEB-PRE-DEPLOY/$TS"; mkdir -p "$DEST"; chmod 0700 "$DEST"
paths=(); for p in /etc/nginx /var/www/studiosat-radio-portal /var/www/studiosat-radio-player /var/www/studiosat-radio-app /var/www/studiosat-radio-assets; do [[ -e "$p" ]] && paths+=("$p"); done
[[ ${#paths[@]} -gt 0 ]] || { echo FATAL=NOTHING_TO_BACKUP >&2; exit 1; }
tar --xattrs --acls --numeric-owner -czpf "$DEST/web-pre-deploy-$TS.tar.gz" "${paths[@]}"
tar -tzf "$DEST/web-pre-deploy-$TS.tar.gz" >/dev/null
sha256sum "$DEST/web-pre-deploy-$TS.tar.gz" | tee "$DEST/SHA256SUMS.txt"
nginx -T > "$DEST/nginx-T.txt" 2>&1 || true
echo "BACKUP=$DEST/web-pre-deploy-$TS.tar.gz"
