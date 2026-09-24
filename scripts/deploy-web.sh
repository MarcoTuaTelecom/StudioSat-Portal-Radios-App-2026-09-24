#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo FATAL=ROOT >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="/root/2026-09-24-STUDIOSAT-PORTAL-APP-DEPLOY-$TS.txt"
exec > >(tee "$LOG") 2>&1

PORTAL=/var/www/studiosat-radio-portal
PLAYER=/var/www/studiosat-radio-player
APP=/var/www/studiosat-radio-app
ASSETS=/var/www/studiosat-radio-assets
CONF=/etc/nginx/conf.d/20-studiosat-radio-clean.conf
OLD_CONF=/etc/nginx/conf.d/studiosat-radio-v2.conf
OLD_SNIP=/etc/nginx/snippets/studiosat-radio-hls-v2.conf
SHARED=/etc/nginx/sites-available/studiosat
MEDIAMTX=studiosat-mediamtx.service
CERT=/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem
KEY=/etc/letsencrypt/live/studiosatweb-completo/privkey.pem
PATHS=(radioprincipal radiopop radiorock radioclassicas radiocountry)
HOSTS=(radio.studiosatweb.com.br www.radio.studiosatweb.com.br radioprincipal.studiosatweb.com.br www.radioprincipal.studiosatweb.com.br radiopop.studiosatweb.com.br www.radiopop.studiosatweb.com.br radiorock.studiosatweb.com.br www.radiorock.studiosatweb.com.br radioclassicas.studiosatweb.com.br www.radioclassicas.studiosatweb.com.br radiocountry.studiosatweb.com.br www.radiocountry.studiosatweb.com.br)
ROLLBACK="/var/backups/studiosat/WEB-ROLLBACK/$TS"
STAGE="/var/www/.studiosat-web-stage-$TS"
HLS_TMP="/run/studiosat-hls-${TS}.min.js"
MUTATED=0
COMMITTED=0

