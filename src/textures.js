// Procedural canvas textures — no external assets.
import * as THREE from 'three';

function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

function canvas(w, h) {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  return [c, c.getContext('2d')];
}

function toTex(c, srgb = true, repeat = true) {
  const t = new THREE.CanvasTexture(c);
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  return t;
}

function grime(ctx, w, h, r, amount, dark = true) {
  for (let i = 0; i < amount; i++) {
    const x = r() * w, y = r() * h, s = 2 + r() * 40;
    const g = ctx.createRadialGradient(x, y, 0, x, y, s);
    const a = 0.02 + r() * 0.06;
    g.addColorStop(0, dark ? `rgba(0,0,0,${a})` : `rgba(255,255,255,${a * 0.6})`);
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g;
    ctx.fillRect(x - s, y - s, s * 2, s * 2);
  }
}

// ---------------------------------------------------------------------------- PBR pipeline
// Draw albedo / height / roughness / metalness layers with the canvas API, then derive
// a tangent-space normal map and cavity AO from the height layer. Output:
// { map, normalMap, ormMap } where orm = R: AO, G: roughness, B: metalness.
function layers(S) {
  const L = {};
  for (const k of ['alb', 'hgt', 'rgh', 'mtl']) { const [c, x] = canvas(S, S); L[k] = { c, x }; }
  return L;
}

function bakePBR(L, S, { normalStrength = 2.5, aoStrength = 2.2 } = {}) {
  const h = L.hgt.x.getImageData(0, 0, S, S).data;
  const r = L.rgh.x.getImageData(0, 0, S, S).data;
  const m = L.mtl.x.getImageData(0, 0, S, S).data;
  const H = new Float32Array(S * S);
  for (let i = 0; i < S * S; i++) H[i] = h[i * 4] / 255;
  // integral image for a cheap box blur (cavity AO)
  const I = new Float64Array((S + 1) * (S + 1));
  for (let y = 0; y < S; y++) {
    let row = 0;
    for (let x = 0; x < S; x++) { row += H[y * S + x]; I[(y + 1) * (S + 1) + x + 1] = I[y * (S + 1) + x + 1] + row; }
  }
  const R = 7;
  const blur = (x, y) => {
    const x0 = Math.max(0, x - R), y0 = Math.max(0, y - R), x1 = Math.min(S, x + R + 1), y1 = Math.min(S, y + R + 1);
    return (I[y1 * (S + 1) + x1] - I[y0 * (S + 1) + x1] - I[y1 * (S + 1) + x0] + I[y0 * (S + 1) + x0]) / ((x1 - x0) * (y1 - y0));
  };
  const [nc, nx] = canvas(S, S);
  const [oc, ox] = canvas(S, S);
  const N = nx.createImageData(S, S), O = ox.createImageData(S, S);
  const at = (x, y) => H[((y + S) % S) * S + ((x + S) % S)];
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const i = y * S + x;
    let dx = -(at(x + 1, y) - at(x - 1, y)) * normalStrength;
    let dy = (at(x, y + 1) - at(x, y - 1)) * normalStrength;
    const l = Math.hypot(dx, dy, 1);
    N.data[i * 4] = (dx / l * 0.5 + 0.5) * 255;
    N.data[i * 4 + 1] = (dy / l * 0.5 + 0.5) * 255;
    N.data[i * 4 + 2] = (1 / l * 0.5 + 0.5) * 255;
    N.data[i * 4 + 3] = 255;
    const ao = Math.max(0.25, Math.min(1, 1 - (blur(x, y) - H[i]) * aoStrength));
    O.data[i * 4] = ao * 255;
    O.data[i * 4 + 1] = r[i * 4];
    O.data[i * 4 + 2] = m[i * 4];
    O.data[i * 4 + 3] = 255;
  }
  nx.putImageData(N, 0, 0); ox.putImageData(O, 0, 0);
  return { map: toTex(L.alb.c), normalMap: toTex(nc, false), ormMap: toTex(oc, false) };
}

