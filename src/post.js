import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { Pass } from 'three/addons/postprocessing/Pass.js';
import { GTAOPass } from 'three/addons/postprocessing/GTAOPass.js';

// AO that ignores sprites, particles and transparent / transmissive effects.
class GameAOPass extends GTAOPass {
  overrideVisibility() {
    const cache = this._visibilityCache;
    this.scene.traverse((o) => {
      cache.set(o, o.visible);
      const m = o.material;
      if (o.isPoints || o.isLine || o.isSprite || o.userData.noAO || (m && (m.transparent || m.transmission > 0 || m.isShaderMaterial))) o.visible = false;
    });
  }
}

// Renders the first-person katana on top of the world (own depth).
class ViewmodelPass extends Pass {
  constructor(scene, camera) {
    super();
    this.scene = scene; this.camera = camera;
    this.needsSwap = false;
  }
  render(renderer, writeBuffer, readBuffer) {
    const old = renderer.autoClear;
    renderer.autoClear = false;
    renderer.setRenderTarget(this.renderToScreen ? null : readBuffer);
    renderer.clearDepth();
    renderer.render(this.scene, this.camera);
    renderer.autoClear = old;
  }
}

const VisorShader = {
  uniforms: {
    tDiffuse: { value: null },
    time: { value: 0 },
    damage: { value: 0 },
    stat: { value: 0 },
    focus: { value: 0 },
    scan: { value: 0 },
    lowhp: { value: 0 },
    dash: { value: 0 },
    fade: { value: 0 },
    steam: { value: 0 },
    resolution: { value: new THREE.Vector2(1, 1) },
  },
  vertexShader: /* glsl */`
    varying vec2 vUv;
    void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }
  `,
  fragmentShader: /* glsl */`
    uniform sampler2D tDiffuse;
    uniform float time, damage, stat, focus, scan, lowhp, dash, fade, steam;
    uniform vec2 resolution;
    varying vec2 vUv;
    float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    void main() {
      vec2 uv = vUv;
      vec2 c = uv - 0.5;
      float r2 = dot(c, c);
      // slight visor barrel
      uv = 0.5 + c * (1.0 - 0.035 * r2);
      // visor condensation: beaded droplets refract the view (Metroid Prime steam)
      float drop = 0.0;
      if (steam > 0.01) {
        vec2 g = uv * vec2(resolution.x / resolution.y, 1.0) * 14.0;
        vec2 id = floor(g); vec2 f = fract(g) - 0.5;
        float rnd = hash(id);
        vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
        float d = length(f - o * 0.6);
        float rad = 0.12 + rnd * 0.22;
        drop = smoothstep(rad, rad * 0.6, d) * step(1.0 - steam, rnd + 0.15);
        uv += (f - o * 0.6) * drop * 0.05;
      }
      // static glitch on damage
      if (stat > 0.01) {
        float line = floor(uv.y * 90.0 + time * 40.0);
        float j = (hash(vec2(line, floor(time * 30.0))) - 0.5) * stat * 0.04;
        uv.x += j * step(0.6, hash(vec2(line * 1.3, floor(time * 20.0))));
      }
      // radial dash blur
      vec3 col;
      float ab = 0.0012 + damage * 0.01 + focus * 0.003 + dash * 0.006 + r2 * 0.006;
      if (dash > 0.01) {
        vec3 acc = vec3(0.0);
        for (int i = 0; i < 6; i++) {
          float k = 1.0 - float(i) * 0.012 * dash;
          vec2 u = 0.5 + (uv - 0.5) * k;
          acc += vec3(texture2D(tDiffuse, u + c * ab).r, texture2D(tDiffuse, u).g, texture2D(tDiffuse, u - c * ab).b);
        }
        col = acc / 6.0;
      } else {
        col = vec3(texture2D(tDiffuse, uv + c * ab).r, texture2D(tDiffuse, uv).g, texture2D(tDiffuse, uv - c * ab).b);
      }
      // fogged visor: milky blur where no droplet sits
      if (steam > 0.01) {
        vec3 b = vec3(0.0);
        for (int i = 0; i < 8; i++) {
          float a = float(i) * 0.785;
          b += texture2D(tDiffuse, uv + vec2(cos(a), sin(a)) * 0.012 * steam).rgb;
        }
        b = b / 8.0 + vec3(0.06, 0.07, 0.08) * steam;
        col = mix(col, b, steam * 0.85 * (1.0 - drop));
        col += drop * 0.04;
      }
      // focus: desaturate, violet tint
      float l = dot(col, vec3(0.299, 0.587, 0.114));
      col = mix(col, vec3(l) * vec3(0.85, 0.9, 1.25), focus * 0.65);
      // scan visor: amber monochrome tint
      col = mix(col, vec3(l * 1.3, l * 0.95, l * 0.5) + vec3(0.02, 0.012, 0.0), scan * 0.55);
      // grade: cool teal shadows, warm highlights, gentle lift so blacks stay readable
      float lum = dot(col, vec3(0.299, 0.587, 0.114));
      col += vec3(-0.004, 0.010, 0.016) * (1.0 - smoothstep(0.0, 0.35, lum));
      col *= mix(vec3(1.0), vec3(1.05, 1.0, 0.94), smoothstep(0.4, 1.0, lum));
      col = col * 0.97 + 0.012;
      // scanlines (subtle)
      col *= 1.0 - 0.035 * sin(uv.y * resolution.y * 1.5);
      // grain
      float g = hash(uv * resolution + fract(time * 13.7) * 100.0) - 0.5;
      col += g * (0.03 + stat * 0.25);
      // vignette
      float vig = smoothstep(0.85, 0.2, length(c * vec2(1.1, 1.0)));
      col *= mix(0.72, 1.0, vig);
      // damage / low hp red edges
      float edge = smoothstep(0.15, 0.75, length(c));
      col = mix(col, vec3(0.6, 0.02, 0.05), edge * (damage * 0.7 + lowhp * (0.25 + 0.15 * sin(time * 6.0))));
      col *= 1.0 - fade;
      gl_FragColor = vec4(col, 1.0);
    }
  `,
};

