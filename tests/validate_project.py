#!/usr/bin/env python3
from pathlib import Path
import json,re,sys
from html.parser import HTMLParser
ROOT=Path(__file__).resolve().parents[1]
errors=[]
required=['portal/index.html','player/index.html','player/manifest.webmanifest','player/sw.js','app/index.html','assets/js/stations.js','assets/js/hls-controller.js','assets/vendor/hls.min.js','nginx/studiosat-radio-clean.conf','scripts/backup-web.sh','scripts/deploy-web.sh']
for rel in required:
    p=ROOT/rel
    if not p.is_file() or p.stat().st_size==0: errors.append(f'missing:{rel}')
class P(HTMLParser): pass
for rel in ['portal/index.html','player/index.html','app/index.html']:
    try: P().feed((ROOT/rel).read_text(encoding='utf-8'))
    except Exception as e: errors.append(f'html:{rel}:{e}')
manifest=json.loads((ROOT/'player/manifest.webmanifest').read_text(encoding='utf-8'))
for key in ['name','short_name','start_url','scope','display','icons']:
    if key not in manifest: errors.append('manifest:'+key)
js=(ROOT/'assets/js/hls-controller.js').read_text(encoding='utf-8')
for token in ['lowLatencyMode:false','maxLiveSyncPlaybackRate:1.0','defaultPlaybackRate=1','playbackRate=1','NETWORK_RETRY_MAX=5','MEDIA_RETRY_MAX=2']:
    if token not in js: errors.append('hls-controller:'+token)
sw=(ROOT/'player/sw.js').read_text(encoding='utf-8')
for token in ['m3u8','m4s','aac','/assets/now/','cache:\'no-store\'']:
    if token not in sw: errors.append('service-worker:'+token)
stations=(ROOT/'assets/js/stations.js').read_text(encoding='utf-8')
slugs=re.findall(r"slug:'([^']+)'",stations)
expected=['radioprincipal','radiopop','radiorock','radioclassicas','radiocountry']
if slugs!=expected: errors.append(f'stations:{slugs}')
ng=(ROOT/'nginx/studiosat-radio-clean.conf').read_text(encoding='utf-8')
for slug in expected:
    if slug not in ng: errors.append('nginx:'+slug)
for host in ['radio.studiosatweb.com.br','www.radio.studiosatweb.com.br']:
    if host not in ng: errors.append('nginx-host:'+host)

app=(ROOT/'app/index.html').read_text(encoding='utf-8')
for token in ['/manifest.webmanifest',"navigator.serviceWorker.register('/sw.js')",'beforeinstallprompt']:
    if token not in app: errors.append('app-pwa:'+token)
for token in ['www.radio.studiosatweb.com.br','return 302 https://radio.studiosatweb.com.br/app/;']:
    if token not in ng: errors.append('nginx-app:'+token)

for p in ROOT.rglob('*'):
    rel=p.relative_to(ROOT)
    if any(part in {'.git','__pycache__'} for part in rel.parts):
        continue
    if rel.as_posix().startswith('assets/vendor/'):
        continue
    if p.name == 'validate_project.py':
        continue
    if p.is_file() and p.stat().st_size<2_000_000 and p.suffix.lower() in {'.md','.txt','.html','.js','.json','.py','.sh','.conf','.svg'}:
        txt=p.read_text(encoding='utf-8',errors='ignore')
        if re.search(r'(?i)(password|passwd|token|secret)\s*[=:]\s*[\"\']?[^\s\"\']{8,}',txt): errors.append('possible-secret:'+str(rel))
if errors:
    print('VALIDATION=FAIL')
    for e in errors: print(' -',e)
    sys.exit(1)
print('VALIDATION=PASS')
print('FILES_REQUIRED=',len(required))
print('STATIONS=5/5')
print('PLAYBACK_RATE_LOCK=PASS')
print('SERVICE_WORKER_LIVE_MEDIA_BYPASS=PASS')