function fillAll(L, a, h, rg, mt) {
  if (a) { L.alb.x.fillStyle = a; } if (h) { L.hgt.x.fillStyle = h; } if (rg) { L.rgh.x.fillStyle = rg; } if (mt) { L.mtl.x.fillStyle = mt; }
}
const gray = (v) => `rgb(${v | 0},${v | 0},${v | 0})`;

function noiseSpeckle(L, S, r, n, { a = 0.05, rough = 0 } = {}) {
  for (let i = 0; i < n; i++) {
    const x = r() * S, y = r() * S, s = 0.5 + r() * 1.8;
    L.alb.x.fillStyle = r() < 0.5 ? `rgba(0,0,0,${a})` : `rgba(255,255,255,${a * 0.6})`;
    L.alb.x.fillRect(x, y, s, s);
    if (rough) { L.rgh.x.fillStyle = gray(128 + (r() - 0.5) * rough); L.rgh.x.fillRect(x, y, s, s); }
  }
}

function grimeBlobs(L, S, r, n, { dark = 0.08, rough = 220 } = {}) {
  for (let i = 0; i < n; i++) {
    const x = r() * S, y = r() * S, s = 10 + r() * 90;
    for (const [ctx, col] of [[L.alb.x, `rgba(8,6,4,${dark * (0.3 + r())})`], [L.rgh.x, `rgba(${rough},${rough},${rough},${0.15 + r() * 0.25})`]]) {
      const g = ctx.createRadialGradient(x, y, 0, x, y, s);
      g.addColorStop(0, col); g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g; ctx.fillRect(x - s, y - s, s * 2, s * 2);
    }
  }
}

function stencil(L, x, y, text, size, color, rot = 0) {
  for (const [ctx, col] of [[L.alb.x, color], [L.rgh.x, 'rgba(200,200,200,0.8)']]) {
    ctx.save(); ctx.translate(x, y); ctx.rotate(rot);
    ctx.font = `bold ${size}px "Share Tech Mono", "Menlo", monospace`;
    ctx.fillStyle = col; ctx.fillText(text, 0, 0);
    ctx.restore();
  }
}

const STENCILS = ['C-04', 'MAINT 7', 'KRG-9', 'NO STEP', 'SECTOR C', '04-B', 'VENT 12', '▲ AUX', 'HAZ 3', '黒鉄', '環C-4', 'PRESS.'];

