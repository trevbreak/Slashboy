import * as THREE from 'three';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { bladeTextures } from './textures.js';

const _v1 = new THREE.Vector3(), _v2 = new THREE.Vector3(), _v3 = new THREE.Vector3();
const UP = new THREE.Vector3(0, 1, 0);

// ---------------------------------------------------------------- viewmodel poses
// p: position in camera space, r: euler (order YXZ), tw: twist about the blade axis
const POSE = {
  rest:   { p: [0.27, -0.30, -0.50], r: [-1.0, 0.3, 0.2], tw: -0.5 },
  s0a:    { p: [0.44, -0.08, -0.42], r: [-1.05, -1.25, 0], tw: 0 },
  s0b:    { p: [-0.32, -0.32, -0.48], r: [-1.85, 1.3, 0], tw: 0 },
  s1a:    { p: [-0.32, -0.30, -0.42], r: [-1.9, 1.25, 0], tw: Math.PI },
  s1b:    { p: [0.42, -0.06, -0.48], r: [-1.15, -1.3, 0], tw: Math.PI },
  s2a:    { p: [0.15, 0.14, -0.32], r: [0.4, 0.05, 0], tw: -Math.PI / 2 },
  s2b:    { p: [0.02, -0.46, -0.5], r: [-2.3, 0.05, 0], tw: -Math.PI / 2 },
  wavea:  { p: [0.52, -0.15, -0.34], r: [-1.45, -1.6, 0], tw: 0 },
  waveb:  { p: [-0.46, -0.2, -0.44], r: [-1.45, 1.6, 0], tw: 0 },
  charge: { p: [0.44, -0.22, -0.30], r: [-1.3, -1.45, 0], tw: 0 },
  guard:  { p: [0.16, -0.17, -0.46], r: [-0.15, 0, 1.45], tw: -Math.PI / 2 },
  dash:   { p: [0.38, -0.42, -0.42], r: [-1.25, 0.35, 0.5], tw: -0.3 },
  scan:   { p: [0.36, -0.55, -0.45], r: [-0.4, 0.2, 0.5], tw: -0.4 },
};
const SLASHES = [
  { a: 's0a', b: 's0b', dur: 0.34, dmg: 12, streak: -0.35 },
  { a: 's1a', b: 's1b', dur: 0.34, dmg: 12, streak: 0.35 },
  { a: 's2a', b: 's2b', dur: 0.46, dmg: 22, streak: 1.45, heavy: true },
];

function lerpAngle(a, b, k) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * k;
}
const easeOut = (t) => 1 - Math.pow(1 - t, 3);
const easeInOut = (t) => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

function mixPose(a, b, k, out) {
  for (let i = 0; i < 3; i++) { out.p[i] = a.p[i] + (b.p[i] - a.p[i]) * k; out.r[i] = a.r[i] + (b.r[i] - a.r[i]) * k; }
  out.tw = a.tw + (b.tw - a.tw) * k;
  return out;
}
const clonePose = (p) => ({ p: p.p.slice(), r: p.r.slice(), tw: p.tw });

export class Player {
  constructor(game) {
    this.game = game;
    this.position = new THREE.Vector3();
    this.vel = new THREE.Vector3();
    this.yaw = 0; this.pitch = 0; this.roll = 0;
    this.radius = 0.35; this.height = 1.75; this.eye = 1.62;
    this.maxHp = 100; this.hp = 100; this.ki = 100;
    this.onGround = true;
    this.stepDist = 0; this.bobT = 0; this.bob = 0; this.landDip = 0;
    this.attack = null; this.comboIdx = 0; this.comboTimer = 0; this.queued = false;
    this.lmbT = 0; this.charging = false; this.chargeT = 0; this.chargeNeed = 0.85; this.chargeSnd = null; this.chargeReady = false;
    this.guard = false; this.guardT = 0;
    this.dashT = 0; this.dashCd = 0; this.dashDir = new THREE.Vector3(); this.airDashUsed = false; this.dashHits = new Set();
    this.focusActive = false; this.focusT = 0;
    this.scanMode = false; this.scanTarget = null; this.scanProgress = 0; this.scanCandidates = []; this.scanPanelOpen = false; this.scanBeepT = 0;
    this.lockTarget = null; this.lockLost = 0;
    this.invuln = 0; this.shake = 0; this.fov = 75; this.dead = false;
    this.heartT = 0; this.statV = 0; this.dashV = 0;
    this.waves = [];
    this.lookDelta = new THREE.Vector2();
    this.buildViewmodel();

    this.bladeLight = new THREE.PointLight(0x7fe8ff, 1.4, 6, 2);
    game.scene.add(this.bladeLight);
    // faint suit/visor fill so nearby geometry never collapses to pure black
    this.visorLight = new THREE.PointLight(0xa8c0d8, 1.8, 9, 1.2);
    game.scene.add(this.visorLight);
  }

