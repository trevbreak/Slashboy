// Creature art: organic geometry, PBR / iridescent materials with animated veins,
// IK legs with foot planting, and the Stalker's refractive cloak.
import * as THREE from 'three';
import { skinPBR, mechPBR } from './textures.js';

export const creatureTime = { value: 0 };

// ---------------------------------------------------------------- noise (JS)
function hash3(x, y, z) {
  let h = x * 374761393 + y * 668265263 + z * 2147483647;
  h = (h ^ (h >>> 13)) * 1274126177;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}
function vnoise(x, y, z) {
  const xi = Math.floor(x), yi = Math.floor(y), zi = Math.floor(z);
  const xf = x - xi, yf = y - yi, zf = z - zi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf), w = zf * zf * (3 - 2 * zf);
  const l = (a, b, t) => a + (b - a) * t;
  return l(
    l(l(hash3(xi, yi, zi), hash3(xi + 1, yi, zi), u), l(hash3(xi, yi + 1, zi), hash3(xi + 1, yi + 1, zi), u), v),
    l(l(hash3(xi, yi, zi + 1), hash3(xi + 1, yi, zi + 1), u), l(hash3(xi, yi + 1, zi + 1), hash3(xi + 1, yi + 1, zi + 1), u), v), w);
}

// Displace a geometry along its normals with fractal noise: lumpy, organic silhouettes.
export function organic(geo, amp = 0.05, freq = 3, seed = 0) {
  geo.computeVertexNormals();
  const p = geo.attributes.position, n = geo.attributes.normal;
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    const d = (vnoise(x * freq + seed, y * freq, z * freq) - 0.5) + (vnoise(x * freq * 2.7, y * freq * 2.7 + seed, z * freq * 2.7) - 0.5) * 0.45;
    p.setXYZ(i, x + n.getX(i) * d * amp, y + n.getY(i) * d * amp, z + n.getZ(i) * d * amp);
  }
  geo.computeVertexNormals();
  return geo;
}

// ---------------------------------------------------------------- shared textures (generated once)
let _tex = null;
function tex() {
  if (!_tex) {
    _tex = {
      chitin: skinPBR(5, { base: [30, 22, 38], rough: 70, metal: 90, cells: 120 }),
      flesh: skinPBR(9, { base: [40, 14, 46], rough: 110, metal: 10, cells: 220 }),
      stalker: skinPBR(21, { base: [18, 16, 24], rough: 95, metal: 40, cells: 90 }),
      mech: mechPBR(3, [78, 82, 92]),
    };
    for (const t of Object.values(_tex)) for (const m of Object.values(t)) { m.repeat.set(2, 2); }
  }
  return _tex;
}

// ---------------------------------------------------------------- shader injection: glowing veins
const NOISE_GLSL = `
  float vh(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float vn(vec3 x){ vec3 i = floor(x); vec3 f = fract(x); f = f*f*(3.0-2.0*f);
    return mix(mix(mix(vh(i),vh(i+vec3(1,0,0)),f.x),mix(vh(i+vec3(0,1,0)),vh(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(vh(i+vec3(0,0,1)),vh(i+vec3(1,0,1)),f.x),mix(vh(i+vec3(0,1,1)),vh(i+vec3(1,1,1)),f.x),f.y),f.z); }
`;

export function veinify(mat, { color = 0xa040ff, freq = 7, strength = 2.2, speed = 2.0, rim = 0 } = {}) {
  const u = {
    vTime: creatureTime,
    veinColor: { value: new THREE.Color(color) },
    veinFreq: { value: freq },
    veinStrength: { value: strength },
    rimStrength: { value: rim },
  };
  mat.userData.vein = u;
  mat.onBeforeCompile = (sh) => {
    Object.assign(sh.uniforms, u);
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vObjPos;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvObjPos = position;');
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', `#include <common>
        varying vec3 vObjPos; uniform float vTime; uniform vec3 veinColor; uniform float veinFreq; uniform float veinStrength; uniform float rimStrength;
        ${NOISE_GLSL}`)
      .replace('#include <emissivemap_fragment>', `#include <emissivemap_fragment>
        {
          vec3 q = vObjPos * veinFreq;
          float n1 = vn(q + vec3(0.0, vTime * 0.05, 0.0));
          float n2 = vn(q * 2.3 + 4.1);
          float v = (1.0 - smoothstep(0.0, 0.045, abs(n1 - 0.5))) + (1.0 - smoothstep(0.0, 0.03, abs(n2 - 0.5))) * 0.55;
          float pulse = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(vTime * ${speed.toFixed(2)} - vObjPos.z * 7.0 - vObjPos.y * 3.0), 2.0);
          totalEmissiveRadiance += veinColor * v * pulse * veinStrength;
        }`)
      .replace('#include <output_fragment>', '#include <output_fragment>')
      .replace('#include <opaque_fragment>', `
        {
          float fr = pow(1.0 - saturate(dot(normalize(vNormal), normalize(vViewPosition))), 3.0);
          outgoingLight += veinColor * fr * rimStrength;
        }
        #include <opaque_fragment>`);
  };
  mat.customProgramCacheKey = () => `vein-${speed.toFixed(2)}`;
  return mat;
}

