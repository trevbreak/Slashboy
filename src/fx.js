import * as THREE from 'three';
import { glowTexture } from './textures.js';

const MAX_P = 1200;

export class FX {
  constructor(game) {
    this.game = game;
    const scene = this.scene = game.scene;
    this.glow = glowTexture();

    // ---- particle pool
    this.pos = new Float32Array(MAX_P * 3);
    this.col = new Float32Array(MAX_P * 3);
    this.size = new Float32Array(MAX_P);
    this.alpha = new Float32Array(MAX_P);
    this.vel = new Float32Array(MAX_P * 3);
    this.life = new Float32Array(MAX_P);
    this.maxLife = new Float32Array(MAX_P);
    this.grav = new Float32Array(MAX_P);
    this.drag = new Float32Array(MAX_P);
    this.cursor = 0;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('color', new THREE.BufferAttribute(this.col, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.size, 1).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('alpha', new THREE.BufferAttribute(this.alpha, 1).setUsage(THREE.DynamicDrawUsage));
    this.pgeo = g;
    const mat = new THREE.ShaderMaterial({
      uniforms: { map: { value: this.glow }, scale: { value: window.innerHeight / 2 } },
      vertexShader: `
        attribute float size; attribute float alpha; attribute vec3 color;
        varying vec3 vC; varying float vA; uniform float scale;
        void main() {
          vC = color; vA = alpha;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          gl_PointSize = size * scale / -mv.z;
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: `
        uniform sampler2D map; varying vec3 vC; varying float vA;
        void main() { vec4 t = texture2D(map, gl_PointCoord); gl_FragColor = vec4(vC * t.a * vA, 1.0); }`,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    });
    this.points = new THREE.Points(g, mat);
    this.points.frustumCulled = false;
    scene.add(this.points);
    

    // ---- ambient dust motes (wrap around camera)
    const DN = 500;
    this.dustN = DN;
    this.dustPos = new Float32Array(DN * 3);
    this.dustOff = new Float32Array(DN * 3);
    for (let i = 0; i < DN * 3; i++) this.dustOff[i] = Math.random() * 16;
    const dg = new THREE.BufferGeometry();
    dg.setAttribute('position', new THREE.BufferAttribute(this.dustPos, 3).setUsage(THREE.DynamicDrawUsage));
    // dust only shows where light actually is: lit by the nearest pool lights + the blade
    const NL = 6;
    this.dustUniforms = {
      map: { value: this.glow },
      scale: { value: window.innerHeight / 2 },
      lightPos: { value: Array.from({ length: NL }, () => new THREE.Vector3()) },
      lightCol: { value: Array.from({ length: NL }, () => new THREE.Color(0, 0, 0)) },
      lightDist: { value: new Array(NL).fill(1) },
    };
    this.dust = new THREE.Points(dg, new THREE.ShaderMaterial({
      uniforms: this.dustUniforms,
      vertexShader: `
        uniform float scale; uniform vec3 lightPos[${NL}]; uniform vec3 lightCol[${NL}]; uniform float lightDist[${NL}];
        varying vec3 vC;
        void main() {
          vec3 c = vec3(0.012, 0.014, 0.018);
          for (int i = 0; i < ${NL}; i++) {
            float d = distance(position, lightPos[i]);
            float k = clamp(1.0 - d / lightDist[i], 0.0, 1.0);
            c += lightCol[i] * k * k * 0.05;
          }
          vC = c;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          gl_PointSize = 0.045 * scale / -mv.z;
          gl_Position = projectionMatrix * mv;
        }`,
      fragmentShader: `
        uniform sampler2D map; varying vec3 vC;
        void main() { float a = texture2D(map, gl_PointCoord).a; gl_FragColor = vec4(vC * a, 1.0); }`,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    this.dust.frustumCulled = false;
    scene.add(this.dust);

    window.addEventListener('resize', () => { mat.uniforms.scale.value = window.innerHeight / 2; this.dustUniforms.scale.value = window.innerHeight / 2; });
    this.steamT = 0;

    // ---- sprites (streaks, flashes) and rings
    this.sprites = [];
    this.rings = [];
    this.pickups = [];

    // flash light
    this.flash = new THREE.PointLight(0xffffff, 0, 16, 2);
    scene.add(this.flash);
    this.flashT = 0;
  }

  emit(p, v, color, size, life, grav = 0, drag = 0) {
    const i = this.cursor; this.cursor = (this.cursor + 1) % MAX_P;
    this.pos[i * 3] = p.x; this.pos[i * 3 + 1] = p.y; this.pos[i * 3 + 2] = p.z;
    this.vel[i * 3] = v.x; this.vel[i * 3 + 1] = v.y; this.vel[i * 3 + 2] = v.z;
    this.col[i * 3] = color.r; this.col[i * 3 + 1] = color.g; this.col[i * 3 + 2] = color.b;
    this.size[i] = size; this.life[i] = life; this.maxLife[i] = life; this.grav[i] = grav; this.drag[i] = drag;
    this.alpha[i] = 1;
  }

  burst(p, { count = 20, color = new THREE.Color(2, 1.5, 0.8), speed = 6, life = 0.5, size = 0.12, grav = 9, drag = 1, dir = null, spread = 1 } = {}) {
    const v = new THREE.Vector3();
    for (let i = 0; i < count; i++) {
      v.set(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).normalize().multiplyScalar(spread);
      if (dir) v.add(dir);
      v.normalize().multiplyScalar(speed * (0.3 + Math.random() * 0.7));
      this.emit(p, v, color, size * (0.6 + Math.random() * 0.8), life * (0.5 + Math.random() * 0.5), grav, drag);
    }
  }

  sparks(p, dir = null, n = 18) { this.burst(p, { count: n, color: new THREE.Color(3, 2, 0.8), speed: 9, life: 0.45, size: 0.07, grav: 14, drag: 0.5, dir, spread: 0.9 }); }
  ichor(p, dir = null, n = 22) { this.burst(p, { count: n, color: new THREE.Color(1.2, 0.2, 2.2), speed: 6, life: 0.7, size: 0.13, grav: 12, drag: 1, dir, spread: 1 }); }
  cyanBurst(p, n = 30) { this.burst(p, { count: n, color: new THREE.Color(0.4, 2.2, 3), speed: 7, life: 0.5, size: 0.1, grav: 0, drag: 3 }); }

  streak(p, angle, color = new THREE.Color(1.5, 3, 3.5), len = 2.6, life = 0.16) {
    const mat = new THREE.SpriteMaterial({ map: this.glow, color, blending: THREE.AdditiveBlending, depthWrite: false, depthTest: false, rotation: angle });
    const s = new THREE.Sprite(mat);
    s.position.copy(p); s.scale.set(len, 0.12, 1);
    this.scene.add(s);
    this.sprites.push({ s, life, max: life, len });
  }

  glowFlash(p, color = new THREE.Color(2, 2, 2), size = 3, life = 0.25) {
    const mat = new THREE.SpriteMaterial({ map: this.glow, color, blending: THREE.AdditiveBlending, depthWrite: false });
    const s = new THREE.Sprite(mat);
    s.position.copy(p); s.scale.setScalar(size);
    this.scene.add(s);
    this.sprites.push({ s, life, max: life, grow: size });
  }

  ring(p, color = new THREE.Color(0.5, 2, 3), maxR = 6, life = 0.6, normal = new THREE.Vector3(0, 1, 0)) {
    const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 48), new THREE.MeshBasicMaterial({ color, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    m.position.copy(p);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), normal);
    this.scene.add(m);
    this.rings.push({ m, life, max: life, maxR });
  }

  lightFlash(p, color = 0xffffff, intensity = 30, dur = 0.15) {
    this.flash.position.copy(p); this.flash.color.set(color); this.flash.intensity = intensity;
    this.flashT = dur; this.flashMax = dur; this.flashI = intensity;
  }

  pickup(p, kind = 'hp') {
    const color = kind === 'hp' ? new THREE.Color(0.6, 2.5, 3) : new THREE.Color(2, 1, 3);
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glow, color, blending: THREE.AdditiveBlending, depthWrite: false }));
    s.scale.setScalar(0.5);
    s.position.copy(p);
    this.scene.add(s);
    this.pickups.push({ s, kind, vel: new THREE.Vector3((Math.random() - 0.5) * 4, 3 + Math.random() * 2, (Math.random() - 0.5) * 4), life: 14, t: 0 });
  }

  // feed the dust shader the nearest active lights
  setDustLights(pool, extra) {
    const u = this.dustUniforms;
    let n = 0;
    for (const l of pool) {
      if (n >= u.lightPos.value.length - 1) break;
      if (l.intensity <= 0.01) continue;
      u.lightPos.value[n].copy(l.position);
      u.lightCol.value[n].copy(l.color).multiplyScalar(Math.min(l.intensity, 25));
      u.lightDist.value[n] = l.distance;
      n++;
    }
    if (extra) {
      u.lightPos.value[n].copy(extra.position);
      u.lightCol.value[n].copy(extra.color).multiplyScalar(extra.intensity * 3);
      u.lightDist.value[n] = extra.distance;
      n++;
    }
    for (; n < u.lightPos.value.length; n++) u.lightCol.value[n].setRGB(0, 0, 0);
  }

  steam(vents, camPos, dt) {
    this.steamT -= dt;
    if (this.steamT > 0) return;
    this.steamT = 0.035;
    const v = new THREE.Vector3();
    for (const p of vents) {
      if (p.distanceToSquared(camPos) > 900) continue;
      const puff = 0.5 + 0.5 * Math.sin(performance.now() * 0.0011 + p.x);
      v.set((Math.random() - 0.5) * 0.4, 1.4 + Math.random() * 1.2 * puff, (Math.random() - 0.5) * 0.4);
      const q = p.clone().add(new THREE.Vector3((Math.random() - 0.5) * 0.5, 0.05, (Math.random() - 0.5) * 0.5));
      const g = 0.10 + Math.random() * 0.05;
      this.emit(q, v, new THREE.Color(g, g * 1.05, g * 1.15), 0.7 + Math.random() * 0.9, 2.2 + Math.random(), -0.15, 0.6);
    }
  }

  update(dt, camPos, player) {
    // particles
    for (let i = 0; i < MAX_P; i++) {
      if (this.life[i] <= 0) { if (this.alpha[i] !== 0) { this.alpha[i] = 0; } continue; }
      this.life[i] -= dt;
      const k = 1 - this.drag[i] * dt;
      this.vel[i * 3] *= k; this.vel[i * 3 + 1] = this.vel[i * 3 + 1] * k - this.grav[i] * dt; this.vel[i * 3 + 2] *= k;
      this.pos[i * 3] += this.vel[i * 3] * dt; this.pos[i * 3 + 1] += this.vel[i * 3 + 1] * dt; this.pos[i * 3 + 2] += this.vel[i * 3 + 2] * dt;
      if (this.pos[i * 3 + 1] < 0.02 && this.vel[i * 3 + 1] < 0) { this.pos[i * 3 + 1] = 0.02; this.vel[i * 3 + 1] *= -0.3; }
      this.alpha[i] = Math.max(0, this.life[i] / this.maxLife[i]);
    }
    this.pgeo.attributes.position.needsUpdate = true;
    this.pgeo.attributes.alpha.needsUpdate = true;
    this.pgeo.attributes.color.needsUpdate = true;
    this.pgeo.attributes.size.needsUpdate = true;

    // dust wrap
    const S = 16, t = performance.now() * 0.001;
    for (let i = 0; i < this.dustN; i++) {
      const ox = this.dustOff[i * 3] + Math.sin(t * 0.1 + i) * 0.4;
      const oy = this.dustOff[i * 3 + 1] + t * 0.05 * ((i % 3) - 1);
      const oz = this.dustOff[i * 3 + 2] + Math.cos(t * 0.13 + i * 0.7) * 0.4;
      this.dustPos[i * 3] = camPos.x + (((ox - camPos.x) % S) + S) % S - S / 2;
      this.dustPos[i * 3 + 1] = camPos.y + (((oy - camPos.y) % S) + S) % S - S / 2;
      this.dustPos[i * 3 + 2] = camPos.z + (((oz - camPos.z) % S) + S) % S - S / 2;
    }
    this.dust.geometry.attributes.position.needsUpdate = true;

    // sprites
    for (let i = this.sprites.length - 1; i >= 0; i--) {
      const o = this.sprites[i];
      o.life -= dt;
      const k = Math.max(0, o.life / o.max);
      o.s.material.opacity = k;
      if (o.len) o.s.scale.set(o.len * (1.3 - k * 0.3), 0.12 * k + 0.02, 1);
      if (o.grow) o.s.scale.setScalar(o.grow * (1 + (1 - k) * 0.6));
      if (o.life <= 0) { this.scene.remove(o.s); o.s.material.dispose(); this.sprites.splice(i, 1); }
    }
    for (let i = this.rings.length - 1; i >= 0; i--) {
      const o = this.rings[i];
      o.life -= dt;
      const k = 1 - Math.max(0, o.life / o.max);
      o.m.scale.setScalar(0.2 + k * o.maxR);
      o.m.material.opacity = 1 - k;
      if (o.life <= 0) { this.scene.remove(o.m); o.m.geometry.dispose(); o.m.material.dispose(); this.rings.splice(i, 1); }
    }
    // flash
    if (this.flashT > 0) { this.flashT -= dt; this.flash.intensity = Math.max(0, this.flashT / this.flashMax) * this.flashI; } else this.flash.intensity = 0;

    // pickups
    if (player) {
      const target = player.position.clone(); target.y += 1.0;
      for (let i = this.pickups.length - 1; i >= 0; i--) {
        const p = this.pickups[i];
        p.t += dt; p.life -= dt;
        const d = p.s.position.distanceTo(target);
        if (p.t > 0.6 && d < 5) {
          const dir = target.clone().sub(p.s.position).normalize();
          p.vel.lerp(dir.multiplyScalar(14), Math.min(1, dt * 6));
        } else {
          p.vel.y -= 9 * dt;
          p.vel.multiplyScalar(1 - dt * 1.5);
        }
        p.s.position.addScaledVector(p.vel, dt);
        if (p.s.position.y < 0.3) { p.s.position.y = 0.3; p.vel.y = Math.abs(p.vel.y) * 0.4; }
        p.s.scale.setScalar(0.4 + Math.sin(p.t * 8) * 0.08);
        if (p.t > 0.6 && d < 0.8) {
          player.collect(p.kind);
          this.scene.remove(p.s); this.pickups.splice(i, 1);
        } else if (p.life <= 0) { this.scene.remove(p.s); this.pickups.splice(i, 1); }
      }
    }
  }
}
