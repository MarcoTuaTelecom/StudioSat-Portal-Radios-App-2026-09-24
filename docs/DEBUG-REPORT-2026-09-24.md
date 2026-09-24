# Relatório de debug — 2026-09-24

## Base analisada

- `candidates/CHG-RWEB01/portal/index.html`
- `candidates/CHG-RWEB01/player/index.html`
- `candidates/CHG-RWEB01/nginx-radio-isolated-v1.conf`
- evidências históricas do app/PWA no backup forense do NS1.

## Problemas corrigidos na reconstrução

1. HLS.js antigo usava `@1` sem fixar versão; agora a versão é `1.7.3`.
2. Player antigo não bloqueava explicitamente `playbackRate`; agora `defaultPlaybackRate=1`, `playbackRate=1` e `maxLiveSyncPlaybackRate=1.0`.
3. Tratamento de erro HLS fatal foi separado em rede e mídia, com limites de retentativa.
4. PWA e favoritos voltaram ao projeto-fonte.
5. Service Worker ignora HLS, segmentos e metadata ao vivo.
6. Portal/app não dependem mais do estado do P2 para serem implantados.
7. Nginx de rádio foi isolado da lógica de playout.
8. Central de instalação foi reconstruída.
9. O código não inventa o APK Android: a origem histórica do APK não está versionada no repositório analisado.
10. Scripts de backup, deploy e rollback foram separados.

## Segunda revisão antes do GitHub

11. O validador de segredos varria `.git/hooks` e gerava falso positivo; `.git`, `__pycache__` e vendor externo foram excluídos da varredura sem reduzir a checagem do código do projeto.
12. A Central de instalação não registrava Service Worker nem expunha manifest em sua origem canônica; corrigido.
13. A Central aberta em hosts `www` poderia sugerir PWA da origem errada; `/app/` em `www.*` agora redireciona para `radio.studiosatweb.com.br/app/`.
14. O deploy anterior não eliminava os conflitos Nginx legados já identificados no NS1; o novo deploy é transacional, preserva TV e desativa somente os conflitos de rádio conhecidos.
15. O deploy anterior não exigia bundle HLS.js oficial; agora o backup completo acontece primeiro, depois o bundle 1.7.3 é baixado para `/run`, validado e injetado no stage sem alterar o checkout.

## Testes executados

- `python3 tests/validate_project.py` → PASS
- `python3 tests/browser_smoke.py` → PASS
- `bash -n scripts/*.sh` → PASS
- `node --check assets/js/stations.js` → PASS
- `node --check assets/js/hls-controller.js` → PASS
- Nginx `-t` com certificado temporário e a configuração de produção → PASS
- inspeção visual desktop do portal e player em Chromium headless → PASS

## O que o debug local não prova

O teste local não substitui a certificação ponta a ponta no NS1. Depois do deploy ainda será necessário validar:

- TLS e DNS reais;
- 12 hostnames públicos;
- os 5 manifests HLS reais;
- avanço de segmentos;
- áudio real por tempo prolongado;
- comportamento em Android/iOS reais;
- APK histórico, caso seja recuperado.