// ---------------------------------------------------------------- materials
export function chitinMaterial(flashList) {
  const t = tex().chitin;
  const m = new THREE.MeshPhysicalMaterial({
    color: 0x2a2234, map: t.map, normalMap: t.normalMap, normalScale: new THREE.Vector2(0.8, 0.8),
    roughnessMap: t.ormMap, metalnessMap: t.ormMap, aoMap: t.ormMap,
    roughness: 0.75, metalness: 0.6,
    clearcoat: 1, clearcoatRoughness: 0.18,
    iridescence: 1, iridescenceIOR: 1.55, iridescenceThicknessRange: [180, 620],
    emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 0,
  });
  flashList.push(m);
  return m;
}

export function fleshMaterial(flashList, color = 0xb040ff) {
  const t = tex().flesh;
  const m = new THREE.MeshPhysicalMaterial({
    color: 0x3a1640, map: t.map, normalMap: t.normalMap, normalScale: new THREE.Vector2(1.2, 1.2),
    roughnessMap: t.ormMap, roughness: 0.9, metalness: 0.0,
    sheen: 1, sheenColor: new THREE.Color(0.8, 0.3, 1.0), sheenRoughness: 0.4,
    clearcoat: 0.6, clearcoatRoughness: 0.35,
    emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 0,
  });
  veinify(m, { color, freq: 6, strength: 2.6, speed: 2.4, rim: 0.4 });
  flashList.push(m);
  return m;
}

export function mechMaterial(flashList, color = 0x5c6370) {
  const t = tex().mech;
  const m = new THREE.MeshStandardMaterial({
    color, map: t.map, normalMap: t.normalMap, roughnessMap: t.ormMap, metalnessMap: t.ormMap, aoMap: t.ormMap,
    roughness: 0.9, metalness: 1, emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 0,
  });
  flashList.push(m);
  return m;
}

export function stalkerBodyMaterial(flashList) {
  const t = tex().stalker;
  const m = new THREE.MeshPhysicalMaterial({
    color: 0x16131e, map: t.map, normalMap: t.normalMap, normalScale: new THREE.Vector2(1, 1),
    roughnessMap: t.ormMap, roughness: 0.7, metalness: 0.4,
    clearcoat: 1, clearcoatRoughness: 0.25,
    sheen: 0.6, sheenColor: new THREE.Color(0.5, 0.4, 1.0),
    emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 0,
  });
  veinify(m, { color: 0xd8c0ff, freq: 4.5, strength: 1.4, speed: 1.4, rim: 0.25 });
  flashList.push(m);
  return m;
}

