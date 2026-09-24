#!/usr/bin/env python3
from pathlib import Path
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from urllib.parse import urlparse
from threading import Thread
import mimetypes
from playwright.sync_api import sync_playwright
R=Path(__file__).resolve().parents[1]
HLS="""window.Hls=class Hls{static isSupported(){return true}static Events={MANIFEST_PARSED:'manifest',ERROR:'error'};static ErrorTypes={NETWORK_ERROR:'network',MEDIA_ERROR:'media'};constructor(c){window.__hlsConfig=c;this.h={}}on(e,f){this.h[e]=f}loadSource(u){window.__lastHlsUrl=u}attachMedia(m){this.m=m;setTimeout(()=>this.h.manifest&&this.h.manifest(),10)}destroy(){}startLoad(){}recoverMediaError(){}};"""
class H(BaseHTTPRequestHandler):
 def do_GET(self):
  p=urlparse(self.path).path
  if p=='/': f=R/'portal/index.html'
  elif p.startswith('/emissora') or p.startswith('/noticias') or p.startswith('/programacao') or p.startswith('/sobre') or p.startswith('/contato'): f=R/'portal/index.html'
  elif p in ['/listen','/listen/']: f=R/'listen/index.html'
  elif p=='/listen/manifest.webmanifest': f=R/'listen/manifest.webmanifest'
  elif p=='/listen/sw.js': f=R/'listen/sw.js'
  elif p in ['/app','/app/']: f=R/'app/index.html'
  elif p=='/assets/vendor/hls.min.js': self.send_response(200);self.send_header('Content-Type','application/javascript');self.end_headers();self.wfile.write(HLS.encode());return
  elif p.endswith('.m3u8'): self.send_response(200);self.send_header('Content-Type','application/vnd.apple.mpegurl');self.end_headers();self.wfile.write(b'#EXTM3U\n#EXTINF:2,\nseg.ts\n');return
  elif p.endswith('.ts'): self.send_response(200);self.end_headers();self.wfile.write(b'x');return
  else: f=R/p.lstrip('/')
  if not f.is_file(): self.send_response(404);self.end_headers();return
  b=f.read_bytes(); self.send_response(200);self.send_header('Content-Type',mimetypes.guess_type(str(f))[0] or 'application/octet-stream');self.end_headers();self.wfile.write(b)
 def log_message(self,*a):pass
srv=ThreadingHTTPServer(('127.0.0.1',0),H); Thread(target=srv.serve_forever,daemon=True).start(); base=f'http://127.0.0.1:{srv.server_port}'
with sync_playwright() as p:
 b=p.chromium.launch(headless=True,args=['--no-sandbox']); c=b.new_context(service_workers='block')
 c.add_init_script("""HTMLMediaElement.prototype.canPlayType=function(){return ''};HTMLMediaElement.prototype.play=function(){Object.defineProperty(this,'paused',{value:false,configurable:true});this.dispatchEvent(new Event('playing'));return Promise.resolve()};HTMLMediaElement.prototype.pause=function(){Object.defineProperty(this,'paused',{value:true,configurable:true});this.dispatchEvent(new Event('pause'))};""")
 page=c.new_page();page.goto(base+'/',wait_until='networkidle');page.wait_for_selector('.station-card');assert page.locator('.station-card').count()==5;assert page.locator('.ad-card').count()>=2;assert page.locator('img').count()>=8;txt=page.locator('body').inner_text();assert 'Pronto para dados de audiência reais' not in txt;assert 'Conteúdo visual próprio' not in txt
 page.locator('#pPlay').click();page.wait_for_timeout(100);assert page.locator('#pSignal span').inner_text()=='Ao vivo';assert page.evaluate("document.getElementById('audio').playbackRate")==1
 page2=c.new_page();page2.goto(base+'/listen/?station=radiopop',wait_until='networkidle');page2.wait_for_timeout(150);assert page2.locator('.stationCard').count()==5;assert 'POP' in page2.locator('#stationTitle').inner_text().upper();assert page2.locator('#promoBadge').inner_text() in ['PUBLICIDADE','APP','DESTAQUE'];page2.locator('#favoriteBtn').click();assert page2.evaluate("JSON.parse(localStorage.getItem('studiosat:favorites')).includes('radiopop')");page2.reload(wait_until='networkidle');assert page2.locator('#favoriteBtn').inner_text()=='♥';page2.evaluate("document.getElementById('audio').playbackRate=1.5");page2.wait_for_timeout(50);assert page2.evaluate("document.getElementById('audio').playbackRate")==1
 page3=c.new_page();page3.goto(base+'/app/',wait_until='domcontentloaded');assert 'CENTRAL OFICIAL DE INSTALAÇÃO' in page3.locator('body').inner_text().upper()
 b.close()
srv.shutdown()
print('BROWSER_E2E=PASS');print('PORTAL_RICH_VISUAL=PASS');print('ADS=PASS');print('APP_5_STATIONS=PASS');print('FAVORITES_PERSIST=PASS');print('PLAYBACK_RATE_LOCK=PASS');print('INSTALL_CENTER=PASS')
