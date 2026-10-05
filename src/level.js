import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { panelPBR, floorPBR, windowTexture, neonTexture, screenTexture, glowTexture, planetTexture, hologramTexture } from './textures.js';

const T = 0.5; // wall thickness
const LIGHT_POOL = 8;
const SHADOW_LIGHTS = 3; // nearest pool lights cast real-time cube shadows
export const holoUniforms = { time: { value: 0 } };

function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

function worldUV(geo, w, h, d, s) {
  const uv = geo.attributes.uv;
  const dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let f = 0; f < 6; f++) for (let i = 0; i < 4; i++) {
    const k = f * 4 + i;
    uv.setXY(k, uv.getX(k) * dims[f][0] / s, uv.getY(k) * dims[f][1] / s);
  }
}

export const shaftUniforms = { time: { value: 0 } };

function shaftMaterial(color, opacity) {
  return new THREE.ShaderMaterial({
    uniforms: { time: shaftUniforms.time, color: { value: new THREE.Color(color) }, opacity: { value: opacity } },
    vertexShader: `
      varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying vec3 vW;
      void main() {
        vUv = uv;
        vec4 wp = modelMatrix * vec4(position, 1.0);
        vW = wp.xyz;
        vN = normalize(mat3(modelMatrix) * normal);
        vV = normalize(cameraPosition - wp.xyz);
        gl_Position = projectionMatrix * viewMatrix * wp;
      }`,
    fragmentShader: `
      uniform float time; uniform vec3 color; uniform float opacity;
      varying vec2 vUv; varying vec3 vN; varying vec3 vV; varying vec3 vW;
      float h(vec3 p){ return fract(sin(dot(p, vec3(12.9898,78.233,37.719)))*43758.5453); }
      float n3(vec3 p){ vec3 i=floor(p); vec3 f=fract(p); f=f*f*(3.0-2.0*f);
        return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),
                   mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z); }
      void main() {
        float fres = pow(abs(dot(normalize(vN), normalize(vV))), 1.6);
        float along = smoothstep(0.0, 0.25, vUv.y) * smoothstep(1.0, 0.85, vUv.y);
        float dust = 0.65 + 0.35 * n3(vW * 0.8 + vec3(0.0, time * 0.15, time * 0.05));
        float camFade = smoothstep(0.5, 3.0, length(cameraPosition - vW));
        gl_FragColor = vec4(color * opacity * fres * along * dust * camFade, 1.0);
      }`,
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, fog: false,
  });
}

// ---------------------------------------------------------------------------- Door
class Door {
  constructor(level, { x, z, axis = 'x', w = 3, h = 3.5, locked = false, name = 'door' }) {
    this.level = level; this.name = name; this.w = w; this.h = h; this.axis = axis;
    this.locked = locked; this.open = 0; this.target = 0; this.timer = 0; this.holdOpen = false;
    this.center = new THREE.Vector3(x, 0, z);
    this.panelPos = new THREE.Vector3(x, 1.6, z);
    const g = this.group = new THREE.Group();
    g.position.set(x, 0, z);
    if (axis === 'z') g.rotation.y = Math.PI / 2;
    level.scene.add(g);

    const mats = level.mats;
    this.leafMat = mats.door;
    this.panelMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    this.stripMat = new THREE.MeshBasicMaterial({ color: 0xffffff });
    this.leaves = [];
    for (const s of [-1, 1]) {
      const leaf = new THREE.Group();
      const body = new THREE.Mesh(new THREE.BoxGeometry(w / 2, h, 0.3), mats.door);
      body.position.set(0, h / 2, 0); body.castShadow = body.receiveShadow = true;
      leaf.add(body);
      // chevron light strips
      const strip = new THREE.Mesh(new THREE.BoxGeometry(0.06, h * 0.8, 0.34), this.stripMat);
      strip.position.set(-s * (w / 4 - 0.05), h / 2, 0);
      leaf.add(strip);
      leaf.userData.strip = strip;
      leaf.position.x = s * w / 4;
      leaf.userData.side = s;
      g.add(leaf);
      this.leaves.push(leaf);
    }
    // lock panel (hex) on both faces, on the left leaf near seam
    const hex = new THREE.CylinderGeometry(0.32, 0.32, 0.36, 6);
    hex.rotateX(Math.PI / 2);
    const panel = new THREE.Mesh(hex, this.panelMat);
    panel.position.set(w / 4 - 0.38, 1.6, 0);
    this.leaves[0].add(panel);
    // frame
    const fm = mats.darkMetal;
    const fw = 0.35;
    for (const s of [-1, 1]) {
      const post = new THREE.Mesh(new THREE.BoxGeometry(fw, h + fw, 0.7), fm);
      post.position.set(s * (w / 2 + fw / 2 - 0.05), (h + fw) / 2, 0); post.castShadow = true;
      g.add(post);
    }
    const top = new THREE.Mesh(new THREE.BoxGeometry(w + fw * 2, fw, 0.7), fm);
    top.position.set(0, h + fw / 2, 0); g.add(top);
    const glowTop = new THREE.Mesh(new THREE.BoxGeometry(w, 0.05, 0.74), this.stripMat);
    glowTop.position.set(0, h - 0.02, 0); g.add(glowTop);

    // collider
    const hw = w / 2, d = 0.25;
    this.collider = axis === 'x'
      ? { min: new THREE.Vector3(x - hw, 0, z - d), max: new THREE.Vector3(x + hw, h, z + d) }
      : { min: new THREE.Vector3(x - d, 0, z - hw), max: new THREE.Vector3(x + d, h, z + hw) };
    level.colliders.push(this.collider);
    this.refreshColor();
  }

  refreshColor() {
    const c = this.locked ? new THREE.Color(4, 0.25, 0.3) : new THREE.Color(0.4, 3, 3.6);
    this.panelMat.color.copy(c);
    this.stripMat.color.copy(c).multiplyScalar(0.5);
  }

  strike() {
    const a = this.level.game.audio;
    if (this.locked) { a.denied(this.panelPos); this.level.game.hud.message('ACCESS DENIED', 1.2, true); return; }
    if (this.target === 0) this.openDoor();
  }
  openDoor() {
    if (this.target === 1) return;
    this.target = 1; this.timer = 0;
    this.level.game.audio.doorOpen(this.panelPos);
  }
  closeDoor() {
    if (this.target === 0) return;
    this.target = 0;
    this.level.game.audio.doorClose(this.panelPos);
  }
  lock(slam = false) {
    this.locked = true; this.refreshColor();
    if (this.target === 1) {
      this.target = 0;
      if (slam) this.level.game.audio.doorLockSlam(this.panelPos); else this.level.game.audio.doorClose(this.panelPos);
    }
  }
  unlock(chime = true) {
    if (!this.locked) return;
    this.locked = false; this.refreshColor();
    if (chime) this.level.game.audio.unlockChime(this.panelPos);
  }

  update(dt, playerPos) {
    const speed = this.target > this.open ? 1.6 : 2.4;
    this.open += Math.sign(this.target - this.open) * Math.min(Math.abs(this.target - this.open), dt * speed);
    const e = this.open * this.open * (3 - 2 * this.open);
    for (const leaf of this.leaves) leaf.position.x = leaf.userData.side * (this.w / 4 + e * this.w / 2);
    this.collider.enabled = this.open < 0.7;
    if (this.target === 1) {
      this.timer += dt;
      const dx = playerPos.x - this.center.x, dz = playerPos.z - this.center.z;
      const dist = Math.hypot(dx, dz);
      if (!this.holdOpen && this.timer > 3 && dist > 6) this.closeDoor();
    } else if (this.open > 0.05) {
      // don't crush the player: reopen if standing in doorway
      const along = this.axis === 'x' ? Math.abs(playerPos.z - this.center.z) : Math.abs(playerPos.x - this.center.x);
      const across = this.axis === 'x' ? Math.abs(playerPos.x - this.center.x) : Math.abs(playerPos.z - this.center.z);
      if (along < 0.7 && across < this.w / 2 && !this.locked) { this.target = 1; this.timer = 0; }
    }
  }
}

// ---------------------------------------------------------------------------- Level
export class Level {
  constructor(game) {
    this.game = game;
    this.scene = game.scene;
    this.colliders = [];
    this.losMeshes = [];
    this.doors = {};
    this.scannables = [];
    this.fixtures = [];
    this.animated = [];
    this.zones = [];
    this.points = {};
    this.moonLevel = 0; this.moonTarget = 0;
    this.time = 0;
  }

  build() {
    this.makeMaterials();
    this.makeLights();
    this.buildBay();
    this.buildCorridor();
    this.buildAtrium();
    this.buildFunnel();
    this.buildArena();
    this.buildFinal();
    this.buildSky();
    this.buildCity();
    this.buildZones();
    this.buildSetPieces();
    this.mergeStatics();
  }

  // Collapse static meshes into one draw call per (16m chunk, material, shadow flags).
  // Chunking keeps frustum culling effective, which matters most for cube shadow faces.
  mergeStatics() {
    const groups = new Map();
    const victims = [];
    this.scene.traverse((o) => {
      if (!o.isMesh || !o.userData.static || o.parent !== this.scene) return;
      const cx = Math.floor(o.position.x / 16), cz = Math.floor(o.position.z / 16);
      const big = o.geometry.boundingSphere || (o.geometry.computeBoundingSphere(), o.geometry.boundingSphere);
      const chunk = big.radius * Math.max(o.scale.x, o.scale.y, o.scale.z) > 20 ? 'big' : `${cx},${cz}`;
      const key = `${chunk}|${o.material.uuid}|${o.castShadow}|${o.receiveShadow}`;
      if (!groups.has(key)) groups.set(key, { mat: o.material, cast: o.castShadow, recv: o.receiveShadow, geos: [] });
      o.updateMatrix();
      const g = o.geometry.index ? o.geometry.clone() : o.geometry.clone();
      g.applyMatrix4(o.matrix);
      for (const name of Object.keys(g.attributes)) if (!['position', 'normal', 'uv'].includes(name)) g.deleteAttribute(name);
      groups.get(key).geos.push(g.index ? g : g);
      victims.push(o);
    });
    for (const o of victims) { this.scene.remove(o); o.geometry.dispose(); }
    let calls = 0;
    for (const { mat, cast, recv, geos } of groups.values()) {
      const indexed = geos.filter((g) => g.index), plain = geos.filter((g) => !g.index);
      for (const set of [indexed, plain]) {
        if (!set.length) continue;
        const merged = mergeGeometries(set, false);
        if (!merged) continue;
        merged.computeBoundingSphere();
        const m = new THREE.Mesh(merged, mat);
        m.castShadow = cast; m.receiveShadow = recv; m.matrixAutoUpdate = false;
        this.scene.add(m);
        calls++;
      }
      for (const g of geos) g.dispose();
    }
    this.mergedCount = { meshes: victims.length, calls };
  }

