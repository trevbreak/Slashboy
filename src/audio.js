// Fully procedural WebAudio engine: ambience, spatial SFX, adaptive music.

const ZONES = {
  silent:   { drone: 0.0,  df: 50, air: 0.0,  wind: 0.0,  hum: 0.0,  rev: 0.3 },
  bay:      { drone: 0.10, df: 55, air: 0.05, wind: 0.0,  hum: 0.025, rev: 0.35 },
  corridor: { drone: 0.12, df: 49, air: 0.03, wind: 0.0,  hum: 0.05, rev: 0.28 },
  atrium:   { drone: 0.09, df: 41, air: 0.035, wind: 0.10, hum: 0.0,  rev: 0.75 },
  funnel:   { drone: 0.17, df: 46, air: 0.02, wind: 0.02, hum: 0.02, rev: 0.35 },
  arena:    { drone: 0.10, df: 43, air: 0.04, wind: 0.0,  hum: 0.03, rev: 0.5 },
  final:    { drone: 0.08, df: 52, air: 0.03, wind: 0.04, hum: 0.0,  rev: 0.55 },
};

const AMBIENT_PALETTE = {
  bay:      ['creak', 'clank', 'drip', 'vent', 'boom'],
  corridor: ['creak', 'clank', 'drip', 'vent', 'buzz', 'skitterFar', 'tap'],
  atrium:   ['boom', 'creak', 'clank', 'whale', 'chime', 'boom'],
  funnel:   ['drip', 'whisper', 'skitterFar', 'creak', 'breath', 'tap'],
  arena:    ['drip', 'creak', 'vent', 'whisper'],
  final:    ['chime', 'boom', 'creak'],
};

const PAD_NOTES = [73.4, 87.3, 98, 110, 116.5, 146.8, 174.6, 196, 220, 233.1, 293.7];

export class AudioEngine {
  constructor() {
    this.ready = false;
    this.zone = 'silent';
    this.ambientTimer = 6;
    this.padTimer = 4;
    this.combat = false;
    this.tension = 0;
  }

  init() {
    if (this.ready) return;
    const ctx = this.ctx = new (window.AudioContext || window.webkitAudioContext)();
    this.master = ctx.createGain();
    this.master.gain.value = 0.9;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -16; comp.ratio.value = 4; comp.attack.value = 0.004; comp.release.value = 0.25;
    this.master.connect(comp); comp.connect(ctx.destination);

    this.buses = {};
    for (const [k, v] of [['sfx', 1], ['amb', 0.9], ['music', 0.55]]) {
      const g = ctx.createGain(); g.gain.value = v; g.connect(this.master); this.buses[k] = g;
    }
    // reverb
    this.reverb = ctx.createConvolver();
    this.reverb.buffer = this._impulse(4.5, 2.6);
    this.reverbIn = ctx.createGain();
    this.reverbOut = ctx.createGain();
    this.reverbOut.gain.value = 0.35;
    this.reverbIn.connect(this.reverb); this.reverb.connect(this.reverbOut); this.reverbOut.connect(this.master);

    // noise buffer
    const len = ctx.sampleRate * 2;
    this.noiseBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const d = this.noiseBuf.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    // brown noise
    this.brownBuf = ctx.createBuffer(1, len, ctx.sampleRate);
    const b = this.brownBuf.getChannelData(0);
    let last = 0;
    for (let i = 0; i < len; i++) { last = (last + 0.02 * (Math.random() * 2 - 1)) / 1.02; b[i] = last * 3.5; }

    this._startAmbience();
    this._startMusic();
    this.ready = true;
  }