// Hard-surface wall panelling
export function panelPBR(seed = 1, base = [44, 48, 54], { S = 1024, wear = 1, decals = true, lights = false } = {}) {
  const r = rng(seed);
  const L = layers(S);
  const [br, bg, bb] = base;
  L.alb.x.fillStyle = `rgb(${br},${bg},${bb})`; L.alb.x.fillRect(0, 0, S, S);
  L.hgt.x.fillStyle = gray(90); L.hgt.x.fillRect(0, 0, S, S);
  L.rgh.x.fillStyle = gray(150); L.rgh.x.fillRect(0, 0, S, S);
  L.mtl.x.fillStyle = gray(160); L.mtl.x.fillRect(0, 0, S, S);

  const rects = [];
  const G = 32;
  const split = (x, y, w, h, d) => {
    if (d > 4 || (d > 1 && r() < 0.28) || w < 96 || h < 96) { rects.push([x, y, w, h]); return; }
    if (w > h ? r() < 0.75 : r() < 0.25) {
      const k = Math.max(G, Math.round((0.3 + r() * 0.4) * w / G) * G);
      split(x, y, k, h, d + 1); split(x + k, y, w - k, h, d + 1);
    } else {
      const k = Math.max(G, Math.round((0.3 + r() * 0.4) * h / G) * G);
      split(x, y, w, k, d + 1); split(x, y + k, w, h - k, d + 1);
    }
  };
  split(0, 0, S, S, 0);

  for (const [x, y, w, h] of rects) {
    const v = (r() - 0.5) * 16;
    const tint = r() < 0.12 ? [12, -2, -10] : r() < 0.1 ? [-6, 0, 8] : [0, 0, 0];
    const kind = r();
    // seam groove
    L.hgt.x.fillStyle = gray(20); L.hgt.x.fillRect(x, y, w, h);
    L.alb.x.fillStyle = 'rgb(8,9,11)'; L.alb.x.fillRect(x, y, w, h);
    // bevelled plate
    const inset = 3;
    for (let k = 0; k < 6; k++) {
      L.hgt.x.fillStyle = gray(110 + k * 18);
      L.hgt.x.fillRect(x + inset + k, y + inset + k, w - (inset + k) * 2, h - (inset + k) * 2);
    }
    L.alb.x.fillStyle = `rgb(${br + v + tint[0]},${bg + v + tint[1]},${bb + v + tint[2]})`;
    L.alb.x.fillRect(x + inset, y + inset, w - inset * 2, h - inset * 2);
    const rough = 110 + r() * 80;
    L.rgh.x.fillStyle = gray(rough); L.rgh.x.fillRect(x + inset, y + inset, w - inset * 2, h - inset * 2);
    L.mtl.x.fillStyle = gray(kind < 0.15 ? 60 : 150 + r() * 80); L.mtl.x.fillRect(x + inset, y + inset, w - inset * 2, h - inset * 2);
    // edge wear: bright, polished rim
    if (wear) {
      L.alb.x.strokeStyle = `rgba(150,160,170,${0.08 + r() * 0.1})`; L.alb.x.lineWidth = 2;
      L.alb.x.strokeRect(x + inset + 1, y + inset + 1, w - inset * 2 - 2, h - inset * 2 - 2);
      L.rgh.x.strokeStyle = gray(70); L.rgh.x.lineWidth = 2;
      L.rgh.x.strokeRect(x + inset + 1, y + inset + 1, w - inset * 2 - 2, h - inset * 2 - 2);
    }
    // rivets / bolts
    if (w > 80 && h > 80 && r() < 0.65) {
      for (const [px, py] of [[x + 14, y + 14], [x + w - 14, y + 14], [x + 14, y + h - 14], [x + w - 14, y + h - 14]]) {
        const g = L.hgt.x.createRadialGradient(px, py, 0, px, py, 5);
        g.addColorStop(0, gray(255)); g.addColorStop(1, gray(150));
        L.hgt.x.fillStyle = g; L.hgt.x.beginPath(); L.hgt.x.arc(px, py, 5, 0, 7); L.hgt.x.fill();
        L.alb.x.fillStyle = 'rgba(120,125,130,0.5)'; L.alb.x.beginPath(); L.alb.x.arc(px, py, 4, 0, 7); L.alb.x.fill();
        L.rgh.x.fillStyle = gray(80); L.rgh.x.beginPath(); L.rgh.x.arc(px, py, 4, 0, 7); L.rgh.x.fill();
      }
    }
    // inset vent slats
    if (kind > 0.82 && w > 120 && h > 70) {
      const n = Math.floor((h - 40) / 12);
      for (let k = 0; k < n; k++) {
        const yy = y + 20 + k * 12;
        const g = L.hgt.x.createLinearGradient(0, yy, 0, yy + 9);
        g.addColorStop(0, gray(40)); g.addColorStop(1, gray(150));
        L.hgt.x.fillStyle = g; L.hgt.x.fillRect(x + 20, yy, w - 40, 9);
        L.alb.x.fillStyle = 'rgba(0,0,0,0.55)'; L.alb.x.fillRect(x + 20, yy, w - 40, 4);
      }
    }
    // recessed service hatch with handle
    else if (kind > 0.7 && w > 140 && h > 140) {
      const hx = x + w * 0.2, hy = y + h * 0.2, hw = w * 0.6, hh = h * 0.6;
      L.hgt.x.fillStyle = gray(60); L.hgt.x.fillRect(hx, hy, hw, hh);
      L.hgt.x.fillStyle = gray(100); L.hgt.x.fillRect(hx + 4, hy + 4, hw - 8, hh - 8);
      L.hgt.x.fillStyle = gray(200); L.hgt.x.fillRect(hx + hw / 2 - 20, hy + hh / 2 - 4, 40, 8);
      L.alb.x.fillStyle = 'rgba(0,0,0,0.3)'; L.alb.x.fillRect(hx, hy, hw, 3);
    }
    // cable conduit
    else if (kind > 0.6 && h > 60) {
      const cy = y + h / 2;
      for (let k = 0; k < 3; k++) {
        const yy = cy - 14 + k * 11;
        const g = L.hgt.x.createLinearGradient(0, yy - 5, 0, yy + 5);
        g.addColorStop(0, gray(120)); g.addColorStop(0.5, gray(230)); g.addColorStop(1, gray(120));
        L.hgt.x.fillStyle = g; L.hgt.x.fillRect(x + 8, yy - 5, w - 16, 10);
        L.alb.x.fillStyle = ['#1a1a1c', '#3a2a14', '#14262a'][k]; L.alb.x.fillRect(x + 8, yy - 4, w - 16, 8);
        L.mtl.x.fillStyle = gray(10); L.mtl.x.fillRect(x + 8, yy - 5, w - 16, 10);
        L.rgh.x.fillStyle = gray(120); L.rgh.x.fillRect(x + 8, yy - 5, w - 16, 10);
      }
    }
    // hazard stripes
    if (r() < 0.05) {
      L.alb.x.save(); L.alb.x.beginPath(); L.alb.x.rect(x + 6, y + 6, w - 12, Math.min(40, h - 12)); L.alb.x.clip();
      for (let k = -60; k < w; k += 28) {
        L.alb.x.fillStyle = 'rgba(200,150,30,0.55)';
        L.alb.x.beginPath(); L.alb.x.moveTo(x + k, y + 46); L.alb.x.lineTo(x + k + 14, y + 46); L.alb.x.lineTo(x + k + 54, y); L.alb.x.lineTo(x + k + 40, y); L.alb.x.fill();
      }
      L.alb.x.restore();
    }
    // stencils
    if (decals && r() < 0.18 && w > 140) {
      stencil(L, x + 16, y + h - 16, STENCILS[Math.floor(r() * STENCILS.length)], 18 + r() * 14, `rgba(${r() < 0.5 ? '210,210,200' : '220,160,60'},${0.35 + r() * 0.3})`);
    }
    // inset indicator lights (emissive handled separately; here just a lens)
    if (lights && r() < 0.15) {
      const lx = x + w - 26, ly = y + 24;
      L.alb.x.fillStyle = r() < 0.5 ? '#2a6a70' : '#702a20'; L.alb.x.fillRect(lx, ly, 10, 4);
    }
  }
  // scratches: bright metal, low roughness
  for (let i = 0; i < 160 * wear; i++) {
    const x = r() * S, y = r() * S, a = r() * Math.PI, l = 6 + r() * 40;
    for (const [ctx, col] of [[L.alb.x, `rgba(170,175,180,${0.06 + r() * 0.12})`], [L.rgh.x, 'rgba(60,60,60,0.6)']]) {
      ctx.strokeStyle = col; ctx.lineWidth = 0.8;
      ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); ctx.stroke();
    }
  }
  // drips & streaks running down
  for (let i = 0; i < 70; i++) {
    const x = r() * S, y = r() * S, l = 30 + r() * 200;
    const g = L.alb.x.createLinearGradient(x, y, x, y + l);
    g.addColorStop(0, `rgba(10,8,5,${0.15 + r() * 0.2})`); g.addColorStop(1, 'rgba(0,0,0,0)');
    L.alb.x.fillStyle = g; L.alb.x.fillRect(x, y, 1 + r() * 4, l);
  }
  grimeBlobs(L, S, r, 110);
  noiseSpeckle(L, S, r, 9000, { a: 0.05, rough: 60 });
  return bakePBR(L, S);
}

