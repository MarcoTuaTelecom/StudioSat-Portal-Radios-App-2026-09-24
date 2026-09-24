#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
HTTP_PORT=18080
HTTPS_PORT=18443
PIDFILE="$TMP/nginx.pid"

cleanup(){
  if [[ -f "$PIDFILE" ]]; then
    nginx -s stop -c "$TMP/nginx.conf" -p "$TMP" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT

for c in nginx openssl curl python3 grep sed; do
  command -v "$c" >/dev/null 2>&1 || { echo "FATAL=MISSING:$c" >&2; exit 1; }
done

openssl req -x509 -nodes -newkey rsa:2048 -days 1   -keyout "$TMP/key.pem" -out "$TMP/cert.pem"   -subj '/CN=radio.studiosatweb.com.br' >/dev/null 2>&1

python3 - "$ROOT/nginx/studiosat-radio-clean.conf" "$TMP/vhost.conf" "$ROOT" "$TMP" "$HTTP_PORT" "$HTTPS_PORT" <<'PY'
import sys
src,dst,root,tmp,http,https=sys.argv[1:]
s=open(src,encoding='utf-8').read()
repls={
 'listen 80;':f'listen {http};',
 'listen [::]:80;':f'listen [::]:{http};',
 'listen 443 ssl;':f'listen {https} ssl;',
 'listen [::]:443 ssl;':f'listen [::]:{https} ssl;',
 '/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem':f'{tmp}/cert.pem',
 '/etc/letsencrypt/live/studiosatweb-completo/privkey.pem':f'{tmp}/key.pem',
 '/var/www/studiosat-radio-player':f'{root}/player',
 '/var/www/studiosat-radio-portal':f'{root}/portal',
 '/var/www/studiosat-radio-app':f'{root}/app',
 '/var/www/studiosat-radio-assets':f'{root}/assets',
 'return 302 https://radio.studiosatweb.com.br/app/;':f'return 302 https://radio.studiosatweb.com.br:{https}/app/;',
}
for a,b in repls.items(): s=s.replace(a,b)
# Isolated test does not depend on host IPv6 availability.
s='\n'.join(line for line in s.splitlines() if 'listen [::]:' not in line)+'\n'
open(dst,'w',encoding='utf-8').write(s)
PY

mkdir -p "$TMP/stale"
printf '%s\n' '<h1>Studio Sat Web - Em construção</h1>' > "$TMP/stale/index.html"

cat > "$TMP/wildcard.conf" <<EOF
server {
  listen $HTTPS_PORT ssl;
  server_name *.studiosatweb.com.br studiosatweb.com.br;
  ssl_certificate $TMP/cert.pem;
  ssl_certificate_key $TMP/key.pem;
  root $TMP/stale;
  index index.html;
  location / { try_files \\$uri \\$uri/ /index.html; }
}
EOF

cat > "$TMP/nginx.conf" <<EOF
worker_processes 1;
pid $PIDFILE;
events { worker_connections 128; }
http {
  include /etc/nginx/mime.types;
  access_log $TMP/access.log;
  error_log $TMP/error.log notice;
  include $TMP/wildcard.conf;
  include $TMP/vhost.conf;
}
EOF

nginx -t -c "$TMP/nginx.conf" -p "$TMP"
nginx -c "$TMP/nginx.conf" -p "$TMP"
sleep 0.3

HOSTS=(
  radio.studiosatweb.com.br
  www.radio.studiosatweb.com.br
  radioprincipal.studiosatweb.com.br
  www.radioprincipal.studiosatweb.com.br
  radiopop.studiosatweb.com.br
  www.radiopop.studiosatweb.com.br
  radiorock.studiosatweb.com.br
  www.radiorock.studiosatweb.com.br
  radioclassicas.studiosatweb.com.br
  www.radioclassicas.studiosatweb.com.br
  radiocountry.studiosatweb.com.br
  www.radiocountry.studiosatweb.com.br
)

for host in "${HOSTS[@]}"; do
  body="$TMP/body"
  headers="$TMP/headers"
  code="$(curl -ksS --resolve "${host}:${HTTPS_PORT}:127.0.0.1"     -D "$headers" -o "$body" -w '%{http_code}'     "https://${host}:${HTTPS_PORT}/")"
  [[ "$code" == "200" ]] || { echo "FATAL=HOST:$host:$code" >&2; exit 1; }
  if [[ "$host" == www.* ]]; then
    grep -Fq '<title>Rádio Studio Sat</title>' "$body" || { echo "FATAL=PORTAL_TITLE:$host" >&2; exit 1; }
  else
    grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" || { echo "FATAL=PLAYER_TITLE:$host" >&2; exit 1; }
  fi
  ! grep -aEqi 'Em constru|construÃ|ConstruÃ|Studio Sat Web - Em' "$body" || { echo "FATAL=STALE_CONSTRUCTION:$host" >&2; exit 1; }
done

for path in   /app/   /manifest.webmanifest   /sw.js   /assets/js/stations.js   /assets/js/hls-controller.js   /assets/css/base.css   /assets/css/player.css   /assets/icons/icon.svg   /assets/icons/icon-192.png   /assets/icons/icon-512.png
do
  code="$(curl -ksS --resolve "radio.studiosatweb.com.br:${HTTPS_PORT}:127.0.0.1"     -o "$TMP/asset" -w '%{http_code}'     "https://radio.studiosatweb.com.br:${HTTPS_PORT}${path}")"
  [[ "$code" == "200" ]] || { echo "FATAL=ASSET:$path:$code" >&2; exit 1; }
done

headers="$TMP/app.headers"
curl -ksS --resolve "radio.studiosatweb.com.br:${HTTPS_PORT}:127.0.0.1"   -D "$headers" -o "$TMP/app.body"   "https://radio.studiosatweb.com.br:${HTTPS_PORT}/app/"
grep -Eiq '^Cache-Control:.*no-store' "$headers" || { echo "FATAL=APP_CACHE_POLICY" >&2; exit 1; }
grep -Fq 'Central de instalação' "$TMP/app.body" || { echo "FATAL=APP_BODY" >&2; exit 1; }

headers="$TMP/root.headers"
curl -ksS --resolve "radio.studiosatweb.com.br:${HTTPS_PORT}:127.0.0.1"   -D "$headers" -o /dev/null   "https://radio.studiosatweb.com.br:${HTTPS_PORT}/"
grep -Eiq '^Cache-Control:.*no-store' "$headers" || { echo "FATAL=PLAYER_CACHE_POLICY" >&2; exit 1; }

headers="$TMP/redirect.headers"
curl -ksS --resolve "www.radio.studiosatweb.com.br:${HTTPS_PORT}:127.0.0.1"   -D "$headers" -o /dev/null   "https://www.radio.studiosatweb.com.br:${HTTPS_PORT}/app/"
grep -Eiq "^Location: https://radio\.studiosatweb\.com\.br:${HTTPS_PORT}/app/" "$headers" || { echo "FATAL=APP_CANONICAL_REDIRECT" >&2; cat "$headers"; exit 1; }

echo "NGINX_INTEGRATION=PASS"
echo "HOSTS=12/12"
echo "APP_ROUTE=200"
echo "PWA_ASSETS=PASS"
echo "EXACT_HOSTS_OVERRIDE_WILDCARD=PASS"
echo "STALE_PAGE=ABSENT"
echo "NO_STORE_HTML=PASS"