  // Bake a reflection / ambient probe per zone so metal and puddles reflect their own room.
  bakeProbes(renderer) {
    const rt = new THREE.WebGLCubeRenderTarget(256, { type: THREE.HalfFloatType });
    const cam = new THREE.CubeCamera(0.1, 400, rt);
    this.scene.add(cam);
    const pmrem = new THREE.PMREMGenerator(renderer);
    const spots = {
      bay: [0, 2.5, -6], spine: [0, 1.6, -26], junction: [8, 1.6, -38.5], atrium: [42, 3, -46],
      funnel: [34, 2, -85], arena: [34, 3, -107], final: [34, 2, -138],
    };
    const savedMoon = this.moon.intensity;
    for (const z of this.zones) {
      const p = new THREE.Vector3(...spots[z.id]);
      this.updateFixtures(0, p);
      this.moon.intensity = z.moon * this.moonMax;
      cam.position.copy(p);
      cam.update(renderer, this.scene);
      z.env = pmrem.fromCubemap(rt.texture).texture;
    }
    this.moon.intensity = savedMoon;
    this.scene.remove(cam);
    rt.dispose(); pmrem.dispose();
  }

  // -------------------------------------------------------------- materials
  makeMaterials() {
    const wall = panelPBR(11, [62, 67, 76]);
    const wallDark = panelPBR(23, [44, 47, 55]);
    const ceil = panelPBR(37, [34, 36, 42], { decals: false });
    const floor = floorPBR(5);
    const doorTex = panelPBR(51, [78, 82, 92], { S: 512 });
    const std = (t, o = {}) => new THREE.MeshStandardMaterial({
      map: t.map, normalMap: t.normalMap, normalScale: new THREE.Vector2(1, 1),
      aoMap: t.ormMap, aoMapIntensity: 1, roughnessMap: t.ormMap, metalnessMap: t.ormMap,
      roughness: 1, metalness: 0.85, envMapIntensity: 1, ...o,
    });
    const glow = (r, g, b) => new THREE.MeshBasicMaterial({ color: new THREE.Color(r, g, b) });
    this.mats = {
      wall: std(wall),
      wallDark: std(wallDark),
      ceil: std(ceil, { roughness: 1.1 }),
      floor: std(floor, { metalness: 0.9 }),
      door: std(doorTex, { metalness: 0.9 }),
      darkMetal: new THREE.MeshStandardMaterial({ color: 0x23272d, roughness: 0.38, metalness: 0.9 }),
      pipe: new THREE.MeshStandardMaterial({ color: 0x3d362c, roughness: 0.35, metalness: 0.85 }),
      rubber: new THREE.MeshStandardMaterial({ color: 0x0b0b0c, roughness: 0.9, metalness: 0.0 }),
      cyan: glow(0.25, 1.6, 2.0),
      cyanDim: glow(0.05, 0.35, 0.45),
      red: glow(3.0, 0.15, 0.2),
      redDim: glow(0.6, 0.03, 0.05),
      amber: glow(2.4, 1.2, 0.2),
      purple: glow(1.4, 0.3, 2.6),
      white: glow(3, 3, 3.2),
      glass: new THREE.MeshStandardMaterial({ color: 0x88aacc, roughness: 0.05, metalness: 0.9, transparent: true, opacity: 0.12, depthWrite: false }),
      bloom: new THREE.MeshStandardMaterial({ color: 0x1a0822, emissive: new THREE.Color(0.2, 0.03, 0.34), emissiveIntensity: 1, roughness: 0.3, metalness: 0.1 }),
      bloomFlesh: new THREE.MeshStandardMaterial({ color: 0x120610, roughness: 0.35, metalness: 0.2 }),
    };
    this.glowTex = glowTexture();
  }

  // -------------------------------------------------------------- light system
  makeLights() {
    const s = this.scene;
    this.hemi = new THREE.HemisphereLight(0x3a5068, 0x0c0d10, 0.7);
    s.add(this.hemi);
    this.lightBoost = 1.7;

    this.pool = [];
    for (let i = 0; i < LIGHT_POOL; i++) {
      const l = new THREE.PointLight(0xffffff, 0, 10, 2);
      if (i < SHADOW_LIGHTS) {
        l.castShadow = true;
        l.shadow.mapSize.set(512, 512);
        l.shadow.bias = -0.002; l.shadow.normalBias = 0.03;
        l.shadow.camera.near = 0.1; l.shadow.radius = 3;
        l.shadow.autoUpdate = false;
      }
      s.add(l); this.pool.push(l);
    }

    // moonlight through the concourse window
    const m = this.moon = new THREE.DirectionalLight(0x9db4ff, 0);
    const target = new THREE.Object3D(); target.position.set(34, 0, -45); s.add(target);
    m.target = target;
    m.position.set(34 + 60, 70, -45 + 8);
    m.castShadow = true;
    m.shadow.mapSize.set(2048, 2048);
    const sc = m.shadow.camera;
    sc.left = -60; sc.right = 60; sc.top = 60; sc.bottom = -60; sc.near = 10; sc.far = 220;
    m.shadow.bias = -0.0004; m.shadow.normalBias = 0.04;
    s.add(m);
    this.moonMax = 2.2;
  }

  fixture({ x, y, z, color = 0xcfe8ff, intensity = 6, distance = 10, mode = 'steady', size = [1.2, 0.08, 0.3], group = null, mesh = true, lightY = -0.25 }) {
    const col = new THREE.Color(color);
    let mat = null, m = null;
    if (mesh) {
      mat = new THREE.MeshBasicMaterial({ color: col.clone().multiplyScalar(3) });
      m = new THREE.Mesh(new THREE.BoxGeometry(...size), mat);
      m.position.set(x, y, z);
      this.scene.add(m);
      const housing = new THREE.Mesh(new THREE.BoxGeometry(size[0] + 0.12, 0.1, size[2] + 0.12), this.mats.darkMetal);
      housing.position.set(x, y + 0.08, z);
      this.scene.add(housing);
    }
    const f = {
      pos: new THREE.Vector3(x, y + lightY, z), color: col, base: intensity, distance, mode, group, mat, mesh: m,
      k: 1, on: true, t: Math.random() * 10, flickT: 2 + Math.random() * 6, flicking: 0, sub: 0, speed: 2,
    };
    this.fixtures.push(f);
    return f;
  }

  setGroup(group, state) {
    for (const f of this.fixtures) if (f.group === group) {
      if (state === 'off') f.on = false;
      else if (state === 'on') f.on = true;
      else { f.mode = state; f.on = true; }
    }
  }

  updateFixtures(dt, playerPos) {
    const audio = this.game.audio;
    for (const f of this.fixtures) {
      f.t += dt;
      let k = 1;
      switch (f.mode) {
        case 'flicker':
          f.flickT -= dt;
          if (f.flickT <= 0) {
            f.flicking = 0.15 + Math.random() * 0.6; f.flickT = 2.5 + Math.random() * 7;
            if (f.pos.distanceTo(playerPos) < 12) audio.buzz(f.pos, f.flicking);
          }
          if (f.flicking > 0) {
            f.flicking -= dt; f.sub -= dt;
            if (f.sub <= 0) { f.sub = 0.03 + Math.random() * 0.07; f.subOn = Math.random() < 0.45; }
            k = f.subOn ? 1 : 0.05;
          }
          break;
        case 'broken':
          f.flickT -= dt;
          if (f.flickT <= 0) {
            f.flicking = 0.1 + Math.random() * 0.35; f.flickT = 3 + Math.random() * 6;
            if (f.pos.distanceTo(playerPos) < 14) { audio.buzz(f.pos, f.flicking); if (Math.random() < 0.5) audio.sparks(f.pos); }
          }
          k = 0;
          if (f.flicking > 0) { f.flicking -= dt; f.sub -= dt; if (f.sub <= 0) { f.sub = 0.03 + Math.random() * 0.05; f.subOn = Math.random() < 0.5; } k = f.subOn ? 0.9 : 0; }
          break;
        case 'pulse':
          k = 0.25 + 0.75 * Math.pow(0.5 + 0.5 * Math.sin(f.t * f.speed), 2);
          break;
        case 'emergency':
          k = 0.3 + 0.7 * (Math.sin(f.t * 4) > 0 ? 1 : 0.2);
          break;
      }
      if (!f.on) k = 0;
      f.k += (k - f.k) * Math.min(1, dt * 30);
      if (f.mat) f.mat.color.copy(f.color).multiplyScalar(0.06 + f.k * 3);
    }
    // refresh one shadow cube per frame, round-robin (static scene; moving things update at ~40Hz)
    this._shadowRR = ((this._shadowRR || 0) + 1) % SHADOW_LIGHTS;
    this.pool[this._shadowRR].shadow.needsUpdate = true;
    // assign nearest fixtures to the light pool
    this._sorted = this._sorted || [];
    const arr = this._sorted; arr.length = 0;
    for (const f of this.fixtures) {
      if (f.k < 0.01) continue;
      f._d = f.pos.distanceToSquared(playerPos) / (f.distance * f.distance);
      arr.push(f);
    }
    arr.sort((a, b) => a._d - b._d);
    for (let i = 0; i < LIGHT_POOL; i++) {
      const l = this.pool[i], f = arr[i];
      if (!f) { l.intensity = 0; l.userData.fixture = null; continue; }
      l.position.copy(f.pos); l.color.copy(f.color); l.distance = f.distance * 1.15;
      l.intensity = f.base * f.k * this.lightBoost;
      if (l.castShadow) {
        l.shadow.camera.far = l.distance;
        if (l.userData.fixture !== f) { l.userData.fixture = f; l.shadow.needsUpdate = true; }
      }
    }
  }

