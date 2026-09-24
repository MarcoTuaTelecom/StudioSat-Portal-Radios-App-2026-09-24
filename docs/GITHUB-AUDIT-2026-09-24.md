# Auditoria GitHub — 2026-09-24

Repositório: `MarcoTuaTelecom/StudioSat-Portal-Radios-App-2026-09-24`

## Escopo auditado

- portal público;
- player/app PWA;
- Central de instalação;
- cinco emissoras;
- HLS controller;
- Service Worker;
- Nginx das rádios;
- backup completo do stack atual do NS1;
- deploy transacional;
- rollback;
- validadores locais.

## Resultado dos testes locais

```text
VALIDATION=PASS
STATIONS=5/5
PLAYBACK_RATE_LOCK=PASS
SERVICE_WORKER_LIVE_MEDIA_BYPASS=PASS
BROWSER_SMOKE=PASS
PLAYER_5_STATIONS=PASS
FAVORITES=PASS
HLS_CONFIG_RATE_1=PASS
PORTAL_5_STATIONS=PASS
APP_INSTALL_CENTER=PASS
bash -n scripts/*.sh=PASS
node --check assets/js/*.js=PASS
node --check player/sw.js=PASS
```

## Decisões de produção

1. A camada web é independente de qualquer mecanismo de playout.
2. O único gate de mídia do deploy web é o MediaMTX canônico estar ativo como backend HLS.
3. O backup completo do stack atual ocorre antes de qualquer mutação.
4. HLS.js 1.7.3 é baixado depois do backup para arquivo temporário em `/run`, validado por tamanho e instalado no stage; o checkout Git não é modificado.
5. O deploy não instala nem controla qualquer playout e não reinicia MediaMTX.
6. O deploy remove somente conflitos Nginx conhecidos da camada de rádio e preserva as rotas de TV.
7. `playbackRate`, `defaultPlaybackRate` e `maxLiveSyncPlaybackRate` permanecem em `1.0`.
8. O Service Worker não cacheia manifests/segmentos HLS nem `now playing`.
9. O estado dos cinco HLS é reportado ao final, mas não é gate para a existência do portal.
10. Qualquer função futura de ingestão, fallback ou automação será implementada como componente independente, fora deste projeto web.

## Limites do debug local

O PASS local não substitui a certificação no NS1. Depois do deploy ainda serão verificados TLS/DNS reais, 12 hosts HTTPS, assets públicos, os cinco manifests HLS disponíveis naquele momento e o comportamento em navegadores/dispositivos reais.
