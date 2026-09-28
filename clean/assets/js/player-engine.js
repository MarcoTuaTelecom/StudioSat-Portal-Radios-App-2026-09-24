(function () {
  "use strict";
  class StudioSatPlayer {
    constructor(audio, onState) {
      this.audio = audio;
      this.onState = onState || function () {};
      this.hls = null;
      this.station = null;
      this.netRetries = 0;
      this.mediaRetries = 0;
      this.wanted = false;
      audio.preload = "none";
      audio.crossOrigin = "anonymous";
      audio.playsInline = true;
      audio.defaultPlaybackRate = 1;
      audio.playbackRate = 1;
      audio.addEventListener("ratechange", () => {
        if (audio.playbackRate !== 1) audio.playbackRate = 1;
        if (audio.defaultPlaybackRate !== 1) audio.defaultPlaybackRate = 1;
      });
      audio.addEventListener("playing", () => this._emit("live", "Ao vivo"));
      audio.addEventListener("waiting", () => this._emit("loading", "Buffer…"));
      audio.addEventListener("stalled", () => this._emit("loading", "Reconectando…"));
      audio.addEventListener("pause", () => { if (!this.wanted) this._emit("idle", "Pausado"); });
    }
    _emit(kind, text) { this.onState({ kind, text, station: this.station }); }
    stop() {
      if (this.hls) { try { this.hls.destroy(); } catch (_) {} this.hls = null; }
      this.audio.pause();
      this.audio.removeAttribute("src");
      try { this.audio.load(); } catch (_) {}
    }
    async attach(station, autoplay) {
      this.stop();
      this.station = station;
      this.netRetries = 0;
      this.mediaRetries = 0;
      this.wanted = !!autoplay;
      this._emit("loading", "Conectando…");
      const url = station.stream;
      const Hls = window.Hls;
      if (this.audio.canPlayType("application/vnd.apple.mpegurl")) {
        this.audio.src = url;
        if (autoplay) await this.play(); else this._emit("ready", "Pronto");
        return true;
      }
      if (!Hls || !Hls.isSupported()) { this._emit("error", "HLS não suportado neste navegador"); return false; }
      this.hls = new Hls({
        enableWorker: true,
        lowLatencyMode: false,
        liveSyncDurationCount: 2,
        liveMaxLatencyDurationCount: 5,
        maxLiveSyncPlaybackRate: 1.0,
        maxBufferLength: 12,
        maxMaxBufferLength: 20,
        backBufferLength: 8,
        maxBufferHole: 0.3,
        manifestLoadingTimeOut: 8000,
        fragLoadingTimeOut: 12000,
        startLevel: 0
      });
      this.hls.loadSource(url);
      this.hls.attachMedia(this.audio);
      this.hls.on(Hls.Events.MANIFEST_PARSED, () => { this._emit("ready", "Pronto"); if (autoplay) this.play(); });
      this.hls.on(Hls.Events.ERROR, (_, data) => {
        if (!data || !data.fatal) return;
        if (data.type === Hls.ErrorTypes.NETWORK_ERROR && this.netRetries < 6) {
          this.netRetries++;
          this._emit("loading", "Reconectando " + this.netRetries + "/6…");
          setTimeout(() => { if (this.hls) { try { this.hls.startLoad(); } catch (_) {} } }, Math.min(4000, 500 * this.netRetries));
          return;
        }
        if (data.type === Hls.ErrorTypes.MEDIA_ERROR && this.mediaRetries < 3) {
          this.mediaRetries++;
          this._emit("loading", "Recuperando áudio…");
          try { this.hls.recoverMediaError(); } catch (_) {}
          return;
        }
        this._emit("error", "Sem sinal — tente outra emissora");
      });
      return true;
    }
    async play() {
      this.wanted = true;
      this.audio.playbackRate = 1;
      try { await this.audio.play(); this._emit("live", "Ao vivo"); return true; }
      catch (_) { this.wanted = false; this._emit("ready", "Toque em ▶ para ouvir"); return false; }
    }
    pause() { this.wanted = false; this.audio.pause(); this._emit("idle", "Pausado"); }
    setVolume(v) { const n = Math.max(0, Math.min(1, Number(v))); this.audio.volume = n; this.audio.muted = n === 0; return n; }
    toggleMute() { this.audio.muted = !this.audio.muted; return this.audio.muted; }
  }
  window.StudioSatPlayer = StudioSatPlayer;
})();