// Floor plates, grating and puddles
export function floorPBR(seed = 7, { S = 1024, puddles = 0.6 } = {}) {
  const r = rng(seed);
  const L = layers(S);
  L.alb.x.fillStyle = '#16191d'; L.alb.x.fillRect(0, 0, S, S);
  L.hgt.x.fillStyle = gray(40); L.hgt.x.fillRect(0, 0, S, S);
  L.rgh.x.fillStyle = gray(160); L.rgh.x.fillRect(0, 0, S, S);
  L.mtl.x.fillStyle = gray(200); L.mtl.x.fillRect(0, 0, S, S);
  const P = 256;
  for (let y = 0; y < S; y += P) for (let x = 0; x < S; x += P) {
    const v = (r() - 0.5) * 10;
    const k = r();
    for (let b = 0; b < 4; b++) { L.hgt.x.fillStyle = gray(120 + b * 25); L.hgt.x.fillRect(x + 3 + b, y + 3 + b, P - 6 - b * 2, P - 6 - b * 2); }
    L.alb.x.fillStyle = `rgb(${32 + v},${35 + v},${39 + v})`; L.alb.x.fillRect(x + 3, y + 3, P - 6, P - 6);
    L.rgh.x.fillStyle = gray(120 + r() * 60); L.rgh.x.fillRect(x + 3, y + 3, P - 6, P - 6);
    if (k < 0.4) {
      // open grating: deep slots
      for (let s = 16; s < P - 16; s += 14) {
        L.hgt.x.fillStyle = gray(0); L.hgt.x.fillRect(x + 16, y + s, P - 32, 7);
        L.alb.x.fillStyle = 'rgba(0,0,0,0.92)'; L.alb.x.fillRect(x + 16, y + s, P - 32, 7);
        L.rgh.x.fillStyle = gray(255); L.rgh.x.fillRect(x + 16, y + s, P - 32, 7);
      }
    } else if (k < 0.8) {
      // diamond tread plate
      for (let yy = 12; yy < P - 12; yy += 18) for (let xx = 12 + ((yy / 18) % 2 ? 9 : 0); xx < P - 12; xx += 18) {
        L.hgt.x.save(); L.hgt.x.translate(x + xx, y + yy); L.hgt.x.rotate(((xx + yy) / 18) % 2 ? 0.78 : -0.78);
        L.hgt.x.fillStyle = gray(225); L.hgt.x.fillRect(-6, -1.5, 12, 3); L.hgt.x.restore();
        L.alb.x.fillStyle = 'rgba(255,255,255,0.05)'; L.alb.x.fillRect(x + xx - 4, y + yy - 1, 8, 2);
      }
    } else {
      // painted guide plate
      L.alb.x.fillStyle = 'rgba(190,140,40,0.25)';
      for (let s = -P; s < P; s += 40) {
        L.alb.x.beginPath(); L.alb.x.moveTo(x + s, y + P - 3); L.alb.x.lineTo(x + s + 20, y + P - 3); L.alb.x.lineTo(x + s + 20 + P, y + 3); L.alb.x.lineTo(x + s + P, y + 3); L.alb.x.fill();
      }
      L.rgh.x.fillStyle = gray(200); L.rgh.x.fillRect(x + 3, y + 3, P - 6, P - 6);
      L.mtl.x.fillStyle = gray(30); L.mtl.x.fillRect(x + 3, y + 3, P - 6, P - 6);
    }
    // corner bolts
    for (const [px, py] of [[x + 10, y + 10], [x + P - 10, y + 10], [x + 10, y + P - 10], [x + P - 10, y + P - 10]]) {
      L.hgt.x.fillStyle = gray(240); L.hgt.x.beginPath(); L.hgt.x.arc(px, py, 4, 0, 7); L.hgt.x.fill();
    }
  }
  for (let i = 0; i < 260; i++) {
    const x = r() * S, y = r() * S, a = r() * Math.PI, l = 10 + r() * 60;
    L.alb.x.strokeStyle = `rgba(160,165,170,${0.05 + r() * 0.1})`; L.alb.x.lineWidth = 1;
    L.alb.x.beginPath(); L.alb.x.moveTo(x, y); L.alb.x.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l); L.alb.x.stroke();
  }
  grimeBlobs(L, S, r, 160, { dark: 0.12, rough: 230 });
  // puddles: dark, mirror-smooth
  for (let i = 0; i < 9 * puddles; i++) {
    const x = r() * S, y = r() * S, s = 30 + r() * 110;
    const sx = 0.6 + r() * 0.8;
    for (const [ctx, col] of [[L.alb.x, 'rgba(4,6,8,0.55)'], [L.rgh.x, 'rgba(8,8,8,0.95)'], [L.hgt.x, 'rgba(70,70,70,0.6)']]) {
      ctx.save(); ctx.translate(x, y); ctx.scale(sx, 1);
      const g = ctx.createRadialGradient(0, 0, 0, 0, 0, s);
      g.addColorStop(0, col); g.addColorStop(0.7, col); g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(0, 0, s, 0, 7); ctx.fill();
      ctx.restore();
    }
  }
  noiseSpeckle(L, S, r, 12000, { a: 0.06, rough: 80 });
  return bakePBR(L, S, { normalStrength: 3 });
}

