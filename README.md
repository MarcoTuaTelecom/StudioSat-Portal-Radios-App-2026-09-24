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
Fonte de áudio (RadioBOSS / futura camada de ingestão)
        ↓ RTMP
MediaMTX no NS1
        ↓ HLS :8888
Nginx
        ├── www.radio...       → portal/
        ├── radio...           → player/
        ├── /assets/           → assets/
        └── /<radio>/...       → MediaMTX HLS
```

O portal e o app **não dependem de P2, Liquidsoap, FFmpeg ou RadioBOSS** para existir. Eles apenas consomem o HLS que estiver disponível no MediaMTX.

## HLS.js

O repositório inclui um *bootstrap loader* de desenvolvimento fixado em `hls.js 1.7.3`. **O deploy de produção não aceita esse loader como dependência final**: depois do backup completo e antes de qualquer mutação na web/Nginx, ele baixa o bundle oficial `1.7.3` para um arquivo temporário, valida o tamanho e instala esse bundle no stage de produção sem alterar o checkout do repositório. Também é possível atualizar manualmente o arquivo vendor do checkout com:

```bash
sudo bash scripts/fetch-hls-vendor.sh
```

Quando chamado sem argumento, esse script substitui `assets/vendor/hls.min.js` pelo bundle oficial `1.7.3`. O deploy automático passa um destino temporário e mantém o checkout imutável.

## Validação local

```bash
python3 tests/validate_project.py
python3 tests/browser_smoke.py
```

O smoke test usa Chromium headless e não precisa de um stream real para validar navegação, seleção de rádios, favoritos, PWA e bloqueio de `playbackRate`.

## Deploy

**Não execute antes de revisar o NS1 atual.** O deploy faz backup da camada web antes de trocar arquivos.

```bash
sudo bash scripts/backup-web.sh
sudo bash scripts/deploy-web.sh
```

O `deploy-web.sh` não inicia, para ou reinicia MediaMTX, P2 ou qualquer playout. Ele exige backup completo do NS1, instala a camada web de forma transacional, remove somente os conflitos Nginx de rádio conhecidos, testa `nginx -t`, recarrega Nginx e valida os 12 hosts localmente. O estado das fontes de áudio é apenas reportado, nunca usado como gate da web.

## Origem

Este projeto foi reconstruído a partir do candidato histórico `candidates/CHG-RWEB01` do repositório StudioSat existente e dos recursos já existentes no app antigo (cinco rádios, favoritos, PWA e central de instalação). O código deste repositório é uma nova base datada de 2026-09-24.

## Ícone PWA

O manifesto usa `assets/icons/icon.svg` (`sizes: any`) para manter o projeto fonte inteiramente textual e auditável.
