const CACHE='studiosat-pwa-2026-09-24-v3';
const STATIC=[
  '/manifest.webmanifest',
  '/assets/icons/icon.svg',
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
        .catch(()=>caches.match(event.request).then(hit=>hit||caches.match('/')))
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
