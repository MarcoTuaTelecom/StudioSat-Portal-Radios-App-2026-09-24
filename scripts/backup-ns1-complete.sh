#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C
umask 077
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo FATAL=ROOT >&2; exit 1; }

TS="$(date -u +%Y%m%dT%H%M%SZ)"
DEST="/var/backups/studiosat/FULL-PRE-PORTAL/$TS"
STATE="$DEST/state"
mkdir -p "$STATE"
chmod 0700 "$DEST" "$STATE"

for cmd in tar sha256sum nginx systemctl ss ps df free journalctl find; do
  command -v "$cmd" >/dev/null || { echo "FATAL=MISSING:$cmd" >&2; exit 1; }
done

{
  echo "UTC=$(date -u --iso-8601=seconds)"
  echo "HOSTNAME=$(hostname -f 2>/dev/null || hostname)"
  echo "KERNEL=$(uname -a)"
} > "$STATE/identity.txt"

nginx -T > "$STATE/nginx-T.txt" 2>&1 || true
systemctl list-units --all --no-pager > "$STATE/systemd-units.txt" 2>&1 || true
systemctl list-unit-files --no-pager > "$STATE/systemd-unit-files.txt" 2>&1 || true
systemctl status nginx studiosat-mediamtx.service --no-pager > "$STATE/status-web-core.txt" 2>&1 || true
ss -lntup > "$STATE/ss-lntup.txt" 2>&1 || true
ps -eo pid,ppid,user,group,stat,lstart,cmd --sort=pid > "$STATE/ps.txt" 2>&1 || true
df -hT > "$STATE/df.txt" 2>&1 || true
free -h > "$STATE/free.txt" 2>&1 || true
journalctl -u nginx -n 300 --no-pager > "$STATE/journal-nginx-last300.txt" 2>&1 || true
journalctl -u studiosat-mediamtx.service -n 500 --no-pager > "$STATE/journal-mediamtx-last500.txt" 2>&1 || true
command -v iptables-save >/dev/null && iptables-save > "$STATE/iptables-save.txt" 2>&1 || true
command -v nft >/dev/null && nft list ruleset > "$STATE/nft-ruleset.txt" 2>&1 || true

paths=()
for p in  /etc/nginx  /etc/studiosat-v2  /opt/studiosat-v2/bin/mediamtx  /var/www  /etc/systemd/system/studiosat-mediamtx.service  /etc/letsencrypt  /etc/fail2ban  /etc/ufw  /etc/ssh  /etc/iptables  /etc/nftables.conf  /etc/hosts  /etc/hostname  /var/spool/cron
do
  [[ -e "$p" ]] && paths+=("$p")
done

[[ ${#paths[@]} -gt 0 ]] || { echo FATAL=NOTHING_TO_BACKUP >&2; exit 1; }

TAR="$DEST/studiosat-ns1-pre-portal-$TS.tar.gz"
tar --xattrs --acls --numeric-owner -czpf "$TAR" "${paths[@]}"
tar -tzf "$TAR" >/dev/null
sha256sum "$TAR" | tee "$DEST/SHA256SUMS.txt"
chmod 0600 "$TAR" "$DEST/SHA256SUMS.txt"
du -h "$TAR" | tee "$DEST/BACKUP-SIZE.txt"

echo "FULL_BACKUP=PASS"
echo "BACKUP_SCOPE=WEB_MEDIAMTX_NGINX_TLS_SYSTEM_STATE"
echo "BACKUP_DIR=$DEST"
echo "BACKUP=$TAR"