  _impulse(seconds, decay) {
    const ctx = this.ctx, rate = ctx.sampleRate, len = rate * seconds;
    const buf = ctx.createBuffer(2, len, rate);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
    }
    return buf;
  }

  get now() { return this.ctx.currentTime; }

  // ---------------------------------------------------------------- core voices
  _dest({ pos = null, bus = 'sfx', rev = 0.25, gain = 1 } = {}) {
    const ctx = this.ctx;
    const g = ctx.createGain();
    g.gain.value = gain;
    let node = g;
    if (pos) {
      const p = ctx.createPanner();
      p.panningModel = 'HRTF'; p.distanceModel = 'inverse';
      p.refDistance = 2.5; p.maxDistance = 300; p.rolloffFactor = 1.1;
      p.positionX.value = pos.x; p.positionY.value = pos.y; p.positionZ.value = pos.z;
      g.connect(p); node = p;
    }
    node.connect(this.buses[bus]);
    if (rev > 0) { const s = ctx.createGain(); s.gain.value = rev; node.connect(s); s.connect(this.reverbIn); }
    return g;
  }

  _env(param, t, peak, attack, dur, curve = 'exp') {
    param.cancelScheduledValues(t);
    param.setValueAtTime(0.0001, t);
    param.linearRampToValueAtTime(peak, t + attack);
    if (curve === 'exp') param.exponentialRampToValueAtTime(0.0001, t + dur);
    else param.linearRampToValueAtTime(0.0001, t + dur);
  }

  tone({ freq = 440, freqEnd = null, type = 'sine', dur = 0.3, gain = 0.3, attack = 0.005, delay = 0,
    filter = null, filterFreq = 2000, filterEnd = null, Q = 1, detune = 0, ...dest } = {}) {
    if (!this.ready) return;
    const ctx = this.ctx, t = this.now + delay;
    const o = ctx.createOscillator();
    o.type = type; o.frequency.setValueAtTime(freq, t); o.detune.value = detune;
    if (freqEnd) o.frequency.exponentialRampToValueAtTime(Math.max(1, freqEnd), t + dur);
    const g = ctx.createGain();
    this._env(g.gain, t, gain, attack, dur);
    let n = o;
    if (filter) {
      const f = ctx.createBiquadFilter(); f.type = filter; f.frequency.setValueAtTime(filterFreq, t); f.Q.value = Q;
      if (filterEnd) f.frequency.exponentialRampToValueAtTime(filterEnd, t + dur);
      o.connect(f); n = f;
    }
    n.connect(g); g.connect(this._dest(dest));
    o.start(t); o.stop(t + dur + 0.05);
    return o;
  }

  noise({ dur = 0.3, gain = 0.3, attack = 0.005, delay = 0, filter = 'bandpass', freq = 1000, freqEnd = null,
    Q = 1, brown = false, rate = 1, ...dest } = {}) {
    if (!this.ready) return;
    const ctx = this.ctx, t = this.now + delay;
    const s = ctx.createBufferSource();
    s.buffer = brown ? this.brownBuf : this.noiseBuf; s.loop = true; s.playbackRate.value = rate;
    const f = ctx.createBiquadFilter(); f.type = filter; f.frequency.setValueAtTime(freq, t); f.Q.value = Q;
    if (freqEnd) f.frequency.exponentialRampToValueAtTime(freqEnd, t + dur);
    const g = ctx.createGain();
    this._env(g.gain, t, gain, attack, dur);
    s.connect(f); f.connect(g); g.connect(this._dest(dest));
    s.start(t, Math.random() * 1.5); s.stop(t + dur + 0.05);
  }

  // ---------------------------------------------------------------- ambience
  _startAmbience() {
    const ctx = this.ctx;
    const amb = this.buses.amb;
    // drone
    this.droneGain = ctx.createGain(); this.droneGain.gain.value = 0;
    this.droneFilter = ctx.createBiquadFilter(); this.droneFilter.type = 'lowpass'; this.droneFilter.frequency.value = 260; this.droneFilter.Q.value = 3;
    this.droneOsc = [];
    for (const [mul, type, det] of [[1, 'sawtooth', -6], [1.498, 'sawtooth', 5], [0.5, 'sine', 0], [2.01, 'triangle', 0]]) {
      const o = ctx.createOscillator(); o.type = type; o.frequency.value = 50 * mul; o.detune.value = det;
      o.connect(this.droneFilter); o.start(); this.droneOsc.push([o, mul]);
    }
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.07;
    const lfoG = ctx.createGain(); lfoG.gain.value = 120;
    lfo.connect(lfoG); lfoG.connect(this.droneFilter.frequency); lfo.start();
    this.droneFilter.connect(this.droneGain); this.droneGain.connect(amb);
    const dSend = ctx.createGain(); dSend.gain.value = 0.3; this.droneGain.connect(dSend); dSend.connect(this.reverbIn);

    // air handling
    const air = ctx.createBufferSource(); air.buffer = this.noiseBuf; air.loop = true;
    const airF = ctx.createBiquadFilter(); airF.type = 'bandpass'; airF.frequency.value = 520; airF.Q.value = 0.6;
    this.airGain = ctx.createGain(); this.airGain.gain.value = 0;
    air.connect(airF); airF.connect(this.airGain); this.airGain.connect(amb); air.start();

    // wind (howling, modulated)
    const wind = ctx.createBufferSource(); wind.buffer = this.brownBuf; wind.loop = true;
    const windF = ctx.createBiquadFilter(); windF.type = 'bandpass'; windF.frequency.value = 400; windF.Q.value = 4;
    const wl = ctx.createOscillator(); wl.frequency.value = 0.11;
    const wlg = ctx.createGain(); wlg.gain.value = 260;
    wl.connect(wlg); wlg.connect(windF.frequency); wl.start();
    this.windGain = ctx.createGain(); this.windGain.gain.value = 0;
    wind.connect(windF); windF.connect(this.windGain); this.windGain.connect(amb); wind.start();
    const wSend = ctx.createGain(); wSend.gain.value = 0.5; this.windGain.connect(wSend); wSend.connect(this.reverbIn);

    // electrical hum
    const hum = ctx.createOscillator(); hum.type = 'sawtooth'; hum.frequency.value = 60;
    const humF = ctx.createBiquadFilter(); humF.type = 'lowpass'; humF.frequency.value = 200;
    this.humGain = ctx.createGain(); this.humGain.gain.value = 0;
    hum.connect(humF); humF.connect(this.humGain); this.humGain.connect(amb); hum.start();

    // tension: high dissonant strings with tremolo
    this.tensionGain = ctx.createGain(); this.tensionGain.gain.value = 0;
    const trem = ctx.createGain(); trem.gain.value = 0.6;
    const tl = ctx.createOscillator(); tl.frequency.value = 5.5;
    const tlg = ctx.createGain(); tlg.gain.value = 0.4; tl.connect(tlg); tlg.connect(trem.gain); tl.start();
    for (const f of [1244.5, 1318.5, 932.3]) {
      const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.value = f;
      const v = ctx.createOscillator(); v.frequency.value = 0.3 + Math.random() * 0.4;
      const vg = ctx.createGain(); vg.gain.value = 4; v.connect(vg); vg.connect(o.detune); v.start();
      o.connect(trem); o.start();
    }
    trem.connect(this.tensionGain); this.tensionGain.connect(amb);
    const tSend = ctx.createGain(); tSend.gain.value = 0.8; this.tensionGain.connect(tSend); tSend.connect(this.reverbIn);
  }

  setZone(name) {
    if (!this.ready || !ZONES[name] || name === this.zone) return;
    this.zone = name;
    const z = ZONES[name], t = this.now, tc = 1.8;
    this.droneGain.gain.setTargetAtTime(z.drone, t, tc);
    for (const [o, mul] of this.droneOsc) o.frequency.setTargetAtTime(z.df * mul, t, tc);
    this.airGain.gain.setTargetAtTime(z.air, t, tc);
    this.windGain.gain.setTargetAtTime(z.wind, t, tc);
    this.humGain.gain.setTargetAtTime(z.hum, t, tc);
    this.reverbOut.gain.setTargetAtTime(z.rev, t, tc);
  }

  // multiply ambience down (for scripted silences)
  duck(amount, time = 0.5) {
    if (!this.ready) return;
    this.buses.amb.gain.setTargetAtTime(0.9 * amount, this.now, time);
  }

  setTension(v) {
    if (!this.ready) return;
    v = Math.max(0, Math.min(1, v));
    if (Math.abs(v - this.tension) < 0.01) return;
    this.tension = v;
    this.tensionGain.gain.setTargetAtTime(v * 0.018, this.now, 0.8);
  }

  update(dt, camera, playerPos) {
    if (!this.ready) return;
    const l = this.ctx.listener, p = camera.position;
    const fwd = camera.getWorldDirection(this._v || (this._v = camera.position.clone()));
    const t = this.now;
    if (l.positionX) {
      l.positionX.setTargetAtTime(p.x, t, 0.02); l.positionY.setTargetAtTime(p.y, t, 0.02); l.positionZ.setTargetAtTime(p.z, t, 0.02);
      l.forwardX.setTargetAtTime(fwd.x, t, 0.02); l.forwardY.setTargetAtTime(fwd.y, t, 0.02); l.forwardZ.setTargetAtTime(fwd.z, t, 0.02);
      l.upX.value = 0; l.upY.value = 1; l.upZ.value = 0;
    } else {
      l.setPosition(p.x, p.y, p.z); l.setOrientation(fwd.x, fwd.y, fwd.z, 0, 1, 0);
    }

    // random ambient one-shots
    this.ambientTimer -= dt;
    if (this.ambientTimer <= 0) {
      this.ambientTimer = 7 + Math.random() * 14;
      const pal = AMBIENT_PALETTE[this.zone];
      if (pal) {
        const kind = pal[Math.floor(Math.random() * pal.length)];
        const a = Math.random() * Math.PI * 2, r = 8 + Math.random() * 20;
        const pos = { x: playerPos.x + Math.cos(a) * r, y: playerPos.y + 1 + Math.random() * 5, z: playerPos.z + Math.sin(a) * r };
        this.ambient(kind, pos);
      }
    }
    // exploration pad
    if (!this.combat) {
      this.padTimer -= dt;
      if (this.padTimer <= 0) {
        this.padTimer = 9 + Math.random() * 14;
        if (this.zone !== 'silent') this.padNote();
      }
    }
  }

  ambient(kind, pos) {
    switch (kind) {
      case 'creak': this.creak(pos); break;
      case 'clank': this.clank(pos, 0.25); break;
      case 'drip': this.drip(pos); break;
      case 'vent': this.ventRumble(pos); break;
      case 'boom': this.distantBoom(); break;
      case 'buzz': this.buzz(pos, 0.6); break;
      case 'whisper': this.whisper(pos); break;
      case 'skitterFar': this.skitter(pos, 0.9, 0.12); break;
      case 'tap': this.taps(pos); break;
      case 'whale': this.whaleCall(pos); break;
      case 'chime': this.chime(); break;
      case 'breath': this.breath(pos); break;
    }
  }

  // ---------------------------------------------------------------- environment SFX
  creak(pos) {
    const f = 90 + Math.random() * 120;
    this.tone({ freq: f, freqEnd: f * (0.7 + Math.random() * 0.6), type: 'sawtooth', dur: 1.2 + Math.random(), gain: 0.06, attack: 0.3,
      filter: 'bandpass', filterFreq: 700, Q: 12, pos, rev: 0.7 });
  }
  clank(pos, gain = 0.4) {
    for (const f of [420, 1130, 2380, 3120]) {
      this.tone({ freq: f * (0.95 + Math.random() * 0.1), type: 'sine', dur: 0.9 + Math.random() * 0.6, gain: gain * 0.25, pos, rev: 0.6 });
    }
    this.noise({ dur: 0.06, gain: gain * 0.8, freq: 2500, Q: 0.8, pos, rev: 0.6 });
  }
  drip(pos) {
    const f = 900 + Math.random() * 900;
    this.tone({ freq: f, freqEnd: f * 2.2, type: 'sine', dur: 0.12, gain: 0.12, pos, rev: 0.8 });
  }
  ventRumble(pos) {
    this.noise({ dur: 2.5, gain: 0.15, attack: 0.8, filter: 'lowpass', freq: 220, brown: true, pos, rev: 0.5 });
  }
  distantBoom() {
    this.noise({ dur: 4, gain: 0.35, attack: 0.05, filter: 'lowpass', freq: 160, freqEnd: 40, brown: true, rev: 0.9, bus: 'amb' });
    this.tone({ freq: 48, freqEnd: 30, type: 'sine', dur: 3, gain: 0.18, rev: 0.6, bus: 'amb' });
  }
  buzz(pos, dur = 0.4) {
    this.tone({ freq: 120, type: 'sawtooth', dur, gain: 0.04, attack: 0.01, filter: 'bandpass', filterFreq: 2400, Q: 2, pos, rev: 0.2 });
    this.noise({ dur: dur * 0.5, gain: 0.04, freq: 5000, Q: 1, pos });
  }
  sparks(pos) {
    for (let i = 0; i < 6; i++) this.noise({ delay: i * 0.03 + Math.random() * 0.02, dur: 0.04, gain: 0.15, freq: 5000 + Math.random() * 3000, Q: 2, pos, rev: 0.3 });
  }
  whisper(pos) {
    for (let i = 0; i < 3; i++) {
      this.noise({ delay: i * 0.35 + Math.random() * 0.2, dur: 0.5 + Math.random() * 0.4, gain: 0.05, attack: 0.15, filter: 'bandpass',
        freq: 1800 + Math.random() * 1600, freqEnd: 900 + Math.random() * 800, Q: 6, pos, rev: 0.9 });
    }
  }
  breath(pos) {
    for (let i = 0; i < 2; i++) {
      this.noise({ delay: i * 1.6, dur: 1.2, gain: 0.07, attack: 0.5, filter: 'bandpass', freq: 600, freqEnd: 380, Q: 3, pos, rev: 0.6 });
    }
  }
  taps(pos) {
    const n = 3 + Math.floor(Math.random() * 4);
    for (let i = 0; i < n; i++) this.noise({ delay: i * (0.15 + Math.random() * 0.25), dur: 0.05, gain: 0.18, freq: 1600, Q: 6, pos, rev: 0.6 });
  }
  skitter(pos, dur = 0.8, gain = 0.25) {
    const n = Math.floor(dur * 28);
    for (let i = 0; i < n; i++) {
      this.noise({ delay: i / 28 + Math.random() * 0.015, dur: 0.025, gain: gain * (0.5 + Math.random() * 0.5), freq: 2500 + Math.random() * 2500, Q: 4, pos, rev: 0.35 });
    }
  }
  skitterPath(from, to, dur, gain = 0.35) {
    const n = Math.floor(dur * 30);
    for (let i = 0; i < n; i++) {
      const k = i / n;
      const pos = { x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k, z: from.z + (to.z - from.z) * k };
      this.noise({ delay: i / 30 + Math.random() * 0.012, dur: 0.03, gain: gain * (0.6 + Math.random() * 0.4), freq: 1800 + Math.random() * 3000, Q: 3, pos, rev: 0.4 });
      if (i % 6 === 0) this.noise({ delay: i / 30, dur: 0.06, gain: gain * 0.6, filter: 'lowpass', freq: 400, pos, rev: 0.4 });
    }
  }
  ventBang(pos) {
    this.noise({ dur: 0.5, gain: 0.9, filter: 'lowpass', freq: 600, freqEnd: 80, pos, rev: 0.6 });
    this.tone({ freq: 140, freqEnd: 60, type: 'square', dur: 0.4, gain: 0.25, filter: 'lowpass', filterFreq: 500, pos, rev: 0.6 });
    this.clank(pos, 0.6);
  }
  grateFall(pos) {
    this.ventBang(pos);
    this.clank({ x: pos.x, y: pos.y - 2, z: pos.z }, 0.7);
    setTimeout(() => this.ready && this.clank({ x: pos.x + 0.3, y: 0.2, z: pos.z }, 0.5), 450);
    setTimeout(() => this.ready && this.clank({ x: pos.x + 0.5, y: 0.2, z: pos.z + 0.2 }, 0.25), 700);
  }
  whaleCall(pos) {
    const p = { x: pos.x + 120, y: pos.y - 30, z: pos.z };
    this.tone({ freq: 70, freqEnd: 52, type: 'sawtooth', dur: 5, gain: 0.08, attack: 1.8, filter: 'lowpass', filterFreq: 300, Q: 6, pos: p, rev: 1 });
    this.tone({ freq: 140, freqEnd: 110, type: 'triangle', dur: 4, gain: 0.03, attack: 2, delay: 0.5, pos: p, rev: 1 });
  }
  leviathanHorn() {
    this.tone({ freq: 38, freqEnd: 34, type: 'sawtooth', dur: 9, gain: 0.25, attack: 3, filter: 'lowpass', filterFreq: 220, Q: 4, rev: 1, bus: 'amb' });
    this.tone({ freq: 57, freqEnd: 51, type: 'sawtooth', dur: 8, gain: 0.12, attack: 3.5, delay: 0.6, filter: 'lowpass', filterFreq: 300, rev: 1, bus: 'amb' });
    this.noise({ dur: 10, gain: 0.15, attack: 4, filter: 'lowpass', freq: 90, brown: true, rev: 1, bus: 'amb' });
  }
  chime() {
    const base = [587.3, 698.5, 880, 1174.7, 1396.9][Math.floor(Math.random() * 5)];
    this.tone({ freq: base, type: 'sine', dur: 4, gain: 0.04, attack: 0.01, rev: 1, bus: 'music' });
    this.tone({ freq: base * 2.76, type: 'sine', dur: 2, gain: 0.012, attack: 0.01, rev: 1, bus: 'music' });
  }
  padNote() {
    const n = PAD_NOTES[Math.floor(Math.random() * PAD_NOTES.length)];
    const dur = 7 + Math.random() * 5;
    this.tone({ freq: n, type: 'triangle', dur, gain: 0.045, attack: 2.5, filter: 'lowpass', filterFreq: 900, rev: 1, bus: 'music' });
    this.tone({ freq: n * 1.5, type: 'sine', dur: dur * 0.8, gain: 0.02, attack: 3, delay: 0.8, rev: 1, bus: 'music', detune: 7 });
    if (Math.random() < 0.35) this.chime();
  }
  doorOpen(pos) {
    this.noise({ dur: 0.9, gain: 0.35, attack: 0.02, filter: 'highpass', freq: 3000, freqEnd: 1200, pos, rev: 0.3 });
    this.tone({ freq: 90, freqEnd: 140, type: 'sawtooth', dur: 0.7, gain: 0.12, filter: 'lowpass', filterFreq: 400, pos, rev: 0.3 });
    this.tone({ freq: 880, type: 'sine', dur: 0.15, gain: 0.08, pos });
    this.tone({ freq: 1320, type: 'sine', dur: 0.2, gain: 0.08, delay: 0.09, pos });
    this.noise({ delay: 0.75, dur: 0.25, gain: 0.4, filter: 'lowpass', freq: 300, pos, rev: 0.4 });
  }
  doorClose(pos) {
    this.noise({ dur: 0.6, gain: 0.25, filter: 'highpass', freq: 2000, freqEnd: 900, pos, rev: 0.3 });
    this.noise({ delay: 0.5, dur: 0.35, gain: 0.55, filter: 'lowpass', freq: 250, pos, rev: 0.5 });
  }
  doorLockSlam(pos) {
    this.noise({ dur: 0.6, gain: 0.9, filter: 'lowpass', freq: 400, freqEnd: 60, pos, rev: 0.7 });
    this.tone({ freq: 70, freqEnd: 40, type: 'square', dur: 0.6, gain: 0.3, filter: 'lowpass', filterFreq: 300, pos, rev: 0.6 });
    this.tone({ freq: 220, type: 'square', dur: 0.25, gain: 0.08, delay: 0.3, filter: 'lowpass', filterFreq: 1200, pos });
    this.tone({ freq: 165, type: 'square', dur: 0.35, gain: 0.08, delay: 0.55, filter: 'lowpass', filterFreq: 1200, pos });
  }
  denied(pos) {
    this.tone({ freq: 180, type: 'square', dur: 0.18, gain: 0.08, filter: 'lowpass', filterFreq: 1200, pos });
    this.tone({ freq: 140, type: 'square', dur: 0.25, gain: 0.08, delay: 0.16, filter: 'lowpass', filterFreq: 1200, pos });
  }
  unlockChime(pos) {
    [660, 990, 1320].forEach((f, i) => this.tone({ freq: f, type: 'sine', dur: 0.4, gain: 0.08, delay: i * 0.08, pos, rev: 0.5 }));
  }
  lightsOut() {
    this.tone({ freq: 120, freqEnd: 30, type: 'sawtooth', dur: 1.6, gain: 0.2, filter: 'lowpass', filterFreq: 800, filterEnd: 60, rev: 0.6 });
    this.noise({ dur: 0.15, gain: 0.4, freq: 3000, Q: 0.5, rev: 0.5 });
    this.noise({ delay: 0.05, dur: 1.2, gain: 0.25, filter: 'lowpass', freq: 200, brown: true, rev: 0.7 });
  }
  lightsOn() {
    for (let i = 0; i < 4; i++) this.buzz(null, 0.08 + Math.random() * 0.1);
    this.tone({ freq: 40, freqEnd: 120, type: 'sawtooth', dur: 1.2, gain: 0.08, filter: 'lowpass', filterFreq: 400, rev: 0.4 });
  }
  alarm(times = 4) {
    for (let i = 0; i < times; i++) {
      this.tone({ freq: 520, freqEnd: 380, type: 'sawtooth', dur: 0.7, gain: 0.06, delay: i * 1.1, filter: 'lowpass', filterFreq: 1800, rev: 0.8 });
    }
  }
  stinger(kind = 'encounter') {
    if (kind === 'encounter') {
      for (const f of [73.4, 77.8, 110, 155.6, 233.1]) {
        this.tone({ freq: f, type: 'sawtooth', dur: 3.5, gain: 0.07, attack: 0.04, filter: 'lowpass', filterFreq: 2400, filterEnd: 300, rev: 0.8, bus: 'music' });
      }
      this.noise({ dur: 1.4, gain: 0.5, filter: 'lowpass', freq: 200, freqEnd: 40, brown: true, rev: 0.8, bus: 'music' });
      this.tone({ freq: 55, freqEnd: 30, type: 'sine', dur: 1.5, gain: 0.4, bus: 'music' });
    } else if (kind === 'scare') {
      for (const f of [1244, 1318, 1396, 1480]) this.tone({ freq: f, type: 'sawtooth', dur: 1.6, gain: 0.025, attack: 0.02, filter: 'bandpass', filterFreq: f, Q: 3, rev: 0.9, bus: 'music' });
      this.noise({ dur: 0.8, gain: 0.3, filter: 'lowpass', freq: 150, brown: true, rev: 0.7, bus: 'music' });
    } else if (kind === 'clear') {
      [293.7, 349.2, 440, 587.3].forEach((f, i) => this.tone({ freq: f, type: 'triangle', dur: 5, gain: 0.05, attack: 0.6, delay: i * 0.25, rev: 1, bus: 'music' }));
    } else if (kind === 'discovery') {
      [440, 554.4, 659.3, 880].forEach((f, i) => this.tone({ freq: f, type: 'sine', dur: 3, gain: 0.045, attack: 0.05, delay: i * 0.12, rev: 1, bus: 'music' }));
    }
  }

  // ---------------------------------------------------------------- player SFX
  swing(variant = 0) {
    const f0 = [3800, 3200, 2600, 2000][variant] || 3000;
    this.noise({ dur: 0.22, gain: 0.32, attack: 0.03, filter: 'bandpass', freq: f0 * 0.5, freqEnd: f0 * 1.6, Q: 1.6, rev: 0.12 });
    this.tone({ freq: 900 + variant * 120, freqEnd: 300, type: 'sine', dur: 0.18, gain: 0.04, rev: 0.1 });
  }
  slashHit(pos, heavy = false) {
    this.noise({ dur: 0.18, gain: 0.55, filter: 'bandpass', freq: 1200, freqEnd: 300, Q: 0.9, pos, rev: 0.3 });
    this.tone({ freq: heavy ? 90 : 130, freqEnd: 40, type: 'sine', dur: 0.25, gain: heavy ? 0.6 : 0.4, pos, rev: 0.2 });
    this.tone({ freq: 2400 + Math.random() * 400, type: 'triangle', dur: 0.3, gain: 0.06, pos, rev: 0.4 });
  }
  clang(pos) {
    for (const f of [1800, 2650, 4200]) this.tone({ freq: f * (0.97 + Math.random() * 0.06), type: 'sine', dur: 0.6, gain: 0.09, pos, rev: 0.5 });
    this.noise({ dur: 0.05, gain: 0.5, freq: 4000, Q: 1, pos });
  }
  deflect(pos) {
    this.tone({ freq: 2000, freqEnd: 5200, type: 'sine', dur: 0.35, gain: 0.18, rev: 0.6, pos });
    this.tone({ freq: 3000, type: 'triangle', dur: 0.9, gain: 0.08, rev: 0.7, pos });
    this.clang(pos);
  }
  guardUp() { this.noise({ dur: 0.1, gain: 0.12, filter: 'highpass', freq: 3000 }); }
  dash() {
    this.noise({ dur: 0.35, gain: 0.45, attack: 0.02, filter: 'bandpass', freq: 600, freqEnd: 3500, Q: 1.2, rev: 0.2 });
    this.tone({ freq: 200, freqEnd: 900, type: 'sine', dur: 0.25, gain: 0.08 });
  }
  chargeStart() {
    if (!this.ready) return null;
    const ctx = this.ctx, t = this.now;
    const o = ctx.createOscillator(); o.type = 'sawtooth';
    o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(440, t + 0.9);
    const o2 = ctx.createOscillator(); o2.type = 'sine';
    o2.frequency.setValueAtTime(660, t); o2.frequency.exponentialRampToValueAtTime(1760, t + 0.9);
    const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.setValueAtTime(400, t); f.frequency.exponentialRampToValueAtTime(3000, t + 0.9);
    const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.07, t + 0.4);
    o.connect(f); o2.connect(f); f.connect(g); g.connect(this._dest({ rev: 0.3 }));
    o.start(t); o2.start(t);
    return { stop: () => { const n = this.now; g.gain.cancelScheduledValues(n); g.gain.setTargetAtTime(0.0001, n, 0.03); o.stop(n + 0.2); o2.stop(n + 0.2); } };
  }
  chargeReady() { this.tone({ freq: 1760, type: 'sine', dur: 0.3, gain: 0.1, rev: 0.4 }); }
  waveRelease() {
    this.noise({ dur: 0.6, gain: 0.6, filter: 'bandpass', freq: 400, freqEnd: 5000, Q: 0.8, rev: 0.5 });
    this.tone({ freq: 220, freqEnd: 55, type: 'sawtooth', dur: 0.6, gain: 0.2, filter: 'lowpass', filterFreq: 1500, rev: 0.5 });
  }
  hurt() {
    this.tone({ freq: 90, freqEnd: 45, type: 'sine', dur: 0.35, gain: 0.6 });
    this.noise({ dur: 0.4, gain: 0.35, filter: 'bandpass', freq: 1800, Q: 0.4 });
    this.tone({ freq: 340, freqEnd: 120, type: 'square', dur: 0.25, gain: 0.05, filter: 'lowpass', filterFreq: 900 });
  }
  footstep(intensity = 1) {
    const f = 140 + Math.random() * 60;
    this.noise({ dur: 0.09, gain: 0.07 * intensity, filter: 'lowpass', freq: 500 + Math.random() * 200, rev: 0.15 });
    this.tone({ freq: f, freqEnd: f * 0.6, type: 'sine', dur: 0.08, gain: 0.05 * intensity, rev: 0.1 });
    this.noise({ dur: 0.03, gain: 0.025 * intensity, filter: 'highpass', freq: 4000, rev: 0.1 });
  }
  land(v) {
    const k = Math.min(1, v / 12);
    this.noise({ dur: 0.18, gain: 0.25 * k + 0.05, filter: 'lowpass', freq: 380, rev: 0.25 });
    this.tone({ freq: 80, freqEnd: 40, type: 'sine', dur: 0.2, gain: 0.25 * k });
  }
  jump() { this.noise({ dur: 0.12, gain: 0.06, filter: 'bandpass', freq: 900, freqEnd: 1600 }); }
  scanBeep(i = 0) { this.tone({ freq: 1200 + i * 120, type: 'square', dur: 0.05, gain: 0.03, filter: 'lowpass', filterFreq: 3000 }); }
  scanDone() {
    [1046.5, 1318.5, 1568].forEach((f, i) => this.tone({ freq: f, type: 'sine', dur: 0.3, gain: 0.07, delay: i * 0.07, rev: 0.4 }));
  }
  visorSwitch(on) { this.tone({ freq: on ? 600 : 900, freqEnd: on ? 900 : 600, type: 'sine', dur: 0.15, gain: 0.07 }); this.noise({ dur: 0.08, gain: 0.05, freq: 4000 }); }
  pickup() { this.tone({ freq: 880, freqEnd: 1760, type: 'sine', dur: 0.15, gain: 0.07, rev: 0.3 }); }
  focusIn() {
    this.tone({ freq: 400, freqEnd: 80, type: 'sine', dur: 0.8, gain: 0.25, rev: 0.8 });
    this.noise({ dur: 0.8, gain: 0.25, filter: 'bandpass', freq: 3000, freqEnd: 200, Q: 1, rev: 0.8 });
    this.buses.sfx.gain.setTargetAtTime(0.7, this.now, 0.2);
    this.buses.amb.gain.setTargetAtTime(0.35, this.now, 0.2);
  }
  focusOut() {
    this.tone({ freq: 80, freqEnd: 400, type: 'sine', dur: 0.5, gain: 0.2, rev: 0.5 });
    this.buses.sfx.gain.setTargetAtTime(1, this.now, 0.2);
    this.buses.amb.gain.setTargetAtTime(0.9, this.now, 0.4);
  }
  heartbeat(gain = 0.4) {
    this.tone({ freq: 55, freqEnd: 35, type: 'sine', dur: 0.18, gain });
    this.tone({ freq: 50, freqEnd: 32, type: 'sine', dur: 0.2, gain: gain * 0.7, delay: 0.22 });
  }
  threatPing(level) { this.tone({ freq: 700 + level * 500, type: 'sine', dur: 0.08, gain: 0.02 + level * 0.03, rev: 0.2 }); }

  // ---------------------------------------------------------------- enemy SFX
  crawlerHiss(pos) {
    this.noise({ dur: 0.7, gain: 0.35, attack: 0.05, filter: 'bandpass', freq: 3500, freqEnd: 2200, Q: 2, pos, rev: 0.4 });
    this.tone({ freq: 300, freqEnd: 180, type: 'sawtooth', dur: 0.5, gain: 0.05, filter: 'bandpass', filterFreq: 1200, Q: 4, pos });
  }
  crawlerScreech(pos) {
    this.tone({ freq: 1400, freqEnd: 700, type: 'sawtooth', dur: 0.45, gain: 0.12, filter: 'bandpass', filterFreq: 1800, Q: 3, pos, rev: 0.5 });
    this.tone({ freq: 1460, freqEnd: 760, type: 'sawtooth', dur: 0.45, gain: 0.1, filter: 'bandpass', filterFreq: 2400, Q: 3, pos, rev: 0.5 });
    this.noise({ dur: 0.4, gain: 0.2, freq: 3000, Q: 1, pos });
  }
  crawlerDie(pos) {
    this.tone({ freq: 900, freqEnd: 120, type: 'sawtooth', dur: 0.6, gain: 0.12, filter: 'bandpass', filterFreq: 1500, Q: 2, pos, rev: 0.5 });
    this.noise({ dur: 0.5, gain: 0.35, filter: 'lowpass', freq: 900, freqEnd: 100, pos, rev: 0.4 });
    this.skitter(pos, 0.3, 0.2);
  }
  sentinelBoot(pos) {
    this.tone({ freq: 60, freqEnd: 240, type: 'sawtooth', dur: 1.5, gain: 0.12, filter: 'lowpass', filterFreq: 300, filterEnd: 2000, pos, rev: 0.6 });
    [523, 659, 784].forEach((f, i) => this.tone({ freq: f, type: 'square', dur: 0.12, gain: 0.04, delay: 1 + i * 0.1, filter: 'lowpass', filterFreq: 2000, pos }));
  }
  sentinelCharge(pos) {
    this.tone({ freq: 300, freqEnd: 1800, type: 'sine', dur: 0.9, gain: 0.12, attack: 0.3, pos, rev: 0.4 });
    this.tone({ freq: 310, freqEnd: 1850, type: 'sawtooth', dur: 0.9, gain: 0.03, attack: 0.3, filter: 'lowpass', filterFreq: 2000, pos });
  }
  sentinelShot(pos) {
    this.tone({ freq: 1600, freqEnd: 200, type: 'sawtooth', dur: 0.3, gain: 0.15, filter: 'lowpass', filterFreq: 4000, pos, rev: 0.5 });
    this.noise({ dur: 0.15, gain: 0.3, freq: 2000, freqEnd: 500, pos });
  }
  sentinelHum(pos) {
    this.tone({ freq: 95, type: 'sawtooth', dur: 1.2, gain: 0.04, attack: 0.3, filter: 'lowpass', filterFreq: 400, pos });
  }
  sentinelDie(pos) {
    this.tone({ freq: 800, freqEnd: 50, type: 'sawtooth', dur: 1.2, gain: 0.15, filter: 'lowpass', filterFreq: 3000, filterEnd: 200, pos, rev: 0.6 });
    this.sparks(pos);
  }
  explosion(pos) {
    this.noise({ dur: 1.5, gain: 0.8, filter: 'lowpass', freq: 1200, freqEnd: 60, pos, rev: 0.7 });
    this.tone({ freq: 70, freqEnd: 25, type: 'sine', dur: 1, gain: 0.6, pos });
  }
  stalkerShriek(pos) {
    for (const [f, d] of [[620, 0], [930, 0.02], [1240, 0.04], [455, 0]]) {
      this.tone({ freq: f, freqEnd: f * 1.6, type: 'sawtooth', dur: 0.9, gain: 0.07, attack: 0.08, delay: d, filter: 'bandpass', filterFreq: f * 2, Q: 2, pos, rev: 0.8 });
    }
    this.noise({ dur: 0.9, gain: 0.3, attack: 0.08, filter: 'bandpass', freq: 2500, freqEnd: 5000, Q: 1, pos, rev: 0.8 });
  }
  stalkerWhoosh(pos) {
    this.noise({ dur: 0.5, gain: 0.3, attack: 0.1, filter: 'bandpass', freq: 300, freqEnd: 1600, Q: 2, pos, rev: 0.6 });
    this.tone({ freq: 200, freqEnd: 600, type: 'sine', dur: 0.4, gain: 0.05, pos, rev: 0.8 });
  }
  stalkerStep(pos) {
    this.noise({ dur: 0.12, gain: 0.12, filter: 'lowpass', freq: 300, pos, rev: 0.5 });
    this.tone({ freq: 3000, type: 'sine', dur: 0.05, gain: 0.015, pos });
  }
  stalkerDie(pos) {
    this.stalkerShriek(pos);
    this.tone({ freq: 400, freqEnd: 40, type: 'sawtooth', dur: 3, gain: 0.15, filter: 'lowpass', filterFreq: 2000, filterEnd: 100, pos, rev: 1 });
    this.explosion(pos);
  }
  cloakShimmer(pos) {
    this.tone({ freq: 2200, freqEnd: 1400, type: 'sine', dur: 0.6, gain: 0.03, attack: 0.2, pos, rev: 0.8 });
  }

  // ---------------------------------------------------------------- music
  _startMusic() {
    const ctx = this.ctx;
    this.combatGain = ctx.createGain(); this.combatGain.gain.value = 0;
    this.combatGain.connect(this.buses.music);
    const cs = ctx.createGain(); cs.gain.value = 0.25; this.combatGain.connect(cs); cs.connect(this.reverbIn);
    this.step = 0;
    this.nextStepTime = 0;
    this.bpm = 132;
    this._sched = setInterval(() => this._schedule(), 25);
  }

  setCombat(on) {
    if (!this.ready || on === this.combat) return;
    this.combat = on;
    const t = this.now;
    if (on) {
      this.step = 0; this.nextStepTime = t + 0.05;
      this.combatGain.gain.setTargetAtTime(0.9, t, 0.3);
    } else {
      this.combatGain.gain.setTargetAtTime(0.0001, t, 1.5);
      this.padTimer = 5;
    }
  }

  _schedule() {
    if (!this.ready) return;
    if (!this.combat && this.combatGain.gain.value < 0.002) return;
    const spb = 60 / this.bpm / 4; // 16th
    while (this.nextStepTime < this.now + 0.12) {
      this._playStep(this.step, this.nextStepTime);
      this.nextStepTime += spb;
      this.step = (this.step + 1) % 64;
    }
  }

  _playStep(s, t) {
    const ctx = this.ctx, out = this.combatGain;
    const st = s % 16, bar = Math.floor(s / 16);
    const v = (fn) => fn();
    // taiko / kick
    if ([0, 6, 8, 11, 14].includes(st) || (bar === 3 && st >= 12)) v(() => {
      const o = ctx.createOscillator(); const g = ctx.createGain();
      o.frequency.setValueAtTime(st === 0 ? 120 : 95, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.25);
      g.gain.setValueAtTime(st === 0 ? 0.7 : 0.45, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.35);
      o.connect(g); g.connect(out); o.start(t); o.stop(t + 0.4);
    });
    // hats
    if (st % 2 === 1) v(() => {
      const src = ctx.createBufferSource(); src.buffer = this.noiseBuf;
      const f = ctx.createBiquadFilter(); f.type = 'highpass'; f.frequency.value = 7000;
      const g = ctx.createGain(); g.gain.setValueAtTime(st % 4 === 3 ? 0.06 : 0.03, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
      src.connect(f); f.connect(g); g.connect(out); src.start(t, Math.random()); src.stop(t + 0.06);
    });
    // metal snare
    if (st === 4 || st === 12) v(() => {
      const src = ctx.createBufferSource(); src.buffer = this.noiseBuf;
      const f = ctx.createBiquadFilter(); f.type = 'bandpass'; f.frequency.value = 1800; f.Q.value = 0.8;
      const g = ctx.createGain(); g.gain.setValueAtTime(0.25, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.18);
      src.connect(f); f.connect(g); g.connect(out); src.start(t, Math.random()); src.stop(t + 0.2);
    });
    // bass ostinato (D phrygian)
    const bassPat = [36.7, 0, 36.7, 0, 38.9, 0, 36.7, 36.7, 0, 36.7, 43.65, 0, 36.7, 0, 32.7, 34.6];
    const shift = [1, 1, 1.189, 0.944][bar];
    const bf = bassPat[st];
    if (bf) v(() => {
      const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = bf * 2 * shift;
      const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.Q.value = 8;
      f.frequency.setValueAtTime(1400, t); f.frequency.exponentialRampToValueAtTime(120, t + 0.14);
      const g = ctx.createGain(); g.gain.setValueAtTime(0.22, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.16);
      o.connect(f); f.connect(g); g.connect(out); o.start(t); o.stop(t + 0.2);
    });
    // dissonant stab every 2 bars
    if (st === 0 && bar % 2 === 0) v(() => {
      for (const fr of [146.8, 155.6, 220, 311.1]) {
        const o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = fr * shift;
        const f = ctx.createBiquadFilter(); f.type = 'lowpass';
        f.frequency.setValueAtTime(3000, t); f.frequency.exponentialRampToValueAtTime(300, t + 1.2);
        const g = ctx.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.linearRampToValueAtTime(0.04, t + 0.02); g.gain.exponentialRampToValueAtTime(0.001, t + 1.5);
        o.connect(f); f.connect(g); g.connect(out); o.start(t); o.stop(t + 1.6);
      }
    });
    // high arp
    if (bar >= 2 && st % 2 === 0) v(() => {
      const arp = [587.3, 622.3, 880, 587.3, 698.5, 622.3, 880, 1174.7];
      const o = ctx.createOscillator(); o.type = 'square'; o.frequency.value = arp[(st / 2) % 8] * shift;
      const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 2200;
      const g = ctx.createGain(); g.gain.setValueAtTime(0.025, t); g.gain.exponentialRampToValueAtTime(0.001, t + 0.12);
      o.connect(f); f.connect(g); g.connect(out); o.start(t); o.stop(t + 0.15);
    });
  }

  suspend() { if (this.ready) this.ctx.suspend(); }
  resume() { if (this.ready) this.ctx.resume(); }
}