  // -------------------------------------------------------------- geometry helpers
  box(x0, y0, z0, x1, y1, z1, mat, { collide = true, cast = true, receive = true, uv = 3, los = true } = {}) {
    const w = x1 - x0, h = y1 - y0, d = z1 - z0;
    if (w <= 0.001 || h <= 0.001 || d <= 0.001) return null;
    const geo = new THREE.BoxGeometry(w, h, d);
    worldUV(geo, w, h, d, uv);
    const m = new THREE.Mesh(geo, mat);
    m.position.set((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2);
    m.castShadow = cast; m.receiveShadow = receive;
    m.userData.static = true;
    this.scene.add(m);
    if (collide) this.colliders.push({ min: new THREE.Vector3(x0, y0, z0), max: new THREE.Vector3(x1, y1, z1) });
    return m;
  }

  collider(x0, y0, z0, x1, y1, z1) {
    const c = { min: new THREE.Vector3(x0, y0, z0), max: new THREE.Vector3(x1, y1, z1) };
    this.colliders.push(c);
    return c;
  }

  // Build a rectangular room. Openings: { side: [{c, w, h, y=0, glass}] } in absolute coords.
  room({ x0, x1, z0, z1, y0 = 0, h, walls = {}, open = {}, wall = this.mats.wall, floor = this.mats.floor, ceil = this.mats.ceil }) {
    const W = { n: true, s: true, e: true, w: true, ...walls };
    const fx0 = x0 - (W.w ? T : 0), fx1 = x1 + (W.e ? T : 0);
    this.box(fx0, y0 - 0.5, z0 - (W.n ? T : 0), fx1, y0, z1 + (W.s ? T : 0), floor, { cast: false, uv: 4 });
    this.box(fx0, y0 + h, z0 - (W.n ? T : 0), fx1, y0 + h + 0.5, z1 + (W.s ? T : 0), ceil, { uv: 4 });
    const side = (s, a0, a1, fixedA, fixedB, alongX) => {
      const ops = (open[s] || []).slice().sort((a, b) => a.c - b.c);
      let cur = a0;
      const mk = (b0, b1, ya, yb) => alongX
        ? this.box(b0, ya, fixedA, b1, yb, fixedB, wall)
        : this.box(fixedA, ya, b0, fixedB, yb, b1, wall);
      for (const op of ops) {
        const s0 = op.c - op.w / 2, s1 = op.c + op.w / 2, oy = op.y || 0;
        mk(cur, s0, y0, y0 + h);
        if (oy > 0) mk(s0, s1, y0, y0 + oy);
        mk(s0, s1, y0 + oy + op.h, y0 + h);
        if (op.glass) {
          const gm = alongX ? new THREE.Mesh(new THREE.PlaneGeometry(op.w, op.h), this.mats.glass)
            : new THREE.Mesh(new THREE.PlaneGeometry(op.w, op.h), this.mats.glass);
          const mid = (fixedA + fixedB) / 2;
          if (alongX) gm.position.set(op.c, y0 + oy + op.h / 2, mid);
          else { gm.position.set(mid, y0 + oy + op.h / 2, op.c); gm.rotation.y = Math.PI / 2; }
          gm.renderOrder = 5;
          this.scene.add(gm);
          if (alongX) this.collider(s0, y0 + oy, fixedA, s1, y0 + oy + op.h, fixedB);
          else this.collider(fixedA, y0 + oy, s0, fixedB, y0 + oy + op.h, s1);
        }
        cur = s1;
      }
      mk(cur, a1, y0, y0 + h);
    };
    if (W.n) side('n', fx0, fx1, z0 - T, z0, true);
    if (W.s) side('s', fx0, fx1, z1, z1 + T, true);
    if (W.w) side('w', z0, z1, x0 - T, x0, false);
    if (W.e) side('e', z0, z1, x1, x1 + T, false);
  }

  ribsZ(x, z0, z1, every, h, inward, skip = []) {
    // vertical ribs along a wall at x (running along z), protruding `inward` (signed)
    for (let z = z0 + every / 2; z < z1; z += every) {
      if (skip.some(([a, b]) => z > a - 0.6 && z < b + 0.6)) continue;
      const xa = Math.min(x, x + inward), xb = Math.max(x, x + inward);
      this.box(xa, 0, z - 0.18, xb, h, z + 0.18, this.mats.darkMetal, { uv: 1 });
    }
  }
  ribsX(z, x0, x1, every, h, inward, skip = []) {
    for (let x = x0 + every / 2; x < x1; x += every) {
      if (skip.some(([a, b]) => x > a - 0.6 && x < b + 0.6)) continue;
      const za = Math.min(z, z + inward), zb = Math.max(z, z + inward);
      this.box(x - 0.18, 0, za, x + 0.18, h, zb, this.mats.darkMetal, { uv: 1 });
    }
  }

  pipe(a, b, r, mat = this.mats.pipe) {
    const dir = new THREE.Vector3().subVectors(b, a);
    const len = dir.length();
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, len, 10), mat);
    m.position.copy(a).addScaledVector(dir, 0.5);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize());
    m.castShadow = true; m.receiveShadow = true;
    m.userData.static = true;
    this.scene.add(m);
    return m;
  }

  cable(a, b, sag, r = 0.025) {
    const mid = a.clone().lerp(b, 0.5); mid.y -= sag;
    const curve = new THREE.CatmullRomCurve3([a, a.clone().lerp(mid, 0.5).setY(mid.y + sag * 0.3), mid, b.clone().lerp(mid, 0.5).setY(mid.y + sag * 0.3), b]);
    const m = new THREE.Mesh(new THREE.TubeGeometry(curve, 24, r, 5), this.mats.rubber);
    m.castShadow = true; m.userData.static = true;
    this.scene.add(m);
  }

  strip(x0, y0, z0, x1, y1, z1, mat) {
    return this.box(x0, y0, z0, x1, y1, z1, mat, { collide: false, cast: false, los: false });
  }

  shaft(from, to, r0, r1, color, opacity) {
    const dir = new THREE.Vector3().subVectors(to, from);
    const len = dir.length();
    const geo = new THREE.CylinderGeometry(r0, r1, len, 20, 1, true);
    const m = new THREE.Mesh(geo, shaftMaterial(color, opacity));
    m.position.copy(from).addScaledVector(dir, 0.5);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.clone().negate().normalize());
    m.renderOrder = 10;
    this.scene.add(m);
    return m;
  }

  screen(x, y, z, rotY, w, h, seed, color) {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h),
      new THREE.MeshBasicMaterial({ map: screenTexture(seed, color), color: new THREE.Color(1.6, 1.6, 1.6) }));
    m.position.set(x, y, z); m.rotation.y = rotY;
    this.scene.add(m);
    return m;
  }

  console(x, z, rotY, seed, color = '#5ff') {
    const g = new THREE.Group();
    const base = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.0, 0.6), this.mats.darkMetal);
    base.position.y = 0.5; base.castShadow = base.receiveShadow = true; g.add(base);
    const top = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.08, 0.7), this.mats.darkMetal);
    top.position.set(0, 1.0, 0.05); top.rotation.x = -0.35; g.add(top);
    const scr = new THREE.Mesh(new THREE.PlaneGeometry(0.95, 0.6), new THREE.MeshBasicMaterial({ map: screenTexture(seed, color), color: new THREE.Color(1.4, 1.4, 1.4) }));
    scr.position.set(0, 1.35, -0.18); scr.rotation.x = -0.25;
    g.add(scr);
    const stand = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.5, 0.08), this.mats.darkMetal);
    stand.position.set(0, 1.1, -0.22); g.add(stand);
    g.position.set(x, 0, z); g.rotation.y = rotY;
    this.scene.add(g);
    const c = Math.cos(rotY), s = Math.sin(rotY);
    const hx = Math.abs(0.6 * c) + Math.abs(0.35 * s), hz = Math.abs(0.6 * s) + Math.abs(0.35 * c);
    this.collider(x - hx, 0, z - hz, x + hx, 1.05, z + hz);
    return g;
  }

  crate(x, z, s = 1, y = 0, rot = 0) {
    const m = this.box(x - s / 2, y, z - s / 2, x + s / 2, y + s, z + s / 2, this.mats.wallDark, { uv: 1.5 });
    if (m && rot) m.rotation.y = rot;
    return m;
  }

  scannable(pos, title, text, opts = {}) {
    const s = { pos: pos.clone ? pos.clone() : new THREE.Vector3(pos.x, pos.y, pos.z), title, text, scanned: false, radius: opts.radius || 0.6, onScan: opts.onScan || null, critical: !!opts.critical };
    this.scannables.push(s);
    return s;
  }

  bloomGrowth(x, y, z, size, rand) {
    const g = new THREE.Group();
    const n = 3 + Math.floor(rand() * 5);
    for (let i = 0; i < n; i++) {
      const r = size * (0.3 + rand() * 0.7);
      const m = new THREE.Mesh(new THREE.IcosahedronGeometry(r, 1), rand() < 0.35 ? this.mats.bloom : this.mats.bloomFlesh);
      m.position.set((rand() - 0.5) * size * 2, (rand() - 0.5) * size * 2, (rand() - 0.5) * size * 2);
      m.scale.set(1, 0.6 + rand() * 0.6, 1);
      g.add(m);
    }
    g.position.set(x, y, z);
    this.scene.add(g);
    this.animated.push((t) => { const k = 1 + Math.sin(t * 1.3 + x * 3 + z) * 0.04; g.scale.setScalar(k); });
    return g;
  }

  tendril(points, r = 0.06) {
    const curve = new THREE.CatmullRomCurve3(points);
    const m = new THREE.Mesh(new THREE.TubeGeometry(curve, 30, r, 6), this.mats.bloomFlesh);
    this.scene.add(m);
    const glow = new THREE.Mesh(new THREE.TubeGeometry(curve, 30, r * 0.35, 4), this.mats.purple);
    this.scene.add(glow);
  }

  // ===================================================================== AREA A — Arrival Bay
  buildBay() {
    const M = this.mats;
    this.room({ x0: -5, x1: 5, z0: -12, z1: 0, h: 5, open: { n: [{ c: 0, w: 3, h: 3.5 }], w: [{ c: -5.5, w: 5, h: 2.2, y: 1.3, glass: true }] } });
    this.ribsZ(5, -12, 0, 3, 5, -0.3);
    this.ribsX(0, -5, 5, 2.5, 5, -0.3);
    // ceiling beams
    for (let z = -10.5; z < 0; z += 3) this.box(-5, 4.5, z - 0.2, 5, 5, z + 0.2, M.darkMetal, { collide: false });
    // window frame
    this.box(-5.2, 1.1, -8.2, -4.7, 1.3, -2.8, M.darkMetal, { collide: false });
    this.strip(-4.98, 1.32, -8, -4.9, 1.36, -3, M.cyanDim);
    // floor guide lights toward door
    for (let z = -1.5; z > -11.5; z -= 1.2) { this.strip(-1.6, 0.0, z - 0.25, -1.45, 0.02, z + 0.25, M.cyanDim); this.strip(1.45, 0.0, z - 0.25, 1.6, 0.02, z + 0.25, M.cyanDim); }
    // cargo
    this.crate(3.6, -2, 1.2); this.crate(3.9, -3.4, 1.0); this.crate(3.7, -2.4, 0.8, 1.2, 0.4);
    this.crate(-3.8, -10.4, 1.4); this.crate(-3.5, -9, 0.9);
    this.console(3.8, -8, -Math.PI / 2, 3, '#f84');
    // pipes in corner
    this.pipe(new THREE.Vector3(4.6, 0, -11.6), new THREE.Vector3(4.6, 5, -11.6), 0.14);
    this.pipe(new THREE.Vector3(4.3, 0, -11.6), new THREE.Vector3(4.3, 5, -11.6), 0.09);
    this.pipe(new THREE.Vector3(-4.6, 4.2, 0), new THREE.Vector3(-4.6, 4.2, -12), 0.12);
    // claw marks near door (dark gouges)
    for (let i = 0; i < 4; i++) {
      const m = new THREE.Mesh(new THREE.BoxGeometry(0.05, 1.1, 0.04), new THREE.MeshBasicMaterial({ color: 0x050303 }));
      m.position.set(-2.2 + i * 0.13, 1.6 - i * 0.05, -11.97); m.rotation.z = 0.35;
      this.scene.add(m);
    }

    // swaying hanging lamp w/ shadow
    const lamp = new THREE.Group();
    lamp.position.set(0, 5, -6);
    const cord = new THREE.Mesh(new THREE.CylinderGeometry(0.01, 0.01, 1.4), M.rubber);
    cord.position.y = -0.7; lamp.add(cord);
    const shade = new THREE.Mesh(new THREE.ConeGeometry(0.35, 0.3, 12, 1, true), M.darkMetal);
    shade.position.y = -1.5; lamp.add(shade);
    const bulbMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 2.6, 2) });
    const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.08, 8, 6), bulbMat);
    bulb.position.y = -1.6; lamp.add(bulb);
    this.scene.add(lamp);
    const spot = new THREE.SpotLight(0xffe2c0, 30, 14, 0.85, 0.6, 1.6);
    spot.castShadow = true; spot.shadow.mapSize.set(1024, 1024); spot.shadow.bias = -0.0006; spot.shadow.camera.near = 0.3;
    this.scene.add(spot); this.scene.add(spot.target);
    this.bayLamp = { lamp, spot, bulbMat, k: 1 };
    this.animated.push((t, dt) => {
      const a = Math.sin(t * 0.9) * 0.09 + Math.sin(t * 2.3) * 0.015;
      lamp.rotation.z = a; lamp.rotation.x = Math.sin(t * 0.7) * 0.04;
      bulb.getWorldPosition(spot.position);
      spot.target.position.set(spot.position.x - a * 12, 0, spot.position.z + lamp.rotation.x * 12);
      // nervous lamp flicker
      const flick = Math.random() < 0.012 ? 0.1 : 1;
      this.bayLamp.k += (flick * (this.bayLamp.on === false ? 0 : 1) - this.bayLamp.k) * Math.min(1, dt * 25);
      spot.intensity = 30 * this.bayLamp.k;
      bulbMat.color.setRGB(3 * this.bayLamp.k + 0.05, 2.6 * this.bayLamp.k + 0.04, 2 * this.bayLamp.k + 0.03);
    });

    // red rotating beacon above the door
    const beacon = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.14, 0.2, 10), M.red);
    beacon.position.set(2.2, 4.0, -11.8); this.scene.add(beacon);
    const bspot = new THREE.SpotLight(0xff2030, 25, 16, 0.35, 0.4, 1.5);
    bspot.position.copy(beacon.position); this.scene.add(bspot); this.scene.add(bspot.target);
    this.animated.push((t) => {
      const a = t * 2.4;
      bspot.target.position.set(2.2 + Math.cos(a) * 6, 1.0, -11.8 + Math.abs(Math.sin(a)) * 8);
    });
    this.fixture({ x: -3, y: 4.85, z: -2, color: 0xa8c8ff, intensity: 4, distance: 9, mode: 'broken' });

    // shuttle outside
    this.buildShuttle();

    this.scannable(new THREE.Vector3(-6.5, 2.4, -5.5), 'KESTREL // PERSONAL SHUTTLE',
      'Your ship. Hull cold, engines idle.\nDocking clamps engaged at 41:12:07 — the exact moment the station went silent.\nAutopilot refuses to undock until a manual release is found inside.');
    this.scannable(new THREE.Vector3(3.8, 1.3, -8), 'DOCKING TERMINAL',
      'MANIFEST — RING C:\n  ARRIVALS (last 72h): 0\n  DEPARTURES: 0\n  PERSONNEL ONSITE: 4,118\n  BIOSIGNS RESPONDING: ——\n\nLast entry: "Maintenance AI requesting quarantine authority. Request…approved?"');
    this.scannable(new THREE.Vector3(-2, 1.6, -11.9), 'GOUGE MARKS',
      'Four parallel cuts in tempered alloy, 2cm deep.\nSpacing inconsistent with any registered tool or drone.\nThey were made from this side. Something wanted out.', { critical: true });

    this.doors.d1 = new Door(this, { x: 0, z: -12.25, axis: 'x', w: 3, h: 3.5, name: 'd1' });
    this.points.start = new THREE.Vector3(0, 0, -2.5);
  }

  buildShuttle() {
    const g = new THREE.Group();
    const hull = new THREE.MeshStandardMaterial({ color: 0x8a9099, roughness: 0.35, metalness: 0.8 });
    const body = new THREE.Mesh(new THREE.CapsuleGeometry(1.6, 7, 6, 12), hull);
    body.rotation.x = Math.PI / 2; body.scale.set(1.2, 1, 0.6); g.add(body);
    const nose = new THREE.Mesh(new THREE.ConeGeometry(1.5, 3, 12), hull);
    nose.rotation.x = -Math.PI / 2; nose.position.z = 6; nose.scale.set(1.3, 1, 0.55); g.add(nose);
    const wing = new THREE.Mesh(new THREE.BoxGeometry(9, 0.15, 2.5), hull);
    wing.position.set(0, -0.3, -1); g.add(wing);
    const canopy = new THREE.Mesh(new THREE.SphereGeometry(0.9, 12, 8, 0, Math.PI * 2, 0, Math.PI / 2), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.1, 0.5, 0.7) }));
    canopy.position.set(0, 0.6, 3.2); canopy.scale.set(1, 0.6, 2); g.add(canopy);
    for (const s of [-1, 1]) {
      const eng = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.6, 1.5, 10), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.3, 0.8, 2) }));
      eng.rotation.x = Math.PI / 2; eng.position.set(s * 1.3, 0, -5); g.add(eng);
      const nav = new THREE.Mesh(new THREE.SphereGeometry(0.1), s < 0 ? this.mats.red : new THREE.MeshBasicMaterial({ color: new THREE.Color(0.2, 3, 0.4) }));
      nav.position.set(s * 4.5, -0.25, -1); g.add(nav);
    }
    g.position.set(-16, 1.5, -5.5);
    g.rotation.y = 0.2;
    this.scene.add(g);
    // docking arm
    const arm = new THREE.Mesh(new THREE.BoxGeometry(10, 1.2, 1.4), this.mats.darkMetal);
    arm.position.set(-10, 2.2, -5.5); this.scene.add(arm);
    // floodlight glow
    const fl = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(1.5, 1.4, 1.2), blending: THREE.AdditiveBlending, depthWrite: false }));
    fl.position.set(-8, 6, -1); fl.scale.setScalar(2.5); this.scene.add(fl);
    this.animated.push((t) => { g.position.y = 1.5 + Math.sin(t * 0.4) * 0.05; });
  }

  // ===================================================================== AREA B/C — Maintenance Spine
  buildCorridor() {
    const M = this.mats;
    this.room({ x0: -1.5, x1: 1.5, z0: -40, z1: -12.5, h: 3.2, walls: { s: false }, open: { e: [{ c: -38.5, w: 3, h: 3.2 }] }, wall: M.wallDark });
    this.ribsZ(-1.5, -40, -12.5, 2.4, 3.2, 0.22);
    this.ribsZ(1.5, -40, -12.5, 2.4, 3.2, -0.22, [[-40, -37]]);
    for (let z = -13.7; z > -40; z -= 2.4) this.box(-1.5, 2.95, z - 0.18, 1.5, 3.2, z + 0.18, M.darkMetal, { collide: false });
    // pipes along upper corners
    this.pipe(new THREE.Vector3(-1.15, 2.75, -12.5), new THREE.Vector3(-1.15, 2.75, -40), 0.12);
    this.pipe(new THREE.Vector3(-1.2, 2.45, -12.5), new THREE.Vector3(-1.2, 2.45, -40), 0.07, M.darkMetal);
    this.pipe(new THREE.Vector3(1.15, 2.7, -12.5), new THREE.Vector3(1.15, 2.7, -36.6), 0.1);
    // hanging cables
    this.cable(new THREE.Vector3(-1.2, 3.1, -16), new THREE.Vector3(1.2, 3.1, -19), 0.7);
    this.cable(new THREE.Vector3(1.2, 3.1, -26), new THREE.Vector3(-0.8, 3.1, -28), 1.0);
    this.cable(new THREE.Vector3(-1.2, 3.1, -33), new THREE.Vector3(1.0, 3.1, -34.5), 0.5);
    // floor edge lights
    this.strip(-1.5, 0, -40, -1.42, 0.03, -12.5, M.cyanDim);
    this.strip(1.42, 0, -36.8, 1.5, 0.03, -12.5, M.cyanDim);
    // ceiling fixtures (the ones that die in the scare)
    const modes = ['steady', 'flicker', 'steady', 'flicker', 'broken', 'steady'];
    [-15, -20, -25, -30, -35, -38.5].forEach((z, i) => this.fixture({ x: 0, y: 3.12, z, intensity: 5, distance: 8, mode: modes[i], group: 'spine', size: [0.25, 0.06, 1.4] }));
    // vent grate over scare point
    this.ventGrate(0, 3.15, -24);
    // terminal
    this.screen(-1.27, 1.6, -18, Math.PI / 2, 0.9, 0.55, 8, '#5ff');
    this.scannable(new THREE.Vector3(-1.27, 1.6, -18), 'MAINTENANCE LOG — SPINE 4',
      'Day 1: Pressure anomalies in ducting. Bio-residue in filters, violet, luminous.\nDay 3: Something is nesting in the vents. The AI says it is "growth." It says it is "beautiful."\nDay 4: We sealed the ducts. We heard it walking above us all night.');
    // sparking broken panel
    const panel = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.6, 0.04), M.wallDark);
    panel.position.set(1.15, 2.4, -31); panel.rotation.set(0.2, -1.2, 0.5);
    this.scene.add(panel);
    this.points.spark = new THREE.Vector3(1.3, 2.6, -31);

    // junction C
    this.room({ x0: 2, x1: 14, z0: -40, z1: -37, h: 3.2, walls: { w: false, e: false }, wall: M.wallDark });
    for (let x = 3.5; x < 14; x += 2.4) this.box(x - 0.18, 2.95, -40, x + 0.18, 3.2, -37, M.darkMetal, { collide: false });
    this.pipe(new THREE.Vector3(2, 2.75, -39.6), new THREE.Vector3(14, 2.75, -39.6), 0.12);
    this.fixture({ x: 9, y: 3.12, z: -38.5, intensity: 4, distance: 8, mode: 'flicker', group: 'junction', size: [1.4, 0.06, 0.25] });
    this.ventGrate(6, 3.15, -38.5);
    this.points.junctionVent = new THREE.Vector3(6, 3.0, -38.5);
    this.strip(2, 0, -37.08, 14, 0.03, -37, M.cyanDim);
  }

  ventGrate(x, y, z) {
    const g = new THREE.Group();
    const frame = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.06, 1.1), this.mats.darkMetal);
    g.add(frame);
    for (let i = -4; i <= 4; i++) {
      const bar = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.08, 0.95), this.mats.rubber);
      bar.position.x = i * 0.11; g.add(bar);
    }
    g.position.set(x, y - 0.04, z);
    this.scene.add(g);
    return g;
  }

  // ===================================================================== AREA D — Grand Concourse
  buildAtrium() {
    const M = this.mats, r = rng(42);
    const X0 = 14.5, X1 = 54, Z0 = -70, Z1 = -10, H = 22;
    this.room({
      x0: X0, x1: X1, z0: Z0, z1: Z1, h: H, wall: M.wall,
      open: {
        w: [{ c: -38.5, w: 3, h: 3 }],
        n: [{ c: 34, w: 4, h: 4 }],
        e: [{ c: -40, w: 56, h: 18, y: 1.5, glass: true }],
      },
    });
    this.doors.d2 = new Door(this, { x: 14.25, z: -38.5, axis: 'z', w: 3, h: 3, name: 'd2' });
    this.doors.d3 = new Door(this, { x: 34, z: -70.25, axis: 'x', w: 4, h: 4, name: 'd3' });

    // massive ribs on walls
    this.ribsZ(X0, Z0, Z1, 6, H, 0.6, [[-40.5, -36.5]]);
    this.ribsX(Z0, X0, X1, 6, H, 0.6, [[31.5, 36.5]]);
    this.ribsX(Z1, X0, X1, 6, H, -0.6);
    // ceiling beams
    for (let z = Z0 + 6; z < Z1; z += 6) this.box(X0, H - 1.2, z - 0.4, X1, H, z + 0.4, M.darkMetal, { collide: false, uv: 2 });
    // window mullions
    for (let z = -68; z <= -12; z += 7) this.box(53.6, 1.5, z - 0.25, 54.2, 19.5, z + 0.25, M.darkMetal, { uv: 1 });
    for (const y of [7.5, 13.5]) this.box(53.7, y - 0.15, -68, 54.1, y + 0.15, -12, M.darkMetal, { collide: false, uv: 1 });
    this.strip(53.5, 1.45, -68, 53.65, 1.52, -12, M.cyanDim);

    // columns
    for (const x of [24, 44]) for (const z of [-22, -58]) this.column(x, z, H);
    // central dormant core
    this.buildCore(34, -40, H);

    // high catwalk along north wall
    const cy = 8;
    this.box(X0, cy - 0.25, Z0, X1 - 0.5, cy, Z0 + 2.5, M.darkMetal, { collide: true, uv: 2 });
    for (let x = X0 + 1; x < X1; x += 1.2) this.box(x - 0.03, cy, Z0 + 2.45, x + 0.03, cy + 1.1, Z0 + 2.5, M.darkMetal, { collide: false, cast: true, los: false });
    this.box(X0, cy + 1.05, Z0 + 2.42, X1 - 0.5, cy + 1.12, Z0 + 2.52, M.darkMetal, { collide: false, los: false });
    this.strip(X0, cy - 0.27, Z0 + 2.45, X1 - 0.5, cy - 0.22, Z0 + 2.52, M.cyanDim);

    // sentinel cradles high on walls
    this.points.sentinelA = new THREE.Vector3(X0 + 1.4, 11, -52);
    this.points.sentinelB = new THREE.Vector3(30, 12.5, Z1 - 1.4);
    for (const p of [this.points.sentinelA, this.points.sentinelB]) {
      const cr = new THREE.Mesh(new THREE.TorusGeometry(1.0, 0.12, 6, 16, Math.PI), M.darkMetal);
      cr.position.set(p.x, p.y - 0.9, p.z);
      cr.rotation.x = Math.PI / 2; cr.rotation.z = Math.PI;
      this.scene.add(cr);
    }

    // dead arboretum trees silhouetted against the window
    for (const [x, z] of [[47, -16], [48, -30], [47, -50], [48.5, -63]]) this.deadTree(x, z, r);

    // debris, benches, planters
    for (let i = 0; i < 16; i++) {
      const x = X0 + 3 + r() * (X1 - X0 - 9), z = Z0 + 4 + r() * (Z1 - Z0 - 8);
      if (Math.hypot(x - 34, z + 40) < 7) continue;
      if (Math.abs(x - 34) < 2.5 && z < -60) continue;
      const s = 0.5 + r() * 0.9;
      const m = this.crate(x, z, s, 0, r() * 1.5);
      if (m) m.rotation.y = r() * Math.PI;
    }
    for (const z of [-30, -50]) {
      this.box(28, 0, z - 0.3, 31, 0.45, z + 0.3, M.darkMetal, { uv: 1 });
      this.box(37, 0, z - 0.3, 40, 0.45, z + 0.3, M.darkMetal, { uv: 1 });
    }
    // fallen banner + hanging banners
    for (const [x, z, col] of [[20, -64, '#f3a'], [48, -64, '#3ef'], [20, -16, '#fa3']]) {
      const ban = new THREE.Mesh(new THREE.PlaneGeometry(3, 9), new THREE.MeshBasicMaterial({ map: neonTexture(x * 7 + z, col), color: new THREE.Color(0.35, 0.35, 0.35), side: THREE.DoubleSide }));
      ban.position.set(x, 15, z); ban.rotation.y = x < 30 ? Math.PI / 2 : -Math.PI / 2; ban.rotation.z = Math.PI / 2;
      this.scene.add(ban);
      this.animated.push((t) => { ban.rotation.x = Math.sin(t * 0.3 + x) * 0.03; });
    }
    // floor path lights from west door to north door
    for (let i = 0; i < 18; i++) {
      const k = i / 17;
      const x = 16.5 + (34 - 16.5) * Math.min(1, k * 1.6);
      const z = -38.5 + (k > 0.6 ? (-68 + 38.5) * ((k - 0.6) / 0.4) : 0);
      if (Math.hypot(x - 34, z + 40) < 5.5) continue;
      this.strip(x - 0.15, 0, z - 0.15, x + 0.15, 0.02, z + 0.15, M.cyanDim);
    }

    // skylight slits + light shafts aligned with the moon
    const ld = new THREE.Vector3().subVectors(this.moon.target.position, this.moon.position).normalize();
    for (const z of [-24, -34, -46, -56]) {
      const top = new THREE.Vector3(53, 18, z);
      const len = 30;
      const bot = top.clone().addScaledVector(ld, len);
      this.shaft(top, bot, 2.2, 3.2, 0x8aa6ff, 0.13);
    }
    // haze near floor
    this.points.atriumCenter = new THREE.Vector3(34, 0, -40);

    // fixtures (sparse)
    this.fixture({ x: 18, y: 6, z: -38.5, color: 0x9fd8ff, intensity: 6, distance: 12, mode: 'flicker', size: [0.3, 0.6, 0.1] });
    this.fixture({ x: 34, y: 6, z: -67.6, color: 0xff9a50, intensity: 6, distance: 12, mode: 'steady', size: [2.0, 0.08, 0.2] });

    // dead sentinel and remains
    const shell = new THREE.Mesh(new THREE.SphereGeometry(0.7, 12, 10, 0, Math.PI * 1.4), M.darkMetal);
    shell.position.set(26, 0.5, -46); shell.rotation.set(1, 0.5, 0.3); shell.castShadow = true;
    this.scene.add(shell);
    this.scannable(new THREE.Vector3(26, 0.6, -46), 'SENTINEL DRONE — INERT',
      'Security drone, model SN-7. Core punctured from inside.\nViolet filaments threaded through its optic array, still faintly warm.\nOthers of its kind remain active. Their firmware has been… revised.\nPlasma bolts can be returned with a well-timed guard [RMB] or strike.');
    const body = new THREE.Group();
    const torso = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.25, 1.6), new THREE.MeshStandardMaterial({ color: 0x23272e, roughness: 0.8 }));
    torso.position.y = 0.13; body.add(torso);
    const helm = new THREE.Mesh(new THREE.SphereGeometry(0.2, 10, 8), new THREE.MeshStandardMaterial({ color: 0x3a3f48, roughness: 0.3, metalness: 0.6 }));
    helm.position.set(0, 0.18, -0.95); body.add(helm);
    body.position.set(41, 0, -33); body.rotation.y = 0.8;
    this.scene.add(body);
    this.bloomGrowth(41.3, 0.2, -33.4, 0.3, r);
    this.scannable(new THREE.Vector3(41, 0.4, -33), 'REMAINS — SEC. OFFICER K. ADEYEMI',
      'Biosign: none. Time of death ≈ 38 hours.\nSidearm discharged 14 times. No targets recovered.\nFinal audio log: "It\'s not on the scanner — it\'s IN the scanner. Switch visors, you can see it with the—"', { critical: true });
    this.scannable(new THREE.Vector3(53, 6, -40), 'KUROGANE-9 // INNER CHASM',
      'The arcology\'s hollow heart: 11 km of vertical city around a central void.\nPopulation at census: 2.3 million.\nCurrent light-signatures suggest grid power is intact.\nNo traffic control chatter on any band. The lights are on. No one is home.');
    this.scannable(new THREE.Vector3(34, 2, -40), 'CONCOURSE CORE // DORMANT',
      'Atmospheric regulator for Ring C. Output: 3%.\nSomething has been feeding on its power conduits.\nTrace residue leads north, toward Hydroponics.');
  }

  column(x, z, H) {
    const M = this.mats;
    const c = new THREE.Mesh(new THREE.CylinderGeometry(1.25, 1.4, H, 16), M.wall);
    c.position.set(x, H / 2, z); c.castShadow = c.receiveShadow = true; c.userData.static = true;
    this.scene.add(c);
    for (const y of [0.4, H - 1]) {
      const ring = new THREE.Mesh(new THREE.CylinderGeometry(1.7, 1.7, 0.8, 16), M.darkMetal);
      ring.position.set(x, y, z); ring.castShadow = ring.receiveShadow = true; ring.userData.static = true; this.scene.add(ring);
    }
    for (let i = 0; i < 4; i++) {
      const a = i * Math.PI / 2 + Math.PI / 4;
      const fin = new THREE.Mesh(new THREE.BoxGeometry(0.25, H, 0.5), M.darkMetal);
      fin.position.set(x + Math.cos(a) * 1.35, H / 2, z + Math.sin(a) * 1.35); fin.rotation.y = -a;
      fin.castShadow = fin.receiveShadow = true; fin.userData.static = true; this.scene.add(fin);
    }
    const g = new THREE.Mesh(new THREE.CylinderGeometry(1.42, 1.42, 0.06, 16, 1, true), M.cyanDim);
    g.position.set(x, 2.8, z); this.scene.add(g);
    this.collider(x - 1.6, 0, z - 1.6, x + 1.6, H, z + 1.6);
  }

  buildCore(x, z, H) {
    const M = this.mats;
    // two step-able tiers
    for (const [r, y] of [[5, 0.3], [3.4, 0.6]]) {
      const tier = new THREE.Mesh(new THREE.CylinderGeometry(r, r, 0.3, 32), M.darkMetal);
      tier.position.set(x, y - 0.15, z); tier.receiveShadow = tier.castShadow = true; this.scene.add(tier);
      const s = r * 0.7;
      this.collider(x - s, 0, z - s, x + s, y, z + s);
      const edge = new THREE.Mesh(new THREE.TorusGeometry(r, 0.03, 4, 48), M.cyanDim);
      edge.rotation.x = Math.PI / 2; edge.position.set(x, y + 0.01, z); this.scene.add(edge);
    }
    const coreMat = this.mats.wallDark.clone();
    coreMat.color = new THREE.Color(0x4c4a5a); coreMat.emissive = new THREE.Color(0.06, 0.02, 0.13);
    for (const k of ['map', 'normalMap', 'aoMap', 'roughnessMap', 'metalnessMap']) {
      coreMat[k] = coreMat[k].clone(); coreMat[k].repeat.set(2, 7); coreMat[k].needsUpdate = true;
    }
    // glowing conduit bands up the column
    for (let y = 1.5; y < H; y += 2.4) {
      const band = new THREE.Mesh(new THREE.CylinderGeometry(1.13, 1.13, 0.06, 32, 1, true), this.mats.purple);
      band.position.set(x, y, z); this.scene.add(band);
    }
    const col = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.1, H, 24), coreMat);
    col.position.set(x, H / 2, z); col.castShadow = true; this.scene.add(col);
    this.collider(x - 1.2, 0, z - 1.2, x + 1.2, H, z + 1.2);
    const rings = [];
    for (const [y, r] of [[3.2, 2.2], [6.5, 2.8], [10.5, 2.4]]) {
      const ring = new THREE.Mesh(new THREE.TorusGeometry(r, 0.09, 6, 48), M.purple);
      ring.position.set(x, y, z); ring.rotation.x = Math.PI / 2 + (Math.random() - 0.5) * 0.2;
      this.scene.add(ring); rings.push(ring);
    }
    this.animated.push((t) => {
      rings.forEach((rg, i) => { rg.rotation.z = t * (0.05 + i * 0.03) * (i % 2 ? -1 : 1); rg.position.y += Math.sin(t * 0.5 + i) * 0.001; });
      coreMat.emissive.setRGB(0.06 + Math.sin(t * 0.6) * 0.03, 0.02, 0.13 + Math.sin(t * 0.6) * 0.06);
    });
    this.fixture({ x, y: 3.5, z: z + 3.2, color: 0xa060ff, intensity: 4, distance: 12, mode: 'pulse', mesh: false }).speed = 0.6;
  }

  deadTree(x, z, r) {
    const mat = new THREE.MeshStandardMaterial({ color: 0x0e0d0c, roughness: 0.95 });
    const planter = this.box(x - 1.2, 0, z - 1.2, x + 1.2, 0.7, z + 1.2, this.mats.darkMetal, { uv: 1 });
    const branch = (p, dir, len, rad, depth) => {
      const end = p.clone().addScaledVector(dir, len);
      const m = new THREE.Mesh(new THREE.CylinderGeometry(rad * 0.6, rad, len, 5), mat);
      m.position.copy(p).lerp(end, 0.5);
      m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
      m.castShadow = true; m.userData.static = true;
      this.scene.add(m);
      if (depth <= 0) return;
      const n = 2 + (r() < 0.4 ? 1 : 0);
      for (let i = 0; i < n; i++) {
        const d = dir.clone().add(new THREE.Vector3((r() - 0.5) * 1.4, r() * 0.4, (r() - 0.5) * 1.4)).normalize();
        branch(end, d, len * (0.6 + r() * 0.2), rad * 0.6, depth - 1);
      }
    };
    branch(new THREE.Vector3(x, 0.7, z), new THREE.Vector3(0, 1, 0), 2.6, 0.22, 4);
  }

  // ===================================================================== AREA E — The Funnel
  buildFunnel() {
    const M = this.mats, r = rng(77);
    this.room({ x0: 30, x1: 38, z0: -80, z1: -70.5, h: 6, walls: { s: false }, open: { n: [{ c: 34, w: 5, h: 4.5 }] }, wall: M.wallDark });
    this.room({ x0: 31.5, x1: 36.5, z0: -90, z1: -80.5, h: 4.5, walls: { s: false }, open: { n: [{ c: 34, w: 2.5, h: 3 }] }, wall: M.wallDark });
    this.room({ x0: 32.75, x1: 35.25, z0: -99.5, z1: -90.5, h: 3, walls: { s: false, n: false }, wall: M.wallDark });
    this.ribsZ(30, -80, -70.5, 2, 6, 0.25); this.ribsZ(38, -80, -70.5, 2, 6, -0.25);
    this.ribsZ(31.5, -90, -80.5, 1.8, 4.5, 0.2); this.ribsZ(36.5, -90, -80.5, 1.8, 4.5, -0.2);
    // pulsing red lights, increasingly close together
    [[-75, 5.9], [-85, 4.4], [-93, 2.92], [-97.5, 2.92]].forEach(([z, y], i) => {
      const f = this.fixture({ x: 34, y, z, color: 0xff2a2a, intensity: 5, distance: 9, mode: 'pulse', size: [0.5, 0.06, 0.5], group: 'funnel' });
      f.speed = 1.3 + i * 0.5;
    });
    // Bloom growth thickening as we go
    for (let i = 0; i < 46; i++) {
      const k = i / 46;
      const z = -72 - k * 27;
      const halfW = z > -80 ? 4 : z > -90 ? 2.5 : 1.25;
      const hgt = z > -80 ? 6 : z > -90 ? 4.5 : 3;
      if (r() > 0.3 + k * 0.7) continue;
      const side = r() < 0.5 ? -1 : 1;
      const onCeil = r() < 0.35;
      const x = onCeil ? 34 + (r() - 0.5) * halfW * 1.6 : 34 + side * (halfW - 0.05);
      const y = onCeil ? hgt - 0.05 : 0.3 + r() * hgt * 0.8;
      this.bloomGrowth(x, y, z, 0.15 + k * 0.35, r);
    }
    this.tendril([new THREE.Vector3(32.8, 3, -92), new THREE.Vector3(33.5, 2.9, -95), new THREE.Vector3(33.2, 2.95, -99)], 0.07);
    this.tendril([new THREE.Vector3(35.2, 0.1, -91), new THREE.Vector3(35.18, 1.2, -94), new THREE.Vector3(35.2, 2.6, -98)], 0.06);
    this.tendril([new THREE.Vector3(31.6, 4.4, -82), new THREE.Vector3(33, 4.45, -86), new THREE.Vector3(36.3, 4.4, -89)], 0.08);
    this.points.funnelGlimpse = new THREE.Vector3(34, 0, -97.5);
    this.scannable(new THREE.Vector3(36.2, 2.2, -86), 'THE BLOOM',
      'Organic lattice. Self-luminous. Grows along power conduits at 30cm/hour.\nNeural-analog structures detected inside each nodule.\nIt is not merely growing. It is listening.', { critical: true });
  }

  // ===================================================================== AREA F — Hydroponics Vault (arena)
  buildArena() {
    const M = this.mats, r = rng(99);
    const X0 = 20, X1 = 48, Z0 = -132, Z1 = -100, H = 12;
    this.room({ x0: X0, x1: X1, z0: Z0, z1: Z1, h: H, open: { s: [{ c: 34, w: 2.5, h: 3 }], n: [{ c: 34, w: 3, h: 3.5 }] } });
    this.doors.d4 = new Door(this, { x: 34, z: -99.75, axis: 'x', w: 2.5, h: 3, name: 'd4' });
    this.doors.d5 = new Door(this, { x: 34, z: -132.25, axis: 'x', w: 3, h: 3.5, locked: true, name: 'd5' });
    this.ribsZ(X0, Z0, Z1, 4, H, 0.4); this.ribsZ(X1, Z0, Z1, 4, H, -0.4);
    this.ribsX(Z0, X0, X1, 4, H, 0.4, [[32.5, 35.5]]); this.ribsX(Z1, X0, X1, 4, H, -0.4, [[32.7, 35.3]]);
    for (let z = Z0 + 4; z < Z1; z += 4) this.box(X0, H - 0.8, z - 0.25, X1, H, z + 0.25, M.darkMetal, { collide: false, uv: 2 });

    // cover pillars
    for (const [x, z] of [[27, -109], [41, -109], [27, -123], [41, -123]]) {
      this.box(x - 1, 0, z - 1, x + 1, H, z + 1, M.wallDark, { uv: 2 });
      this.strip(x - 1.02, 2.5, z - 1.02, x + 1.02, 2.56, z + 1.02, M.cyanDim);
    }
    // central hydroponic tank w/ specimen
    const tank = new THREE.Mesh(new THREE.CylinderGeometry(2, 2, 6, 24, 1, true), new THREE.MeshStandardMaterial({ color: 0x66ffaa, transparent: true, opacity: 0.12, roughness: 0.05, metalness: 0.5, depthWrite: false, side: THREE.DoubleSide }));
    tank.position.set(34, 3.6, -116); this.scene.add(tank);
    const liquid = new THREE.Mesh(new THREE.CylinderGeometry(1.9, 1.9, 5.4, 24), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.01, 0.07, 0.035), transparent: true, opacity: 0.4, depthWrite: false, blending: THREE.AdditiveBlending }));
    liquid.position.set(34, 3.4, -116); this.scene.add(liquid);
    for (const y of [0.3, 6.8]) {
      const cap = new THREE.Mesh(new THREE.CylinderGeometry(2.3, 2.3, 0.6, 24), M.darkMetal);
      cap.position.set(34, y, -116); cap.castShadow = true; this.scene.add(cap);
    }
    const spec = new THREE.Group();
    const sb = new THREE.Mesh(new THREE.CapsuleGeometry(0.35, 1.4, 4, 8), M.bloomFlesh); spec.add(sb);
    for (let i = 0; i < 4; i++) {
      const arm = new THREE.Mesh(new THREE.CapsuleGeometry(0.07, 1.2, 3, 5), M.bloomFlesh);
      arm.position.set(Math.cos(i * 1.6) * 0.4, -0.3 + i * 0.1, Math.sin(i * 1.6) * 0.4); arm.rotation.z = 0.6 * (i % 2 ? 1 : -1);
      spec.add(arm);
    }
    const eye = new THREE.Mesh(new THREE.SphereGeometry(0.08), M.purple); eye.position.set(0, 0.6, 0.3); spec.add(eye);
    spec.position.set(34, 3.4, -116); this.scene.add(spec);
    this.animated.push((t) => { spec.rotation.y = t * 0.1; spec.position.y = 3.4 + Math.sin(t * 0.4) * 0.15; });
    this.collider(31.7, 0, -118.3, 36.3, 7, -113.7);
    this.scannable(new THREE.Vector3(34, 3.4, -116), 'SPECIMEN TANK 7',
      'Contents: Bloom progenitor organism, catalogued "BENIGN".\nTank integrity nominal. The specimen is facing you.\nIt has been facing you since you entered.', { critical: true });

    // planter rows (low cover)
    for (const x of [23, 45]) for (const z of [-104, -116, -128]) {
      this.box(x - 1.4, 0, z - 2.2, x + 1.4, 0.9, z + 2.2, M.darkMetal, { uv: 1 });
      this.strip(x - 1.2, 0.9, z - 2, x + 1.2, 0.93, z + 2, new THREE.MeshBasicMaterial({ color: new THREE.Color(0.05, 0.6, 0.15) }));
    }
    // vents in ceiling
    this.points.arenaVents = [];
    for (const [x, z] of [[24, -106], [44, -106], [24, -126], [44, -126], [30, -112], [38, -120]]) {
      this.ventGrate(x, H - 0.02, z);
      this.points.arenaVents.push(new THREE.Vector3(x, H - 0.5, z));
    }
    this.points.arenaSentinels = [new THREE.Vector3(X0 + 1.5, 8, -116), new THREE.Vector3(X1 - 1.5, 8, -116)];
    this.points.stalkerSpawn = new THREE.Vector3(34, 0, -129);
    this.points.arenaCenter = new THREE.Vector3(34, 0, -116);

    // grow lights
    for (const [x, z] of [[27, -104], [41, -104], [27, -128], [41, -128], [34, -108], [34, -124]]) {
      this.fixture({ x, y: H - 0.05, z, color: 0x5bff9a, intensity: 6, distance: 14, mode: x === 41 && z === -128 ? 'flicker' : 'steady', size: [3, 0.08, 0.5], group: 'arena' });
    }
    // emergency red (off at first)
    for (const [x, z] of [[20.4, -110], [47.6, -122], [34, -131.6], [34, -100.4]]) {
      const f = this.fixture({ x, y: 9, z, color: 0xff1020, intensity: 9, distance: 18, mode: 'emergency', size: [0.3, 0.3, 0.3], group: 'alarm' });
      f.on = false;
    }
  }

  // ===================================================================== AREA G — Descent Lift
  buildFinal() {
    const M = this.mats;
    this.room({ x0: 29, x1: 39, z0: -148, z1: -132.5, h: 7, walls: { s: false }, open: { n: [{ c: 34, w: 8, h: 4.5, y: 1.2, glass: true }] } });
    this.ribsZ(29, -148, -132.5, 2.5, 7, 0.3); this.ribsZ(39, -148, -132.5, 2.5, 7, -0.3);
    const pad = new THREE.Mesh(new THREE.CylinderGeometry(2.6, 2.6, 0.2, 40), M.darkMetal);
    pad.position.set(34, 0.1, -141.5); pad.receiveShadow = true; this.scene.add(pad);
    this.collider(32.2, 0, -143.3, 35.8, 0.2, -139.7);
    const ring = new THREE.Mesh(new THREE.TorusGeometry(2.5, 0.05, 4, 64), M.amber);
    ring.rotation.x = Math.PI / 2; ring.position.set(34, 0.22, -141.5); this.scene.add(ring);
    this.liftRing = ring;
    this.console(36.8, -145.5, Math.PI * 0.8, 21, '#fb4');
    this.fixture({ x: 34, y: 6.9, z: -141.5, color: 0xffc070, intensity: 7, distance: 12, mode: 'steady', size: [1, 0.08, 1], group: 'final' });
    // the shaft below, seen through the window: Bloom glow from the depths
    const glow = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(1.2, 0.2, 2.2), blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    glow.position.set(34, -60, -190); glow.scale.setScalar(120); this.scene.add(glow);
    this.animated.push((t) => { glow.material.color.setRGB(1.0 + Math.sin(t * 0.5) * 0.3, 0.2, 2 + Math.sin(t * 0.5) * 0.5); });
    for (let i = 0; i < 10; i++) {
      const b = new THREE.Mesh(new THREE.BoxGeometry(2 + Math.random() * 6, 120, 2 + Math.random() * 6), M.darkMetal);
      b.position.set(34 + (Math.random() - 0.5) * 80, -50, -170 - Math.random() * 60); this.scene.add(b);
    }
    this.points.liftCenter = new THREE.Vector3(34, 0, -141.5);
    this.scannable(new THREE.Vector3(36.8, 1.3, -145.5), 'LIFT CONTROL // DESCENT TO SECTOR 2',
      'Destination: Inner Chasm, Level -4,000. "Bloom Heart."\nThe station AI left one message on loop:\n"KAGE OPERATIVE. YOU WERE NOT INVITED. COME DOWN ANYWAY."\n\nStep onto the lift to descend.', { critical: true });
  }

  // ===================================================================== SKY & CITY
  buildSky() {
    // stars
    const n = 2500, pos = new Float32Array(n * 3), col = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      const u = Math.random() * 2 - 1, a = Math.random() * Math.PI * 2, s = Math.sqrt(1 - u * u);
      pos.set([Math.cos(a) * s * 1500, u * 1500, Math.sin(a) * s * 1500], i * 3);
      const b = 0.4 + Math.random() * 1.2;
      col.set([b * (0.8 + Math.random() * 0.2), b * 0.9, b], i * 3);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    g.setAttribute('color', new THREE.BufferAttribute(col, 3));
    const stars = new THREE.Points(g, new THREE.PointsMaterial({ size: 2.2, sizeAttenuation: false, vertexColors: true, fog: false, depthWrite: false }));
    this.scene.add(stars);
    // planet
    const planet = new THREE.Mesh(new THREE.SphereGeometry(260, 48, 32), new THREE.MeshBasicMaterial({ map: planetTexture(), fog: false, color: new THREE.Color(0.55, 0.6, 0.75) }));
    planet.position.set(1000, 620, -700); planet.rotation.z = 0.4;
    this.scene.add(planet);
    const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(0.25, 0.4, 0.9), blending: THREE.AdditiveBlending, fog: false, depthWrite: false }));
    halo.position.copy(planet.position); halo.scale.setScalar(820); this.scene.add(halo);
  }

  buildCity() {
    const r = rng(1234);
    const city = new THREE.Group();
    this.scene.add(city);
    const texes = [];
    for (let i = 0; i < 10; i++) texes.push(windowTexture(100 + i, i));
    const geo = new THREE.BoxGeometry(1, 1, 1);
    for (let i = 0; i < 110; i++) {
      const x = 80 + Math.pow(r(), 0.8) * 700;
      const z = -40 + (r() - 0.5) * 1100;
      const w = 14 + r() * 45, d = 14 + r() * 45;
      const top = -60 + r() * r() * 260;
      const bottom = -700;
      const h = top - bottom;
      const tex = texes[Math.floor(r() * texes.length)].clone();
      tex.needsUpdate = true;
      tex.repeat.set(Math.max(1, Math.round(w / 18)), Math.max(1, Math.round(h / 70)));
      const dist = Math.hypot(x - 54, z + 40);
      const k = 1.2 * Math.exp(-dist / 520);
      const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ map: tex, color: new THREE.Color(k, k, k * 1.1), fog: false }));
      m.scale.set(w, h, d);
      m.position.set(x, bottom + h / 2, z);
      city.add(m);
      // rooftop beacon
      if (r() < 0.5) {
        const b = new THREE.Sprite(new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(3, 0.2, 0.2), blending: THREE.AdditiveBlending, fog: false, depthWrite: false }));
        b.position.set(x, top + 3, z); b.scale.setScalar(6 + dist * 0.01);
        city.add(b);
        const ph = r() * 6;
        this.animated.push((t) => { b.visible = ((t + ph) % 2.2) < 0.25; });
      }
      // neon signs
      if (r() < 0.3 && top > -40) {
        const cols = ['#ff3ab0', '#3af0ff', '#ffb43a', '#a07bff'];
        const ncol = cols[Math.floor(r() * cols.length)];
        const sign = new THREE.Mesh(new THREE.PlaneGeometry(w * 0.8, w * 0.2), new THREE.MeshBasicMaterial({ map: neonTexture(i * 13, ncol), color: new THREE.Color(2, 2, 2), fog: false, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
        sign.position.set(x - w / 2 - 0.5, top - 10 - r() * 30, z);
        sign.rotation.y = -Math.PI / 2;
        city.add(sign);
        if (r() < 0.4) { const ph = r() * 9; this.animated.push((t) => { sign.visible = Math.sin(t * 13 + ph) > -0.7 || ((t + ph) % 5) > 0.3; }); }
      }
    }
    // haze layers below
    const hazeTex = this.glowTex;
    for (const [y, c, o] of [[-80, [0.6, 0.15, 0.5], 0.35], [-180, [0.2, 0.35, 0.7], 0.45], [-320, [0.5, 0.2, 0.6], 0.6]]) {
      for (let i = 0; i < 8; i++) {
        const s = new THREE.Mesh(new THREE.PlaneGeometry(900, 900), new THREE.MeshBasicMaterial({ map: hazeTex, color: new THREE.Color(c[0] * o, c[1] * o, c[2] * o), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
        s.rotation.x = -Math.PI / 2;
        s.position.set(350 + (r() - 0.5) * 600, y + (r() - 0.5) * 30, -40 + (r() - 0.5) * 900);
        city.add(s);
      }
    }
    // flying traffic lanes
    const lanes = [];
    for (const [x, y, speed, col] of [[110, -10, 22, [3, 2.2, 1]], [150, 25, -30, [1, 2, 3]], [230, -40, 18, [3, 0.6, 1.6]], [320, 60, -25, [2.5, 2.5, 2.5]], [180, -90, 28, [1, 2.5, 3]]]) {
      const mat = new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(...col), blending: THREE.AdditiveBlending, fog: false, depthWrite: false });
      for (let i = 0; i < 14; i++) {
        const s = new THREE.Sprite(mat);
        s.scale.setScalar(2.5);
        s.userData = { x: x + (r() - 0.5) * 8, y: y + (r() - 0.5) * 4, z: -600 + r() * 1200, speed: speed * (0.8 + r() * 0.4) };
        city.add(s); lanes.push(s);
      }
    }
    this.animated.push((t, dt) => {
      for (const s of lanes) {
        const u = s.userData;
        u.z += u.speed * dt;
        if (u.z > 600) u.z -= 1200; if (u.z < -600) u.z += 1200;
        s.position.set(u.x, u.y, u.z);
      }
    });

    // the leviathan — a vast ship drifting past, triggered once
    const lev = new THREE.Group();
    const lm = new THREE.MeshBasicMaterial({ color: 0x030405, fog: false });
    const hull = new THREE.Mesh(new THREE.CylinderGeometry(22, 34, 380, 10), lm);
    hull.rotation.x = Math.PI / 2; lev.add(hull);
    const prow = new THREE.Mesh(new THREE.ConeGeometry(22, 120, 10), lm);
    prow.rotation.x = Math.PI / 2; prow.position.z = 250; lev.add(prow);
    for (let i = 0; i < 6; i++) {
      const fin = new THREE.Mesh(new THREE.BoxGeometry(4, 50 + r() * 50, 40), lm);
      fin.position.set(0, 40, -150 + i * 55); lev.add(fin);
    }
    const lightsMat = new THREE.SpriteMaterial({ map: this.glowTex, color: new THREE.Color(3, 0.3, 0.2), blending: THREE.AdditiveBlending, fog: false, depthWrite: false });
    for (let i = 0; i < 18; i++) {
      const s = new THREE.Sprite(lightsMat); s.scale.setScalar(6);
      s.position.set(-30, (r() - 0.5) * 40, -180 + i * 22); lev.add(s);
    }
    lev.position.set(520, 70, -900);
    lev.visible = false;
    this.scene.add(lev);
    this.leviathan = lev;
    this.animated.push((t, dt) => {
      if (!lev.visible) return;
      lev.position.z += dt * 16;
      lightsMat.opacity = 0.5 + 0.5 * Math.sin(t * 2);
      if (lev.position.z > 900) lev.visible = false;
    });
  }

  startLeviathan() {
    this.leviathan.visible = true;
    this.leviathan.position.z = -700;
  }

  // ===================================================================== set pieces & life
  hologram(x, y, z, rotY, w, h, lines, color = '#6ff', opts = {}) {
    const tex = hologramTexture(lines, color, opts.tex);
    const col = new THREE.Color(color);
    const mat = new THREE.ShaderMaterial({
      uniforms: { map: { value: tex }, time: holoUniforms.time, color: { value: col.multiplyScalar(opts.gain || 2.2) }, seed: { value: Math.random() * 10 } },
      vertexShader: `
        uniform float time; uniform float seed; varying vec2 vUv;
        void main() {
          vUv = uv;
          vec3 p = position;
          float glitch = step(0.985, fract(sin(floor(time * 9.0 + seed) * 43.7) * 917.3));
          p.x += glitch * (fract(sin(floor(uv.y * 20.0) + time) * 91.7) - 0.5) * 0.15;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);
        }`,
      fragmentShader: `
        uniform sampler2D map; uniform float time; uniform vec3 color; uniform float seed; varying vec2 vUv;
        void main() {
          vec2 uv = vUv;
          float band = step(0.97, fract(uv.y * 3.0 - time * 0.35 + seed));
          uv.x += band * 0.01;
          float t = texture2D(map, uv).r;
          float scan = 0.65 + 0.35 * sin(uv.y * 300.0 - time * 8.0);
          float flick = 0.85 + 0.15 * sin(time * 37.0 + seed) * sin(time * 13.0);
          float edge = smoothstep(0.0, 0.05, uv.y) * smoothstep(1.0, 0.95, uv.y);
          vec3 c = color * (t * scan * flick + band * 0.15 + 0.025) * edge;
          gl_FragColor = vec4(c, 1.0);
        }`,
      transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    });
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h, 1, 1), mat);
    m.position.set(x, y, z); m.rotation.y = rotY;
    m.renderOrder = 8;
    this.scene.add(m);
    // projector base glow
    if (opts.projector !== false) {
      const beam = new THREE.Mesh(new THREE.PlaneGeometry(w, h * 0.6), new THREE.MeshBasicMaterial({ map: this.glowTex, color: col.clone().multiplyScalar(0.06), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
      beam.position.set(0, -h * 0.65, 0); m.add(beam);
    }
    if (opts.spin) this.animated.push((t) => { m.rotation.y = rotY + t * opts.spin; });
    if (opts.bob) this.animated.push((t) => { m.position.y = y + Math.sin(t * 0.8) * opts.bob; });
    return m;
  }

  buildSetPieces() {
    const M = this.mats;
    // ---- holograms
    this.hologram(0, 4.0, -11.6, 0, 2.6, 1.2, [{ text: '環 C', y: 110, size: 80 }, { text: 'ARRIVALS  ▸  MAINTENANCE SPINE', y: 190 }], '#6ff');
    this.hologram(1.25, 1.9, -27.5, -Math.PI / 2, 1.3, 0.65, [{ text: '⚠ 生物災害', y: 110, size: 64 }, { text: 'DUCT 4 — SEALED', y: 190 }], '#ff4a5a', { projector: false });
    this.hologram(34, 14, -64, 0, 9, 4.5, [{ text: '黒鉄 KUROGANE', y: 120, size: 70 }, { text: 'A NEW HEAVEN ABOVE THE EARTH', y: 200 }], '#ff6ad5', { bob: 0.4, gain: 1.6 });
    this.hologram(16.2, 7, -30, Math.PI / 2, 5, 2.5, [{ text: '展望', y: 115, size: 76 }, { text: 'OBSERVATION DECK  ▸', y: 195 }], '#ffb347', { projector: false, gain: 1.4 });
    this.hologram(34, 4.2, -101.6, 0, 3, 1.1, [{ text: '収容', y: 110, size: 72 }, { text: 'CONTAINMENT LV.2', y: 195 }], '#ff4a5a', { projector: false });
    this.hologram(34, 4.8, -146, 0, 4, 1.6, [{ text: '降下  ▼', y: 115, size: 72 }, { text: 'SECTOR 2 // BLOOM HEART', y: 195 }], '#ffb347', { projector: false });

    // ---- ceiling fan under a light in the spine: sweeping shadows
    const fan = new THREE.Group();
    fan.position.set(0, 2.62, -30);
    const hub = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 0.08, 12), M.darkMetal);
    hub.castShadow = true; fan.add(hub);
    for (let i = 0; i < 5; i++) {
      const blade = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.015, 0.16), M.darkMetal);
      blade.position.x = 0.36; blade.rotation.x = 0.25;
      const arm = new THREE.Group(); arm.rotation.y = i * Math.PI * 2 / 5; arm.add(blade);
      blade.castShadow = true; fan.add(arm);
    }
    const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.5), M.darkMetal);
    rod.position.y = 0.28; fan.add(rod);
    this.scene.add(fan);
    this.animated.push((t, dt) => { fan.rotation.y += dt * 2.6; });

    // ---- steam vents (particles + visor condensation are driven by fx/main)
    this.points.steamVents = [
      new THREE.Vector3(4.2, 0.05, -10.6),
      new THREE.Vector3(-1.0, 0.05, -34.5),
      new THREE.Vector3(32.6, 0.05, -77),
      new THREE.Vector3(46.5, 0.05, -112),
    ];
    for (const v of this.points.steamVents) {
      const g = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.04, 0.8), M.darkMetal);
      g.position.copy(v); g.receiveShadow = true; this.scene.add(g);
      for (let i = -3; i <= 3; i++) {
        const bar = new THREE.Mesh(new THREE.BoxGeometry(0.03, 0.05, 0.7), M.rubber);
        bar.position.set(v.x + i * 0.1, v.y + 0.01, v.z); this.scene.add(bar);
      }
    }

    // ---- extra practical lights so spaces read: sconces, column uplights, floor guides
    for (const z of [-20, -32, -44, -56]) {
      this.fixture({ x: 15.0, y: 4.5, z, color: 0xffb070, intensity: 3.5, distance: 9, size: [0.08, 0.6, 0.3] });
    }
    for (const x of [24, 44]) for (const z of [-22, -58]) {
      this.fixture({ x: x + (x < 34 ? 1.9 : -1.9), y: 0.05, z, color: 0x58e6ff, intensity: 5, distance: 10, size: [0.4, 0.05, 0.4], lightY: 0.35 });
    }
    this.fixture({ x: 0, y: 4.85, z: -9, color: 0x9fc4ff, intensity: 3, distance: 8, mode: 'flicker' });
    this.fixture({ x: 34, y: 5.9, z: -71.5, color: 0xff8a50, intensity: 3, distance: 8 });
    this.fixture({ x: 34, y: 2.9, z: -132.8, color: 0xffb060, intensity: 3, distance: 7, group: 'final' });

    // indicator light strips on walls (emissive detail)
    const mats = [M.cyanDim, M.redDim, M.amber];
    const r = rng(314);
    for (let i = 0; i < 26; i++) {
      const z = -13 - r() * 26, side = r() < 0.5 ? -1.48 : 1.48;
      const y = 0.6 + r() * 1.6;
      this.strip(side - 0.02, y, z, side + 0.02, y + 0.03, z + 0.1 + r() * 0.3, mats[Math.floor(r() * 3)]);
    }
  }

  // ===================================================================== zones
  buildZones() {
    // [name, x0, z0, x1, z1, ambience, moon]
    this.zones = [
      { id: 'bay', box: [-6, -12.3, 6, 1], amb: 'bay', moon: 0, title: 'ARRIVAL BAY 03', sub: 'KUROGANE-9 // DOCKING RING C' },
      { id: 'spine', box: [-2, -41, 2, -12.3], amb: 'corridor', moon: 0, title: 'MAINTENANCE SPINE', sub: 'SUBLEVEL 4' },
      { id: 'junction', box: [2, -41, 14.25, -36.5], amb: 'corridor', moon: 1 },
      { id: 'atrium', box: [14.25, -70.25, 55, -9], amb: 'atrium', moon: 1, title: 'GRAND CONCOURSE', sub: 'RING C // PUBLIC LEVEL' },
      { id: 'funnel', box: [29, -99.75, 39, -70.25], amb: 'funnel', moon: 0.5, title: 'SERVICE THROAT', sub: 'HYDROPONICS ACCESS' },
      { id: 'arena', box: [19, -132.25, 49, -99.75], amb: 'arena', moon: 0, title: 'HYDROPONICS VAULT', sub: 'CONTAINMENT LEVEL 2' },
      { id: 'final', box: [28, -149, 40, -132.25], amb: 'final', moon: 0, title: 'DESCENT LIFT', sub: 'TO SECTOR 2' },
    ];
  }

  zoneAt(p) {
    for (const z of this.zones) {
      const [x0, z0, x1, z1] = z.box;
      if (p.x >= x0 && p.x <= x1 && p.z >= z0 && p.z <= z1) return z;
    }
    return null;
  }

  // ===================================================================== collision
  resolveCircle(p, r, yMin, yMax) {
    let hit = false;
    for (const c of this.colliders) {
      if (c.enabled === false) continue;
      if (c.max.y <= yMin || c.min.y >= yMax) continue;
      const cx = Math.max(c.min.x, Math.min(p.x, c.max.x));
      const cz = Math.max(c.min.z, Math.min(p.z, c.max.z));
      const dx = p.x - cx, dz = p.z - cz;
      const d2 = dx * dx + dz * dz;
      if (d2 >= r * r) continue;
      if (d2 > 1e-9) {
        const d = Math.sqrt(d2), push = (r - d) / d;
        p.x += dx * push; p.z += dz * push;
      } else {
        const l = p.x - c.min.x, rr = c.max.x - p.x, b = p.z - c.min.z, f = c.max.z - p.z;
        const m = Math.min(l, rr, b, f);
        if (m === l) p.x = c.min.x - r; else if (m === rr) p.x = c.max.x + r; else if (m === b) p.z = c.min.z - r; else p.z = c.max.z + r;
      }
      hit = true;
    }
    return hit;
  }

  groundAt(p, r, maxUp = 0.45) {
    let g = -50;
    const m = r * 0.6;
    for (const c of this.colliders) {
      if (c.enabled === false) continue;
      if (p.x < c.min.x - m || p.x > c.max.x + m || p.z < c.min.z - m || p.z > c.max.z + m) continue;
      if (c.max.y <= p.y + maxUp && c.max.y > g) g = c.max.y;
    }
    return g;
  }

  ceilingAt(p, r, headY) {
    let cmin = Infinity;
    const m = r * 0.6;
    for (const c of this.colliders) {
      if (c.enabled === false) continue;
      if (p.x < c.min.x - m || p.x > c.max.x + m || p.z < c.min.z - m || p.z > c.max.z + m) continue;
      if (c.min.y >= headY - 0.3 && c.min.y < cmin) cmin = c.min.y;
    }
    return cmin;
  }

  // Ray vs collider AABBs (walls, props, closed doors). Boxes containing the origin are ignored.
  lineOfSight(a, b) {
    const dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z;
    const ix = 1 / (dx || 1e-9), iy = 1 / (dy || 1e-9), iz = 1 / (dz || 1e-9);
    for (const c of this.colliders) {
      if (c.enabled === false) continue;
      let t1 = (c.min.x - a.x) * ix, t2 = (c.max.x - a.x) * ix;
      let tmin = Math.min(t1, t2), tmax = Math.max(t1, t2);
      t1 = (c.min.y - a.y) * iy; t2 = (c.max.y - a.y) * iy;
      tmin = Math.max(tmin, Math.min(t1, t2)); tmax = Math.min(tmax, Math.max(t1, t2));
      t1 = (c.min.z - a.z) * iz; t2 = (c.max.z - a.z) * iz;
      tmin = Math.max(tmin, Math.min(t1, t2)); tmax = Math.min(tmax, Math.max(t1, t2));
      if (tmax >= tmin && tmin > 0 && tmin < 1) return false;
    }
    return true;
  }

  update(dt, playerPos) {
    this.time += dt;
    shaftUniforms.time.value = this.time;
    holoUniforms.time.value = this.time;
    for (const fn of this.animated) fn(this.time, dt);
    for (const d of Object.values(this.doors)) d.update(dt, playerPos);
    this.updateFixtures(dt, playerPos);
    this.moonLevel += (this.moonTarget - this.moonLevel) * Math.min(1, dt * 1.5);
    this.moon.intensity = this.moonLevel * this.moonMax;
    this.moon.shadow.autoUpdate = this.moonLevel > 0.02;
    if (this.liftRing) this.liftRing.material.color.setRGB(2.4 + Math.sin(this.time * 3), 1.2, 0.2);
  }
}

export function buildLevel(game) {
  const L = new Level(game);
  L.build();
  return L;
}
