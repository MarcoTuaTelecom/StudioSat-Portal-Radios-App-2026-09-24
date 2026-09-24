#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 027

# Studio Sat — instalação pinada do Portal + App no NS1
# Data: 2026-09-24
#
# Não instala Liquidsoap.
# Não instala nem controla qualquer mecanismo de playout.
# Não reinicia MediaMTX.
# Não altera RadioBOSS, DNS, firewall ou serviços de TV.

REPO="https://github.com/MarcoTuaTelecom/StudioSat-Portal-Radios-App-2026-09-24.git"
EXPECTED_COMMIT="0b708770426c226114b1f7958cee8f5e51f46c2c"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
WORK="/run/studiosat-portal-app-install-${TS}"
LOG="/root/2026-09-24-09-STUDIOSAT-INSTALAR-PORTAL-APP-NS1-${TS}.txt"

exec > >(tee "$LOG") 2>&1

section() {
  printf '\n================================================================\n%s\n================================================================\n' "$*"
}

die() {
  echo "FATAL=$*" >&2
  exit 1
}

cleanup() {
  rc=$?
  rm -rf "$WORK" 2>/dev/null || true
  exit "$rc"
}
trap cleanup EXIT

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "EXECUTE_COMO_ROOT"

for cmd in git bash python3 nginx systemctl sha256sum; do
  command -v "$cmd" >/dev/null 2>&1 || die "FERRAMENTA_AUSENTE:$cmd"
done

section "0. CONTRATO DESTA INSTALACAO"
cat <<EOF
REPOSITORIO=$REPO
COMMIT_PINADO=$EXPECTED_COMMIT

ESCOPO:
- portal das cinco radios;
- player/app PWA;
- Central de instalacao;
- assets;
- configuracao Nginx exclusiva das radios;
- backup completo do stack atual antes da mutacao;
- rollback automatico da web em caso de falha.

FORA DO ESCOPO:
- qualquer mecanismo de playout;
- Liquidsoap;
- RadioBOSS;
- DNS;
- firewall;
- TVs;
- reinicio do MediaMTX.
EOF

section "1. CLONE LIMPO DO COMMIT AUDITADO"
rm -rf "$WORK"
git clone --quiet "$REPO" "$WORK"
cd "$WORK"
git checkout --quiet --detach "$EXPECTED_COMMIT"

ACTUAL="$(git rev-parse HEAD)"
[[ "$ACTUAL" == "$EXPECTED_COMMIT" ]] || die "COMMIT_DIVERGENTE:$ACTUAL"
[[ -z "$(git status --porcelain)" ]] || die "CHECKOUT_NAO_LIMPO"
echo "CHECKOUT_COMMIT=$ACTUAL"
echo "CHECKOUT_CLEAN=YES"

section "2. VALIDACAO DO PROJETO ANTES DO DEPLOY"
python3 tests/validate_project.py

for f in scripts/*.sh; do
  bash -n "$f" || die "BASH_SYNTAX:$f"
done
echo "BASH_SYNTAX_ALL=PASS"

if command -v node >/dev/null 2>&1; then
  node --check assets/js/stations.js
  node --check assets/js/hls-controller.js
  node --check player/sw.js
  echo "NODE_JS_SYNTAX=PASS"
else
  echo "NODE_JS_SYNTAX=SKIPPED_NODE_NOT_INSTALLED"
fi

section "3. ESTADO PRE-DEPLOY"
nginx -t
systemctl is-active --quiet nginx || die "NGINX_NAO_ATIVO"
systemctl is-active --quiet studiosat-mediamtx.service || die "MEDIAMTX_NAO_ATIVO"

echo "NGINX_PREFLIGHT=PASS"
echo "MEDIAMTX_PREFLIGHT=PASS"
echo "SOURCE_LAYER_OUTSIDE_WEB_SCOPE=YES"

section "4. DEPLOY TRANSACIONAL"
bash scripts/deploy-web.sh

section "5. RESULTADO DO WRAPPER"
echo "INSTALL_WRAPPER=PASS"
echo "SOURCE_COMMIT=$EXPECTED_COMMIT"
echo "TEMP_SOURCE_REMOVED_ON_EXIT=YES"
echo "SOURCE_LAYER_CONTROLLED=NO"
echo "LIQUIDSOAP_TOUCHED=NO"
echo "MEDIAMTX_RESTARTED=NO"
echo "WRAPPER_LOG=$LOG"
echo
echo "IMPORTANTE: envie este log e o log DEPLOY_WEB gerado pelo scripts/deploy-web.sh para revisao antes da proxima etapa."