// Small mechanical panelling for drones / props (512)
export function mechPBR(seed = 3, base = [70, 74, 82]) {
  return panelPBR(seed, base, { S: 512, wear: 0.6, decals: false, lights: true });
}

// Organic / chitin surface: cellular bumps and fine pores
export function skinPBR(seed = 5, { S = 512, base = [24, 18, 30], rough = 90, metal = 40, cells = 140 } = {}) {
  const r = rng(seed);
  const L = layers(S);
  L.alb.x.fillStyle = `rgb(${base[0]},${base[1]},${base[2]})`; L.alb.x.fillRect(0, 0, S, S);
  L.hgt.x.fillStyle = gray(60); L.hgt.x.fillRect(0, 0, S, S);
  L.rgh.x.fillStyle = gray(rough); L.rgh.x.fillRect(0, 0, S, S);
  L.mtl.x.fillStyle = gray(metal); L.mtl.x.fillRect(0, 0, S, S);
  for (let i = 0; i < cells; i++) {
    const x = r() * S, y = r() * S, s = 10 + r() * 34;
    for (const [dx, dy] of [[0, 0], [S, 0], [-S, 0], [0, S], [0, -S]]) {
      const g = L.hgt.x.createRadialGradient(x + dx, y + dy, 0, x + dx, y + dy, s);
      g.addColorStop(0, gray(200)); g.addColorStop(0.8, gray(120)); g.addColorStop(1, 'rgba(60,60,60,0)');
      L.hgt.x.fillStyle = g; L.hgt.x.beginPath(); L.hgt.x.arc(x + dx, y + dy, s, 0, 7); L.hgt.x.fill();
      const v = (r() - 0.5) * 20;
      L.alb.x.fillStyle = `rgba(${base[0] + 20 + v},${base[1] + 10 + v},${base[2] + 25 + v},0.35)`;
      L.alb.x.beginPath(); L.alb.x.arc(x + dx, y + dy, s * 0.7, 0, 7); L.alb.x.fill();
    }
  }
  // fine pores / ridges
  for (let i = 0; i < 6000; i++) {
    const x = r() * S, y = r() * S;
    L.hgt.x.fillStyle = gray(30); L.hgt.x.fillRect(x, y, 1.5, 1.5);
  }
  for (let i = 0; i < 90; i++) {
    let x = r() * S, y = r() * S, a = r() * 6.28;
    L.hgt.x.strokeStyle = gray(30); L.hgt.x.lineWidth = 2;
    L.hgt.x.beginPath(); L.hgt.x.moveTo(x, y);
    for (let k = 0; k < 8; k++) { a += (r() - 0.5) * 0.8; x += Math.cos(a) * 9; y += Math.sin(a) * 9; L.hgt.x.lineTo(x, y); }
    L.hgt.x.stroke();
  }
  return bakePBR(L, S, { normalStrength: 4, aoStrength: 3 });
}

