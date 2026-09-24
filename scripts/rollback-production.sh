#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "FATAL=EXECUTE_COMO_ROOT" >&2; exit 1; }

DIR="${1:-}"
[[ -d "$DIR" ]] || {
  echo "uso: $0 /var/backups/studiosat/PORTAL-APP-PRODUCTION/<timestamp>" >&2
  exit 2
}

PORTAL="/var/www/studiosat-radio-portal"
PLAYER="/var/www/studiosat-radio-player"
APP="/var/www/studiosat-radio-app"
ASSETS="/var/www/studiosat-radio-assets"
NEW_CONF="/etc/nginx/conf.d/20-studiosat-radio-clean.conf"
OLD_CONF="/etc/nginx/conf.d/studiosat-radio-v2.conf"

[[ -d "$DIR/var-www" && -d "$DIR/nginx" ]] || {
  echo "FATAL=BACKUP_FORMAT_INVALID" >&2
  exit 1
}

rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
  [[ -e "$DIR/var-www/$d" ]] && cp -a "$DIR/var-www/$d" "/var/www/$d"
done

rm -f "$NEW_CONF" "$OLD_CONF"
[[ -f "$DIR/nginx/20-studiosat-radio-clean.conf" ]] &&
  cp -a "$DIR/nginx/20-studiosat-radio-clean.conf" "$NEW_CONF"
[[ -f "$DIR/nginx/studiosat-radio-v2.conf" ]] &&
  cp -a "$DIR/nginx/studiosat-radio-v2.conf" "$OLD_CONF"

nginx -t
systemctl reload nginx
systemctl is-active --quiet nginx

echo "ROLLBACK_PRODUCTION=PASS"
echo "BACKUP_DIR=$DIR"
echo "ONLY_SERVICE_OPERATION=NGINX_RELOAD"
