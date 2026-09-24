#!/usr/bin/env python3
from pathlib import Path
import json,re,sys,struct
from html.parser import HTMLParser
from urllib.parse import urlparse

ROOT=Path(__file__).resolve().parents[1]
errors=[]

required=[
 'portal/index.html','player/index.html','player/manifest.webmanifest','player/sw.js','app/index.html',
 'assets/css/base.css','assets/css/portal.css','assets/css/player.css','assets/css/app.css',
 'assets/js/stations.js','assets/js/hls-controller.js',
 'assets/icons/icon.svg','assets/icons/icon-192.png','assets/icons/icon-512.png',
 'assets/vendor/hls.min.js',
 'nginx/studiosat-radio-clean.conf',
 'scripts/fetch-hls-vendor.sh','scripts/deploy-production.sh','scripts/rollback-production.sh',
 'tests/nginx_integration.sh','tests/browser_smoke.py'
]
for rel in required:
    p=ROOT/rel
    if not p.is_file() or p.stat().st_size==0:
        errors.append(f'missing:{rel}')

class Collector(HTMLParser):
    def __init__(self):
        super().__init__()
        self.refs=[]
    def handle_starttag(self,tag,attrs):
        d=dict(attrs)
        for key in ('src','href'):
            if key in d: self.refs.append((tag,key,d[key]))

html_files=['portal/index.html','player/index.html','app/index.html']
for rel in html_files:
    try:
        text=(ROOT/rel).read_text(encoding='utf-8')
        p=Collector(); p.feed(text)
    except Exception as e:
        errors.append(f'html:{rel}:{e}')
        continue
    if '<meta charset="utf-8">' not in text.lower():
        errors.append(f'html-charset:{rel}')
    for _,_,ref in p.refs:
        if not ref.startswith('/'):
            continue
        path=urlparse(ref).path
        if path=='/manifest.webmanifest':
            target=ROOT/'player/manifest.webmanifest'
        elif path=='/sw.js':
            target=ROOT/'player/sw.js'
        elif path.startswith('/assets/'):
            target=ROOT/path.lstrip('/')
        elif path in ('/app','/app/'):
            target=ROOT/'app/index.html'
        else:
            continue
        if not target.is_file():
            errors.append(f'broken-local-ref:{rel}:{ref}')

manifest=json.loads((ROOT/'player/manifest.webmanifest').read_text(encoding='utf-8'))
for key in ['id','name','short_name','start_url','scope','display','icons']:
    if key not in manifest: errors.append('manifest:'+key)
if manifest.get('start_url')!='/': errors.append('manifest:start_url-must-root')
if manifest.get('scope')!='/': errors.append('manifest:scope-must-root')
if manifest.get('display') not in ('standalone','fullscreen','minimal-ui'): errors.append('manifest:display')
if manifest.get('prefer_related_applications',False) not in (False,None): errors.append('manifest:prefer_related_applications')

icons=manifest.get('icons',[])
by_size={i.get('sizes'):i for i in icons}
for size in ('192x192','512x512'):
    i=by_size.get(size)
    if not i: errors.append('manifest-icon:'+size); continue
    if i.get('type')!='image/png': errors.append('manifest-icon-type:'+size)
    p=ROOT/i.get('src','').lstrip('/')
    if not p.is_file(): errors.append('manifest-icon-file:'+size)

def png_size(path):
    b=path.read_bytes()[:24]
    if len(b)<24 or b[:8]!=b'\x89PNG\r\n\x1a\n': return None
    return struct.unpack('>II',b[16:24])

for size,expected in [('192x192',(192,192)),('512x512',(512,512))]:
    i=by_size.get(size)
    if i:
        p=ROOT/i['src'].lstrip('/')
        if p.is_file() and png_size(p)!=expected:
            errors.append(f'png-dimensions:{size}:{png_size(p)}')

js=(ROOT/'assets/js/hls-controller.js').read_text(encoding='utf-8')
for token in ['lowLatencyMode:false','maxLiveSyncPlaybackRate:1.0','defaultPlaybackRate=1','playbackRate=1','NETWORK_RETRY_MAX=5','MEDIA_RETRY_MAX=2']:
    if token not in js: errors.append('hls-controller:'+token)

sw=(ROOT/'player/sw.js').read_text(encoding='utf-8')
for token in ['studiosat-pwa-2026-09-24-v4','m3u8','m4s','aac','/assets/now/',"cache:'no-store'",'/assets/icons/icon-192.png','/assets/icons/icon-512.png']:
    if token not in sw: errors.append('service-worker:'+token)

stations=(ROOT/'assets/js/stations.js').read_text(encoding='utf-8')
slugs=re.findall(r"slug:'([^']+)'",stations)
expected=['radioprincipal','radiopop','radiorock','radioclassicas','radiocountry']
if slugs!=expected: errors.append(f'stations:{slugs}')

