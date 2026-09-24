# StudioSat Portal + App — 2026-09-24

Projeto do portal público e do aplicativo/PWA das cinco rádios Studio Sat.

## Escopo atual

Este repositório contém somente a camada web:

- portal das 5 rádios;
- player/app;
- PWA instalável;
- favoritos;
- Central de instalação;
- metadados `now playing` opcionais;
- HLS.js 1.7.3;
- Nginx dedicado às rádios;
- testes de release;
- deploy e rollback exclusivamente da camada web.

A origem de áudio não pertence a este projeto. O navegador apenas consome HLS do MediaMTX através do Nginx.

## Emissoras

- `radioprincipal`
- `radiopop`
- `radiorock`
- `radioclassicas`
- `radiocountry`

## Arquitetura

```text
fonte externa
    ↓
MediaMTX
    ↓ HLS
Nginx
    ├── radio.*      → player/app
    ├── www.radio.*  → portal
    ├── /assets/     → assets web
    └── /<radio>/    → proxy HLS
```

## PWA

O manifesto inclui:

- `id: /`;
- `start_url: /`;
- `scope: /`;
- `display: standalone`;
- ícones PNG 192x192 e 512x512;
- ícone SVG complementar;
- Service Worker com mídia ao vivo sempre `no-store`.

O HTML de navegação também é entregue com política `no-store` no Nginx para impedir que a antiga página de manutenção volte por cache.

## HLS.js

Produção usa exatamente hls.js `1.7.3`.

O script `scripts/fetch-hls-vendor.sh` verifica o bundle por SHA256:

```text
a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e
```

Conteúdo divergente é rejeitado.

## Gates de release

Antes de qualquer deploy:

```bash
python3 tests/validate_project.py
python3 tests/browser_smoke.py
bash tests/nginx_integration.sh
```

O teste Nginx sobe uma instância isolada em portas alternativas e verifica:

- sintaxe real do Nginx;
- 12 hostnames;
- portal e player corretos;
- rota `/app/` retornando 200;
- manifest, Service Worker, JS, CSS e ícones;
- ausência da página antiga de construção;
- política `no-store` para HTML;
- redirecionamento da Central de instalação.

## Deploy de produção

Existe somente um entrypoint de produção:

```bash
sudo bash scripts/deploy-production.sh
```

Ele:

1. executa todos os gates locais;
2. valida Nginx, TLS e resolução dos 12 hostnames;
3. faz backup transacional da camada web;
4. baixa e verifica criptograficamente HLS.js;
5. monta um stage e compara hashes com o projeto-fonte;
6. substitui somente os diretórios web das rádios e o vhost dedicado;
7. executa `nginx -t`;
8. recarrega somente Nginx;
9. certifica os 12 hosts localmente;
10. certifica os 12 hosts pela rota pública.

Não altera configuração compartilhada, DNS, firewall, systemd, TVs ou serviços de mídia.

## Rollback

```bash
sudo bash scripts/rollback-production.sh /var/backups/studiosat/PORTAL-APP-PRODUCTION/<timestamp>
```

O rollback atua somente sobre a camada web e recarrega Nginx.