// Refractive active camouflage: real transmission (bends what's behind it) + a shimmering fresnel edge.
export function cloakMaterial() {
  const u = { cTime: creatureTime, reveal: { value: 0 }, flash: { value: 0 } };
  const m = new THREE.MeshPhysicalMaterial({
    color: 0xeef4ff, metalness: 0, roughness: 0.05, transmission: 1, thickness: 0.5, ior: 1.22,
    specularIntensity: 0.6, envMapIntensity: 0.4,
  });
  m.userData.cloak = u;
  m.onBeforeCompile = (sh) => {
    Object.assign(sh.uniforms, u);
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nvarying vec3 vObjPos2;')
      .replace('#include <begin_vertex>', '#include <begin_vertex>\nvObjPos2 = position;');
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', `#include <common>\nvarying vec3 vObjPos2; uniform float cTime; uniform float reveal; uniform float flash;`)
      .replace('#include <opaque_fragment>', `
        {
          float fr = pow(1.0 - saturate(dot(normalize(vNormal), normalize(vViewPosition))), 2.5);
          float band = 0.5 + 0.5 * sin(vObjPos2.y * 22.0 - cTime * 6.0 + sin(vObjPos2.x * 9.0 + cTime) * 2.0);
          vec3 shimmer = vec3(0.45, 0.65, 1.0) * fr * (0.12 + band * 0.18);
          vec3 thermal = mix(vec3(1.6, 0.5, 0.2), vec3(2.2, 1.6, 0.4), band) * (0.25 + fr * 1.2);
          outgoingLight = mix(outgoingLight + shimmer, thermal, reveal * 0.85) + vec3(flash);
        }
        #include <opaque_fragment>`);
  };
  m.customProgramCacheKey = () => 'cloak';
  return m;
}

export function glowSprite(texture, color, size) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, color, blending: THREE.AdditiveBlending, depthWrite: false }));
  s.scale.setScalar(size);
  return s;
}

// Tapered limb segment lying along +X from the origin.
export function limb(len, r0, r1, mat, seg = 8) {
  const g = new THREE.CylinderGeometry(r1, r0, len, seg, 4);
  g.rotateZ(-Math.PI / 2);
  g.translate(len / 2, 0, 0);
  const m = new THREE.Mesh(g, mat);
  m.castShadow = true;
  return m;
}

// ---------------------------------------------------------------- IK leg with foot planting
const _w = new THREE.Vector3(), _l = new THREE.Vector3();
export class IKLeg {
  constructor(body, hip, rest, a, b, mats, opts = {}) {
    this.body = body; this.hip = hip.clone(); this.rest = rest.clone();
    this.a = a; this.b = b;
    this.group = opts.group || 0;
    this.hipG = new THREE.Group(); this.hipG.position.copy(hip); body.add(this.hipG);
    this.femurG = new THREE.Group(); this.hipG.add(this.femurG);
    const joint = new THREE.Mesh(new THREE.SphereGeometry(opts.r0 * 1.35, 10, 8), mats.joint);
    this.hipG.add(joint);
    this.femurG.add(limb(a, opts.r0, opts.r0 * 0.7, mats.limb));
    this.kneeG = new THREE.Group(); this.kneeG.position.x = a; this.femurG.add(this.kneeG);
    const knee = new THREE.Mesh(new THREE.SphereGeometry(opts.r0 * 0.95, 10, 8), mats.joint);
    this.kneeG.add(knee);
    // knee spike
    const spike = new THREE.Mesh(new THREE.ConeGeometry(opts.r0 * 0.5, opts.r0 * 4, 5), mats.limb);
    spike.position.set(0, opts.r0 * 1.8, 0); spike.rotation.z = 0.3; this.kneeG.add(spike);
    this.kneeG.add(limb(b * 0.85, opts.r0 * 0.75, opts.r0 * 0.35, mats.limb));
    const claw = new THREE.Mesh(new THREE.ConeGeometry(opts.r0 * 0.35, b * 0.2, 5), mats.claw || mats.limb);
    claw.rotation.z = -Math.PI / 2; claw.position.x = b * 0.95; claw.castShadow = true;
    this.kneeG.add(claw);
    this.foot = new THREE.Vector3();
    this.from = new THREE.Vector3(); this.to = new THREE.Vector3();
    this.stepT = 1; this.stepping = false; this.init = false;
  }

  desired(out, groundY, lead) {
    out.copy(this.rest);
    this.body.localToWorld(out);
    out.add(lead);
    out.y = groundY;
    return out;
  }