ng=(ROOT/'nginx/studiosat-radio-clean.conf').read_text(encoding='utf-8')
all_hosts=[]
for slug in ['radio']+expected:
    all_hosts += [f'{slug}.studiosatweb.com.br',f'www.{slug}.studiosatweb.com.br']
for host in all_hosts:
    if host not in ng: errors.append('nginx-host:'+host)
for root in ['/var/www/studiosat-radio-player','/var/www/studiosat-radio-portal','/var/www/studiosat-radio-app','/var/www/studiosat-radio-assets']:
    if root not in ng: errors.append('nginx-root:'+root)
if '/var/www/studiosatweb' in ng: errors.append('nginx-old-docroot-present')
if re.search(r'location\s*=\s*/app/\s*\{[^}]*alias\s+[^;]*index\.html\s*;',ng,re.S):
    errors.append('nginx-app:file-alias-forbidden')
if 'location = /app/' not in ng or 'root /var/www/studiosat-radio-app;' not in ng or 'try_files /index.html =404;' not in ng:
    errors.append('nginx-app:root-try-files-required')
if '/etc/nginx/sites-available/studiosat' in ng:
    errors.append('nginx:shared-config-reference-forbidden')

app=(ROOT/'app/index.html').read_text(encoding='utf-8')
for token in ['/manifest.webmanifest',"/assets/icons/icon-192.png","navigator.serviceWorker.register('/sw.js')",'beforeinstallprompt']:
    if token not in app: errors.append('app-pwa:'+token)
player=(ROOT/'player/index.html').read_text(encoding='utf-8')
for token in ['/manifest.webmanifest','/assets/icons/icon-192.png',"navigator.serviceWorker.register('/sw.js')"]:
    if token not in player: errors.append('player-pwa:'+token)

portal=(ROOT/'portal/index.html').read_text(encoding='utf-8')
if "labels[0]==='www'?labels[1]:labels[0]" not in portal:
    errors.append('portal:station-host-selection')

fetch=(ROOT/'scripts/fetch-hls-vendor.sh').read_text(encoding='utf-8')
expected_hls='a12e7ee1cd64a69dcdb314157e45dafcba705bfb0b1440b7935cb265d374423e'
if expected_hls not in fetch: errors.append('hls-vendor:sha256-not-pinned')

# Current main must not carry obsolete deploy entrypoints that can reintroduce older behavior.
for obsolete in ['scripts/deploy-web.sh','scripts/deploy-portal-app-only.sh','scripts/install-ns1-pinned.sh','scripts/repair-live-portal-app-only.sh']:
    if (ROOT/obsolete).exists(): errors.append('obsolete-script-present:'+obsolete)

# Banned legacy marker and stale construction page must not exist in current source.
for p in ROOT.rglob('*'):
    rel=p.relative_to(ROOT)
    if any(part in {'.git','__pycache__'} for part in rel.parts): continue
    if not p.is_file(): continue
    if p.name=='validate_project.py': continue
    if p.suffix.lower() not in {'.md','.txt','.html','.js','.json','.py','.sh','.conf','.svg','.webmanifest'}: continue
    txt=p.read_text(encoding='utf-8',errors='ignore')
    # tests/nginx_integration.sh deliberately contains the stale-page fixture
    # to prove exact radio hostnames beat the legacy wildcard.
    if rel.as_posix()!='tests/nginx_integration.sh' and re.search(r'(?i)studio sat web\s*-\s*em constru',txt):
        errors.append('stale-construction:'+str(rel))
    if re.search(r'(?<![A-Za-z0-9])P2(?![A-Za-z0-9])',txt): errors.append('banned-legacy-marker:'+str(rel))
    if p.name!='validate_project.py' and re.search(r'(?i)(password|passwd|token|secret)\s*[=:]\s*["\']?[^\s"\']{8,}',txt):
        errors.append('possible-secret:'+str(rel))

if errors:
    print('VALIDATION=FAIL')
    for e in sorted(set(errors)): print(' -',e)
    sys.exit(1)

print('VALIDATION=PASS')
print('FILES_REQUIRED=',len(required))
print('STATIONS=5/5')
print('PWA_ICONS=192x192,512x512')
print('PWA_MANIFEST=PASS')
print('PLAYBACK_RATE_LOCK=PASS')
print('SERVICE_WORKER_LIVE_MEDIA_BYPASS=PASS')
print('NGINX_APP_ROUTE_STATIC=PASS')
print('OBSOLETE_DEPLOY_SCRIPTS=ABSENT')
print('LEGACY_MARKER=ABSENT')
