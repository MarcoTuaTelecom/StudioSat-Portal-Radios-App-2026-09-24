#!/usr/bin/env python3
from pathlib import Path
import re
from playwright.sync_api import sync_playwright

ROOT=Path(__file__).resolve().parents[1]
HLS_STUB="""window.Hls=class Hls{static isSupported(){return true}static Events={MANIFEST_PARSED:'manifest',ERROR:'error'};static ErrorTypes={NETWORK_ERROR:'network',MEDIA_ERROR:'media'};constructor(c){window.__hlsConfig=c;this.handlers={}}on(e,f){this.handlers[e]=f}loadSource(u){window.__lastHlsUrl=u}attachMedia(){setTimeout(()=>this.handlers.manifest&&this.handlers.manifest(),10)}destroy(){}startLoad(){}recoverMediaError(){}};window.dispatchEvent(new CustomEvent('studiosat:hls-ready'));"""
MEDIA_STUB="""HTMLMediaElement.prototype.canPlayType=function(){return '';};HTMLMediaElement.prototype.play=function(){this.dispatchEvent(new Event('playing'));return Promise.resolve();};HTMLMediaElement.prototype.pause=function(){this.dispatchEvent(new Event('pause'));};"""
LOCALSTORAGE_STUB="""(()=>{const s={};Object.defineProperty(window,'localStorage',{value:{getItem:k=>Object.prototype.hasOwnProperty.call(s,k)?s[k]:null,setItem:(k,v)=>s[k]=String(v),removeItem:k=>delete s[k],clear:()=>Object.keys(s).forEach(k=>delete s[k])}});history.replaceState=()=>{};})();"""

def split_html(path):
    text=path.read_text(encoding='utf-8')
    scripts=re.findall(r'<script>(.*?)</script>',text,re.S)
    cleaned=re.sub(r'<script>.*?</script>','',text,flags=re.S)
    cleaned=re.sub(r'<script[^>]+src="[^"]+"[^>]*></script>','',cleaned,flags=re.I)
    return cleaned,scripts

def add_common(page):
    page.add_script_tag(content=LOCALSTORAGE_STUB)
    page.add_script_tag(content=MEDIA_STUB)
    page.add_script_tag(content=HLS_STUB)
    page.add_script_tag(content=(ROOT/'assets/js/stations.js').read_text(encoding='utf-8'))
    page.add_script_tag(content=(ROOT/'assets/js/hls-controller.js').read_text(encoding='utf-8'))

def run_player(page):
    html,scripts=split_html(ROOT/'player/index.html')
    page.set_content(html)
    add_common(page)
    for s in scripts: page.add_script_tag(content=s)
    page.evaluate("window.dispatchEvent(new Event('DOMContentLoaded'))")
    page.wait_for_timeout(100)
    assert page.locator('#stationTabs button').count()==5
    page.locator('#stationTabs button',has_text='Rock').click();page.wait_for_timeout(50)
    assert page.locator('#stationTitle').inner_text()=='ROCK'
    assert page.evaluate('window.__hlsConfig.lowLatencyMode') is False
    assert page.evaluate('window.__hlsConfig.maxLiveSyncPlaybackRate')==1
    page.evaluate("document.getElementById('audio').playbackRate=1.5")
    page.wait_for_timeout(50)
    assert page.evaluate("document.getElementById('audio').playbackRate")==1
    page.locator('#favorite').click()
    assert page.evaluate("JSON.parse(localStorage.getItem('studiosat:favorites')).includes('radiorock')")
    page.locator('#stationTabs button',has_text='Pop').click();page.wait_for_timeout(50)
    assert page.locator('#stationTitle').inner_text()=='POP'

def run_portal(page):
    html,scripts=split_html(ROOT/'portal/index.html')
    page.set_content(html);add_common(page)
    for s in scripts: page.add_script_tag(content=s)
    page.evaluate("window.dispatchEvent(new Event('DOMContentLoaded'))")
    page.wait_for_timeout(80)
    assert page.locator('#stations .station-card').count()==5
    page.locator('#stations .station-card',has_text='Country').locator('button').click();page.wait_for_timeout(30)
    assert 'radiocountry' in page.locator('#openPlayer').get_attribute('href')

def run_app(page):
    html,scripts=split_html(ROOT/'app/index.html')
    page.set_content(html)
    for s in scripts: page.add_script_tag(content=s)
    assert 'Central de instalação' in page.locator('body').inner_text()

def main():
    with sync_playwright() as p:
        browser=p.chromium.launch(headless=True,executable_path='/usr/bin/chromium',args=['--no-sandbox'])
        ctx=browser.new_context(service_workers='block')
        page=ctx.new_page();run_player(page)
        page=ctx.new_page();run_portal(page)
        page=ctx.new_page();run_app(page)
        browser.close()
    print('BROWSER_SMOKE=PASS')
    print('PLAYER_5_STATIONS=PASS')
    print('FAVORITES=PASS')
    print('PLAYBACK_RATE_LOCK=PASS')
    print('HLS_CONFIG_RATE_1=PASS')
    print('PORTAL_5_STATIONS=PASS')
    print('APP_INSTALL_CENTER=PASS')
if __name__=='__main__': main()
