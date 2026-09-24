# Segurança

- Não guardar senhas, tokens, chaves RTMP, certificados privados ou credenciais no repositório.
- O projeto web não precisa conhecer credenciais de publicação do MediaMTX.
- `/assets/now/*.json` deve conter somente metadados públicos da programação.
- Backups do NS1 que incluam `/etc/letsencrypt` devem permanecer fora do GitHub.
- O deploy web não deve alterar firewall, DNS, MediaMTX, Liquidsoap, RadioBOSS ou qualquer mecanismo de origem/automação de áudio.
