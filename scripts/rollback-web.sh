#!/usr/bin/env bash
set -Eeuo pipefail
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo FATAL=ROOT >&2; exit 1; }
DIR="${1:-}"
[[ -d "$DIR" ]] || { echo "uso: $0 /var/backups/studiosat/WEB-ROLLBACK/<timestamp>" >&2; exit 2; }
PORTAL=/var/www/studiosat-radio-portal; PLAYER=/var/www/studiosat-radio-player; APP=/var/www/studiosat-radio-app; ASSETS=/var/www/studiosat-radio-assets
CONF=/etc/nginx/conf.d/20-studiosat-radio-clean.conf; OLD_CONF=/etc/nginx/conf.d/studiosat-radio-v2.conf; OLD_SNIP=/etc/nginx/snippets/studiosat-radio-hls-v2.conf; SHARED=/etc/nginx/sites-available/studiosat
rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do [[ -e "$DIR/var-www/$d" ]] && cp -a "$DIR/var-www/$d" "/var/www/$d"; done
rm -f "$CONF" "$OLD_CONF" "$OLD_SNIP"
[[ -f "$DIR/nginx/20-studiosat-radio-clean.conf" ]] && cp -a "$DIR/nginx/20-studiosat-radio-clean.conf" "$CONF"
[[ -f "$DIR/nginx/studiosat-radio-v2.conf" ]] && cp -a "$DIR/nginx/studiosat-radio-v2.conf" "$OLD_CONF"
[[ -f "$DIR/nginx/studiosat-radio-hls-v2.conf" ]] && cp -a "$DIR/nginx/studiosat-radio-hls-v2.conf" "$OLD_SNIP"
[[ -f "$DIR/nginx/sites-available-studiosat" ]] && cp -a "$DIR/nginx/sites-available-studiosat" "$SHARED"
nginx -t
systemctl reload nginx
systemctl is-active --quiet nginx
echo ROLLBACK_WEB=PASS
