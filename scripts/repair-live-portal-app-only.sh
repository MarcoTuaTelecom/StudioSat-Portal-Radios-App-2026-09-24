#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027

# Studio Sat — correção cirúrgica Portal + App no NS1
# Data: 2026-09-24
#
# Altera SOMENTE:
# - quatro diretórios web de rádio em /var/www
# - vhost dedicado /etc/nginx/conf.d/20-studiosat-radio-clean.conf
# - desativa o vhost antigo /etc/nginx/conf.d/studiosat-radio-v2.conf, se existir
# - reload do Nginx
#
# NÃO altera MediaMTX, systemd, DNS, firewall, TVs, RadioBOSS,
# Liquidsoap, /etc/studiosat-v2, /opt/studiosat-v2 ou
# /etc/nginx/sites-available/studiosat.

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "FATAL=EXECUTE_COMO_ROOT" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="/root/2026-09-24-STUDIOSAT-FIX-PORTAL-APP-LIVE-${TS}.txt"

PORTAL="/var/www/studiosat-radio-portal"
PLAYER="/var/www/studiosat-radio-player"
APP="/var/www/studiosat-radio-app"
ASSETS="/var/www/studiosat-radio-assets"

NEW_CONF="/etc/nginx/conf.d/20-studiosat-radio-clean.conf"
OLD_CONF="/etc/nginx/conf.d/studiosat-radio-v2.conf"
SHARED="/etc/nginx/sites-available/studiosat"

CERT="/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem"
KEY="/etc/letsencrypt/live/studiosatweb-completo/privkey.pem"

BACKUP="/var/backups/studiosat/PORTAL-APP-LIVE-FIX/${TS}"
STAGE="/var/www/.studiosat-live-fix-${TS}"
HLS_TMP="/run/studiosat-hls-${TS}.min.js"
SHARED_SHA="/run/studiosat-shared-${TS}.sha256"

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

MUTATED=0
COMMITTED=0

exec > >(tee "$LOG") 2>&1