  // planted: feet stick to the floor and step when stretched; otherwise feet follow the rest pose (airborne)
  update(dt, groundY, vel, planted, otherStepping, tuck = 0) {
    if (!this.init) { this.desired(this.foot, groundY, _l.set(0, 0, 0)); this.init = true; }
    if (!planted) {
      const t = _w.copy(this.rest);
      t.y += tuck; t.x *= 1 - tuck * 0.4; t.z *= 1 - tuck * 0.2;
      this.body.localToWorld(t);
      this.foot.lerp(t, Math.min(1, dt * 14));
      this.stepping = false; this.stepT = 1;
    } else {
      const speed = Math.hypot(vel.x, vel.z);
      const lead = _l.set(vel.x, 0, vel.z).multiplyScalar(0.12);
      const want = this.desired(_w, groundY, lead);
      if (this.stepping) {
        this.stepT = Math.min(1, this.stepT + dt / Math.max(0.07, 0.13 - speed * 0.006));
        const k = this.stepT;
        this.foot.lerpVectors(this.from, this.to, k);
        this.foot.y += Math.sin(k * Math.PI) * (0.14 + speed * 0.012);
        if (k >= 1) this.stepping = false;
      } else if (!otherStepping && this.foot.distanceTo(want) > 0.32 + speed * 0.05) {
        this.stepping = true; this.stepT = 0;
        this.from.copy(this.foot); this.to.copy(want);
      }
    }
    this.solve();
  }

  solve() {
    const t = _w.copy(this.foot);
    this.body.worldToLocal(t);
    t.sub(this.hip);
    this.hipG.rotation.y = Math.atan2(-t.z, t.x);
    const h = Math.hypot(t.x, t.z), dy = t.y;
    const a = this.a, b = this.b;
    const d = Math.min(a + b - 0.001, Math.max(0.05, Math.hypot(h, dy)));
    const ang = Math.atan2(dy, h);
    const alpha = Math.acos(THREE.MathUtils.clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1));
    const beta = Math.acos(THREE.MathUtils.clamp((a * a + b * b - d * d) / (2 * a * b), -1, 1));
    this.femurG.rotation.z = ang + alpha;
    this.kneeG.rotation.z = -(Math.PI - beta);
  }
}

