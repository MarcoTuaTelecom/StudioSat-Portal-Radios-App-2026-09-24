# Deploy — Player + Portal limpos (2026-09-27)

## Corrige
1. Remove portal premium com vídeo ~27 MB (principal causa de engasgo).
2. Remove metadados/letras inventados.
3. Player HLS baixa latência (~4–8 s com segmentos de 2 s).
4. Nginx sem cookieCheck no HLS.
5. Portal e player separados (`www.*` vs `radio.*`).

## No NS1 (root)

```bash
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p /var/backups/studiosat/clean-$TS
cp -a /var/www/studiosat-radio-player /var/backups/studiosat/clean-$TS/ 2>/dev/null || true
cp -a /var/www/studiosat-radio-portal /var/backups/studiosat/clean-$TS/ 2>/dev/null || true
cp -a /var/www/studiosat-radio-assets /var/backups/studiosat/clean-$TS/ 2>/dev/null || true

# Clone/checkout branch fix/player-limpo-baixa-latencia e entre em clean/
mkdir -p /var/www/studiosat-radio-player /var/www/studiosat-radio-portal /var/www/studiosat-radio-assets
rsync -a --delete player/ /var/www/studiosat-radio-player/
rsync -a --delete portal/ /var/www/studiosat-radio-portal/
rsync -a --delete assets/ /var/www/studiosat-radio-assets/
mkdir -p /var/www/studiosat-radio-assets/vendor
curl -fsSL -o /var/www/studiosat-radio-assets/vendor/hls.min.js https://cdn.jsdelivr.net/npm/hls.js@1.5.17/dist/hls.min.js

cp nginx/studiosat-radio-clean.conf /etc/nginx/sites-available/studiosat-radio-clean.conf
ln -sfn /etc/nginx/sites-available/studiosat-radio-clean.conf /etc/nginx/sites-enabled/studiosat-radio-clean.conf
# Desative vhosts premium de rádio conflitantes (não mexa em TV)
nginx -t && systemctl reload nginx
```

## Teste
```bash
curl -sI https://radio.studiosatweb.com.br/ | grep -i x-studiosat
curl -s https://radio.studiosatweb.com.br/radioprincipal/index.m3u8 | head
```
Esperado: `X-StudioSat-Web: player-clean-20260927`

## Latência
Segmentos ~2 s + liveSyncDurationCount 2 ⇒ atraso típico **4–8 segundos**.
Minutos de atraso vinham do portal premium, não do MediaMTX.
