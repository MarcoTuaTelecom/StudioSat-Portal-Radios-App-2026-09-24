# StudioSat Portal + App — 2026-09-24

Projeto limpo e independente do portal público das rádios e do aplicativo/PWA da Studio Sat.

## Escopo

- Portal editorial das 5 rádios.
- Player/app das 5 rádios.
- PWA instalável.
- Favoritos persistentes.
- Central de instalação.
- Metadados `now playing` opcionais.
- HLS com velocidade travada em `1.0`.
- HLS.js fixado em `1.7.3`.
- Service Worker sem cache de mídia ao vivo.
- Nginx isolado para rádio, sem lógica de playout.
- Backup/deploy/rollback separados da aplicação.

## Emissoras

- `radioprincipal`
- `radiopop`
- `radiorock`
- `radioclassicas`
- `radiocountry`

## Arquitetura

```text
Fonte de áudio externa ao projeto web
        ↓ RTMP
MediaMTX no NS1
        ↓ HLS :8888
Nginx
        ├── www.radio...       → portal/
        ├── radio...           → player/
        ├── /assets/           → assets/
        └── /<radio>/...       → MediaMTX HLS
```

O portal e o app são totalmente independentes do mecanismo que publica áudio no MediaMTX. Eles apenas consomem o HLS disponível.

## HLS.js

O repositório inclui um *bootstrap loader* de desenvolvimento fixado em `hls.js 1.7.3`. O deploy de produção baixa o bundle oficial `1.7.3` depois do backup completo e antes de qualquer mutação, valida o tamanho e injeta esse bundle no stage de produção sem alterar o checkout do repositório.

Também é possível atualizar manualmente o vendor do checkout com:

```bash
sudo bash scripts/fetch-hls-vendor.sh
```

## Validação local

```bash
python3 tests/validate_project.py
python3 tests/browser_smoke.py
```

O smoke test usa Chromium headless e não precisa de um stream real para validar navegação, seleção de rádios, favoritos, PWA e bloqueio de `playbackRate`.

## Deploy

No NS1, o deploy exige apenas:

- Nginx ativo;
- MediaMTX canônico ativo;
- TLS válido;
- configuração Nginx compartilhada em estado conhecido.

Ele não controla, instala nem reconstrói qualquer playout. O estado das cinco fontes de áudio é apenas reportado no final.

```bash
sudo bash scripts/deploy-web.sh
```

## Origem

Este projeto foi reconstruído a partir do candidato histórico `candidates/CHG-RWEB01` do repositório StudioSat existente e dos recursos já existentes no app antigo (cinco rádios, favoritos, PWA e central de instalação). O código deste repositório é uma nova base datada de 2026-09-24.

## Ícone PWA

O manifesto usa `assets/icons/icon.svg` (`sizes: any`) para manter o projeto fonte inteiramente textual e auditável.