// ---------------------------------------------------------------- Crawler
export function buildCrawler(enemy, glowTex) {
  const flash = enemy.flashMats;
  const chitin = chitinMaterial(flash);
  const flesh = fleshMaterial(flash, 0xb44cff);
  const dark = new THREE.MeshPhysicalMaterial({ color: 0x0c0a10, roughness: 0.3, metalness: 0.5, clearcoat: 1, emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 0 });
  flash.push(dark);
  const body = new THREE.Group();
  const add = (geo, mat, x, y, z, sx = 1, sy = 1, sz = 1) => {
    const m = new THREE.Mesh(geo, mat); m.position.set(x, y, z); m.scale.set(sx, sy, sz);
    m.castShadow = true; body.add(m); return m;
  };
  // thorax + segmented dorsal plates
  add(organic(new THREE.SphereGeometry(0.34, 40, 28), 0.08, 4, 1), chitin, 0, 0, 0, 1, 0.62, 1.2);
  for (let i = 0; i < 5; i++) {
    const g = new THREE.SphereGeometry(0.38 - i * 0.02, 28, 10, 0, Math.PI * 2, 0, Math.PI * 0.38);
    const p = add(g, chitin, 0, 0.11 + Math.sin(i * 0.8) * 0.03, -0.2 + i * 0.22, 1.08, 0.7, 0.75);
    p.rotation.x = -0.25 + i * 0.12;
  }
  // abdomen: glowing veined sac that breathes
  enemy.abdomen = add(organic(new THREE.SphereGeometry(0.44, 40, 28), 0.1, 3.5, 7), flesh, 0, 0.1, 0.72, 1.05, 0.8, 1.35);
  // dorsal spines
  for (let i = 0; i < 7; i++) {
    const s = add(new THREE.ConeGeometry(0.03, 0.22 + Math.sin(i / 6 * Math.PI) * 0.18, 5), dark, 0, 0.22 + Math.sin(i / 6 * Math.PI) * 0.06, -0.25 + i * 0.16);
    s.rotation.x = 0.7;
  }
  // head
  const head = enemy.head = new THREE.Group(); head.position.set(0, 0.04, -0.46); body.add(head);
  const skull = new THREE.Mesh(organic(new THREE.SphereGeometry(0.21, 32, 22), 0.05, 6, 3), chitin);
  skull.scale.set(1.15, 0.8, 1.4); skull.castShadow = true; head.add(skull);
  enemy.eyeMat = new THREE.MeshPhysicalMaterial({ color: 0x100000, emissive: new THREE.Color(2.2, 0.1, 0.06), emissiveIntensity: 1, clearcoat: 1, roughness: 0.1 });
  for (const [x, y, z, r] of [[-0.07, 0.07, -0.25, 0.034], [0.07, 0.07, -0.25, 0.034], [-0.13, 0.03, -0.2, 0.025], [0.13, 0.03, -0.2, 0.025], [-0.04, 0.12, -0.2, 0.018], [0.04, 0.12, -0.2, 0.018]]) {
    const e = new THREE.Mesh(new THREE.SphereGeometry(r, 10, 8), enemy.eyeMat); e.position.set(x, y, z); head.add(e);
  }
  enemy.eyeGlow = glowSprite(glowTex, new THREE.Color(0.7, 0.05, 0.03), 0.22);
  enemy.eyeGlow.position.set(0, 0.07, -0.3); head.add(enemy.eyeGlow);
  // mandibles: two-part hooked pincers
  enemy.mandibles = [];
  for (const s of [-1, 1]) {
    const m = new THREE.Group(); m.position.set(s * 0.08, -0.06, -0.24); head.add(m);
    const base = new THREE.Mesh(new THREE.ConeGeometry(0.04, 0.2, 6), dark);
    base.rotation.x = -Math.PI / 2; base.position.z = -0.08; m.add(base);
    const hook = new THREE.Mesh(new THREE.ConeGeometry(0.022, 0.16, 5), dark);
    hook.position.set(-s * 0.04, 0, -0.2); hook.rotation.set(-Math.PI / 2, 0, -s * 0.9); m.add(hook);
    enemy.mandibles.push(m);
  }
  // feelers: jointed chains that twitch
  enemy.feelers = [];
  for (const s of [-1, 1]) {
    let parent = head;
    const chain = [];
    for (let i = 0; i < 5; i++) {
      const seg = new THREE.Group();
      seg.position.set(i === 0 ? s * 0.07 : 0, i === 0 ? 0.14 : 0.13, i === 0 ? -0.15 : 0);
      if (i === 0) seg.rotation.set(-0.9, s * 0.4, 0);
      const rod = new THREE.Mesh(new THREE.CylinderGeometry(0.006 * (1 - i * 0.15), 0.008 * (1 - i * 0.15), 0.13, 4), dark);
      rod.position.y = 0.065; seg.add(rod);
      parent.add(seg); chain.push(seg); parent = seg;
    }
    enemy.feelers.push({ chain, s });
  }
  // legs
  const legMats = { limb: chitin, joint: dark, claw: dark };
  enemy.legs = [];
  let idx = 0;
  for (const s of [-1, 1]) for (const z of [-0.3, 0.02, 0.32]) {
    const hip = new THREE.Vector3(s * 0.24, 0.0, z);
    const rest = new THREE.Vector3(s * 0.95, -0.55, z * 1.9 - 0.05);
    const group = (idx === 0 || idx === 4 || idx === 2) ? 0 : 1;
    enemy.legs.push(new IKLeg(body, hip, rest, 0.55, 0.72, legMats, { r0: 0.05, group }));
    idx++;
  }
  body.position.y = 0.55;
  return body;
}