section(){ printf '\n================================================================\n%s\n================================================================\n' "$*"; }
die(){ echo "FATAL=$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "MISSING:$1"; }

restore_web(){
  [[ "$MUTATED" -eq 1 ]] || return 0
  [[ "$COMMITTED" -eq 0 ]] || return 0
  echo "ROLLBACK=AUTO_START"
  rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
  for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
    [[ -e "$ROLLBACK/var-www/$d" ]] && cp -a "$ROLLBACK/var-www/$d" "/var/www/$d"
  done
  rm -f "$CONF" "$OLD_CONF" "$OLD_SNIP"
  [[ -f "$ROLLBACK/nginx/20-studiosat-radio-clean.conf" ]] && cp -a "$ROLLBACK/nginx/20-studiosat-radio-clean.conf" "$CONF"
  [[ -f "$ROLLBACK/nginx/studiosat-radio-v2.conf" ]] && cp -a "$ROLLBACK/nginx/studiosat-radio-v2.conf" "$OLD_CONF"
  [[ -f "$ROLLBACK/nginx/studiosat-radio-hls-v2.conf" ]] && cp -a "$ROLLBACK/nginx/studiosat-radio-hls-v2.conf" "$OLD_SNIP"
  [[ -f "$ROLLBACK/nginx/sites-available-studiosat" ]] && cp -a "$ROLLBACK/nginx/sites-available-studiosat" "$SHARED"
  if nginx -t; then systemctl reload nginx || true; fi
  echo "ROLLBACK=AUTO_DONE"
}
on_exit(){ rc=$?; trap - EXIT ERR; if ((rc!=0)); then restore_web; fi; rm -rf "$STAGE" 2>/dev/null || true; rm -f "$HLS_TMP" 2>/dev/null || true; exit "$rc"; }
trap on_exit EXIT
trap 'echo "ERROR_LINE=${BASH_LINENO[0]:-unknown}"' ERR

section "0. ESCOPO"
cat <<'EOF'
Instala SOMENTE portal/player/app/assets e camada Nginx das rádios.
Não instala nem altera qualquer mecanismo de playout.
Não instala Liquidsoap.
Não altera RadioBOSS, DNS, firewall ou serviços de TV.
MediaMTX não é reiniciado; apenas precisa estar ativo como backend HLS.
EOF

for c in nginx systemctl python3 curl grep sed awk sha256sum tar find stat cp rm install readlink openssl getent; do need "$c"; done

section "1. PREFLIGHT WEB/CORE"
nginx -t
systemctl is-active --quiet nginx || die NGINX_NOT_ACTIVE
systemctl is-active --quiet "$MEDIAMTX" || die MEDIAMTX_NOT_ACTIVE
[[ -r "$CERT" && -r "$KEY" ]] || die TLS_FILES_MISSING
for host in "${HOSTS[@]}"; do openssl x509 -in "$CERT" -noout -text | grep -Fq "DNS:$host" || die "TLS_SAN_MISSING:$host"; done
[[ -f "$SHARED" ]] || die SHARED_NGINX_MISSING
for f in "$ROOT/portal/index.html" "$ROOT/player/index.html" "$ROOT/player/manifest.webmanifest" "$ROOT/player/sw.js" "$ROOT/app/index.html" "$ROOT/nginx/studiosat-radio-clean.conf"; do [[ -s "$f" ]] || die "MISSING:$f"; done
python3 "$ROOT/tests/validate_project.py"

section "2. BACKUP COMPLETO OBRIGATORIO — ANTES DE QUALQUER MUTACAO"
BACKUP_OUT="$(bash "$ROOT/scripts/backup-ns1-complete.sh")"
echo "$BACKUP_OUT"
grep -q '^FULL_BACKUP=PASS$' <<<"$BACKUP_OUT" || die FULL_BACKUP_FAILED
BACKUP_PATH="$(awk -F= '/^BACKUP=/{print substr($0,index($0,"=")+1)}' <<<"$BACKUP_OUT" | tail -1)"
[[ -s "$BACKUP_PATH" ]] || die BACKUP_FILE_NOT_FOUND

section "3. HLS.JS OFICIAL 1.7.3 EM TEMP — CHECKOUT NAO E ALTERADO"
bash "$ROOT/scripts/fetch-hls-vendor.sh" "$HLS_TMP"
SIZE="$(stat -c '%s' "$HLS_TMP")"
(( SIZE > 300000 )) || die "HLS_VENDOR_NOT_PRODUCTION:$SIZE"
sha256sum "$HLS_TMP"

section "4. ANALISE DE CONFLITOS NGINX"
mkdir -p "$ROLLBACK"
chmod 0700 "$ROLLBACK"
python3 - "$SHARED" "$ROLLBACK/shared.patched" <<'PY'
import sys
src,dst=sys.argv[1:]
s=open(src,encoding='utf-8').read()
old='location ~ ^/(tvkids|tvteens|tvviva|tvmaisjovem|tvkidsweb|radioprincipal|radiopop|radiorock|radioclassicas|radiocountry)(/.*)?$ {'
new='location ~ ^/(tvkids|tvteens|tvviva|tvmaisjovem|tvkidsweb)(/.*)?$ {'
if old in s:
    if s.count(old)!=1: raise SystemExit('mixed regex count != 1')
    s=s.replace(old,new)
else:
    locs='\n'.join(line for line in s.splitlines() if 'location' in line and any(x in line for x in ['radioprincipal','radiopop','radiorock','radioclassicas','radiocountry']))
    if locs: raise SystemExit('unexpected shared radio locations: '+locs)
for t in ['tvkids','tvteens','tvviva','tvmaisjovem','tvkidsweb']:
    if t not in s: raise SystemExit('TV token missing: '+t)
open(dst,'w',encoding='utf-8').write(s)
print('SHARED_PATCH=READY')
PY

section "5. BACKUP TRANSACIONAL WEB/NGINX"
mkdir -p "$ROLLBACK/var-www" "$ROLLBACK/nginx"
chmod 0700 "$ROLLBACK"
for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do [[ -e "/var/www/$d" ]] && cp -a "/var/www/$d" "$ROLLBACK/var-www/$d"; done
[[ -f "$CONF" ]] && cp -a "$CONF" "$ROLLBACK/nginx/20-studiosat-radio-clean.conf"
[[ -f "$OLD_CONF" ]] && cp -a "$OLD_CONF" "$ROLLBACK/nginx/studiosat-radio-v2.conf"
[[ -f "$OLD_SNIP" ]] && cp -a "$OLD_SNIP" "$ROLLBACK/nginx/studiosat-radio-hls-v2.conf"
cp -a "$SHARED" "$ROLLBACK/nginx/sites-available-studiosat"
nginx -T > "$ROLLBACK/nginx-T.before.txt" 2>&1

section "6. STAGE"
mkdir -p "$STAGE/portal" "$STAGE/player" "$STAGE/app" "$STAGE/assets"
cp -a "$ROOT/portal/." "$STAGE/portal/"
cp -a "$ROOT/player/." "$STAGE/player/"
cp -a "$ROOT/app/." "$STAGE/app/"
cp -a "$ROOT/assets/." "$STAGE/assets/"
install -o root -g root -m 0644 "$HLS_TMP" "$STAGE/assets/vendor/hls.min.js"
find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chown -R root:root "$STAGE"

section "7. MUTACAO TRANSACIONAL"
MUTATED=1
rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
mv "$STAGE/portal" "$PORTAL"
mv "$STAGE/player" "$PLAYER"
mv "$STAGE/app" "$APP"
mv "$STAGE/assets" "$ASSETS"
install -o root -g root -m 0644 "$ROOT/nginx/studiosat-radio-clean.conf" "$CONF"
install -o root -g root -m 0644 "$ROLLBACK/shared.patched" "$SHARED"
rm -f "$OLD_CONF" "$OLD_SNIP"

section "8. VALIDAR E RECARREGAR NGINX"
nginx -t
nginx -T > "$ROLLBACK/nginx-T.after.txt" 2>&1
if awk -v f="$SHARED" '
  /^# configuration file /{infile=($0 ~ f)}
  infile && /location/ && /(radioprincipal|radiopop|radiorock|radioclassicas|radiocountry)/{bad=1}
  END{exit bad?1:0}' "$ROLLBACK/nginx-T.after.txt"; then :; else die SHARED_RADIO_OVERLAP_REMAINS; fi
systemctl reload nginx
sleep 2
systemctl is-active --quiet nginx || die NGINX_FAILED_AFTER_RELOAD

section "9. TESTAR 12 HOSTS HTTPS"
PASS=0
for host in "${HOSTS[@]}"; do
  body="$ROLLBACK/${host//./_}.html"
  code="$(curl -ksS --resolve "$host:443:127.0.0.1" --max-time 12 -o "$body" -w '%{http_code}' "https://$host/" || true)"
  [[ "$code" == 200 ]] || die "HOST:$host:HTTP:$code"
  if [[ "$host" == www.* ]]; then grep -Fq '<title>Rádio Studio Sat</title>' "$body" || die "PORTAL_BODY:$host"; else grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" || die "PLAYER_BODY:$host"; fi
  PASS=$((PASS+1))
  echo "HOST_PASS=$host"
done
[[ "$PASS" -eq 12 ]] || die HOST_COUNT

section "10. PWA/ASSETS"
for u in manifest.webmanifest sw.js assets/vendor/hls.min.js assets/js/hls-controller.js assets/icons/icon.svg; do
  code="$(curl -ksS --resolve radio.studiosatweb.com.br:443:127.0.0.1 --max-time 12 -o /dev/null -w '%{http_code}' "https://radio.studiosatweb.com.br/$u" || true)"
  [[ "$code" == 200 ]] || die "ASSET:$u:HTTP:$code"
done
code="$(curl -ksSI --resolve www.radio.studiosatweb.com.br:443:127.0.0.1 --max-time 12 -o /dev/null -w '%{http_code}' https://www.radio.studiosatweb.com.br/app/ || true)"
[[ "$code" == 302 ]] || die "WWW_APP_REDIRECT_HTTP:$code"

section "11. REPORTAR HLS SEM CONTROLAR A ORIGEM"
ONLINE=0
for p in "${PATHS[@]}"; do
  code="$(curl -ksSL --resolve radio.studiosatweb.com.br:443:127.0.0.1 --max-time 8 -o "$ROLLBACK/$p.m3u8" -w '%{http_code}' "https://radio.studiosatweb.com.br/$p/index.m3u8" || true)"
  if [[ "$code" == 200 ]] && grep -q '^#EXTM3U' "$ROLLBACK/$p.m3u8"; then
    ONLINE=$((ONLINE+1))
    echo "HLS=$p:ONLINE"
  else
    echo "HLS=$p:OFFLINE_HTTP_$code"
  fi
done

COMMITTED=1
section "12. RESULTADO"
echo "DEPLOY_WEB=PASS"
echo "FULL_BACKUP=PASS"
echo "BACKUP=$BACKUP_PATH"
echo "ROLLBACK=$ROLLBACK"
echo "HOSTS_WEB=12/12"
echo "HLS_ONLINE=$ONLINE/5"
echo "SOURCE_CONTROLLED_BY_WEB=NO"
echo "MEDIAMTX_RESTARTED=NO"
echo "LIQUIDSOAP_TOUCHED=NO"
echo "LOG=$LOG"