// Katana blade: polished steel with a wavy hamon temper line toward the edge (U across width, V along length)
export function bladeTextures() {
  const W = 64, H = 1024, r = rng(17);
  const [c, x] = canvas(W, H);
  const [rc, rx] = canvas(W, H);
  const g = x.createLinearGradient(0, 0, W, 0);
  g.addColorStop(0, '#d8dee6'); g.addColorStop(0.45, '#c2c9d2'); g.addColorStop(1, '#6a7380');
  x.fillStyle = g; x.fillRect(0, 0, W, H);
  rx.fillStyle = gray(70); rx.fillRect(0, 0, W, H);
  // hamon: cloudy white band with wavy boundary
  x.beginPath(); x.moveTo(0, 0);
  for (let y = 0; y <= H; y += 8) x.lineTo(W * (0.32 + Math.sin(y * 0.045) * 0.06 + Math.sin(y * 0.13) * 0.03 + (r() - 0.5) * 0.02), y);
  x.lineTo(0, H); x.closePath();
  x.fillStyle = 'rgba(245,248,255,0.55)'; x.fill();
  rx.fillStyle = gray(45); rx.fillRect(0, 0, W * 0.3, H);
  // shinogi ridge line
  x.fillStyle = 'rgba(40,46,56,0.6)'; x.fillRect(W * 0.62, 0, 2, H);
  // micro scratches along length
  for (let i = 0; i < 300; i++) {
    const xx = r() * W, yy = r() * H;
    x.fillStyle = `rgba(255,255,255,${r() * 0.08})`; x.fillRect(xx, yy, 0.6, 6 + r() * 30);
  }
  return { map: toTex(c, true, false), roughnessMap: toTex(rc, false, false) };
}