// ---------------------------------------------------------------- Sentinel
export function buildSentinel(enemy, glowTex) {
  const flash = enemy.flashMats;
  const shell = mechMaterial(flash, 0x8a919c);
  const darkMech = mechMaterial(flash, 0x2a2e36);
  const g = new THREE.Group();
  const core = new THREE.Mesh(new THREE.SphereGeometry(0.4, 32, 24), darkMech); core.castShadow = true; g.add(core);
  // four armour petals around the forward axis
  enemy.petals = [];
  for (let i = 0; i < 4; i++) {
    const geo = new THREE.SphereGeometry(0.58, 24, 16, i * Math.PI / 2 + 0.06, Math.PI / 2 - 0.12, Math.PI * 0.14, Math.PI * 0.72);
    geo.rotateX(Math.PI / 2);
    const p = new THREE.Mesh(geo, shell); p.castShadow = true;
    const pivot = new THREE.Group(); pivot.add(p); g.add(pivot);
    const a = i * Math.PI / 2 + Math.PI / 4;
    pivot.userData.dir = new THREE.Vector3(Math.cos(a), Math.sin(a), 0);
    // trim light on each petal
    const trim = new THREE.Mesh(new THREE.TorusGeometry(0.585, 0.008, 4, 16, Math.PI / 2 - 0.2), null);
    trim.rotation.z = i * Math.PI / 2 + 0.1; trim.position.z = -0.12;
    pivot.add(trim);
    enemy.petals.push({ pivot, trim });
  }
  // iris eye
  enemy.irisU = { time: creatureTime, color: { value: new THREE.Color(0.4, 2.6, 3.6) }, pupil: { value: 0.25 }, power: { value: 0.55 } };
  const iris = new THREE.Mesh(new THREE.CircleGeometry(0.2, 48), new THREE.ShaderMaterial({
    uniforms: enemy.irisU,
    vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
    fragmentShader: `
      uniform float time; uniform vec3 color; uniform float pupil; uniform float power; varying vec2 vUv;
      void main() {
        vec2 c = vUv - 0.5; float r = length(c) * 2.0; float a = atan(c.y, c.x);
        float rings = 0.5 + 0.5 * sin(r * 40.0 - time * 3.0);
        float seg = step(0.5, fract(a * 6.0 / 6.2832 + time * 0.15)) * step(0.62, r) * step(r, 0.8);
        float iris = smoothstep(pupil, pupil + 0.05, r) * (1.0 - smoothstep(0.92, 1.0, r));
        vec3 col = color * (iris * (0.35 + 0.65 * rings) + seg * 0.8) + color * 3.0 * (1.0 - smoothstep(0.0, pupil, r)) * 0.15;
        col += vec3(1.0) * smoothstep(pupil + 0.03, pupil, r) * smoothstep(pupil - 0.06, pupil, r) * 2.0;
        gl_FragColor = vec4(col * power, 1.0);
      }`,
  }));
  iris.position.z = -0.405; iris.rotation.y = Math.PI; g.add(iris);
  enemy.irisMesh = iris;
  const lens = new THREE.Mesh(new THREE.SphereGeometry(0.22, 24, 12, 0, Math.PI * 2, 0, Math.PI / 2),
    new THREE.MeshPhysicalMaterial({ color: 0x88aacc, roughness: 0.02, metalness: 0, transparent: true, opacity: 0.25, clearcoat: 1 }));
  lens.rotation.x = -Math.PI / 2; lens.position.z = -0.38; g.add(lens);
  enemy.eyeGlow = glowSprite(glowTex, new THREE.Color(0.15, 0.7, 1.0), 0.55);
  enemy.eyeGlow.position.z = -0.55; g.add(enemy.eyeGlow);
  // gyro rings with node lights
  enemy.ringLights = new THREE.MeshBasicMaterial({ color: new THREE.Color(1.2, 0.25, 0.15) });
  enemy.rings = [];
  for (const [r, tilt] of [[0.86, 0], [0.98, Math.PI / 2]]) {
    const ring = new THREE.Group();
    const torus = new THREE.Mesh(new THREE.TorusGeometry(r, 0.03, 8, 48), darkMech); torus.castShadow = true; ring.add(torus);
    for (let i = 0; i < 8; i++) {
      const a = i * Math.PI / 4;
      const node = new THREE.Mesh(new THREE.BoxGeometry(0.07, 0.07, 0.1), i % 2 ? shell : enemy.ringLights);
      node.position.set(Math.cos(a) * r, Math.sin(a) * r, 0); node.rotation.z = a; ring.add(node);
    }
    ring.rotation.y = tilt;
    const holder = new THREE.Group(); holder.add(ring); g.add(holder);
    enemy.rings.push({ holder, ring });
  }
  // rear sensor array + antennae with blinking tips
  const back = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.24, 0.25, 12), darkMech);
  back.rotation.x = Math.PI / 2; back.position.z = 0.45; g.add(back);
  enemy.blink = new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 0.2, 0.2) });
  for (const s of [-1, 1]) {
    const ant = new THREE.Mesh(new THREE.CylinderGeometry(0.008, 0.012, 0.55, 4), darkMech);
    ant.position.set(s * 0.12, 0.38, 0.38); ant.rotation.set(0.5, 0, -s * 0.25); g.add(ant);
    const tip = new THREE.Mesh(new THREE.SphereGeometry(0.022, 6, 4), enemy.blink);
    tip.position.set(s * 0.19, 0.62, 0.52); g.add(tip);
  }
  // thruster
  const thr = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.08, 0.14, 12), darkMech);
  thr.position.y = -0.48; g.add(thr);
  enemy.thrusterGlow = glowSprite(glowTex, new THREE.Color(0.3, 0.9, 2.2), 0.7);
  enemy.thrusterGlow.position.y = -0.62; g.add(enemy.thrusterGlow);
  const trimMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.3, 1.8, 2.4) });
  enemy.trimMat = trimMat;
  for (const p of enemy.petals) p.trim.material = trimMat;
  return g;
}

