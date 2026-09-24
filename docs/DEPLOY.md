# Deploy seguro no NS1

## Regra

A camada web é independente da origem de áudio. O deploy não controla nem modifica serviços de mídia.

## Único entrypoint

```bash
sudo bash scripts/deploy-production.sh
```

Não use scripts históricos de deploy. Eles foram removidos do branch atual para evitar caminhos concorrentes.

## Gates antes de produção

O próprio deploy executa:

```bash
python3 tests/validate_project.py
node --check assets/js/stations.js
node --check assets/js/hls-controller.js
node --check player/sw.js
bash tests/nginx_integration.sh
```

O teste Nginx isolado usa portas alternativas e reproduz a configuração do projeto sem tocar na instância de produção.

## Mutação permitida

Somente:

- `/var/www/studiosat-radio-portal`
- `/var/www/studiosat-radio-player`
- `/var/www/studiosat-radio-app`
- `/var/www/studiosat-radio-assets`
- `/etc/nginx/conf.d/20-studiosat-radio-clean.conf`
- remoção de `/etc/nginx/conf.d/studiosat-radio-v2.conf`, se ainda existir;
- `systemctl reload nginx`.

A configuração compartilhada `/etc/nginx/sites-available/studiosat` é verificada por SHA256 e não é alterada.

## Backup e rollback

Antes da troca, o deploy cria:

```text
/var/backups/studiosat/PORTAL-APP-PRODUCTION/<timestamp>/
```

Rollback manual:

```bash
sudo bash scripts/rollback-production.sh /var/backups/studiosat/PORTAL-APP-PRODUCTION/<timestamp>
```

## Critérios de aprovação

A release só é declarada aprovada quando houver:

```text
RELEASE_GATES=PASS
WEB_BACKUP=PASS
NGINX_LOCAL=12/12
NGINX_PUBLIC=12/12
APP_PWA_ROUTES=PASS
SHARED_NGINX_CHANGED=NO
MEDIA_STACK_CHANGED=NO
SYSTEMD_CHANGED=NO
DNS_CHANGED=NO
FIREWALL_CHANGED=NO
TV_CHANGED=NO
ONLY_SERVICE_OPERATION=NGINX_RELOAD
PORTAL_APP_PRODUCTION=PASS
```
