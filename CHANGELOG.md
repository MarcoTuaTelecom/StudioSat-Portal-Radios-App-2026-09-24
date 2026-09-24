# Changelog

## 2026-09-24 — reconstrução limpa

- separa portal, player/app e infraestrutura web;
- remove dependência implícita de P2 da camada web;
- fixa `hls.js` em `1.7.3`;
- adiciona fallback de carregamento para a biblioteca HLS;
- trava `defaultPlaybackRate` e `playbackRate` em `1.0`;
- define `maxLiveSyncPlaybackRate: 1.0` e `lowLatencyMode: false`;
- tratamento diferenciado de erro de rede e de mídia;
- Service Worker não faz cache de HLS, segmentos ou metadados `now playing`;
- favoritos persistidos em `localStorage`;
- seleção por hostname e `?station=`;
- central de instalação PWA;
- Nginx dedicado a 12 hostnames de rádio;
- Central PWA canônica em `radio.studiosatweb.com.br/app/`; acessos `/app/` pelos hosts `www` redirecionam para a origem instalável;
- deploy transacional independente do estado do P2 e com rollback automático;
- deploy baixa HLS.js 1.7.3 para arquivo temporário depois do backup completo e instala o bundle no stage sem alterar o checkout;
- scripts de backup, deploy e rollback web;
- validação estática e browser smoke test;
- auditoria final do repositório GitHub antes da instalação no NS1.