  // ================================================================ viewmodel
  buildViewmodel() {
    const vs = this.game.vmScene;
    const pmrem = new THREE.PMREMGenerator(this.game.renderer);
    vs.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    vs.environmentIntensity = 0.12;
    vs.add(new THREE.AmbientLight(0x404858, 0.6));
    const key = new THREE.DirectionalLight(0xbfd8ff, 0.55); key.position.set(-1, 2, 1); vs.add(key);
    this.vmLight = new THREE.PointLight(0x7fe8ff, 0.15, 1.2, 2); this.vmLight.position.set(0.1, -0.1, -0.3); vs.add(this.vmLight);
    this.vmFill = new THREE.AmbientLight(0xffffff, 0); vs.add(this.vmFill);

    const outer = this.vm = new THREE.Group();
    outer.rotation.order = 'YXZ';
    const inner = this.vmInner = new THREE.Group();
    outer.add(inner);
    outer.scale.setScalar(0.62);
    vs.add(outer);

    // blade with curvature and taper
    const L = 0.95;
    const bg = new THREE.BoxGeometry(0.03, L, 0.006, 1, 32, 1);
    const pa = bg.attributes.position;
    for (let i = 0; i < pa.count; i++) {
      let x = pa.getX(i), y = pa.getY(i) + L / 2, z = pa.getZ(i);
      const t = y / L;
      x *= 1 - 0.25 * t;
      if (t > 0.92) { const k = (t - 0.92) / 0.08; x = x < 0 ? x + (0.015 * (1 - 0.25 * t) * 2) * k * k : x; z *= 1 - k * 0.8; }
      x += 0.035 * t * t;
      pa.setXYZ(i, x, y + 0.1, z);
    }
    bg.computeVertexNormals();
    const bt = bladeTextures();
    const steel = new THREE.MeshPhysicalMaterial({ color: 0xa6b0bb, map: bt.map, roughnessMap: bt.roughnessMap, metalness: 1, roughness: 0.55, clearcoat: 0.5, clearcoatRoughness: 0.1 });
    inner.add(new THREE.Mesh(bg, steel));
    // energy edge
    const eg = new THREE.BoxGeometry(0.004, L * 0.9, 0.008, 1, 30, 1);
    const ea = eg.attributes.position;
    for (let i = 0; i < ea.count; i++) {
      const y = ea.getY(i) + L * 0.45, t = y / L;
      ea.setXYZ(i, ea.getX(i) - 0.015 * (1 - 0.25 * t) + 0.035 * t * t, y + 0.12, ea.getZ(i));
    }
    // energy edge: plasma flowing toward the tip
    this.edgeColor = new THREE.Color(0.3, 1.6, 2.1);
    this.edgeU = { color: { value: this.edgeColor }, time: { value: 0 } };
    this.edgeMat = new THREE.ShaderMaterial({
      uniforms: this.edgeU,
      vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: `uniform vec3 color; uniform float time; varying vec2 vUv;
        void main(){
          float flow = 0.65 + 0.35 * sin(vUv.y * 90.0 - time * 18.0) * sin(vUv.y * 23.0 - time * 7.0);
          float tipFade = smoothstep(1.0, 0.85, vUv.y) * smoothstep(0.0, 0.05, vUv.y);
          gl_FragColor = vec4(color * flow * (0.6 + tipFade * 0.6), 1.0);
        }`,
    });
    inner.add(new THREE.Mesh(eg, this.edgeMat));
    this.blade = { base: new THREE.Vector3(0.0, 0.14, 0), tip: new THREE.Vector3(0.035, 0.1 + L, 0) };

    const dark = new THREE.MeshStandardMaterial({ color: 0x15171c, roughness: 0.7, metalness: 0.3 });
    const gold = new THREE.MeshStandardMaterial({ color: 0x5a4a2a, roughness: 0.35, metalness: 0.9 });
    // ornate tsuba: open ring with spokes and a cyan inlay
    const tsubaG = new THREE.Group(); tsubaG.position.y = 0.075; inner.add(tsubaG);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(0.05, 0.008, 6, 24), gold); ring.rotation.x = Math.PI / 2; tsubaG.add(ring);
    const disc = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 0.012, 16), gold); tsubaG.add(disc);
    for (let i = 0; i < 6; i++) {
      const sp = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.008, 0.006), gold);
      const a = i * Math.PI / 3; sp.position.set(Math.cos(a) * 0.036, 0, Math.sin(a) * 0.036); sp.rotation.y = -a; tsubaG.add(sp);
    }
    const inlay = new THREE.Mesh(new THREE.TorusGeometry(0.042, 0.0025, 4, 24), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.2, 1.3, 1.7) }));
    inlay.rotation.x = Math.PI / 2; inlay.position.y = 0.007; tsubaG.add(inlay);
    const hab = new THREE.Mesh(new THREE.BoxGeometry(0.034, 0.025, 0.012), gold);
    hab.position.y = 0.095; inner.add(hab);
    const handle = new THREE.Mesh(new THREE.CylinderGeometry(0.017, 0.019, 0.27, 8), dark);
    handle.position.y = -0.065; inner.add(handle);
    for (let i = 0; i < 7; i++) {
      const wrap = new THREE.Mesh(new THREE.TorusGeometry(0.0195, 0.004, 4, 8), new THREE.MeshStandardMaterial({ color: 0x0c2a33, roughness: 0.8 }));
      wrap.rotation.x = Math.PI / 2; wrap.position.y = -0.18 + i * 0.035; inner.add(wrap);
    }
    const pommel = new THREE.Mesh(new THREE.CylinderGeometry(0.022, 0.02, 0.025, 8), gold);
    pommel.position.y = -0.21; inner.add(pommel);
    // gloved hand & forearm (attached to outer so it doesn't twist with the blade)
    const armor = new THREE.MeshStandardMaterial({ color: 0x1a1d24, roughness: 0.45, metalness: 0.6 });
    const hand = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.1, 0.05), armor);
    hand.position.set(0.026, -0.03, 0.012); outer.add(hand);
    // fingers curled around the grip
    for (let i = 0; i < 4; i++) {
      const f = new THREE.Mesh(new THREE.TorusGeometry(0.024, 0.0095, 6, 10, Math.PI * 1.3), armor);
      f.rotation.set(Math.PI / 2, 0, Math.PI * 0.85); f.position.set(0.0, -0.075 + i * 0.024, 0.0);
      outer.add(f);
    }
    const thumb = new THREE.Mesh(new THREE.CapsuleGeometry(0.009, 0.04, 3, 6), armor);
    thumb.position.set(-0.016, 0.0, -0.016); thumb.rotation.set(0.4, 0, 0.5); outer.add(thumb);
    const plate = new THREE.Mesh(new THREE.BoxGeometry(0.05, 0.085, 0.012), new THREE.MeshStandardMaterial({ color: 0x2a2f38, metalness: 0.9, roughness: 0.3 }));
    plate.position.set(0.05, -0.03, 0.012); plate.rotation.y = 0.3; outer.add(plate);
    const knuck = new THREE.Mesh(new THREE.BoxGeometry(0.074, 0.02, 0.02), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.2, 1.4, 1.8) }));
    knuck.position.set(0.006, -0.02, -0.04); outer.add(knuck);
    const fore = new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.05, 0.42, 10), armor);
    fore.position.set(0.02, -0.2, 0.15); fore.rotation.x = 0.85; outer.add(fore);
    const cuff = new THREE.Mesh(new THREE.CylinderGeometry(0.052, 0.052, 0.03, 10), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.2, 1.2, 1.6) }));
    cuff.position.set(0.02, -0.1, 0.06); cuff.rotation.x = 0.85; outer.add(cuff);

    this.pose = clonePose(POSE.rest);
    this.tmpPose = clonePose(POSE.rest);

    // slash trail
    const N = 16;
    this.trailN = N;
    this.trailBase = []; this.trailTip = [];
    const tg = new THREE.BufferGeometry();
    this.trailPos = new Float32Array(N * 2 * 3);
    this.trailA = new Float32Array(N * 2);
    tg.setAttribute('position', new THREE.BufferAttribute(this.trailPos, 3).setUsage(THREE.DynamicDrawUsage));
    tg.setAttribute('a', new THREE.BufferAttribute(this.trailA, 1).setUsage(THREE.DynamicDrawUsage));
    const idx = [];
    for (let i = 0; i < N - 1; i++) { const a = i * 2, b = a + 1, c = a + 2, d = a + 3; idx.push(a, b, c, b, d, c); }
    tg.setIndex(idx);
    this.trailColor = new THREE.Color(0.5, 2.2, 3.0);
    const tm = new THREE.ShaderMaterial({
      uniforms: { color: { value: this.trailColor } },
      vertexShader: 'attribute float a; varying float vA; void main(){ vA = a; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
      fragmentShader: 'uniform vec3 color; varying float vA; void main(){ gl_FragColor = vec4(color * vA, 1.0); }',
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    this.trail = new THREE.Mesh(tg, tm);
    this.trail.frustumCulled = false;
    vs.add(this.trail);
  }

  applyPose(p) {
    this.vm.position.set(p.p[0], p.p[1], p.p[2]);
    this.vm.rotation.set(p.r[0], p.r[1], p.r[2]);
    this.vmInner.rotation.y = p.tw;
  }

  updateTrail(active) {
    if (active) {
      this.vm.updateMatrixWorld(true);
      this.trailBase.unshift(this.blade.base.clone().applyMatrix4(this.vmInner.matrixWorld));
      this.trailTip.unshift(this.blade.tip.clone().applyMatrix4(this.vmInner.matrixWorld));
    } else if (this.trailBase.length) { this.trailBase.pop(); this.trailTip.pop(); }
    while (this.trailBase.length > this.trailN) { this.trailBase.pop(); this.trailTip.pop(); }
    const n = this.trailBase.length;
    for (let i = 0; i < this.trailN; i++) {
      const j = Math.min(i, n - 1);
      const b = n ? this.trailBase[j] : this.vm.position, t = n ? this.trailTip[j] : this.vm.position;
      // pull base toward tip so the ribbon reads as an arc of the outer blade
      this.trailPos.set([b.x + (t.x - b.x) * 0.6, b.y + (t.y - b.y) * 0.6, b.z + (t.z - b.z) * 0.6], i * 6);
      this.trailPos.set([t.x, t.y, t.z], i * 6 + 3);
      const a = i < n ? Math.pow(1 - i / this.trailN, 1.6) : 0;
      this.trailA[i * 2] = 0; this.trailA[i * 2 + 1] = a * 0.4;
    }
    this.trail.geometry.attributes.position.needsUpdate = true;
    this.trail.geometry.attributes.a.needsUpdate = true;
  }

  // ================================================================ helpers
  forward(out = new THREE.Vector3()) {
    return out.set(-Math.sin(this.yaw) * Math.cos(this.pitch), Math.sin(this.pitch), -Math.cos(this.yaw) * Math.cos(this.pitch));
  }
  eyePos(out = new THREE.Vector3()) { return out.copy(this.position).setY(this.position.y + this.eye); }
  addShake(v) { this.shake = Math.min(1.2, this.shake + v); }

  respawn(pos, yaw = 0) {
    this.position.copy(pos); this.vel.set(0, 0, 0);
    this.yaw = yaw; this.pitch = 0;
    this.hp = this.maxHp; this.ki = 100; this.dead = false;
    this.attack = null; this.charging = false; this.chargeT = 0; this.guard = false;
    this.lockTarget = null; this.invuln = 1; this.dashT = 0;
    if (this.chargeSnd) { this.chargeSnd.stop(); this.chargeSnd = null; }
    if (this.focusActive) this.endFocus();
    for (const w of this.waves) this.game.scene.remove(w.mesh);
    this.waves.length = 0;
  }

  collect(kind) {
    if (kind === 'hp') this.hp = Math.min(this.maxHp, this.hp + 12);
    else this.ki = Math.min(100, this.ki + 25);
    this.game.audio.pickup();
  }

  // ================================================================ damage
  receiveHit(dmg, srcPos, kind = 'melee', attacker = null) {
    if (this.dead) return 'none';
    const g = this.game;
    if (this.invuln > 0) return 'evaded';
    const toSrc = _v1.subVectors(srcPos, this.eyePos(_v2)).setY(0).normalize();
    const fwd = _v3.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    if (this.guard && fwd.dot(toSrc) > 0.25) {
      if (this.guardT < 0.25) {
        // perfect parry
        g.audio.deflect(srcPos);
        g.fx.cyanBurst(_v2.copy(this.eyePos()).addScaledVector(fwd, 0.8), 30);
        g.fx.lightFlash(this.eyePos(), 0x9ff4ff, 25, 0.2);
        g.hitStop(0.14);
        this.ki = Math.min(100, this.ki + 15);
        this.addShake(0.3);
        if (attacker && attacker.stagger) attacker.stagger(1.6, fwd);
        g.hud.message('PARRY', 0.6);
        return 'parry';
      }
      this.hp -= dmg * 0.15;
      this.ki = Math.max(0, this.ki - 8);
      g.audio.clang(srcPos);
      g.fx.sparks(_v2.copy(this.eyePos()).addScaledVector(fwd, 0.7), toSrc.clone().negate(), 12);
      this.addShake(0.25);
      this.vel.addScaledVector(toSrc, -4);
      return 'block';
    }
    this.hp -= dmg;
    this.invuln = 0.6;
    g.hud.damage(dmg);
    g.audio.hurt();
    this.statV = 1;
    this.addShake(0.5);
    this.vel.addScaledVector(toSrc, -6);
    if (this.hp <= 0) { this.hp = 0; this.dead = true; g.onPlayerDeath(); }
    return 'hit';
  }

  // ================================================================ abilities
  startSlash(idx) {
    const s = SLASHES[idx];
    this.attack = { kind: 'slash', idx, t: 0, dur: s.dur, hit: false, from: clonePose(this.pose), def: s };
    this.queued = false;
    this.game.audio.swing(idx);
  }

  startWave() {
    this.attack = { kind: 'wave', t: 0, dur: 0.4, hit: false, from: clonePose(this.pose) };
    this.ki -= 25;
    this.game.audio.waveRelease();
  }

  fireWave() {
    const g = this.game;
    const dir = this.forward();
    const geo = new THREE.RingGeometry(1.0, 1.35, 32, 1, 0, Math.PI);
    geo.rotateX(-Math.PI / 2);
    const mesh = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: new THREE.Color(1.2, 3.0, 4.0), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    const p = this.eyePos().addScaledVector(dir, 0.8);
    p.y -= 0.15;
    mesh.position.copy(p);
    mesh.lookAt(_v1.copy(p).sub(dir));
    mesh.rotateZ((Math.random() - 0.5) * 0.3);
    g.scene.add(mesh);
    this.waves.push({ mesh, dir, dist: 0, hits: new Set(), life: 1.2 });
    g.fx.lightFlash(p, 0x8ff0ff, 20, 0.2);
    this.addShake(0.25);
  }

  performHit(dmg, heavy, streakAngle) {
    const g = this.game;
    const eye = this.eyePos(new THREE.Vector3());
    const fwd = this.forward(new THREE.Vector3());
    let hits = 0;
    for (const e of g.enemies.list) {
      if (!e.alive || e.dormant) continue;
      const c = e.center();
      const to = _v1.subVectors(c, eye);
      const dist = to.length() - e.radius;
      if (dist > 3.0) continue;
      to.normalize();
      const cosLimit = dist < 1.2 ? 0.2 : 0.55;
      if (fwd.dot(to) < cosLimit) continue;
      const hp = _v2.copy(c).addScaledVector(to, -e.radius * 0.7);
      e.takeDamage(dmg, fwd.clone(), heavy ? 'heavy' : 'slash');
      hits++;
      if (e.organic) g.fx.ichor(hp, fwd, heavy ? 30 : 18); else g.fx.sparks(hp, fwd, heavy ? 28 : 16);
      g.fx.streak(hp, streakAngle + (Math.random() - 0.5) * 0.2);
      g.audio.slashHit(hp, heavy);
    }
    // deflect bolts
    for (const b of g.enemies.bolts) {
      if (b.reflected || b.dead) continue;
      const to = _v1.subVectors(b.pos, eye);
      const d = to.length();
      if (d > 3.6) continue;
      if (fwd.dot(to.normalize()) < 0.35) continue;
      g.enemies.reflectBolt(b);
      g.audio.deflect(b.pos);
      g.fx.cyanBurst(b.pos, 24);
      g.hud.message('DEFLECT', 0.6);
      hits++;
    }
    // doors
    for (const d of Object.values(g.level.doors)) {
      const to = _v1.subVectors(d.panelPos, eye);
      const dist = to.length();
      if (dist > 3.4) continue;
      if (fwd.dot(to.normalize()) < 0.5) continue;
      d.strike();
      g.fx.sparks(_v2.copy(eye).addScaledVector(fwd, Math.min(dist, 2.5)), null, 8);
      g.audio.clang(d.panelPos);
    }
    if (hits) {
      g.hitStop(heavy ? 0.11 : 0.065);
      this.addShake(heavy ? 0.35 : 0.18);
      g.hud.hitMarker();
      this.ki = Math.min(100, this.ki + 3 * hits);
      g.fx.lightFlash(_v2.copy(eye).addScaledVector(fwd, 1.5), 0x9ff4ff, heavy ? 18 : 10, 0.1);
    }
  }

  startDash(wish) {
    const g = this.game;
    this.dashDir.copy(wish.lengthSq() > 0.01 ? wish : _v1.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw))).normalize();
    this.dashT = 0.17; this.dashCd = 0.5; this.ki -= 12; this.invuln = Math.max(this.invuln, 0.24);
    if (!this.onGround) this.airDashUsed = true;
    this.dashHits.clear();
    g.audio.dash();
    this.dashV = 1;
  }

  startFocus() {
    this.focusActive = true; this.focusT = 4.5; this.ki -= 35;
    this.game.audio.focusIn();
  }
  endFocus() {
    this.focusActive = false;
    this.game.audio.focusOut();
  }

  toggleLock() {
    const g = this.game;
    if (this.lockTarget) { this.lockTarget = null; return; }
    const eye = this.eyePos(new THREE.Vector3()), fwd = this.forward(new THREE.Vector3());
    let best = null, bestScore = Infinity;
    for (const e of g.enemies.list) {
      if (!e.alive || e.dormant || (e.cloaked && !this.scanMode)) continue;
      const to = _v1.subVectors(e.center(), eye);
      const d = to.length();
      if (d > 32) continue;
      const ang = Math.acos(Math.min(1, fwd.dot(to.normalize())));
      if (ang > 0.65) continue;
      const score = ang * 3 + d * 0.05;
      if (score < bestScore && g.level.lineOfSight(eye, e.center())) { best = e; bestScore = score; }
    }
    if (best) { this.lockTarget = best; g.audio.tone({ freq: 1400, freqEnd: 1800, type: 'sine', dur: 0.08, gain: 0.06 }); }
    else g.audio.tone({ freq: 400, type: 'square', dur: 0.06, gain: 0.03, filter: 'lowpass', filterFreq: 1200 });
  }

  // ================================================================ scan visor
  updateScan(dt, input) {
    const g = this.game;
    const eye = this.eyePos(new THREE.Vector3()), fwd = this.forward(new THREE.Vector3());
    const cands = this.scanCandidates; cands.length = 0;
    for (const s of g.level.scannables) {
      const to = _v1.subVectors(s.pos, eye);
      const d = to.length();
      if (d > 22) continue;
      if (fwd.dot(to.normalize()) < 0.3) continue;
      cands.push(s);
    }
    for (const e of g.enemies.list) {
      if (!e.alive || !e.scanInfo) continue;
      const c = e.center();
      const to = _v1.subVectors(c, eye);
      if (to.length() > 30 || fwd.dot(to.normalize()) < 0.3) continue;
      if (!e._scanProxy) e._scanProxy = { pos: new THREE.Vector3(), enemy: e, title: e.scanInfo.title, text: e.scanInfo.text, get scanned() { return g.scannedTypes.has(e.type); }, set scanned(v) { if (v) g.scannedTypes.add(e.type); } };
      e._scanProxy.pos.copy(c);
      cands.push(e._scanProxy);
    }
    // target: closest to crosshair
    let best = null, bestA = Infinity;
    for (const s of cands) {
      const to = _v1.subVectors(s.pos, eye);
      const d = to.length();
      const a = Math.acos(Math.min(1, fwd.dot(to.normalize())));
      const tol = Math.max(0.06, Math.atan((s.radius || 0.8) / d) * 1.4);
      if (a < tol && a < bestA && g.level.lineOfSight(eye, _v2.copy(s.pos).addScaledVector(to, -0.4))) { best = s; bestA = a; }
    }
    if (best !== this.scanTarget) { this.scanProgress = 0; this.scanTarget = best; }

    if (this.scanPanelOpen) {
      if (input.mousePressed[0]) { this.scanPanelOpen = false; g.hud.closeScan(); }
      return;
    }
    if (best && input.mouseDown[0]) {
      if (best.scanned) {
        if (input.mousePressed[0]) { g.hud.openScan(best); this.scanPanelOpen = true; g.audio.scanBeep(3); }
      } else {
        this.scanProgress += dt / 1.1;
        this.scanBeepT -= dt;
        if (this.scanBeepT <= 0) { this.scanBeepT = 0.12; g.audio.scanBeep(Math.floor(this.scanProgress * 6)); }
        if (this.scanProgress >= 1) {
          best.scanned = true;
          this.scanProgress = 0;
          g.audio.scanDone();
          g.hud.openScan(best);
          this.scanPanelOpen = true;
          if (best.onScan) best.onScan();
        }
      }
    } else this.scanProgress = Math.max(0, this.scanProgress - dt * 2);
  }

  // ================================================================ main update
  update(dt, realDt) {
    const g = this.game, input = g.input, level = g.level;
    if (this.dead) { this.updateCamera(realDt); return; }
    this.invuln = Math.max(0, this.invuln - dt);
    this.dashCd = Math.max(0, this.dashCd - dt);
    this.comboTimer = Math.max(0, this.comboTimer - dt);
    if (!this.focusActive && !this.charging) this.ki = Math.min(100, this.ki + dt * 7);
    const controls = g.controlsEnabled;

    // ---------- look
    const sens = input.sensitivity;
    this.lookDelta.set(controls ? input.dx : 0, controls ? input.dy : 0);
    if (this.lockTarget && (!this.lockTarget.alive || this.lockTarget.dormant || (this.lockTarget.cloaked && !this.scanMode))) this.lockTarget = null;
    if (this.lockTarget) {
      const c = this.lockTarget.center();
      const eye = this.eyePos(_v1);
      const to = _v2.subVectors(c, eye);
      const d = to.length();
      if (d > 40) this.lockTarget = null;
      else {
        const ty = Math.atan2(-to.x, -to.z);
        const tp = Math.asin(Math.max(-1, Math.min(1, to.y / d)));
        const k = 1 - Math.exp(-realDt * 12);
        this.yaw = lerpAngle(this.yaw, ty, k);
        this.pitch += (tp - this.pitch) * k;
        this.lockLost = level.lineOfSight(eye, c) ? 0 : this.lockLost + realDt;
        if (this.lockLost > 1.5) this.lockTarget = null;
      }
    } else {
      this.yaw -= this.lookDelta.x * sens;
      this.pitch -= this.lookDelta.y * sens;
      this.pitch = Math.max(-1.45, Math.min(1.45, this.pitch));
    }

    // ---------- toggles
    if (controls) {
      if (input.just('KeyE')) {
        this.scanMode = !this.scanMode;
        g.audio.visorSwitch(this.scanMode);
        if (!this.scanMode) { this.scanPanelOpen = false; g.hud.closeScan(); this.scanTarget = null; }
        if (this.charging) this.cancelCharge();
        if (this.scanMode && !g.flags.scanHinted) { g.flags.scanHinted = true; g.hud.hint('Hold <b>LMB</b> on a marker to scan. Cloaked things show up in this visor.', 6); }
      }
      if (input.just('KeyQ')) this.toggleLock();
      if (input.just('KeyR')) {
        if (this.focusActive) this.endFocus();
        else if (this.ki >= 35) this.startFocus();
        else g.audio.denied(null);
      }
    }
    if (this.focusActive) { this.focusT -= realDt; if (this.focusT <= 0) this.endFocus(); }

    // ---------- movement intent
    let f = 0, s = 0;
    if (controls) {
      if (input.down('KeyW')) f += 1;
      if (input.down('KeyS')) f -= 1;
      if (input.down('KeyD')) s += 1;
      if (input.down('KeyA')) s -= 1;
    }
    const fwdFlat = _v1.set(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
    const right = _v2.set(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    const wish = new THREE.Vector3().addScaledVector(fwdFlat, f).addScaledVector(right, s);
    if (wish.lengthSq() > 1) wish.normalize();

    if (controls && (input.just('ShiftLeft') || input.just('ShiftRight')) && this.dashCd <= 0 && this.ki >= 12 && (this.onGround || !this.airDashUsed)) this.startDash(wish);

    let speed = 5.4;
    if (this.guard) speed *= 0.45;
    if (this.scanMode) speed *= 0.6;
    if (this.charging) speed *= 0.65;
    if (this.attack) speed *= 0.75;

    if (this.dashT > 0) {
      this.dashT -= dt;
      this.vel.x = this.dashDir.x * 24; this.vel.z = this.dashDir.z * 24;
      this.vel.y = Math.max(this.vel.y, 0) * 0.5;
      // phantom step: cut through enemies
      for (const e of g.enemies.list) {
        if (!e.alive || e.dormant || this.dashHits.has(e)) continue;
        const c = e.center();
        if (Math.hypot(c.x - this.position.x, c.z - this.position.z) < e.radius + 1.0 && Math.abs(c.y - (this.position.y + 1)) < 2) {
          this.dashHits.add(e);
          e.takeDamage(10, this.dashDir.clone(), 'dash');
          if (e.organic) g.fx.ichor(c, this.dashDir, 14); else g.fx.sparks(c, this.dashDir, 14);
          g.audio.slashHit(c, false);
          g.fx.streak(c, 0, new THREE.Color(1.5, 1, 3.5), 3.5, 0.2);
          g.hitStop(0.04);
        }
      }
      if (this.dashT <= 0) { this.vel.x *= 0.35; this.vel.z *= 0.35; }
    } else {
      const rate = this.onGround ? 14 : 3;
      const k = 1 - Math.exp(-rate * dt);
      this.vel.x += (wish.x * speed - this.vel.x) * k;
      this.vel.z += (wish.z * speed - this.vel.z) * k;
    }

    if (controls && input.just('Space') && this.onGround) {
      this.vel.y = 6.4; this.onGround = false; g.audio.jump();
    }
    if (this.dashT <= 0) this.vel.y -= 19 * dt;

    // ---------- integrate & collide
    const oldY = this.position.y;
    const steps = this.dashT > 0 ? 3 : 1;
    for (let i = 0; i < steps; i++) {
      this.position.x += this.vel.x * dt / steps;
      this.position.z += this.vel.z * dt / steps;
      level.resolveCircle(this.position, this.radius, this.position.y + 0.45, this.position.y + this.height);
    }
    this.position.y += this.vel.y * dt;
    if (this.vel.y > 0) {
      const ceil = level.ceilingAt(this.position, this.radius, oldY + this.height);
      if (this.position.y + this.height > ceil) { this.position.y = ceil - this.height; this.vel.y = 0; }
    }
    const maxUp = this.onGround ? 0.45 : Math.max(0.05, oldY - this.position.y + 0.05);
    const ground = level.groundAt(this.position, this.radius, maxUp);
    if (this.position.y <= ground) {
      if (!this.onGround && this.vel.y < -3) { g.audio.land(-this.vel.y); this.landDip = Math.min(0.25, -this.vel.y * 0.02); }
      this.position.y = ground; this.vel.y = Math.max(0, this.vel.y); this.onGround = true; this.airDashUsed = false;
    } else if (this.onGround && this.position.y - ground < 0.35 && this.vel.y <= 0) {
      this.position.y = ground;
    } else this.onGround = false;
    if (this.position.y < -30) { this.receiveHit(15, this.position, 'fall'); g.respawnAtCheckpoint(false); }

    // footsteps & bob
    const hs = Math.hypot(this.vel.x, this.vel.z);
    if (this.onGround && hs > 0.8 && this.dashT <= 0) {
      this.stepDist += hs * dt;
      this.bobT += hs * dt * 1.35;
      if (this.stepDist > 2.0) { this.stepDist = 0; g.audio.footstep(Math.min(1, hs / 5)); }
    }
    this.bob += ((this.onGround ? Math.sin(this.bobT * 2) * 0.035 * Math.min(1, hs / 5) : 0) - this.bob) * Math.min(1, dt * 10);

    // ---------- combat input
    if (controls && this.scanMode) {
      this.updateScan(realDt, input);
      this.guard = false;
    } else if (controls) {
      // guard
      const wantGuard = input.mouseDown[2] && !this.attack && !this.charging;
      if (wantGuard && !this.guard) { this.guardT = 0; g.audio.guardUp(); }
      this.guard = wantGuard;
      if (this.guard) this.guardT += dt;

      if (input.mousePressed[0]) {
        this.lmbT = 0;
        if (!this.attack) {
          const idx = this.comboTimer > 0 ? this.comboIdx : 0;
          this.startSlash(idx);
        } else if (this.attack.kind === 'slash' && this.attack.t > this.attack.dur * 0.35) this.queued = true;
      }
      if (input.mouseDown[0]) {
        this.lmbT += dt;
        if (!this.attack && this.lmbT > 0.32 && !this.charging && this.ki >= 25) {
          this.charging = true; this.chargeT = 0; this.chargeReady = false;
          this.chargeSnd = g.audio.chargeStart();
        }
        if (this.charging) {
          this.chargeT += dt;
          if (!this.chargeReady && this.chargeT >= this.chargeNeed) { this.chargeReady = true; g.audio.chargeReady(); }
        }
      }
      if (input.mouseReleased[0]) {
        if (this.charging) {
          const ready = this.chargeT >= this.chargeNeed;
          this.cancelCharge();
          if (ready) this.startWave();
        }
        this.lmbT = 0;
      }
    }

    // ---------- attack progression & viewmodel pose
    this.updateAttack(dt);

    // ---------- arc waves
    this.updateWaves(dt);

    // heartbeat when low
    if (this.hp < 30) {
      this.heartT -= realDt;
      if (this.heartT <= 0) { this.heartT = 0.75 + this.hp / 60; g.audio.heartbeat(0.3); }
    }

    this.updateCamera(realDt);
  }

  cancelCharge() {
    this.charging = false; this.chargeT = 0; this.chargeReady = false;
    if (this.chargeSnd) { this.chargeSnd.stop(); this.chargeSnd = null; }
  }

  updateAttack(dt) {
    const a = this.attack;
    let target = null;
    let trailOn = false;
    if (a) {
      a.t += dt;
      const k = a.t / a.dur;
      let pa, pb;
      if (a.kind === 'slash') { pa = POSE[a.def.a]; pb = POSE[a.def.b]; } else { pa = POSE.wavea; pb = POSE.waveb; }
      const W = 0.2, S = 0.3;
      if (k < W) target = mixPose(a.from, pa, easeOut(k / W), this.tmpPose);
      else if (k < W + S) { target = mixPose(pa, pb, easeInOut((k - W) / S), this.tmpPose); trailOn = true; }
      else target = mixPose(pb, POSE.rest, easeInOut(Math.min(1, (k - W - S) / (1 - W - S))), this.tmpPose);
      if (k > W + S * 0.2 && k < W + S + 0.05) trailOn = true;
      if (!a.hit && k >= W + S * 0.45) {
        a.hit = true;
        if (a.kind === 'slash') this.performHit(a.def.dmg, !!a.def.heavy, a.def.streak);
        else { this.fireWave(); this.performHit(14, true, 0); }
      }
      // pose copy
      this.pose.p = target.p.slice(); this.pose.r = target.r.slice(); this.pose.tw = target.tw;
      if (a.t >= a.dur) {
        this.attack = null;
        if (a.kind === 'slash') {
          this.comboIdx = (a.idx + 1) % 3;
          this.comboTimer = a.idx === 2 ? 0 : 0.38;
          if (this.queued && a.idx < 2) this.startSlash(a.idx + 1);
          else if (this.queued) { this.queued = false; this.startSlash(0); }
        }
      } else if (a.kind === 'slash' && this.queued && k > 0.62 && a.idx < 2) {
        // cancel recovery into the next slash for snappy combos
        this.attack = null;
        this.startSlash(a.idx + 1);
      }
    } else {
      let rest = POSE.rest;
      if (this.charging) rest = POSE.charge;
      else if (this.guard) rest = POSE.guard;
      else if (this.dashT > 0) rest = POSE.dash;
      else if (this.scanMode) rest = POSE.scan;
      const k = 1 - Math.exp(-dt * (this.guard ? 22 : 12));
      mixPose(this.pose, rest, k, this.pose);
    }
    // sway & bob layered on top
    const view = this.tmpPose2 || (this.tmpPose2 = clonePose(POSE.rest));
    view.p[0] = this.pose.p[0] - this.lookDelta.x * 0.00025 + Math.cos(this.bobT) * 0.008;
    view.p[1] = this.pose.p[1] + this.lookDelta.y * 0.00025 + Math.abs(Math.sin(this.bobT)) * 0.01 - this.landDip * 0.3;
    view.p[2] = this.pose.p[2];
    view.r[0] = this.pose.r[0]; view.r[1] = this.pose.r[1]; view.r[2] = this.pose.r[2];
    view.tw = this.pose.tw;
    if (this.charging) { const j = Math.min(1, this.chargeT / this.chargeNeed) * 0.004; view.p[0] += (Math.random() - 0.5) * j; view.p[1] += (Math.random() - 0.5) * j; }
    this.applyPose(view);
    this.updateTrail(trailOn);

    // blade glow
    const charge = this.charging ? Math.min(1, this.chargeT / this.chargeNeed) : 0;
    const glow = 0.45 + charge * 1.4 + (trailOn ? 0.4 : 0) + (this.focusActive ? 0.3 : 0);
    const col = this.focusActive ? [1.4, 1.2, 3.6] : charge >= 1 ? [2.4, 2.6, 4] : [0.4, 2.6, 3.4];
    this.edgeColor.setRGB(col[0] * glow, col[1] * glow, col[2] * glow);
    this.edgeU.time.value += dt;
    this.trailColor.setRGB(col[0] * 0.5, col[1] * 0.5, col[2] * 0.5);
    this.bladeLight.intensity = 1.2 + charge * 5 + (trailOn ? 2 : 0);
    this.vmLight.intensity = 0.12 + charge * 1.2;
  }

  updateWaves(dt) {
    const g = this.game;
    for (let i = this.waves.length - 1; i >= 0; i--) {
      const w = this.waves[i];
      const prev = w.mesh.position.clone();
      const step = 34 * dt;
      w.mesh.position.addScaledVector(w.dir, step);
      w.dist += step; w.life -= dt;
      w.mesh.scale.setScalar(1 + w.dist * 0.03);
      w.mesh.material.opacity = Math.min(1, w.life * 2);
      // enemies
      for (const e of g.enemies.list) {
        if (!e.alive || e.dormant || w.hits.has(e)) continue;
        const c = e.center();
        const d = distPointSegment(c, prev, w.mesh.position);
        if (d < e.radius + 1.3 * w.mesh.scale.x) {
          w.hits.add(e);
          e.takeDamage(38, w.dir.clone(), 'wave');
          if (e.organic) g.fx.ichor(c, w.dir, 30); else g.fx.sparks(c, w.dir, 30);
          g.audio.slashHit(c, true);
          g.fx.streak(c, 0, new THREE.Color(1.5, 3, 4), 4, 0.25);
          g.hitStop(0.05);
        }
      }
      for (const b of g.enemies.bolts) {
        if (!b.dead && !b.reflected && distPointSegment(b.pos, prev, w.mesh.position) < 1.4) { b.dead = true; g.fx.cyanBurst(b.pos, 12); }
      }
      const wallHit = !g.level.lineOfSight(prev, w.mesh.position);
      if (wallHit || w.life <= 0 || w.dist > 40) {
        if (wallHit) { g.fx.sparks(prev, w.dir.clone().negate(), 20); g.audio.clang(prev); }
        g.scene.remove(w.mesh); w.mesh.geometry.dispose(); w.mesh.material.dispose();
        this.waves.splice(i, 1);
      }
    }
  }

  updateCamera(dt) {
    const g = this.game, cam = g.camera;
    this.shake = Math.max(0, this.shake - dt * 2.2);
    this.landDip = Math.max(0, this.landDip - dt * 0.8);
    this.statV = Math.max(0, this.statV - dt * 1.6);
    this.dashV = Math.max(0, this.dashV - dt * 4);
    const sh = this.shake * this.shake;
    const strafe = (g.input.down('KeyD') ? 1 : 0) - (g.input.down('KeyA') ? 1 : 0);
    this.roll += ((g.controlsEnabled ? -strafe * 0.012 : 0) - this.roll) * Math.min(1, dt * 6);
    cam.position.set(
      this.position.x + (Math.random() - 0.5) * sh * 0.12,
      this.position.y + this.eye + this.bob - this.landDip + (Math.random() - 0.5) * sh * 0.12,
      this.position.z + (Math.random() - 0.5) * sh * 0.12,
    );
    if (this.dead) cam.position.y = this.position.y + 0.5;
    cam.rotation.set(this.pitch + (Math.random() - 0.5) * sh * 0.03, this.yaw, this.roll + (this.dead ? 0.4 : 0));
    const targetFov = 75 + (this.dashT > 0 ? 10 : 0) - (this.focusActive ? 6 : 0) - (this.charging ? Math.min(1, this.chargeT) * 4 : 0);
    this.fov += (targetFov - this.fov) * Math.min(1, dt * 10);
    cam.fov = this.fov; cam.updateProjectionMatrix();
    cam.updateMatrixWorld();

    // blade light rides at the right hand
    const fwd = this.forward(_v1), right = _v2.set(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
    this.bladeLight.position.copy(cam.position).addScaledVector(fwd, 0.5).addScaledVector(right, 0.35).add(_v3.set(0, -0.2, 0));
    this.visorLight.position.copy(cam.position).addScaledVector(fwd, 0.6);
  }
}

function distPointSegment(p, a, b) {
  const ab = _v3.subVectors(b, a);
  const t = Math.max(0, Math.min(1, _v1.subVectors(p, a).dot(ab) / Math.max(1e-6, ab.lengthSq())));
  return _v2.copy(a).addScaledVector(ab, t).distanceTo(p);
}
