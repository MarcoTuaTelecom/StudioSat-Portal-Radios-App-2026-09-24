const CACHE="studiosat-clean-v1";
const PRECACHE=["/","/index.html","/manifest.webmanifest","/assets/css/app.css","/assets/js/stations.js","/assets/js/player-engine.js","/assets/icons/icon.svg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(PRECACHE)).then(()=>self.skipWaiting()))});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{const u=new URL(e.request.url),p=u.pathname;
if(p.includes(".m3u8")||p.includes(".ts")||p.includes(".m4s")||p.includes(".aac")||/\/radio(principal|pop|rock|classicas|country)\//.test(p)){e.respondWith(fetch(e.request));return;}
if(e.request.method!=="GET")return;
e.respondWith(caches.match(e.request).then(hit=>hit||fetch(e.request).then(res=>{if(!res||res.status!==200||res.type==="opaque")return res;const copy=res.clone();caches.open(CACHE).then(c=>c.put(e.request,copy));return res;}));});
