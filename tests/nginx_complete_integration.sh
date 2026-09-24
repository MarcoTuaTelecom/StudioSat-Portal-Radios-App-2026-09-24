#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; TMP="$(mktemp -d)"; HP=18080; SP=18443; MP=18888
cleanup(){ [[ -f "$TMP/nginx.pid" ]]&&nginx -s stop -c "$TMP/nginx.conf" -p "$TMP" >/dev/null 2>&1||true; [[ -n "${MOCK_PID:-}" ]]&&kill "$MOCK_PID" 2>/dev/null||true; rm -rf "$TMP"; }; trap cleanup EXIT
for c in nginx openssl curl python3; do command -v "$c" >/dev/null|| {  echo FATAL=MISSING:$c; exit 1; };done
mkdir -p "$TMP/site"; cp -a "$ROOT/portal" "$ROOT/listen" "$ROOT/app" "$ROOT/assets" "$TMP/site/"
openssl req -x509 -nodes -newkey rsa:2048 -days 1 -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -subj '/CN=radio.studiosatweb.com.br' >/dev/null 2>&1
cat >"$TMP/mock.py" <<'PY'
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
 def do_GET(self):
  if self.path.endswith('.m3u8'): b=b'#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n#EXT-X-MEDIA-SEQUENCE:1\n#EXTINF:2.0,\nseg.ts\n'; typ='application/vnd.apple.mpegurl'
  elif self.path.endswith('.ts'): b=b'FAKE_TS_SEGMENT'; typ='video/mp2t'
  else: b=b'not found'; typ='text/plain'
  self.send_response(200 if self.path.endswith(('.m3u8','.ts')) else 404); self.send_header('Content-Type',typ); self.end_headers(); self.wfile.write(b)
 def log_message(self,*a): pass
ThreadingHTTPServer(('127.0.0.1',18888),H).serve_forever()
PY
python3 "$TMP/mock.py" & MOCK_PID=$!
python3 - "$ROOT/nginx/studiosat-radio-complete.conf" "$TMP/vhost.conf" "$TMP" "$HP" "$SP" "$MP" <<'PY'
import sys
src,dst,tmp,hp,sp,mp=sys.argv[1:]; s=open(src).read()
s=s.replace('listen 80;',f'listen {hp};').replace('listen [::]:80;','').replace('listen 443 ssl;',f'listen {sp} ssl;').replace('listen [::]:443 ssl;','')
s=s.replace('/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem',tmp+'/cert.pem').replace('/etc/letsencrypt/live/studiosatweb-completo/privkey.pem',tmp+'/key.pem')
s=s.replace('/var/www/studiosat-radio-site',tmp+'/site').replace('127.0.0.1:8888','127.0.0.1:'+mp)
open(dst,'w').write(s)
PY
mkdir -p "$TMP/stale"; echo '<title>Studio Sat Web - Em construção</title>' > "$TMP/stale/index.html"
cat >"$TMP/wild.conf" <<EOF
server { listen $SP ssl; server_name *.studiosatweb.com.br; ssl_certificate $TMP/cert.pem; ssl_certificate_key $TMP/key.pem; root $TMP/stale; location / { try_files \$uri /index.html; } }
EOF
cat >"$TMP/nginx.conf" <<EOF
worker_processes 1; pid $TMP/nginx.pid; events { worker_connections 256; } http { include /etc/nginx/mime.types; error_log $TMP/error.log notice; access_log off; include $TMP/wild.conf; include $TMP/vhost.conf; }
EOF
nginx -t -c "$TMP/nginx.conf" -p "$TMP"; nginx -c "$TMP/nginx.conf" -p "$TMP"; sleep .4
main=(radio.studiosatweb.com.br www.radio.studiosatweb.com.br)
stations=(radioprincipal radiopop radiorock radioclassicas radiocountry)
for h in "${main[@]}"; do b="$TMP/b"; c=$(curl -ksS --resolve "$h:$SP:127.0.0.1" -o "$b" -w '%{http_code}' "https://$h:$SP/"); [[ "$c" == 200 ]]&&grep -Fq '<title>Studio Sat Rádio</title>' "$b"&&!grep -qi 'Em construção' "$b"|| { echo FATAL=PORTAL:$h:$c;exit 1; }; done
for s in "${stations[@]}"; do for h in "$s.studiosatweb.com.br" "www.$s.studiosatweb.com.br"; do b="$TMP/b"; c=$(curl -ksS --resolve "$h:$SP:127.0.0.1" -o "$b" -w '%{http_code}' "https://$h:$SP/"); [[ "$c" == 200 ]]&&grep -Fq '<title>Radio Studio Sat</title>' "$b"|| { echo FATAL=APP_HOST:$h:$c;exit 1; }; done; done
for path in /listen/ /listen/manifest.webmanifest /listen/sw.js /app/ /assets/content.json /assets/ref/hero-v5.webp /assets/ref/program-1-v5.webp; do c=$(curl -ksS --resolve "radio.studiosatweb.com.br:$SP:127.0.0.1" -o /dev/null -w '%{http_code}' "https://radio.studiosatweb.com.br:$SP$path"); [[ "$c" == 200 ]]|| { echo FATAL=ROUTE:$path:$c;exit 1; }; done
for s in "${stations[@]}"; do f="$TMP/$s.m3u8"; c=$(curl -ksS --resolve "radio.studiosatweb.com.br:$SP:127.0.0.1" -o "$f" -w '%{http_code}' "https://radio.studiosatweb.com.br:$SP/$s/index.m3u8"); [[ "$c" == 200 ]]&&grep -q '^#EXTM3U' "$f"|| { echo FATAL=HLS:$s:$c;exit 1; }; c=$(curl -ksS --resolve "radio.studiosatweb.com.br:$SP:127.0.0.1" -o /dev/null -w '%{http_code}' "https://radio.studiosatweb.com.br:$SP/$s/seg.ts"); [[ "$c" == 200 ]]|| { echo FATAL=SEG:$s:$c;exit 1; }; done
hdr="$TMP/h"; curl -ksS --resolve "radio.studiosatweb.com.br:$SP:127.0.0.1" -D "$hdr" -o /dev/null "https://radio.studiosatweb.com.br:$SP/"; grep -Eiq '^Cache-Control:.*no-store' "$hdr"|| { echo FATAL=CACHE;exit 1; }
echo NGINX_INTEGRATION=PASS; echo PORTAL_HOSTS=2/2; echo STATION_APP_HOSTS=10/10; echo APP_ROUTES=PASS; echo HLS_PROXY=5/5; echo STALE_WILDCARD_OVERRIDDEN=PASS
