#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027

# Studio Sat — deploy canônico SOMENTE Portal + App
# Data: 2026-09-24
# Única operação de serviço: reload do Nginx.
# Não altera MediaMTX, Liquidsoap, RadioBOSS, systemd, DNS, firewall,
# configuração de TV, /etc/studiosat-v2, /opt/studiosat-v2
# nem /etc/nginx/sites-available/studiosat.

[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "FATAL=EXECUTE_COMO_ROOT" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG="/root/2026-09-24-STUDIOSAT-PORTAL-APP-PRODUCTION-${TS}.txt"

PORTAL="/var/www/studiosat-radio-portal"
PLAYER="/var/www/studiosat-radio-player"
APP="/var/www/studiosat-radio-app"
ASSETS="/var/www/studiosat-radio-assets"
NEW_CONF="/etc/nginx/conf.d/20-studiosat-radio-clean.conf"
OLD_CONF="/etc/nginx/conf.d/studiosat-radio-v2.conf"
SHARED="/etc/nginx/sites-available/studiosat"
CERT="/etc/letsencrypt/live/studiosatweb-completo/fullchain.pem"
KEY="/etc/letsencrypt/live/studiosatweb-completo/privkey.pem"

BACKUP="/var/backups/studiosat/PORTAL-APP-PRODUCTION/${TS}"
STAGE="/var/www/.studiosat-production-${TS}"
HLS_TMP="/run/studiosat-hls-${TS}.min.js"
SHARED_SHA="/run/studiosat-shared-${TS}.sha256"
EXPECTED_HLS_SHA="a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e"

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
LOCAL_COMMITTED=0
exec > >(tee "$LOG") 2>&1

section(){ printf '\n================================================================\n%s\n================================================================\n' "$*"; }
die(){ echo "FATAL=$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "FERRAMENTA_AUSENTE:$1"; }

rollback(){
  [[ "$MUTATED" -eq 1 && "$LOCAL_COMMITTED" -eq 0 ]] || return 0
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
  if (( rc != 0 )); then rollback; fi
  rm -rf "$STAGE" 2>/dev/null || true
  rm -f "$HLS_TMP" "$SHARED_SHA" 2>/dev/null || true
  exit "$rc"
}
trap finish EXIT
trap 'echo "ERROR_LINE=${BASH_LINENO[0]:-unknown}"' ERR

for c in nginx systemctl python3 curl grep awk sha256sum tar find stat cp rm install openssl getent; do
  need "$c"
done

section "0. CONTRATO"
cat <<'EOF'
ESCOPO DE MUDANÇA:
- /var/www/studiosat-radio-portal
- /var/www/studiosat-radio-player
- /var/www/studiosat-radio-app
- /var/www/studiosat-radio-assets
- /etc/nginx/conf.d/20-studiosat-radio-clean.conf
- remoção do vhost antigo /etc/nginx/conf.d/studiosat-radio-v2.conf
- reload do Nginx

FORA DO ESCOPO:
- qualquer serviço de mídia ou automação
- systemd
- DNS
- firewall
- TVs
- configuração compartilhada /etc/nginx/sites-available/studiosat
EOF

section "1. RELEASE GATES — ANTES DE PRODUCAO"
python3 "$ROOT/tests/validate_project.py"
if command -v node >/dev/null 2>&1; then
  node --check "$ROOT/assets/js/stations.js"
  node --check "$ROOT/assets/js/hls-controller.js"
  node --check "$ROOT/player/sw.js"
  echo "NODE_SYNTAX=PASS"
else
  echo "NODE_SYNTAX=SKIPPED_NOT_INSTALLED_ON_NS1"
fi
for f in "$ROOT"/scripts/*.sh "$ROOT"/tests/*.sh; do bash -n "$f"; done
bash "$ROOT/tests/nginx_integration.sh"
echo "RELEASE_GATES=PASS"

section "2. PREFLIGHT DO NS1 — SOMENTE LEITURA"
nginx -t
systemctl is-active --quiet nginx || die "NGINX_NAO_ATIVO"
[[ -r "$CERT" && -r "$KEY" ]] || die "TLS_AUSENTE"
[[ -f "$SHARED" ]] || die "SHARED_NGINX_AUSENTE"

for host in "${HOSTS[@]}"; do
  openssl x509 -in "$CERT" -noout -text | grep -Fq "DNS:$host" ||
    die "TLS_SAN_AUSENTE:$host"
  getent ahostsv4 "$host" >/dev/null 2>&1 || die "DNS_NAO_RESOLVE:$host"
done
sha256sum "$SHARED" > "$SHARED_SHA"
echo "NS1_PREFLIGHT=PASS"

section "3. BACKUP WEB TRANSACIONAL"
mkdir -p "$BACKUP/var-www" "$BACKUP/nginx"
chmod 0700 "$BACKUP"
for d in studiosat-radio-portal studiosat-radio-player studiosat-radio-app studiosat-radio-assets; do
  [[ -e "/var/www/$d" ]] && cp -a "/var/www/$d" "$BACKUP/var-www/$d"
done
[[ -f "$NEW_CONF" ]] && cp -a "$NEW_CONF" "$BACKUP/nginx/20-studiosat-radio-clean.conf"
[[ -f "$OLD_CONF" ]] && cp -a "$OLD_CONF" "$BACKUP/nginx/studiosat-radio-v2.conf"
[[ -f /var/www/studiosatweb/index.html ]] && cp -a /var/www/studiosatweb/index.html "$BACKUP/old-studiosatweb-index.html"
nginx -T > "$BACKUP/nginx-T.before.txt" 2>&1

BACKUP_ITEMS=("$BACKUP/var-www" "$BACKUP/nginx")
[[ -f "$BACKUP/old-studiosatweb-index.html" ]] && BACKUP_ITEMS+=("$BACKUP/old-studiosatweb-index.html")
tar --xattrs --acls --numeric-owner -czpf "$BACKUP/web-before-${TS}.tar.gz" "${BACKUP_ITEMS[@]}"
tar -tzf "$BACKUP/web-before-${TS}.tar.gz" >/dev/null
sha256sum "$BACKUP/web-before-${TS}.tar.gz" | tee "$BACKUP/SHA256SUMS.txt"
echo "WEB_BACKUP=PASS"

section "4. DEPENDENCIA HLS.JS VERIFICADA CRIPTOGRAFICAMENTE"
bash "$ROOT/scripts/fetch-hls-vendor.sh" "$HLS_TMP"
[[ "$(sha256sum "$HLS_TMP" | awk '{print $1}')" == "$EXPECTED_HLS_SHA" ]] ||
  die "HLSJS_SHA_FINAL_DIVERGENTE"
echo "HLSJS_VERIFIED=PASS"

section "5. STAGE E COMPARACAO BINARIA"
mkdir -p "$STAGE/portal" "$STAGE/player" "$STAGE/app" "$STAGE/assets"
cp -a "$ROOT/portal/." "$STAGE/portal/"
cp -a "$ROOT/player/." "$STAGE/player/"
cp -a "$ROOT/app/." "$STAGE/app/"
cp -a "$ROOT/assets/." "$STAGE/assets/"
install -o root -g root -m 0644 "$HLS_TMP" "$STAGE/assets/vendor/hls.min.js"
find "$STAGE" -type d -exec chmod 0755 {} +
find "$STAGE" -type f -exec chmod 0644 {} +
chown -R root:root "$STAGE"

python3 - "$ROOT" "$STAGE" <<'PY'
from pathlib import Path
import hashlib,sys
root=Path(sys.argv[1]); stage=Path(sys.argv[2])
pairs=[('portal','portal'),('player','player'),('app','app'),('assets','assets')]
errors=[]
for src_name,dst_name in pairs:
    src=root/src_name; dst=stage/dst_name
    for p in src.rglob('*'):
        if not p.is_file(): continue
        rel=p.relative_to(src)
        if src_name=='assets' and rel.as_posix()=='vendor/hls.min.js':
            continue
        q=dst/rel
        if not q.is_file(): errors.append(f'missing-stage:{src_name}/{rel}'); continue
        h=lambda x: hashlib.sha256(x.read_bytes()).hexdigest()
        if h(p)!=h(q): errors.append(f'hash-stage:{src_name}/{rel}')
if errors:
    print('\n'.join(errors)); raise SystemExit(1)
print('STAGE_HASH_COMPARE=PASS')
PY

section "6. TROCA SOMENTE DA CAMADA WEB DE RADIO"
MUTATED=1
rm -rf "$PORTAL" "$PLAYER" "$APP" "$ASSETS"
mv "$STAGE/portal" "$PORTAL"
mv "$STAGE/player" "$PLAYER"
mv "$STAGE/app" "$APP"
mv "$STAGE/assets" "$ASSETS"
rm -f "$OLD_CONF"
install -o root -g root -m 0644 "$ROOT/nginx/studiosat-radio-clean.conf" "$NEW_CONF"

section "7. PROVAS NGINX ANTES DO RELOAD"
nginx -t
nginx -T > "$BACKUP/nginx-T.after.txt" 2>&1
grep -Fq "# configuration file $NEW_CONF:" "$BACKUP/nginx-T.after.txt" || die "NOVO_VHOST_NAO_CARREGADO"
if grep -Fq "# configuration file $OLD_CONF:" "$BACKUP/nginx-T.after.txt"; then die "VHOST_ANTIGO_AINDA_CARREGADO"; fi
sha256sum -c "$SHARED_SHA" || die "SHARED_NGINX_FOI_ALTERADO"
echo "NGINX_PRE_RELOAD_PROOF=PASS"

section "8. RELOAD UNICO DO NGINX"
systemctl reload nginx
sleep 2
systemctl is-active --quiet nginx || die "NGINX_FALHOU_APOS_RELOAD"

section "9. CERTIFICACAO LOCAL 12/12"
LOCAL=0
for host in "${HOSTS[@]}"; do
  body="$BACKUP/local-${host//./_}.html"
  code="$(curl -ksS --resolve "${host}:443:127.0.0.1" --max-time 15 -o "$body" -w '%{http_code}' "https://${host}/" || true)"
  [[ "$code" == "200" ]] || die "HOST_LOCAL_NAO_200:$host:$code"
  if [[ "$host" == www.* ]]; then
    grep -Fq '<title>Rádio Studio Sat</title>' "$body" || die "PORTAL_LOCAL_ERRADO:$host"
  else
    grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" || die "PLAYER_LOCAL_ERRADO:$host"
  fi
  ! grep -aEqi 'Em constru|construÃ|ConstruÃ|Studio Sat Web - Em' "$body" || die "PAGINA_ANTIGA_AINDA_SERVIDA:$host"
  LOCAL=$((LOCAL+1))
done
[[ "$LOCAL" -eq 12 ]] || die "LOCAL_HOST_COUNT:$LOCAL"

for path in /app/ /manifest.webmanifest /sw.js /assets/js/stations.js /assets/js/hls-controller.js /assets/vendor/hls.min.js /assets/icons/icon.svg /assets/icons/icon-192.png /assets/icons/icon-512.png; do
  code="$(curl -ksS --resolve radio.studiosatweb.com.br:443:127.0.0.1 --max-time 15 -o "$BACKUP/check" -w '%{http_code}' "https://radio.studiosatweb.com.br$path" || true)"
  [[ "$code" == "200" ]] || die "APP_ASSET_LOCAL_NAO_200:$path:$code"
done
[[ "$(sha256sum "$ASSETS/vendor/hls.min.js" | awk '{print $1}')" == "$EXPECTED_HLS_SHA" ]] || die "HLSJS_DEPLOYED_SHA_DIVERGENTE"
grep -Fq "studiosat-pwa-2026-09-24-v4" "$PLAYER/sw.js" || die "SERVICE_WORKER_V4_AUSENTE"
echo "LOCAL_CERTIFICATION=PASS"

# Daqui em diante a instalação local é válida; falha pública não restaura uma web local correta.
LOCAL_COMMITTED=1

section "10. CERTIFICACAO PUBLICA 12/12"
PUBLIC=0
for host in "${HOSTS[@]}"; do
  body="$BACKUP/public-${host//./_}.html"
  code="$(curl -ksSL --max-time 20 -o "$body" -w '%{http_code}' "https://$host/" || true)"
  [[ "$code" == "200" ]] || die "HOST_PUBLICO_NAO_200:$host:$code"
  if [[ "$host" == www.* ]]; then
    grep -Fq '<title>Rádio Studio Sat</title>' "$body" || die "PORTAL_PUBLICO_ERRADO:$host"
  else
    grep -Fq '<title>Rádio Studio Sat — Ao Vivo</title>' "$body" || die "PLAYER_PUBLICO_ERRADO:$host"
  fi
  ! grep -aEqi 'Em constru|construÃ|ConstruÃ|Studio Sat Web - Em' "$body" || die "PAGINA_ANTIGA_PUBLICA:$host"
  PUBLIC=$((PUBLIC+1))
done
[[ "$PUBLIC" -eq 12 ]] || die "PUBLIC_HOST_COUNT:$PUBLIC"

section "11. RESULTADO"
echo "PORTAL_APP_PRODUCTION=PASS"
echo "RELEASE_GATES=PASS"
echo "WEB_BACKUP=PASS"
echo "NGINX_LOCAL=12/12"
echo "NGINX_PUBLIC=12/12"
echo "APP_PWA_ROUTES=PASS"
echo "HLSJS_SHA256=$EXPECTED_HLS_SHA"
echo "SHARED_NGINX_CHANGED=NO"
echo "MEDIA_STACK_CHANGED=NO"
echo "SYSTEMD_CHANGED=NO"
echo "DNS_CHANGED=NO"
echo "FIREWALL_CHANGED=NO"
echo "TV_CHANGED=NO"
echo "ONLY_SERVICE_OPERATION=NGINX_RELOAD"
echo "BACKUP_DIR=$BACKUP"
echo "LOG=$LOG"
