#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
R=Path(__file__).resolve().parents[1]; e=[]
req=['portal/index.html','listen/index.html','listen/manifest.webmanifest','listen/sw.js','app/index.html','assets/content.json','assets/portal-complete.css','assets/media-engine.js','assets/portal-complete.js','assets/ref/hero-v5.webp','assets/ref/about-v5.webp','assets/ref/news-studio-v5.webp','assets/ref/news-mobile-v5.webp','assets/ref/program-1-v5.webp','assets/ref/program-2-v5.webp','assets/ref/program-3-v5.webp','nginx/studiosat-radio-complete.conf','scripts/probe-live-contract.sh','tests/nginx_complete_integration.sh','tests/browser_complete.py']
for x in req:
 p=R/x
 if not p.is_file() or p.stat().st_size==0:e.append('missing:'+x)
bad=['Área preparada para conteúdo editorial real','Pronto para dados de audiência reais','Espaço editorial sem dados inventados','Conteúdo visual próprio','Pronto para integração futura']
for x in ['portal/index.html','listen/index.html','app/index.html']:
 t=(R/x).read_text(errors='ignore')
 for b in bad:
  if b.lower() in t.lower():e.append('placeholder:'+x)
d=json.loads((R/'assets/content.json').read_text()); ids=[x.get('id') for x in d.get('stations',[])]; exp=['radioprincipal','radiopop','radiorock','radioclassicas','radiocountry']
if ids!=exp:e.append('stations')
if len(d.get('site',{}).get('promotions',[]))<2:e.append('ads')
for s in d.get('stations',[]):
 if s.get('stream')!=f"/{s['id']}/index.m3u8":e.append('stream:'+s['id'])
 if not str(s.get('art','')).startswith('/assets/ref/'):e.append('station-art:'+s['id'])
 for k in ['art','hero','schedule','playlist','news','team','promotions']:
  if not s.get(k):e.append('content:'+s['id']+':'+k)
l=(R/'listen/index.html').read_text()
for tok in ['PUBLICIDADE','TRADUÇÃO','Favoritos','MediaMetadata','maxLiveSyncPlaybackRate:1.0','lowLatencyMode:false','defaultPlaybackRate=1','playbackRate=1','/assets/content.json','studiosat:favorites','studiosat:lastStation','URLSearchParams','liveState','SINAL PRONTO']:
 if tok not in l:e.append('listen:'+tok)
if re.search(r'createMediaElementSource|createAnalyser',l):e.append('webaudio')
if 'data:image' in l or 'images.unsplash.com' in l:e.append('listen-remote-or-inline-art')
if '\\\\nfunction' in l:e.append('listen-literal-backslash-newline')
p=(R/'portal/index.html').read_text()
for tok in ['complete-rebuild-2026-09-24','/assets/portal-complete.css']:
 if tok not in p:e.append('portal:'+tok)
j=(R/'assets/portal-complete.js').read_text()
for tok in ['Destaques & Publicidade','station-card-art','/assets/content.json',"$('[data-toggle]').forEach"]:
 if tok not in j:e.append('portal-js:'+tok)
if 'data:image' in j or 'images.unsplash.com' in j:e.append('portal-js-remote-or-inline-art')
if '\\\\nfunction' in j:e.append('portal-js-literal-backslash-newline')
if 'data:image' in json.dumps(d) or 'images.unsplash.com' in json.dumps(d):e.append('content-remote-or-inline-art')
if e:
 print('VALIDATION=FAIL');[print(' -',x) for x in sorted(set(e))];sys.exit(1)
print('VALIDATION=PASS');print('PRODUCT_PLACEHOLDERS=ABSENT');print('RICH_PORTAL=PASS');print('AD_SLOTS=PASS');print('STATIONS=5/5');print('FULL_WEB_APP=PASS');print('WEB_AUDIO_ANALYSER=ABSENT');print('PLAYBACK_RATE_LOCK=PASS')