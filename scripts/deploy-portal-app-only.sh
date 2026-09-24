#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027

# Studio Sat — deploy SOMENTE Portal + App
# Data: 2026-09-24
#
# ESCOPO DE ESCRITA:
#   /var/www/studiosat-radio-portal
#   /var/www/studiosat-radio-player
#   /var/www/studiosat-radio-app
#   /var/www/studiosat-radio-assets
#   /etc/nginx/conf.d/20-studiosat-radio-clean.conf
#   /etc/nginx/conf.d/studiosat-radio-v2.conf  (somente desativação, se existir)
#
# A única operação de serviço é: systemctl reload nginx
#
# NÃO altera:
#   MediaMTX
#   /etc/studiosat-v2
#   /opt/studiosat-v2
#   systemd units
#   RadioBOSS
#   Liquidsoap
#   DNS
#   firewall
#   configurações de TV
#   /etc/nginx/sites-available/studiosat

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "FATAL=EXECUTE_COMO_ROOT" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="/root/2026-09-24-STUDIOSAT-PORTAL-APP-ONLY-${TS}.txt"

PORTAL="/var/www/studiosat-radio-portal"
PLAYER="/var/www/studiosat-radio-player"
APP="/var/www/studiosat-radio-app"
ASSETS="/var/www/studiosat-radio-assets"

NEW_CONF="/etc/nginx/conf.d/20-studiosat-radio-clean.conf"
LEGACY_RADIO_CONF="/etc/nginx/conf.d/studiosat-radio-v2.conf"

CERT="/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem"
KEY="/etc/letsencrypt/live/studiosatweb-completo/privkey.pem"

STAGE="/var/www/.studiosat-portal-app-stage-${TS}"
ROLLBACK="/var/backups/studiosat/PORTAL-APP-ONLY/${TS}"
HLS_TMP="/run/studiosat-hls-${TS}.min.js"

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

PATHS=(radioprincipal radiopop radiorock radioclassicas radiocountry)

MUTATED=0
COMMITTED=0

exec > >(tee "$LOG") 2>&1