section(){ printf '\n================================================================\n%s\n================================================================\n' "$*"; }
die(){ echo "FATAL=$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "FERRAMENTA_AUSENTE:$1"; }

restore(){
  [[ "$MUTATED" -eq 1 && "$COMMITTED" -eq 0 ]] || return 0
  echo "ROLLBACK=AUTO_START"

  rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
  for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
    [[ -e "$BACKUP/var-www/$d" ]] && cp -a "$BACKUP/var-www/$d" "/var/www/$d"
  done

  rm -f "$NEW_CONF" "$OLD_CONF"
  [[ -f "$BACKUP/nginx/20-studiosat-radio-clean.conf" ]] &&
    cp -a "$BACKUP/nginx/20-studiosat-radio-clean.conf" "$NEW_CONF"
  [[ -f "$BACKUP/nginx/studiosat-radio-v2.conf" ]] &&
    cp -a "$BACKUP/nginx/studiosat-radio-v2.conf" "$OLD_CONF"

  if nginx -t; then systemctl reload nginx || true; fi
  echo "ROLLBACK=AUTO_DONE"
}

finish(){
  rc=$?
  trap - EXIT ERR
  if (( rc != 0 )); then restore; fi
  rm -rf "$STAGE" 2>/dev/null || true
  rm -f "$HLS_TMP" "$SHARED_SHA" 2>/dev/null || true
  exit "$rc"
}
trap finish EXIT
trap 'echo "ERROR_LINE=${BASH_LINENO[0]:-unknown}"' ERR

for c in nginx systemctl python3 curl grep awk sha256sum tar find stat cp rm install openssl; do need "$c"; done

section "0. CAUSA JA IDENTIFICADA E ESCOPO"
cat <<'EOF'
A sonda mostrou que:
- radio.studiosatweb.com.br e www.radio... ainda eram atendidos por
  /etc/nginx/conf.d/studiosat-radio-v2.conf;
- esse vhost apontava para /var/www/studiosatweb;
- /var/www/studiosatweb/index.html continha a página "Em construção";
- a configuração web nova não estava carregada.

Esta correção substitui somente essa camada web de rádio.
EOF

section "1. VALIDAR FONTE DO PROJETO"
for f in   "$ROOT/portal/index.html"   "$ROOT/player/index.html"   "$ROOT/player/manifest.webmanifest"   "$ROOT/player/sw.js"   "$ROOT/app/index.html"   "$ROOT/nginx/studiosat-radio-clean.conf"   "$ROOT/scripts/fetch-hls-vendor.sh"   "$ROOT/tests/validate_project.py"
do
  [[ -s "$f" ]] || die "FONTE_AUSENTE:$f"
done

python3 "$ROOT/tests/validate_project.py"

section "2. PREFLIGHT NGINX/TLS"
nginx -t
systemctl is-active --quiet nginx || die "NGINX_NAO_ATIVO"
[[ -r "$CERT" && -r "$KEY" ]] || die "TLS_AUSENTE"

for host in "${HOSTS[@]}"; do
  openssl x509 -in "$CERT" -noout -text | grep -Fq "DNS:$host" ||
    die "TLS_SAN_AUSENTE:$host"
done

[[ -f "$SHARED" ]] || die "SHARED_NGINX_AUSENTE"
sha256sum "$SHARED" > "$SHARED_SHA"

section "3. BACKUP WEB ANTES DA MUDANCA"
mkdir -p "$BACKUP/var-www" "$BACKUP/nginx"
chmod 0700 "$BACKUP"

for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
  [[ -e "/var/www/$d" ]] && cp -a "/var/www/$d" "$BACKUP/var-www/$d"
done

[[ -f "$NEW_CONF" ]] && cp -a "$NEW_CONF" "$BACKUP/nginx/20-studiosat-radio-clean.conf"
[[ -f "$OLD_CONF" ]] && cp -a "$OLD_CONF" "$BACKUP/nginx/studiosat-radio-v2.conf"
[[ -f /var/www/studiosatweb/index.html ]] &&
  cp -a /var/www/studiosatweb/index.html "$BACKUP/old-studiosatweb-index.html"

nginx -T > "$BACKUP/nginx-T.before.txt" 2>&1

tar --xattrs --acls --numeric-owner -czpf   "$BACKUP/web-radio-before-${TS}.tar.gz"   "$BACKUP/var-www" "$BACKUP/nginx"   $( [[ -f "$BACKUP/old-studiosatweb-index.html" ]] && printf '%q' "$BACKUP/old-studiosatweb-index.html" )

tar -tzf "$BACKUP/web-radio-before-${TS}.tar.gz" >/dev/null
sha256sum "$BACKUP/web-radio-before-${TS}.tar.gz" | tee "$BACKUP/SHA256SUMS.txt"
echo "WEB_BACKUP=PASS"

section "4. HLS.JS OFICIAL 1.7.3"
bash "$ROOT/scripts/fetch-hls-vendor.sh" "$HLS_TMP"
SIZE="$(stat -c '%s' "$HLS_TMP")"
(( SIZE > 300000 )) || die "HLSJS_INVALIDO:$SIZE"

section "5. STAGE COMPLETO"
mkdir -p "$STAGE/portal" "$STAGE/player" "$STAGE/app" "$STAGE/assets"
cp -a "$ROOT/portal/." "$STAGE/portal/"
cp -a "$ROOT/player/." "$STAGE/player/"
cp -a "$ROOT/app/." "$STAGE/app/"
cp -a "$ROOT/assets/." "$STAGE/assets/"
install -o root -g root -m 0644 "$HLS_TMP" "$STAGE/assets/vendor/hls.min.js"

find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chown -R root:root "$STAGE"

section "6. TROCA CIRURGICA DA CAMADA WEB DE RADIO"
MUTATED=1

rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
mv "$STAGE/portal" "$PORTAL"
mv "$STAGE/player" "$PLAYER"
mv "$STAGE/app" "$APP"
mv "$STAGE/assets" "$ASSETS"

# Retira SOMENTE o vhost antigo específico de rádio do conjunto carregado.
rm -f "$OLD_CONF"

install -o root -g root -m 0644   "$ROOT/nginx/studiosat-radio-clean.conf"   "$NEW_CONF"

section "7. PROVAS ANTES DO RELOAD"
nginx -t
nginx -T > "$BACKUP/nginx-T.after.txt" 2>&1

grep -Fq "# configuration file $NEW_CONF:" "$BACKUP/nginx-T.after.txt" ||
  die "NOVO_VHOST_NAO_CARREGADO"

if grep -Fq "# configuration file $OLD_CONF:" "$BACKUP/nginx-T.after.txt"; then
  die "VHOST_ANTIGO_AINDA_CARREGADO"
fi

sha256sum -c "$SHARED_SHA" || die "SHARED_NGINX_FOI_ALTERADO"

section "8. RELOAD SOMENTE NGINX"
systemctl reload nginx
sleep 2
systemctl is-active --quiet nginx || die "NGINX_FALHOU_APOS_RELOAD"

section "9. TESTE LOCAL DOS 12 HOSTS"
PASS=0
for host in "${HOSTS[@]}"; do
  body="$BACKUP/local-${host//./_}.html"
  headers="$BACKUP/local-${host//./_}.headers"

  code="$(curl -ksS --resolve "${host}:443:127.0.0.1"     --max-time 15 -D "$headers" -o "$body" -w '%{http_code}'     "https://${host}/" || true)"

  [[ "$code" == "200" ]] || die "HOST_LOCAL_NAO_200:$host:$code"

  if [[ "$host" == www.* ]]; then
    grep -Fq '<title>Rádio Studio Sat</title>' "$body" ||
      die "PORTAL_LOCAL_ERRADO:$host"
  else
    grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" ||
      die "PLAYER_LOCAL_ERRADO:$host"
  fi

  if grep -aEqi 'Em constru|construÃ|ConstruÃ|Studio Sat Web - Em' "$body"; then
    die "PAGINA_CONSTRUCAO_AINDA_SERVIDA:$host"
  fi

  echo "HOST_LOCAL_PASS=$host"
  PASS=$((PASS+1))
done
[[ "$PASS" -eq 12 ]] || die "HOST_LOCAL_COUNT:$PASS"

section "10. TESTE APP / PWA / CACHE"
for path in   /app/   /manifest.webmanifest   /sw.js   /assets/js/stations.js   /assets/js/hls-controller.js   /assets/vendor/hls.min.js   /assets/icons/icon.svg
do
  code="$(curl -ksS --resolve radio.studiosatweb.com.br:443:127.0.0.1     --max-time 15 -o "$BACKUP/check-$(echo "$path" | tr '/.' '__')"     -w '%{http_code}' "https://radio.studiosatweb.com.br$path" || true)"
  [[ "$code" == "200" ]] || die "APP_ASSET_NAO_200:$path:$code"
done

grep -Fq "studiosat-pwa-2026-09-24-v3" "$PLAYER/sw.js" ||
  die "SERVICE_WORKER_V3_NAO_PUBLICADO"

section "11. TESTE VIA DNS NORMAL — PUBLICACAO EXTERNA"
PUBLIC=0
for host in radio.studiosatweb.com.br www.radio.studiosatweb.com.br; do
  body="$BACKUP/public-${host//./_}.html"
  code="$(curl -ksSL --max-time 20 -o "$body" -w '%{http_code}' "https://$host/" || true)"
  echo "PUBLIC_HOST=$host HTTP=$code"
  if [[ "$code" == "200" ]]; then
    if [[ "$host" == www.* ]]; then
      grep -Fq '<title>Rádio Studio Sat</title>' "$body" && PUBLIC=$((PUBLIC+1)) || true
    else
      grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" && PUBLIC=$((PUBLIC+1)) || true
    fi
  fi
done
echo "PUBLIC_PRIMARY_HOSTS=$PUBLIC/2"

COMMITTED=1

section "12. RESULTADO"
echo "PORTAL_APP_LIVE_FIX=PASS"
echo "ROOT_CAUSE=OLD_RADIO_VHOST_POINTING_TO_OLD_DOCROOT"
echo "OLD_ACTIVE_VHOST_REMOVED=YES"
echo "NEW_RADIO_VHOST_ACTIVE=YES"
echo "LOCAL_HOSTS=12/12"
echo "APP_PWA=PASS"
echo "STALE_HTML_CACHE_POLICY=NO_STORE"
echo "SERVICE_WORKER_CACHE_VERSION=v3"
echo "SHARED_NGINX_CHANGED=NO"
echo "MEDIA_STACK_CHANGED=NO"
echo "SYSTEMD_CHANGED=NO"
echo "DNS_CHANGED=NO"
echo "FIREWALL_CHANGED=NO"
echo "TV_CHANGED=NO"
echo "ONLY_SERVICE_OPERATION=NGINX_RELOAD"
echo "PUBLIC_PRIMARY_HOSTS=$PUBLIC/2"
echo "BACKUP_DIR=$BACKUP"
echo "LOG=$LOG"
