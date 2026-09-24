# Arquitetura web Studio Sat

A aplicação começa **depois** do MediaMTX. O navegador conhece apenas o HLS publicado pelo MediaMTX e não conhece nem controla a origem de áudio.

```text
/radioprincipal/index.m3u8
/radiopop/index.m3u8
/radiorock/index.m3u8
/radioclassicas/index.m3u8
/radiocountry/index.m3u8
```

O Nginx encaminha esses paths para `http://127.0.0.1:8888`, que é o HLS do MediaMTX.

## Hostnames

Player/App:

- `radio.studiosatweb.com.br`
- `radioprincipal.studiosatweb.com.br`
- `radiopop.studiosatweb.com.br`
- `radiorock.studiosatweb.com.br`
- `radioclassicas.studiosatweb.com.br`
- `radiocountry.studiosatweb.com.br`

Portal:

- `www.radio.studiosatweb.com.br`
- `www.radioprincipal.studiosatweb.com.br`
- `www.radiopop.studiosatweb.com.br`
- `www.radiorock.studiosatweb.com.br`
- `www.radioclassicas.studiosatweb.com.br`
- `www.radiocountry.studiosatweb.com.br`

## Regras de estabilidade do áudio

- nunca alterar `playbackRate` para recuperar atraso;
- `maxLiveSyncPlaybackRate = 1.0`;
- `lowLatencyMode = false`;
- recuperar erro de rede sem recriar loops agressivos;
- tentar `recoverMediaError()` no máximo duas vezes por sessão;
- não cachear manifesto, segmento ou metadado ao vivo no Service Worker;
- não usar Service Worker como proxy de áudio.

## Separação de responsabilidades

A camada web não cria, processa, recodifica, alterna nem recupera a fonte de áudio. Qualquer tecnologia futura de ingestão ou automação deve ser um componente independente, com contrato claro de publicação no MediaMTX.