// ---------------------------------------------------------------- Stalker
export function buildStalker(enemy, glowTex) {
  const flash = enemy.flashMats;
  const bodyMat = enemy.bodyMat = stalkerBodyMaterial(flash);
  enemy.cloakMat = cloakMaterial();
  enemy.parts = [];
  const add = (geo, parent, x, y, z, rx = 0, ry = 0, rz = 0, s = null) => {
    const m = new THREE.Mesh(geo, bodyMat);
    m.position.set(x, y, z); m.rotation.set(rx, ry, rz);
    if (s) m.scale.set(...s);
    m.castShadow = true;
    parent.add(m); enemy.parts.push(m);
    return m;
  };
  const root = enemy.rig = new THREE.Group();
  const hips = enemy.hips = new THREE.Group(); hips.position.y = 1.3; root.add(hips);
  add(organic(new THREE.SphereGeometry(0.19, 20, 14), 0.06, 5, 2), hips, 0, 0, 0, 0, 0, 0, [1.3, 0.8, 0.9]);
  const torso = enemy.torso = new THREE.Group(); torso.position.y = 0.1; torso.rotation.x = -0.35; hips.add(torso);
  // lathe torso: pinched waist flaring to a broad chest
  const prof = [];
  for (let i = 0; i <= 16; i++) {
    const t = i / 16;
    const r = 0.09 + Math.sin(t * Math.PI * 0.95) * 0.17 + Math.max(0, t - 0.55) * 0.18 - Math.max(0, t - 0.9) * 1.2;
    prof.push(new THREE.Vector2(Math.max(0.02, r), t * 1.15));
  }
  const tg = organic(new THREE.LatheGeometry(prof, 24), 0.05, 4, 9);
  add(tg, torso, 0, 0, 0, 0, 0, 0, [1.25, 1, 0.75]);
  // ribcage
  for (let i = 0; i < 5; i++) {
    const rib = add(new THREE.TorusGeometry(0.21 - Math.abs(i - 2) * 0.02, 0.018, 6, 20, Math.PI * 1.1), torso, 0, 0.5 + i * 0.1, -0.02, Math.PI / 2 + 0.2, 0, Math.PI * 1.45, [1.35, 1, 1]);
    rib.rotation.order = 'XZY';
  }
  // spine plates
  for (let i = 0; i < 8; i++) add(new THREE.ConeGeometry(0.035, 0.24 - Math.abs(i - 4) * 0.02, 4), torso, 0, 0.2 + i * 0.12, 0.17, 1.0, 0, 0);
  // neck + head with split jaw
  const neck = enemy.neck = new THREE.Group(); neck.position.y = 1.15; torso.add(neck);
  add(new THREE.CylinderGeometry(0.05, 0.07, 0.18, 8), neck, 0, 0.03, 0);
  const skull = add(organic(new THREE.SphereGeometry(0.16, 28, 20), 0.04, 6, 4), neck, 0, 0.14, -0.1, 0.3, 0, 0, [0.85, 0.9, 2.2]);
  skull.userData.skull = true;
  for (let i = 0; i < 4; i++) add(new THREE.ConeGeometry(0.025, 0.3, 4), neck, (i % 2 ? 1 : -1) * 0.05 * (1 + (i >> 1)), 0.22, 0.12 + i * 0.03, -2.2, 0, (i % 2 ? -1 : 1) * 0.3);
  enemy.jaw = [];
  for (const s of [-1, 1]) {
    const j = new THREE.Group(); j.position.set(s * 0.05, 0.06, -0.15); neck.add(j);
    add(new THREE.ConeGeometry(0.035, 0.36, 5), j, 0, 0, -0.16, -Math.PI / 2, 0, 0, [1, 1, 0.6]);
    enemy.jaw.push({ g: j, s });
  }
  enemy.eyeMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(2.5, 2.5, 3.2) });
  enemy.eye = new THREE.Mesh(new THREE.BoxGeometry(0.018, 0.17, 0.02), enemy.eyeMat);
  enemy.eye.position.set(0, 0.15, -0.44); neck.add(enemy.eye);
  enemy.eyeGlow = glowSprite(glowTex, new THREE.Color(0.6, 0.6, 0.9), 0.16);
  enemy.eyeGlow.position.set(0, 0.15, -0.47); neck.add(enemy.eyeGlow);
  // arms with long claws (glowing tips)
  enemy.arms = [];
  const tipMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 2.6, 3.4) });
  enemy.tipMat = tipMat;
  for (const s of [-1, 1]) {
    const sh = new THREE.Group(); sh.position.set(s * 0.34, 0.95, 0); torso.add(sh);
    add(organic(new THREE.SphereGeometry(0.09, 14, 10), 0.04, 6, s), sh, 0, 0, 0);
    add(organic(new THREE.CapsuleGeometry(0.065, 0.5, 6, 10), 0.05, 9, s), sh, 0, -0.32, 0);
    const el = new THREE.Group(); el.position.y = -0.65; sh.add(el);
    add(organic(new THREE.CapsuleGeometry(0.05, 0.56, 6, 10), 0.04, 10, s + 3), el, 0, -0.32, 0);
    add(new THREE.ConeGeometry(0.03, 0.5, 4), el, s * 0.05, -0.2, 0.05, 0.2, 0, s * 0.15, [0.5, 1, 1]); // forearm blade
    const hand = new THREE.Group(); hand.position.y = -0.68; el.add(hand);
    for (let k = -1; k <= 1; k++) {
      const claw = add(new THREE.ConeGeometry(0.022, 0.62, 5), hand, k * 0.05, -0.3, 0, 0, 0, k * 0.12, [1, 1, 0.45]);
      const tip = new THREE.Mesh(new THREE.SphereGeometry(0.012, 6, 4), tipMat);
      tip.position.set(k * 0.05 + Math.sin(k * 0.12) * 0.3, -0.6, 0); hand.add(tip);
    }
    enemy.arms.push({ sh, el, s });
  }
  // digitigrade legs
  enemy.legs = [];
  for (const s of [-1, 1]) {
    const hip = new THREE.Group(); hip.position.set(s * 0.15, 0, 0); hips.add(hip);
    add(organic(new THREE.CapsuleGeometry(0.095, 0.42, 6, 10), 0.06, 7, s + 5), hip, 0, -0.3, 0, 0, 0, 0, [1, 1, 1.25]);
    add(new THREE.ConeGeometry(0.03, 0.2, 4), hip, 0, -0.62, 0.08, 1.9, 0, 0);
    const knee = new THREE.Group(); knee.position.y = -0.62; hip.add(knee);
    add(organic(new THREE.CapsuleGeometry(0.06, 0.46, 6, 10), 0.04, 9, s + 7), knee, 0, -0.3, 0);
    const ank = new THREE.Group(); ank.position.y = -0.62; knee.add(ank);
    add(new THREE.BoxGeometry(0.09, 0.05, 0.3), ank, 0, -0.03, -0.1);
    for (const k of [-1, 1]) add(new THREE.ConeGeometry(0.018, 0.14, 4), ank, k * 0.03, -0.04, -0.3, -Math.PI / 2, 0, 0);
    enemy.legs.push({ hip, knee, ank, s });
  }
  // back tendrils: hanging chains with secondary motion
  enemy.tendrils = [];
  for (const [x, z] of [[-0.12, 0.16], [0.12, 0.16], [0, 0.2]]) {
    let parent = torso;
    const chain = [];
    for (let i = 0; i < 7; i++) {
      const seg = new THREE.Group();
      seg.position.set(i === 0 ? x : 0, i === 0 ? 1.0 : -0.14, i === 0 ? z : 0);
      if (i === 0) seg.rotation.x = 2.4;
      add(new THREE.CapsuleGeometry(0.022 * (1 - i * 0.1), 0.1, 3, 6), seg, 0, -0.07, 0);
      parent.add(seg); chain.push(seg); parent = seg;
    }
    enemy.tendrils.push({ chain, ph: Math.random() * 6 });
  }
  return root;
}