section(){ printf '\n================================================================\n%s\n================================================================\n' "$*"; }
die(){ echo "FATAL=$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "FERRAMENTA_AUSENTE:$1"; }

restore_web(){
  [[ "$MUTATED" -eq 1 ]] || return 0
  [[ "$COMMITTED" -eq 0 ]] || return 0

  echo "ROLLBACK=AUTO_START"

  rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
  for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
    [[ -e "$ROLLBACK/var-www/$d" ]] && cp -a "$ROLLBACK/var-www/$d" "/var/www/$d"
  done

  rm -f "$NEW_CONF"
  [[ -f "$ROLLBACK/nginx/20-studiosat-radio-clean.conf" ]] &&
    cp -a "$ROLLBACK/nginx/20-studiosat-radio-clean.conf" "$NEW_CONF"

  [[ -f "$ROLLBACK/nginx/studiosat-radio-v2.conf" ]] &&
    cp -a "$ROLLBACK/nginx/studiosat-radio-v2.conf" "$LEGACY_RADIO_CONF"

  if nginx -t; then
    systemctl reload nginx || true
  fi

  echo "ROLLBACK=AUTO_DONE"
}

on_exit(){
  rc=$?
  trap - EXIT ERR
  if (( rc != 0 )); then
    restore_web
  fi
  rm -rf "$STAGE" 2>/dev/null || true
  rm -f "$HLS_TMP" "$HLS_TMP.shared.sha.before" 2>/dev/null || true
  exit "$rc"
}
trap on_exit EXIT
trap 'echo "ERROR_LINE=${BASH_LINENO[0]:-unknown}"' ERR

section "0. CONTRATO"
cat <<'EOF'
Esta execução reconstrói e publica SOMENTE:
- portal das rádios;
- player/app PWA;
- Central de instalação;
- assets web;
- vhost Nginx exclusivo das rádios.

Não modifica a configuração compartilhada /etc/nginx/sites-available/studiosat.
Não modifica qualquer origem ou processamento de áudio.
Não reinicia nenhum serviço de mídia.
A única operação de serviço é reload do Nginx.
EOF

for c in nginx systemctl python3 curl grep awk sha256sum tar find stat cp rm install openssl; do
  need "$c"
done

section "1. VALIDAR PROJETO FONTE"
for f in   "$ROOT/portal/index.html"   "$ROOT/player/index.html"   "$ROOT/player/manifest.webmanifest"   "$ROOT/player/sw.js"   "$ROOT/app/index.html"   "$ROOT/nginx/studiosat-radio-clean.conf"   "$ROOT/scripts/fetch-hls-vendor.sh"   "$ROOT/tests/validate_project.py"
do
  [[ -s "$f" ]] || die "ARQUIVO_FONTE_AUSENTE:$f"
done

python3 "$ROOT/tests/validate_project.py"

section "2. PREFLIGHT SOMENTE WEB"
nginx -t
systemctl is-active --quiet nginx || die "NGINX_NAO_ATIVO"

[[ -r "$CERT" && -r "$KEY" ]] || die "TLS_AUSENTE"

for host in "${HOSTS[@]}"; do
  openssl x509 -in "$CERT" -noout -text | grep -Fq "DNS:$host" ||
    die "TLS_SAN_AUSENTE:$host"
done

if [[ -e /etc/nginx/sites-available/studiosat ]]; then
  sha256sum /etc/nginx/sites-available/studiosat > "$HLS_TMP.shared.sha.before"
fi

section "3. BACKUP SOMENTE DA CAMADA WEB"
mkdir -p "$ROLLBACK/var-www" "$ROLLBACK/nginx"
chmod 0700 "$ROLLBACK"

for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
  [[ -e "/var/www/$d" ]] && cp -a "/var/www/$d" "$ROLLBACK/var-www/$d"
done

[[ -f "$NEW_CONF" ]] &&
  cp -a "$NEW_CONF" "$ROLLBACK/nginx/20-studiosat-radio-clean.conf"

[[ -f "$LEGACY_RADIO_CONF" ]] &&
  cp -a "$LEGACY_RADIO_CONF" "$ROLLBACK/nginx/studiosat-radio-v2.conf"

nginx -T > "$ROLLBACK/nginx-T.before.txt" 2>&1

tar --xattrs --acls --numeric-owner -czpf   "$ROLLBACK/portal-app-only-${TS}.tar.gz"   "$ROLLBACK/var-www" "$ROLLBACK/nginx"

tar -tzf "$ROLLBACK/portal-app-only-${TS}.tar.gz" >/dev/null
sha256sum "$ROLLBACK/portal-app-only-${TS}.tar.gz" |
  tee "$ROLLBACK/SHA256SUMS.txt"

echo "WEB_BACKUP=PASS"
echo "WEB_BACKUP_DIR=$ROLLBACK"

section "4. PREPARAR HLS.JS OFICIAL SEM ALTERAR PRODUCAO"
bash "$ROOT/scripts/fetch-hls-vendor.sh" "$HLS_TMP"

HLS_SIZE="$(stat -c '%s' "$HLS_TMP")"
(( HLS_SIZE > 300000 )) || die "HLSJS_INVALIDO:$HLS_SIZE"

section "5. STAGE"
mkdir -p "$STAGE/portal" "$STAGE/player" "$STAGE/app" "$STAGE/assets"

cp -a "$ROOT/portal/." "$STAGE/portal/"
cp -a "$ROOT/player/." "$STAGE/player/"
cp -a "$ROOT/app/." "$STAGE/app/"
cp -a "$ROOT/assets/." "$STAGE/assets/"

install -o root -g root -m 0644 "$HLS_TMP" "$STAGE/assets/vendor/hls.min.js"

find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chown -R root:root "$STAGE"

section "6. PUBLICAR SOMENTE PORTAL/APP"
MUTATED=1

rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"

mv "$STAGE/portal" "$PORTAL"
mv "$STAGE/player" "$PLAYER"
mv "$STAGE/app" "$APP"
mv "$STAGE/assets" "$ASSETS"

rm -f "$LEGACY_RADIO_CONF"

install -o root -g root -m 0644   "$ROOT/nginx/studiosat-radio-clean.conf"   "$NEW_CONF"

section "7. VALIDAR NGINX ANTES DO RELOAD"
nginx -t
nginx -T > "$ROLLBACK/nginx-T.after.txt" 2>&1

if [[ -f "$HLS_TMP.shared.sha.before" ]]; then
  sha256sum -c "$HLS_TMP.shared.sha.before" ||
    die "CONFIG_COMPARTILHADA_FOI_ALTERADA"
fi

section "8. RELOAD SOMENTE NGINX"
systemctl reload nginx
sleep 2
systemctl is-active --quiet nginx || die "NGINX_FALHOU_APOS_RELOAD"

section "9. TESTAR 12 HOSTS LOCALMENTE"
PASS=0
for host in "${HOSTS[@]}"; do
  body="$ROLLBACK/${host//./_}.html"
  code="$(curl -ksS --resolve "$host:443:127.0.0.1" --max-time 12     -o "$body" -w '%{http_code}' "https://$host/" || true)"

  [[ "$code" == "200" ]] || die "HOST_NAO_200:$host:$code"

  if [[ "$host" == www.* ]]; then
    grep -Fq '<title>Rádio Studio Sat</title>' "$body" ||
      die "PORTAL_CONTEUDO_INVALIDO:$host"
  else
    grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" ||
      die "PLAYER_CONTEUDO_INVALIDO:$host"
  fi

  PASS=$((PASS+1))
  echo "HOST_PASS=$host"
done

[[ "$PASS" -eq 12 ]] || die "HOSTS_PASS_INVALIDO:$PASS"

section "10. TESTAR APP/PWA/ASSETS"
for url in   manifest.webmanifest   sw.js   assets/vendor/hls.min.js   assets/js/hls-controller.js   assets/js/stations.js   assets/icons/icon.svg
do
  code="$(curl -ksS --resolve radio.studiosatweb.com.br:443:127.0.0.1     --max-time 12 -o /dev/null -w '%{http_code}'     "https://radio.studiosatweb.com.br/$url" || true)"

  [[ "$code" == "200" ]] || die "ASSET_NAO_200:$url:$code"
done

code="$(curl -ksS --resolve radio.studiosatweb.com.br:443:127.0.0.1   --max-time 12 -o "$ROLLBACK/app.html" -w '%{http_code}'   https://radio.studiosatweb.com.br/app/ || true)"

[[ "$code" == "200" ]] || die "APP_NAO_200:$code"

section "11. HLS — SOMENTE OBSERVACAO"
ONLINE=0
for p in "${PATHS[@]}"; do
  code="$(curl -ksSL --resolve radio.studiosatweb.com.br:443:127.0.0.1     --max-time 8 -o "$ROLLBACK/$p.m3u8" -w '%{http_code}'     "https://radio.studiosatweb.com.br/$p/index.m3u8" || true)"

  if [[ "$code" == "200" ]] && grep -q '^#EXTM3U' "$ROLLBACK/$p.m3u8"; then
    ONLINE=$((ONLINE+1))
    echo "HLS=$p:ONLINE"
  else
    echo "HLS=$p:SEM_FONTE_OU_INDISPONIVEL_HTTP_$code"
  fi
done

COMMITTED=1

section "12. RESULTADO"
echo "PORTAL_APP_ONLY_DEPLOY=PASS"
echo "WEB_BACKUP=PASS"
echo "HOSTS_HTTPS_LOCAL=12/12"
echo "APP_PWA=PASS"
echo "HLS_ONLINE=$ONLINE/5"
echo "SHARED_NGINX_CHANGED=NO"
echo "MEDIA_SERVICES_CHANGED=NO"
echo "SYSTEMD_CHANGED=NO"
echo "DNS_CHANGED=NO"
echo "FIREWALL_CHANGED=NO"
echo "TV_CONFIG_CHANGED=NO"
echo "ONLY_SERVICE_OPERATION=NGINX_RELOAD"
echo "ROLLBACK_DIR=$ROLLBACK"
echo "LOG=$LOG"
