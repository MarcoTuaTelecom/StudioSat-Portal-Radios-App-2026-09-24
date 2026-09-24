export class MediaEngine{
  constructor(audio){
    this.audio=audio;this.hls=null;this.station=null;this.state='IDLE';
    this.generation=0;this.retries=0;this.maxRetries=6;this.onState=()=>{};this._lockRate=()=>{if(audio.defaultPlaybackRate!==1)audio.defaultPlaybackRate=1;if(audio.playbackRate!==1)audio.playbackRate=1};audio.defaultPlaybackRate=1;audio.playbackRate=1;audio.addEventListener('ratechange',this._lockRate);
    audio.addEventListener('playing',()=>{this._lockRate();this._set('PLAYING')});
    audio.addEventListener('waiting',()=>this._set('BUFFERING'));
    audio.addEventListener('pause',()=>{if(this.state!=='IDLE'&&this.state!=='ERROR')this._set('READY')});
    audio.addEventListener('error',()=>this._set('ERROR'));
  }
  _set(s){this.state=s;this.onState(s)}
  restorePrefs(){
    const v=parseFloat(localStorage.getItem('ss_volume')||'0.85');
    this.audio.volume=Number.isFinite(v)?Math.min(1,Math.max(0,v)):.85;
    this.audio.muted=localStorage.getItem('ss_muted')==='1';
  }
  setVolume(v){this.audio.volume=Math.min(1,Math.max(0,v));localStorage.setItem('ss_volume',String(this.audio.volume))}
  mute(v){this.audio.muted=!!v;localStorage.setItem('ss_muted',this.audio.muted?'1':'0')}
  async loadStation(st,{autoplay=false}={}){
    this.generation++;const g=this.generation;this.station=st;this.retries=0;this._set('LOADING');
    if(this.hls){try{this.hls.destroy()}catch{}this.hls=null}
    if(window.Hls&&Hls.isSupported()){
      const h=new Hls({enableWorker:true,lowLatencyMode:false,liveSyncDurationCount:5,liveMaxLatencyDurationCount:12,maxLiveSyncPlaybackRate:1.0,maxBufferLength:30,maxMaxBufferLength:45,backBufferLength:30,manifestLoadingMaxRetry:4,levelLoadingMaxRetry:4,fragLoadingMaxRetry:6});
      this.hls=h;h.loadSource(st.stream);h.attachMedia(this.audio);
      await new Promise((resolve,reject)=>{
        let done=false;
        h.on(Hls.Events.MANIFEST_PARSED,()=>{if(g!==this.generation||done)return;done=true;this._set('READY');resolve()});
        h.on(Hls.Events.ERROR,(_,d)=>{
          if(g!==this.generation||!d.fatal)return;
          if(!done){done=true;reject(new Error('Falha HLS'))}
          this._recover(d,g);
        });
      });
    }else if(this.audio.canPlayType('application/vnd.apple.mpegurl')){
      this.audio.src=st.stream;this._set('READY');
    }else throw new Error('HLS não suportado');
    this._mediaSession();
    if(autoplay&&g===this.generation)await this.play();
  }
  async _recover(d,g){
    if(g!==this.generation||!this.hls)return;
    this.retries++;if(this.retries>this.maxRetries){this._set('ERROR');return}
    this._set('RECONNECTING');
    await new Promise(r=>setTimeout(r,Math.min(8000,750*2**(this.retries-1))));
    if(g!==this.generation||!this.hls)return;
    if(d.type===Hls.ErrorTypes.NETWORK_ERROR)this.hls.startLoad();
    else if(d.type===Hls.ErrorTypes.MEDIA_ERROR)this.hls.recoverMediaError();
    else this._set('ERROR');
  }
  async play(){this._lockRate();await this.audio.play();this._lockRate();this._set('PLAYING');this._mediaSession()}
  pause(){this.audio.pause();this._lockRate();this._set('READY')}
  async toggle(){this.audio.paused?await this.play():this.pause()}
  _mediaSession(){
    if(!('mediaSession'in navigator)||!this.station)return;
    navigator.mediaSession.metadata=new MediaMetadata({
      title:this.station.name,artist:'Studio Sat',album:this.station.short
    });
    navigator.mediaSession.setActionHandler('play',()=>this.play().catch(()=>{}));
    navigator.mediaSession.setActionHandler('pause',()=>this.pause());
  }
}