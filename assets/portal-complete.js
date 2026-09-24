import{MediaEngine}from'/assets/media-engine.js';
const audio=document.getElementById('audio'),engine=new MediaEngine(audio);
engine.restorePrefs();
const $=(s,r=document)=>r.querySelector(s),$$=(s,r=document)=>[...r.querySelectorAll(s)];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let content=null,current=null,heroTimers=[],newsTimer=null;

function mins(t){const[h,m]=String(t||'00:00').split(':').map(Number);return h*60+m}
function schedule(st){
  const a=[...(st.schedule||[])].sort((x,y)=>mins(x.time)-mins(y.time));
  if(!a.length)return{a,idx:-1,cur:null,next:null};
  let n;
  try{
    const f=new Intl.DateTimeFormat('en-GB',{timeZone:'America/Sao_Paulo',hour:'2-digit',minute:'2-digit',hour12:false});
    const p=f.formatToParts(new Date());
    n=+p.find(x=>x.type==='hour').value*60 + +p.find(x=>x.type==='minute').value;
  }catch{n=new Date().getHours()*60+new Date().getMinutes()}
  let idx=a.length-1;
  for(let i=0;i<a.length;i++){
    const start=mins(a[i].time),end=i<a.length-1?mins(a[i+1].time):1440;
    if(n>=start&&n<end){idx=i;break}
  }
  return{a,idx,cur:a[idx],next:a[(idx+1)%a.length]}
}
function stationLogo(){
  return`<div class="station-logo-inner">STUDIO<br>SAT<span class="logo-bars"><i></i><i></i><i></i></span></div>`
}
function hero(items,stationId){
  const arr=(items&&items.length)?items:[{eyebrow:'STUDIO SAT',title:'Mais que rádio, é a sua companhia.',text:'Cinco estilos, uma só emoção.',image:'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201200%20700%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%235b62e8%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23172769%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%221200%22%20height%3D%22700%22%20fill%3D%22url(%23g)%22%2F%3E%3Ccircle%20cx%3D%221020%22%20cy%3D%2290%22%20r%3D%22260%22%20fill%3D%22white%22%20opacity%3D%22.08%22%2F%3E%3Ccircle%20cx%3D%22650%22%20cy%3D%22260%22%20r%3D%22120%22%20fill%3D%22rgba(255%2C255%2C255%2C.15)%22%2F%3E%3Crect%20x%3D%22605%22%20y%3D%22120%22%20width%3D%2290%22%20height%3D%22230%22%20rx%3D%2245%22%20fill%3D%22white%22%20opacity%3D%22.9%22%2F%3E%3Cpath%20d%3D%22M540%20270c0%20120%20220%20120%20220%200M650%20390v100M570%20490h160%22%20stroke%3D%22white%22%20stroke-width%3D%2222%22%20fill%3D%22none%22%20stroke-linecap%3D%22round%22%2F%3E%3Ctext%20x%3D%2270%22%20y%3D%22570%22%20fill%3D%22white%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2272%22%20font-weight%3D%22900%22%3ECINCO%20R%C3%81DIOS.%20UMA%20S%C3%93%20PAIX%C3%83O.%3C%2Ftext%3E%3Ctext%20x%3D%2272%22%20y%3D%22625%22%20fill%3D%22white%22%20opacity%3D%22.78%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2225%22%20font-weight%3D%22700%22%3ER%C3%81DIO%20STUDIO%20SAT%3C%2Ftext%3E%3C%2Fsvg%3E'}];
  return`<section class="hero" data-slider>${arr.map((h,i)=>`<article class="hero-slide ${i===0?'active':''}">
    <img src="${esc(h.image)}" alt="">
    <div class="hero-shade"></div>
    <div class="hero-copy">
      <div class="hero-eyebrow">${esc(h.eyebrow||'STUDIO SAT')}</div>
      <h1>${esc(h.title)}</h1>
      <p>${esc(h.text||'')}</p>
      <button class="hero-cta" data-play="${esc(stationId)}">▶ &nbsp; OUÇA AGORA</button>
    </div>
  </article>`).join('')}
  <div class="hero-dots">${arr.map((_,i)=>`<button data-dot="${i}" class="${i===0?'active':''}"></button>`).join('')}</div>
  </section>`
}
function eq(){return'<div class="eq">'+Array.from({length:19},()=>'<i></i>').join('')+'</div>'}
function onair(st){
  const d=schedule(st);
  const nextEnd=d.a.length&&d.next?d.a[(d.idx+2)%d.a.length]?.time:'';
  return`<aside class="onair">
    <div class="onair-title"><span class="red-dot"></span>AO VIVO AGORA</div>
    <div class="station-row">
      <div class="station-logo">${stationLogo()}</div>
      <div><h2>${esc(st.name)}</h2><p>${esc(st.description||'')}</p>${eq()}</div>
    </div>
    <div class="onair-info">
      <div class="onair-label">Você está ouvindo</div>
      <div class="onair-program">${esc(d.cur?.title||'Studio Sat')}</div>
      <div class="onair-time">${esc(d.cur?.time||'')} ${d.next?'– '+esc(d.next.time):''}</div>
      <button class="onair-play" data-toggle>▶</button>
      <div class="onair-next"><div class="onair-label">A seguir</div><strong>${esc(d.next?.title||'')}</strong><div class="onair-time">${esc(d.next?.time||'')} ${nextEnd?'– '+esc(nextEnd):''}</div></div>
      <div class="onair-volume"><span>🔊</span><input data-card-vol type="range" min="0" max="1" step=".01" value="${audio.volume}"></div>
    </div>
  </aside>`
}
function stationCards(){
  return content.stations.map(st=>`<article class="station-card" style="background:linear-gradient(145deg,${esc(st.accent)},${esc(st.accent2)})"><img class="station-card-art" src="${esc(st.art||'')}" alt="">
    <div class="station-logo-mini">STUDIO<br>SAT</div>
    <h3>${esc(st.short)}</h3>
    <div class="desc">${esc(st.description||'')}</div>
    <button class="station-card-play" data-play="${esc(st.id)}">▶</button>
    <a class="station-open" data-route href="/emissora/${esc(st.slug)}/">ABRIR →</a>
    <div class="station-kicker">${esc(st.kicker||'')}</div>
  </article>`).join('')
}
function programRows(st,limit=3){
  const d=schedule(st);
  const exact=['data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201200%20700%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%236558ff%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23d944d9%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%221200%22%20height%3D%22700%22%20fill%3D%22url(%23g)%22%2F%3E%3Ccircle%20cx%3D%221020%22%20cy%3D%2290%22%20r%3D%22260%22%20fill%3D%22white%22%20opacity%3D%22.08%22%2F%3E%3Ccircle%20cx%3D%22650%22%20cy%3D%22260%22%20r%3D%22120%22%20fill%3D%22rgba(255%2C255%2C255%2C.15)%22%2F%3E%3Crect%20x%3D%22605%22%20y%3D%22120%22%20width%3D%2290%22%20height%3D%22230%22%20rx%3D%2245%22%20fill%3D%22white%22%20opacity%3D%22.9%22%2F%3E%3Cpath%20d%3D%22M540%20270c0%20120%20220%20120%20220%200M650%20390v100M570%20490h160%22%20stroke%3D%22white%22%20stroke-width%3D%2222%22%20fill%3D%22none%22%20stroke-linecap%3D%22round%22%2F%3E%3Ctext%20x%3D%2270%22%20y%3D%22570%22%20fill%3D%22white%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2272%22%20font-weight%3D%22900%22%3EPRINCIPAL%3C%2Ftext%3E%3Ctext%20x%3D%2272%22%20y%3D%22625%22%20fill%3D%22white%22%20opacity%3D%22.78%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2225%22%20font-weight%3D%22700%22%3ER%C3%81DIO%20STUDIO%20SAT%3C%2Ftext%3E%3C%2Fsvg%3E','data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201200%20700%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%23dd477f%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%235b54d8%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%221200%22%20height%3D%22700%22%20fill%3D%22url(%23g)%22%2F%3E%3Ccircle%20cx%3D%221020%22%20cy%3D%2290%22%20r%3D%22260%22%20fill%3D%22white%22%20opacity%3D%22.08%22%2F%3E%3Cg%20fill%3D%22white%22%20opacity%3D%22.9%22%3E%3Crect%20x%3D%22240%22%20y%3D%22260%22%20width%3D%2234%22%20height%3D%22180%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22310%22%20y%3D%22225%22%20width%3D%2234%22%20height%3D%22250%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22380%22%20y%3D%22190%22%20width%3D%2234%22%20height%3D%22320%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22450%22%20y%3D%22155%22%20width%3D%2234%22%20height%3D%22390%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22520%22%20y%3D%22260%22%20width%3D%2234%22%20height%3D%22180%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22590%22%20y%3D%22225%22%20width%3D%2234%22%20height%3D%22250%22%20rx%3D%2217%22%2F%3E%3Crect%20x%3D%22660%22%20y%3D%22190%22%20width%3D%2234%22%20height%3D%22320%22%20rx%3D%2217%22%2F%3E%3C%2Fg%3E%3Ctext%20x%3D%2270%22%20y%3D%22570%22%20fill%3D%22white%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2272%22%20font-weight%3D%22900%22%3ESTUDIO%20SAT%20%E2%80%94%20AO%20VIVO%3C%2Ftext%3E%3Ctext%20x%3D%2272%22%20y%3D%22625%22%20fill%3D%22white%22%20opacity%3D%22.78%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2225%22%20font-weight%3D%22700%22%3ER%C3%81DIO%20STUDIO%20SAT%3C%2Ftext%3E%3C%2Fsvg%3E','data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201200%20700%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%235b62e8%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23172769%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%221200%22%20height%3D%22700%22%20fill%3D%22url(%23g)%22%2F%3E%3Ccircle%20cx%3D%221020%22%20cy%3D%2290%22%20r%3D%22260%22%20fill%3D%22white%22%20opacity%3D%22.08%22%2F%3E%3Ccircle%20cx%3D%22650%22%20cy%3D%22260%22%20r%3D%22120%22%20fill%3D%22rgba(255%2C255%2C255%2C.15)%22%2F%3E%3Crect%20x%3D%22605%22%20y%3D%22120%22%20width%3D%2290%22%20height%3D%22230%22%20rx%3D%2245%22%20fill%3D%22white%22%20opacity%3D%22.9%22%2F%3E%3Cpath%20d%3D%22M540%20270c0%20120%20220%20120%20220%200M650%20390v100M570%20490h160%22%20stroke%3D%22white%22%20stroke-width%3D%2222%22%20fill%3D%22none%22%20stroke-linecap%3D%22round%22%2F%3E%3Ctext%20x%3D%2270%22%20y%3D%22570%22%20fill%3D%22white%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2272%22%20font-weight%3D%22900%22%3ECINCO%20R%C3%81DIOS.%20UMA%20S%C3%93%20PAIX%C3%83O.%3C%2Ftext%3E%3Ctext%20x%3D%2272%22%20y%3D%22625%22%20fill%3D%22white%22%20opacity%3D%22.78%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2225%22%20font-weight%3D%22700%22%3ER%C3%81DIO%20STUDIO%20SAT%3C%2Ftext%3E%3C%2Fsvg%3E'];
  return d.a.slice(0,limit).map((p,i)=>`<div class="program-row">
    <img class="program-img" src="${esc(st.id==='radioprincipal'&&i<3?exact[i]:(st.playlist?.[i%Math.max(st.playlist?.length||1,1)]?.cover||st.hero?.[0]?.image||''))}" alt="">
    <div><div class="program-line">${i===d.idx?'<span class="live-tag">NO AR</span>':''}<span class="program-title">${esc(p.title)}</span></div>
    <div class="program-time">${esc(p.time)}${i<d.a.length-1?' – '+esc(d.a[(i+1)%d.a.length].time):''}<br>${esc(st.name)}</div></div>
  </div>`).join('')
}
function allNews(){
  return content.stations.flatMap(st=>(st.news||[]).map(n=>({...n,station:st.short,stationSlug:st.slug})))
    .sort((a,b)=>String(b.date).localeCompare(String(a.date)));
}
function newsPanel(items){
  const pages=[];for(let i=0;i<items.length;i+=2)pages.push(items.slice(i,i+2));if(!pages.length)pages.push([]);
  return`<div class="news-panel" data-news>${pages.map((pg,pi)=>`<div class="news-page ${pi===0?'active':''}">${pg.map((n,ni)=>`<article class="news-item">
    <img src="${esc(n.image)}" alt="">
    <div><time>${esc(n.date)}</time><h3>${esc(n.title)}</h3><p>${esc(n.summary||'')}</p><a class="news-read" data-route href="/emissora/${esc(n.stationSlug||'principal')}/">LER MAIS →</a></div>
  </article>`).join('')}</div>`).join('')}</div>`
}
function aboutPanel(){
  return`<div class="about-panel">
    <img src="${esc(content.site.about_image||'data:image/svg+xml;charset=UTF-8,%3Csvg%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%20viewBox%3D%220%200%201200%20700%22%3E%3Cdefs%3E%3ClinearGradient%20id%3D%22g%22%20x1%3D%220%22%20y1%3D%220%22%20x2%3D%221%22%20y2%3D%221%22%3E%3Cstop%20stop-color%3D%22%235b62e8%22%2F%3E%3Cstop%20offset%3D%221%22%20stop-color%3D%22%23172769%22%2F%3E%3C%2FlinearGradient%3E%3C%2Fdefs%3E%3Crect%20width%3D%221200%22%20height%3D%22700%22%20fill%3D%22url(%23g)%22%2F%3E%3Ccircle%20cx%3D%221020%22%20cy%3D%2290%22%20r%3D%22260%22%20fill%3D%22white%22%20opacity%3D%22.08%22%2F%3E%3Ccircle%20cx%3D%22650%22%20cy%3D%22260%22%20r%3D%22120%22%20fill%3D%22rgba(255%2C255%2C255%2C.15)%22%2F%3E%3Crect%20x%3D%22605%22%20y%3D%22120%22%20width%3D%2290%22%20height%3D%22230%22%20rx%3D%2245%22%20fill%3D%22white%22%20opacity%3D%22.9%22%2F%3E%3Cpath%20d%3D%22M540%20270c0%20120%20220%20120%20220%200M650%20390v100M570%20490h160%22%20stroke%3D%22white%22%20stroke-width%3D%2222%22%20fill%3D%22none%22%20stroke-linecap%3D%22round%22%2F%3E%3Ctext%20x%3D%2270%22%20y%3D%22570%22%20fill%3D%22white%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2272%22%20font-weight%3D%22900%22%3ECINCO%20R%C3%81DIOS.%20UMA%20S%C3%93%20PAIX%C3%83O.%3C%2Ftext%3E%3Ctext%20x%3D%2272%22%20y%3D%22625%22%20fill%3D%22white%22%20opacity%3D%22.78%22%20font-family%3D%22Arial%2Csans-serif%22%20font-size%3D%2225%22%20font-weight%3D%22700%22%3ER%C3%81DIO%20STUDIO%20SAT%3C%2Ftext%3E%3C%2Fsvg%3E')}" alt="">
    <h3>${esc(content.site.about_title||'Somos música, informação e boa companhia.')}</h3>
    <p>${esc(content.site.about_text||'')}</p>
    <a class="about-link" data-route href="/sobre/">CONHEÇA NOSSA HISTÓRIA →</a>
  </div>`
}
function promoSection(){const arr=content.site.promotions||[];return '<section class="page ad-section"><div class="section-head"><div><h2>Destaques & Publicidade</h2><p>Campanhas, novidades e serviços Studio Sat.</p></div><a class="section-more" href="/listen/">ABRIR APP →</a></div><div class="ad-grid">'+arr.map(x=>'<article class="ad-card"><img src="'+esc(x.image)+'" alt=""><div class="ad-copy"><small>'+esc(x.eyebrow||'PUBLICIDADE')+'</small><h3>'+esc(x.title)+'</h3><p>'+esc(x.text||'')+'</p><a href="'+esc(x.link||'/')+'">'+esc(x.button||'SAIBA MAIS')+'</a></div></article>').join('')+'</div></section>';}\nfunction lowerColumns(st,stationOnly=false){
  const news=stationOnly?(st.news||[]).map(n=>({...n,station:st.short,stationSlug:st.slug})):allNews().slice(0,6);
  return`<div class="page lower">
    <section>
      <div class="section-head"><div><h2>${stationOnly?'Programação':'Programação em Destaque'}</h2></div><a class="section-more" data-route href="/programacao/">VER PROGRAMAÇÃO COMPLETA →</a></div>
      <div class="panel">${programRows(st,3)}</div>
    </section>
    <section>
      <div class="section-head"><div><h2>${stationOnly?'Notícias da '+esc(st.short):'Últimas Notícias'}</h2></div><a class="section-more" data-route href="/noticias/">VER TODAS →</a></div>
      ${newsPanel(news)}
    </section>
    <section>
      <div class="section-head"><div><h2>${stationOnly?'Sobre a '+esc(st.short):'Sobre a Studio Sat'}</h2></div></div>
      ${stationOnly?`<div class="about-panel"><img src="${esc(st.hero?.[0]?.image||'')}" alt=""><h3>${esc(st.description||'')}</h3><p>${esc(st.kicker||'')}</p><button class="about-link" data-play="${esc(st.id)}">OUÇA AGORA →</button></div>`:aboutPanel()}
    </section>
  </div>`
}
function home(){
  const st=current||content.stations[0];
  const h=(content.site.home_hero&&content.site.home_hero.length)?content.site.home_hero:content.stations[0].hero;
  return`<div class="page home-top"><div class="home-grid">${hero(h,st.id)}${onair(st)}</div></div>
  <section class="page stations-section"><div class="section-head"><div><h2>Nossas Rádios</h2><p>Cinco emissoras, para todos os momentos da sua vida.</p></div><a class="section-more" data-route href="/emissoras/">VER TODAS →</a></div><div class="station-grid">${stationCards()}</div></section>
  ${promoSection()}${lowerColumns(st,false)}`
}
function stationPage(st){
  return`<div class="page station-page-top"><div class="home-grid">${hero(st.hero,st.id)}${onair(st)}</div></div>
  <section class="page stations-section"><div class="section-head"><div><h2>${esc(st.name)}</h2><p>${esc(st.kicker||'')}</p></div><button class="hero-cta" data-play="${esc(st.id)}">▶ &nbsp; OUÇA AGORA</button></div><div class="station-grid">${stationCards()}</div></section>
  ${promoSection()}${lowerColumns(st,true)}
  <section class="page station-page-content"><h2 class="media-title">Playlist da ${esc(st.short)}</h2><div class="media-grid">${(st.playlist||[]).map(x=>`<article class="media-card"><img src="${esc(x.cover)}"><div class="media-card-body"><h3>${esc(x.title)}</h3><p>${esc(x.artist||'')}</p></div></article>`).join('')}</div>
  <h2 class="media-title">Equipe da ${esc(st.short)}</h2><div class="media-grid">${(st.team||[]).map(x=>`<article class="media-card"><img src="${esc(x.image)}"><div class="media-card-body"><h3>${esc(x.name)}</h3><p>${esc(x.role||'')}</p></div></article>`).join('')}</div></section>`
}
function resolvedRoute(){
  let p=location.pathname.replace(/\/+$/,'')||'/';
  const h=(location.hash||'').replace(/^#/,'').replace(/\/+$/,'');
  if(p==='/'&&h.startsWith('/'))p=h||'/';
  return p;
}
function simplePage(type){
  if(type==='emissoras')return`<section class="page simple-page"><div class="section-head"><div><h2>Nossas Rádios</h2><p>Cinco emissoras, cinco identidades.</p></div></div><div class="station-grid">${stationCards()}</div></section>`;
  if(type==='programacao')return`<section class="page simple-page">${content.stations.map(st=>`<div class="simple-box" style="margin-bottom:14px"><h2>${esc(st.name)}</h2>${programRows(st,99)}</div>`).join('')}</section>`;
  if(type==='noticias')return`<section class="page simple-page"><div class="all-news-grid">${allNews().map(n=>`<article class="media-card"><img src="${esc(n.image)}"><div class="media-card-body"><small>${esc(n.station)} · ${esc(n.date)}</small><h3>${esc(n.title)}</h3><p>${esc(n.summary||'')}</p></div></article>`).join('')}</div></section>`;
  if(type==='sobre')return`<section class="page simple-page"><div class="simple-box"><h1>${esc(content.site.about_title||'Sobre a Studio Sat')}</h1><div class="contact-grid"><img src="${esc(content.site.about_image||'/assets/ref/about-v5.webp')}" style="width:100%;border-radius:8px"><p style="font-size:15px;line-height:1.8">${esc(content.site.about_text||'')}</p></div></div></section>`;
  return`<section class="page simple-page"><div class="simple-box"><h1>Contato</h1><div class="contact-grid"><div><strong>E-mail</strong><p>${esc(content.site.contact_email||'contato@studiosatweb.com.br')}</p><strong>WhatsApp</strong><p>${esc(content.site.whatsapp||'')}</p></div><div><p>${esc(content.site.contact_text||'Entre em contato com nossa equipe.')}</p></div></div></div></section>`;
}
function route(){
  const p=resolvedRoute();
  if(p.startsWith('/emissora/')){const slug=p.split('/')[2],st=content.stations.find(s=>s.slug===slug);return st?stationPage(st):home()}
  if(p==='/emissoras')return simplePage('emissoras');
  if(p==='/programacao')return simplePage('programacao');
  if(p==='/noticias')return simplePage('noticias');
  if(p==='/sobre')return simplePage('sobre');
  if(p==='/contato')return simplePage('contato');
  return home()
}
function startLoops(){
  heroTimers.forEach(clearInterval);heroTimers=[];
  $$('[data-slider]').forEach(sl=>{
    const slides=$$('.hero-slide',sl),dots=$$('.hero-dots button',sl);let i=0;
    const show=n=>{slides[i]?.classList.remove('active');dots[i]?.classList.remove('active');i=n;slides[i]?.classList.add('active');dots[i]?.classList.add('active')};
    dots.forEach((d,n)=>d.onclick=()=>show(n));
    if(slides.length>1)heroTimers.push(setInterval(()=>show((i+1)%slides.length),6500));
  });
  clearInterval(newsTimer);
  const box=$('[data-news]');if(box){const pages=$$('.news-page',box);let i=0;if(pages.length>1)newsTimer=setInterval(()=>{pages[i].classList.remove('active');i=(i+1)%pages.length;pages[i].classList.add('active')},8000)}
}
function bind(){
  $$('[data-route]').forEach(a=>a.onclick=e=>{e.preventDefault();history.pushState({},'',a.getAttribute('href'));render()});
  $$('[data-play]').forEach(b=>b.onclick=e=>{e.preventDefault();e.stopPropagation();selectStation(b.dataset.play,true)});
  $$('[data-toggle]').forEach(b=>b.onclick=toggle);
  $$('[data-card-vol]').forEach(v=>v.oninput=e=>{engine.setVolume(+e.target.value);$('#vol').value=e.target.value});
}
function render(){
  $('#app').innerHTML=route();
  bind();startLoops();updatePlayer();
  $$('.nav a').forEach(a=>a.classList.toggle('active',a.pathname===location.pathname));
}
function updatePlayer(){
  const st=current||content?.stations?.[0];if(!st)return;const d=schedule(st);
  $('#pStation').textContent=st.name;
  $('#pProgram').textContent=d.cur?.title||'Ao vivo';
  $('#pTime').textContent=d.cur?(d.cur.time+(d.next?' – '+d.next.time:'')):'';
}
async function selectStation(id,autoplay){
  const st=content.stations.find(s=>s.id===id);if(!st)return;
  current=st;localStorage.setItem('ss_last_station',id);
  try{await engine.loadStation(st,{autoplay})}catch(e){console.warn(e)}
  updatePlayer();render()
}
async function toggle(){
  if(!engine.station||engine.state==='ERROR'){await selectStation(current?.id||content.stations[0].id,true);return}
  await engine.toggle()
}
function adjacent(dir){
  const i=Math.max(0,content.stations.findIndex(s=>s.id===(current?.id||content.stations[0].id)));
  selectStation(content.stations[(i+dir+content.stations.length)%content.stations.length].id,true)
}
engine.onState=s=>{
  document.body.classList.toggle('playing',s==='PLAYING');
  $('#pPlay').textContent=s==='PLAYING'?'❚❚':'▶';
  $('[data-toggle]').forEach(b=>b.textContent=s==='PLAYING'?'❚❚':'▶');const sig=$('#pSignal');if(sig){sig.dataset.state=s;const t=sig.querySelector('span');if(t)t.textContent=({IDLE:'Aguardando reprodução',LOADING:'Conectando…',READY:'Sinal disponível',PLAYING:'Ao vivo',BUFFERING:'Bufferizando…',RECONNECTING:'Reconectando…',ERROR:'Sem sinal'})[s]||s}
};
$('#pPlay').onclick=toggle;
$('#prevBtn').onclick=()=>adjacent(-1);
$('#nextBtn').onclick=()=>adjacent(1);
$('#mute').onclick=()=>{engine.mute(!audio.muted);$('#mute').textContent=audio.muted?'🔇':'🔊'};
$('#vol').value=audio.volume;$('#vol').oninput=e=>engine.setVolume(+e.target.value);
$('#shareBtn').onclick=async()=>{try{if(navigator.share)await navigator.share({title:'Studio Sat',url:location.href});else await navigator.clipboard.writeText(location.href)}catch{}};
window.onpopstate=render;window.onhashchange=render;

(async()=>{
  const r=await fetch('/assets/content.json',{cache:'no-store'});
  if(!r.ok)throw new Error('Falha no conteúdo');
  content=await r.json();
  current=content.stations.find(s=>s.id===localStorage.getItem('ss_last_station'))||content.stations[0];
  render()
})().catch(e=>{$('#app').innerHTML='<div class="page loading">Falha ao carregar o portal.</div>';console.error(e)});