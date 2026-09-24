# Deploy seguro no NS1

## Pré-condição

A camada web é independente de qualquer mecanismo de playout. Uma rádio sem publisher pode ficar sem áudio, mas isso não bloqueia a instalação do portal/app. O único gate de mídia do deploy é o MediaMTX canônico estar ativo, pois ele é o backend HLS esperado pela configuração.

## Execução

1. `python3 tests/validate_project.py`
2. `python3 tests/browser_smoke.py` (ambiente de desenvolvimento)
3. No NS1, execute **somente** `sudo bash scripts/deploy-web.sh`.
4. O deploy chama `scripts/backup-ns1-complete.sh` antes de qualquer mutação.
5. Depois do backup completo, baixa HLS.js 1.7.3 para `/run`, valida o tamanho e não modifica o checkout.
6. Faz backup transacional da web/Nginx.
7. Instala portal, player/PWA, app e assets.
8. Desativa os conflitos Nginx de rádio conhecidos e remove os cinco paths de rádio da regex compartilhada com TV, preservando os paths de TV.
9. Executa `nginx -t`; em qualquer erro, restaura automaticamente a camada web anterior.
10. Recarrega somente Nginx.
11. Valida localmente os 12 hosts HTTPS com `curl --resolve`.
12. Consulta os cinco HLS e reporta quantos estão online, sem controlar a origem.

## Não faz

- não reinicia MediaMTX;
- não instala nem controla playout;
- não instala Liquidsoap;
- não altera RadioBOSS;
- não altera DNS/firewall;
- não altera serviços de TV.

## Resultado esperado

`DEPLOY_WEB=PASS`, `HOSTS_WEB=12/12` e `HLS_ONLINE=N/5`. O valor de `N` depende das fontes externas que estiverem publicando naquele instante.