export function createPipeline(canvas, scene, camera, vmScene, vmCamera) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
  renderer.setPixelRatio(1);
  renderer.info.autoReset = true;
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.35;

  // multisampled HDR target: MSAA for clean edges on the geometry
  const rt = new THREE.WebGLRenderTarget(window.innerWidth, window.innerHeight, { type: THREE.HalfFloatType, samples: 4 });
  const composer = new EffectComposer(renderer, rt);
  composer.addPass(new RenderPass(scene, camera));
  const ao = new GameAOPass(scene, camera, window.innerWidth, window.innerHeight);
  ao.blendIntensity = 0.85;
  ao.updateGtaoMaterial({ radius: 0.9, distanceExponent: 1.4, thickness: 1.6, scale: 1.25, samples: 12, distanceFallOff: 1.0, screenSpaceRadius: false });
  ao.updatePdMaterial({ lumaPhi: 10, depthPhi: 2, normalPhi: 3, radius: 6, rings: 2, samples: 12 });
  composer.addPass(ao);
  composer.addPass(new ViewmodelPass(vmScene, vmCamera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(window.innerWidth, window.innerHeight), 0.85, 0.55, 0.72);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());
  const visor = new ShaderPass(VisorShader);
  composer.addPass(visor);

  const resize = () => {
    const w = window.innerWidth, h = window.innerHeight;
    renderer.setSize(w, h);
    composer.setPixelRatio(renderer.getPixelRatio());
    composer.setSize(w, h);
    // AO at half resolution: big saving, the denoiser hides it
    ao.setSize(Math.floor(w * renderer.getPixelRatio() * 0.5), Math.floor(h * renderer.getPixelRatio() * 0.5));
    camera.aspect = w / h; camera.updateProjectionMatrix();
    vmCamera.aspect = w / h; vmCamera.updateProjectionMatrix();
    visor.uniforms.resolution.value.set(w, h);
  };
  window.addEventListener('resize', resize);
  resize();

  // quality presets; dynamic resolution keeps ~60fps inside each preset's pixel-ratio range
  const QUALITY = {
    ULTRA:  { ao: true,  msaa: 4, bloom: true, minPR: 1.0,  maxPR: 2 },
    HIGH:   { ao: true,  msaa: 4, bloom: true, minPR: 0.75, maxPR: 2 },
    MEDIUM: { ao: false, msaa: 2, bloom: true, minPR: 0.6,  maxPR: 1.25 },
  };
  let maxPR = 2, minPR = 0.75;
  const setQuality = (name) => {
    const q = QUALITY[name];
    ao.enabled = q.ao; bloom.enabled = q.bloom;
    for (const t of [composer.renderTarget1, composer.renderTarget2]) { t.samples = q.msaa; t.dispose(); }
    minPR = q.minPR; maxPR = Math.min(window.devicePixelRatio, q.maxPR);
    const pr = THREE.MathUtils.clamp(renderer.getPixelRatio(), minPR, maxPR);
    renderer.setPixelRatio(pr); resize();
  };
  let acc = 0, frames = 0;
  const adapt = (dt) => {
    acc += dt; frames++;
    if (acc < 1.5) return;
    const ms = (acc / frames) * 1000;
    acc = 0; frames = 0;
    const pr = renderer.getPixelRatio();
    let next = pr;
    if (ms > 18.5 && pr > minPR) next = Math.max(minPR, pr - 0.15);
    else if (ms < 13 && pr < maxPR) next = Math.min(maxPR, pr + 0.1);
    if (Math.abs(next - pr) > 0.01) { renderer.setPixelRatio(next); resize(); }
  };

  return { renderer, composer, bloom, ao, visor: visor.uniforms, adapt, resize, setQuality, QUALITY };
}
