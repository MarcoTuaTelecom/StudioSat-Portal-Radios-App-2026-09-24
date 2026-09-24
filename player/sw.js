const CACHE='studiosat-pwa-2026-09-24-v4';
const STATIC=[
  '/manifest.webmanifest',
  '/assets/icons/icon.svg',
  '/assets/icons/icon-192.png',
  '/assets/icons/icon-512.png',
  '/assets/css/base.css',
  '/assets/css/player.css',
  '/assets/js/stations.js',
  '/assets/js/hls-controller.js',
  '/assets/vendor/hls.min.js'
];

function isLiveMedia(url){
  return /\/(radioprincipal|radiopop|radiorock|radioclassicas|radiocountry)\//.test(url.pathname)
    || /\.(m3u8|ts|m4s|aac|mp4)(\?|$)/i.test(url.pathname)
    || url.pathname.startsWith('/assets/now/');
}

function isNavigation(request){
  return request.mode==='navigate'
    || (request.headers.get('accept')||'').includes('text/html');
}

self.addEventListener('install',event=>{
  event.waitUntil(
    caches.open(CACHE)
      .then(cache=>cache.addAll(STATIC))
      .then(()=>self.skipWaiting())
  );
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys()
      .then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k))))
      .then(()=>self.clients.claim())
  );
});

self.addEventListener('fetch',event=>{
  const url=new URL(event.request.url);

  if(isLiveMedia(url)){
    event.respondWith(fetch(event.request,{cache:'no-store'}));
    return;
  }

  if(event.request.method!=='GET') return;

  if(isNavigation(event.request)){
    event.respondWith(
      fetch(event.request,{cache:'no-store'})
        .then(response=>{
          if(response && response.status===200){
            const copy=response.clone();
            caches.open(CACHE).then(cache=>cache.put(event.request,copy));
          }
          return response;
        })
        .catch(async()=>{
          const hit=await caches.match(event.request);
          if(hit) return hit;
          return new Response(
            '<!doctype html><meta charset="utf-8"><title>Rádio Studio Sat</title><h1>Rádio Studio Sat</h1><p>Sem conexão no momento.</p>',
            {status:503,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store'}}
          );
        })
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then(hit=>{
      if(hit) return hit;
      return fetch(event.request).then(response=>{
        if(!response || response.status!==200 || response.type==='opaque') return response;
        const copy=response.clone();
        caches.open(CACHE).then(cache=>cache.put(event.request,copy));
        return response;
      });
    })
  );
});
