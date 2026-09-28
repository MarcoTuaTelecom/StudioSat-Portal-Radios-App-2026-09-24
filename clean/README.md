# Studio Sat — Player + Portal limpos (2026-09-27)

Branch: `fix/player-limpo-baixa-latencia`

Pacote em `clean/`:
- player enxuto (sem vídeo 27MB, sem demo falso)
- portal com links das 5 emissoras
- HLS.js baixa latência (`liveSyncDurationCount: 2`)
- Nginx sem cookieCheck no HLS

Deploy: ver `clean/docs/DEPLOY.md`

Streams reais (já no ar no MediaMTX):
- /radioprincipal/index.m3u8
- /radiopop/index.m3u8
- /radiorock/index.m3u8
- /radioclassicas/index.m3u8
- /radiocountry/index.m3u8