// Hologram text panel
export function hologramTexture(lines, color = '#6ff', { W = 512, H = 256 } = {}) {
  const [c, x] = canvas(W, H);
  x.fillStyle = '#000'; x.fillRect(0, 0, W, H);
  x.strokeStyle = color; x.lineWidth = 3; x.globalAlpha = 0.6;
  x.strokeRect(6, 6, W - 12, H - 12);
  x.beginPath(); x.moveTo(6, 40); x.lineTo(60, 40); x.moveTo(W - 60, H - 40); x.lineTo(W - 6, H - 40); x.stroke();
  x.globalAlpha = 1;
  x.fillStyle = color; x.shadowColor = color; x.shadowBlur = 14;
  lines.forEach((l, i) => {
    x.font = i === 0 ? `bold ${l.size || 64}px "Hiragino Sans", "Rajdhani", sans-serif` : `${l.size || 26}px "Share Tech Mono", monospace`;
    x.textAlign = 'center';
    x.fillText(l.text, W / 2, l.y);
  });
  return toTex(c, true, false);
}

// Lit windows for distant towers
export function windowTexture(seed, hue) {
  const W = 128, H = 512, r = rng(seed);
  const [c, ctx] = canvas(W, H);
  ctx.fillStyle = '#020306'; ctx.fillRect(0, 0, W, H);
  const cols = 8, rows = 48;
  const palette = [
    [255, 190, 120], [120, 230, 255], [255, 90, 200], [190, 160, 255], [255, 240, 220],
  ];
  const main = palette[hue % palette.length];
  for (let y = 0; y < rows; y++) {
    const floorLit = r() < 0.55;
    for (let x = 0; x < cols; x++) {
      if (!floorLit || r() < 0.55) continue;
      const col = r() < 0.8 ? main : palette[Math.floor(r() * palette.length)];
      const a = 0.25 + r() * 0.75;
      ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},${a})`;
      ctx.fillRect(x * (W / cols) + 3, y * (H / rows) + 2, W / cols - 6, H / rows - 5);
    }
  }
  // occasional vertical neon strip
  if (r() < 0.5) {
    const col = palette[Math.floor(r() * 3) + 1];
    ctx.fillStyle = `rgba(${col[0]},${col[1]},${col[2]},0.9)`;
    ctx.fillRect(r() < 0.5 ? 0 : W - 3, 0, 3, H);
  }
  const t = toTex(c);
  t.magFilter = THREE.NearestFilter;
  return t;
}

// Neon sign with abstract glyphs
export function neonTexture(seed, color) {
  const W = 256, H = 64, r = rng(seed);
  const [c, ctx] = canvas(W, H);
  ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H);
  ctx.strokeStyle = color; ctx.lineWidth = 4; ctx.lineCap = 'square';
  ctx.shadowColor = color; ctx.shadowBlur = 10;
  const n = 4 + Math.floor(r() * 4);
  const gw = (W - 20) / n;
  for (let i = 0; i < n; i++) {
    const x0 = 10 + i * gw + 4, x1 = x0 + gw - 10, y0 = 12, y1 = H - 12;
    ctx.beginPath();
    const strokes = 2 + Math.floor(r() * 3);
    for (let s = 0; s < strokes; s++) {
      const pts = [[x0, y0], [x1, y0], [x0, y1], [x1, y1], [(x0 + x1) / 2, y0], [(x0 + x1) / 2, y1], [x0, (y0 + y1) / 2], [x1, (y0 + y1) / 2]];
      const a = pts[Math.floor(r() * pts.length)], b = pts[Math.floor(r() * pts.length)];
      ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]);
    }
    ctx.stroke();
  }
  return toTex(c, true, false);
}

// Console screen with fake text lines
export function screenTexture(seed, color = '#5ff') {
  const W = 256, H = 160, r = rng(seed);
  const [c, ctx] = canvas(W, H);
  ctx.fillStyle = '#010608'; ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = color;
  for (let y = 10; y < H - 10; y += 9) {
    let x = 10;
    while (x < W - 20 && r() < 0.93) {
      const w = 4 + r() * 26;
      ctx.globalAlpha = 0.3 + r() * 0.6;
      ctx.fillRect(x, y, w, 4);
      x += w + 5;
    }
  }
  ctx.globalAlpha = 1;
  ctx.strokeStyle = color; ctx.strokeRect(4, 4, W - 8, H - 8);
  return toTex(c, true, false);
}

export function glowTexture() {
  const S = 64;
  const [c, ctx] = canvas(S, S);
  const g = ctx.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.25, 'rgba(255,255,255,0.6)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
  return toTex(c, false, false);
}

export function planetTexture() {
  const W = 512, H = 256, r = rng(99);
  const [c, ctx] = canvas(W, H);
  const g = ctx.createLinearGradient(0, 0, 0, H);
  g.addColorStop(0, '#2a3550'); g.addColorStop(0.5, '#4a5f7a'); g.addColorStop(1, '#1a2238');
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  for (let i = 0; i < 70; i++) {
    const y = r() * H, h = 2 + r() * 14;
    ctx.fillStyle = `rgba(${150 + r() * 80},${160 + r() * 60},${190 + r() * 60},${0.05 + r() * 0.12})`;
    ctx.fillRect(0, y, W, h);
  }
  grime(ctx, W, H, r, 120, false);
  return toTex(c, true, false);
}
