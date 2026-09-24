(function(){
'use strict';
const NETWORK_RETRY_MAX=5, MEDIA_RETRY_MAX=2;
function sleep(ms){return new Promise(r=>setTimeout(r,ms));}
class StudioSatAudioController{
  constructor(audio,opts={}){
    this.audio=audio;this.opts=opts;this.hls=null;this.station=null;this.networkRetries=0;this.mediaRetries=0;this.destroyed=false;this.playRequested=false;
    this._lockRate=this._lockRate.bind(this);this._onPlaying=this._onPlaying.bind(this);this._onWaiting=this._onWaiting.bind(this);this._onStalled=this._onStalled.bind(this);this._onPause=this._onPause.bind(this);
    audio.defaultPlaybackRate=1;audio.playbackRate=1;audio.addEventListener('ratechange',this._lockRate);audio.addEventListener('playing',this._onPlaying);audio.addEventListener('waiting',this._onWaiting);audio.addEventListener('stalled',this._onStalled);audio.addEventListener('pause',this._onPause);
  }
  _status(text,kind=''){this.opts.onStatus?.(text,kind);}
  _lockRate(){if(this.audio.defaultPlaybackRate!==1)this.audio.defaultPlaybackRate=1;if(this.audio.playbackRate!==1)this.audio.playbackRate=1;}
  _onPlaying(){this._lockRate();this._status('Ao vivo','ok');this.opts.onPlaying?.();}
  _onWaiting(){this._status('Bufferizando…','warn');}
  _onStalled(){this._status('Recarregando buffer…','warn');}
  _onPause(){if(!this.playRequested)this._status('Pausado','');this.opts.onPause?.();}
  streamUrl(station){return `${this.opts.streamBase||''}/${station.slug}/index.m3u8`.replace(/([^:]\/)\/+/, '$1');}
  async _waitForHls(timeout=8000){if(window.Hls)return true;return new Promise(resolve=>{let done=false;const finish=v=>{if(done)return;done=true;window.removeEventListener('studiosat:hls-ready',onReady);clearTimeout(t);resolve(v)};const onReady=()=>finish(!!window.Hls);window.addEventListener('studiosat:hls-ready',onReady,{once:true});const t=setTimeout(()=>finish(!!window.Hls),timeout);});}
  _disposeTransport(){if(this.hls){try{this.hls.destroy();}catch{}this.hls=null;}this.audio.pause();this.audio.removeAttribute('src');this.audio.load();}
  async attach(station,{autoplay=false}={}){
    this.station=station;this.networkRetries=0;this.mediaRetries=0;this.playRequested=autoplay;this._disposeTransport();this._lockRate();this._status('Conectando…','');
    const url=this.streamUrl(station);
    if(this.audio.canPlayType('application/vnd.apple.mpegurl')){this.audio.src=url;this._status('Áudio pronto','ok');}
    else{
      const available=await this._waitForHls();
      if(!available){this._status('Biblioteca HLS indisponível','err');return false;}
      const Hls=window.Hls;
      if(!Hls.isSupported?.()){this._status('Navegador sem suporte HLS/MSE','err');return false;}
      this.hls=new Hls({
        enableWorker:true,
        lowLatencyMode:false,
        liveSyncDurationCount:5,
        liveMaxLatencyDurationCount:12,
        maxLiveSyncPlaybackRate:1.0,
        maxBufferLength:30,
        maxMaxBufferLength:45,
        backBufferLength:30,
        maxBufferHole:0.5,
        manifestLoadingTimeOut:10000,
        fragLoadingTimeOut:15000
      });
      this.hls.loadSource(url);this.hls.attachMedia(this.audio);
      this.hls.on(Hls.Events.MANIFEST_PARSED,()=>{this._lockRate();this._status('Áudio pronto','ok');if(autoplay)this.play();});
      this.hls.on(Hls.Events.ERROR,async(_,data)=>{if(!data?.fatal)return;const h=this.hls;if(!h)return;
        if(data.type===Hls.ErrorTypes.NETWORK_ERROR&&this.networkRetries<NETWORK_RETRY_MAX){this.networkRetries++;this._status(`Reconectando rede ${this.networkRetries}/${NETWORK_RETRY_MAX}…`,'warn');await sleep(Math.min(5000,700*this.networkRetries));try{h.startLoad();}catch{}return;}
        if(data.type===Hls.ErrorTypes.MEDIA_ERROR&&this.mediaRetries<MEDIA_RETRY_MAX){this.mediaRetries++;this._status(`Recuperando mídia ${this.mediaRetries}/${MEDIA_RETRY_MAX}…`,'warn');try{h.recoverMediaError();}catch{}return;}
        this._status('Falha fatal no stream','err');this.opts.onFatal?.(data);
      });
    }
    if(autoplay&&this.audio.canPlayType('application/vnd.apple.mpegurl'))await this.play();
    return true;
  }
  async play(){this.playRequested=true;this._lockRate();try{await this.audio.play();this._lockRate();return true;}catch(e){this.playRequested=false;this._status('Clique em ▶ para permitir o áudio','warn');return false;}}
  pause(){this.playRequested=false;this.audio.pause();this._lockRate();}
  setVolume(v){const n=Math.max(0,Math.min(1,Number(v)));this.audio.volume=n;this.audio.muted=false;return n;}
  toggleMute(){this.audio.muted=!this.audio.muted;return this.audio.muted;}
  destroy(){this.destroyed=true;this._disposeTransport();this.audio.removeEventListener('ratechange',this._lockRate);this.audio.removeEventListener('playing',this._onPlaying);this.audio.removeEventListener('waiting',this._onWaiting);this.audio.removeEventListener('stalled',this._onStalled);this.audio.removeEventListener('pause',this._onPause);}
}
window.StudioSatAudioController=StudioSatAudioController;
})();
