import * as THREE from 'three';
import { buildCrawler, buildSentinel, buildStalker, creatureTime } from './creatures.js';

const BODY_Y = 0.55;

const _a = new THREE.Vector3(), _b = new THREE.Vector3(), _c = new THREE.Vector3();
const yawTo = (dx, dz) => Math.atan2(-dx, -dz);
function lerpAngle(a, b, k) {
  let d = b - a;
  while (d > Math.PI) d -= Math.PI * 2;
  while (d < -Math.PI) d += Math.PI * 2;
  return a + d * k;
}

// ============================================================================ base
class Enemy {
  constructor(mgr, type, pos) {
    this.mgr = mgr; this.game = mgr.game; this.type = type;
    this.pos = pos.clone(); this.vel = new THREE.Vector3();
    this.mesh = new THREE.Group();
    this.mesh.position.copy(pos);
    this.game.scene.add(this.mesh);
    this.alive = true; this.dormant = false; this.cloaked = false;
    this.state = 'idle'; this.stateT = 0; this.flashT = 0; this.deathT = 0;
    this.radius = 0.5; this.centerY = 0.5; this.facing = 0;
    this.flashMats = [];
    this.encounter = null;
    this._center = new THREE.Vector3();
    this.removeMe = false;
  }
  center() { return this._center.set(this.pos.x, this.pos.y + this.centerY, this.pos.z); }
  setState(s) { this.state = s; this.stateT = 0; }
  mat(params) {
    const m = new THREE.MeshStandardMaterial(params);
    this.flashMats.push(m);
    return m;
  }
  takeDamage(dmg, dir, kind) {
    if (!this.alive || this.dormant) return;
    this.hp -= dmg;
    this.flashT = 0.1;
    this.onHurt(dmg, dir, kind);
    if (this.hp <= 0) this.die(dir);
  }
  onHurt() {}
  stagger() {}
  die(dir) {
    this.alive = false; this.setState('dead');
    this.onDie(dir);
    const g = this.game, c = this.center().clone();
    const drops = this.dropCount ?? 2;
    for (let i = 0; i < drops; i++) g.fx.pickup(c, Math.random() < 0.7 ? 'hp' : 'ki');
    this.mgr.onDeath(this);
  }
  onDie() {}
  updateFlash(dt) {
    this.flashT = Math.max(0, this.flashT - dt);
    const k = this.flashT > 0 ? 2.5 : 0;
    for (const m of this.flashMats) m.emissiveIntensity = k > 0 ? k : (m.userData.baseEI || 0);
  }
  playerDist() {
    const p = this.game.player.position;
    return Math.hypot(p.x - this.pos.x, p.z - this.pos.z);
  }
  dispose() { this.game.scene.remove(this.mesh); }
}

// ============================================================================ Crawler
class Crawler extends Enemy {
  constructor(mgr, pos, opts = {}) {
    super(mgr, 'crawler', pos);
    this.hp = this.maxHp = 34;
    this.radius = 0.55; this.centerY = 0.45;
    this.organic = true; this.dropCount = 1;
    this.scanInfo = { title: 'CRAWLER // BLOOM-THRALL', text: 'Maintenance drone overgrown and repurposed by the Bloom.\nHunts by vibration. Telegraphs a crouch and hiss before it leaps.\nStrike or dash aside during the leap. A guard timed at the moment of impact staggers it.' };
    this.build();
    this.gait = Math.random() * 10;
    this.strafeDir = Math.random() < 0.5 ? -1 : 1;
    this.leapHit = false;
    this.skitterT = 0;
    this.circleT = 0;
    this.attackCd = 0.8 + Math.random();
    this.speed = 5.2 + Math.random() * 0.8;
    if (opts.drop) { this.setState('drop'); this.vel.set(0, -2, 0); }
    else if (opts.scurry) { this.setState('scurry'); this.dormant = true; this.scurryTo = opts.scurry.clone(); this.scanInfo = null; }
    else this.setState('stalk');
  }

  build() {
    this.body = buildCrawler(this, this.game.fx.glow);
    this.mesh.add(this.body);
  }

  stagger(t = 0.6, dir = null) {
    if (!this.alive) return;
    this.setState('stagger'); this.staggerDur = t;
    if (dir) this.vel.set(dir.x * 6, 2, dir.z * 6);
  }

  onHurt(dmg, dir, kind) {
    if (this.state === 'drop') return;
    if (this.hp > 0) {
      this.stagger(kind === 'heavy' || kind === 'wave' ? 0.7 : 0.35, dir);
      if (Math.random() < 0.5) this.game.audio.crawlerScreech(this.center());
    }
  }

  onDie(dir) {
    const g = this.game;
    g.audio.crawlerDie(this.center());
    g.fx.ichor(this.center(), dir, 50);
    if (dir) this.vel.set(dir.x * 7, 4, dir.z * 7);
    this.eyeMat.emissive.setRGB(0.05, 0, 0);
    this.eyeGlow.visible = false;
  }

  update(dt) {
    const g = this.game, P = g.player, L = g.level;
    this.stateT += dt;
    this.updateFlash(dt);
    const toP = _a.subVectors(P.position, this.pos); toP.y = 0;
    const dist = toP.length();
    const dir = dist > 0.001 ? toP.clone().divideScalar(dist) : new THREE.Vector3(0, 0, 1);
    let moving = 0;
    this.attackCd -= dt;

    switch (this.state) {
      case 'scurry': {
        const d = _b.subVectors(this.scurryTo, this.pos).setY(0);
        const l = d.length();
        d.normalize();
        this.facing = yawTo(d.x, d.z);
        this.vel.x = d.x * 10; this.vel.z = d.z * 10;
        if (l < 0.6) this.removeMe = true;
        break;
      }
      case 'drop':
        this.vel.y -= 22 * dt;
        const prevY = this.pos.y;
        this.pos.y += this.vel.y * dt;
        this.body.rotation.x = Math.min(this.body.rotation.x + dt * 4, 0);
        // search from where we were last frame so a fast fall can't tunnel through the floor
        const landY = L.groundAt(this.pos, 0.3, prevY - this.pos.y + 0.1);
        if (this.pos.y <= landY) {
          this.pos.y = landY;
          this.vel.set(0, 0, 0);
          g.audio.land(10); g.audio.crawlerScreech(this.center());
          g.fx.burst(this.pos.clone().setY(0.1), { count: 14, color: new THREE.Color(0.4, 0.4, 0.45), speed: 3, life: 0.6, grav: 2, size: 0.25 });
          this.setState('land');
        }
        break;
      case 'land':
        this.facing = lerpAngle(this.facing, yawTo(dir.x, dir.z), dt * 8);
        if (this.stateT > 0.5) this.setState('stalk');
        break;
      case 'stalk': {
        // approach with a weaving, skittering gait
        this.facing = lerpAngle(this.facing, yawTo(dir.x, dir.z), dt * 7);
        const side = _b.set(-dir.z, 0, dir.x).multiplyScalar(Math.sin(this.stateT * 2.2) * 0.8 * this.strafeDir);
        const want = dist > 4.5 ? dir.clone().add(side).normalize() : side.clone().normalize().multiplyScalar(0.6).addScaledVector(dir, -0.2);
        this.vel.x += (want.x * this.speed - this.vel.x) * Math.min(1, dt * 8);
        this.vel.z += (want.z * this.speed - this.vel.z) * Math.min(1, dt * 8);
        moving = 1;
        this.skitterT -= dt;
        if (this.skitterT <= 0) { this.skitterT = 0.6 + Math.random() * 0.5; g.audio.skitter(this.center(), 0.4, 0.18); }
        if (dist < 7.5 && this.attackCd <= 0 && g.level.lineOfSight(this.center(), P.eyePos())) {
          this.setState('windup'); g.audio.crawlerHiss(this.center());
        }
        if (Math.random() < dt * 0.15) this.strafeDir *= -1;
        break;
      }
      case 'windup':
        this.facing = lerpAngle(this.facing, yawTo(dir.x, dir.z), dt * 12);
        this.vel.multiplyScalar(1 - dt * 10);
        this.body.position.y = BODY_Y - Math.min(1, this.stateT / 0.5) * 0.22;
        this.eyeMat.emissive.setRGB(6 + Math.sin(this.stateT * 60) * 3, 0.4, 0.3); this.eyeGlow.material.color.setRGB(1.6, 0.12, 0.06);
        if (this.stateT > 0.55) {
          // leap at a predicted point
          const lead = P.vel.clone().setY(0).multiplyScalar(0.25);
          const tgt = P.position.clone().add(lead);
          const d = _b.subVectors(tgt, this.pos).setY(0);
          const len = Math.min(d.length(), 9);
          d.normalize();
          this.vel.set(d.x * (6 + len), 5.2, d.z * (6 + len));
          this.leapHit = false;
          this.setState('leap');
          g.audio.crawlerScreech(this.center());
        }
        break;
      case 'leap': {
        this.vel.y -= 16 * dt;
        this.body.rotation.x = -0.4;
        const c = this.center();
        if (!this.leapHit && c.distanceTo(_c.copy(P.position).setY(P.position.y + 1.0)) < 1.15) {
          this.leapHit = true;
          const r = P.receiveHit(14, c, 'melee', this);
          if (r === 'hit' || r === 'block') this.vel.multiplyScalar(-0.3);
        }
        break;
      }
      case 'recover':
        this.vel.multiplyScalar(1 - dt * 8);
        this.body.position.y += (BODY_Y - this.body.position.y) * dt * 6;
        if (this.stateT > 0.7) { this.setState('stalk'); this.attackCd = 1.2 + Math.random() * 1.5; }
        break;
      case 'stagger':
        this.vel.x *= 1 - dt * 6; this.vel.z *= 1 - dt * 6;
        this.body.rotation.z = Math.sin(this.stateT * 40) * 0.15 * (1 - this.stateT / this.staggerDur);
        if (this.stateT > this.staggerDur) { this.body.rotation.z = 0; this.setState('stalk'); this.attackCd = 0.5 + Math.random(); }
        break;
      case 'dead':
        this.vel.x *= 1 - dt * 3; this.vel.z *= 1 - dt * 3;
        this.body.rotation.z += (Math.PI - this.body.rotation.z) * Math.min(1, dt * 6);
        if (this.stateT > 2.5) this.pos.y -= dt * 0.3;
        if (this.stateT > 4.5) this.removeMe = true;
        break;
    }

    // gravity for non-flying states
    if (this.state !== 'drop') {
      if (this.state !== 'leap') this.vel.y -= 20 * dt;
      const prevY = this.pos.y;
      this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt; this.pos.y += this.vel.y * dt;
      if (this.state !== 'scurry') L.resolveCircle(this.pos, this.radius, this.pos.y + 0.3, this.pos.y + 0.9);
      const gnd = L.groundAt(this.pos, 0.3, Math.max(0.5, prevY - this.pos.y + 0.1));
      if (this.pos.y <= gnd) {
        this.pos.y = gnd;
        if (this.state === 'leap') { this.setState('recover'); this.body.rotation.x = 0; g.audio.land(6); }
        this.vel.y = 0;
      }
    }
    // separation
    for (const o of this.mgr.list) {
      if (o === this || !o.alive || o.type !== 'crawler') continue;
      const dx = this.pos.x - o.pos.x, dz = this.pos.z - o.pos.z, d = Math.hypot(dx, dz);
      if (d < 1.1 && d > 0.001) { this.pos.x += dx / d * (1.1 - d) * 0.5; this.pos.z += dz / d * (1.1 - d) * 0.5; }
    }
    // don't overlap the player
    if (this.alive && this.state !== 'leap') {
      const dx = this.pos.x - P.position.x, dz = this.pos.z - P.position.z, d = Math.hypot(dx, dz);
      if (d < 0.9 && d > 0.001) { this.pos.x += dx / d * (0.9 - d); this.pos.z += dz / d * (0.9 - d); }
    }

    // animation
    const hs = Math.hypot(this.vel.x, this.vel.z);
    this.gait += dt * (4 + hs * 3.2);
    if (this.alive) {
      const fast = this.state === 'windup' || this.state === 'leap';
      for (const [i, m] of this.mandibles.entries()) m.rotation.y = (i ? -1 : 1) * (0.15 + (0.5 + 0.5 * Math.sin(this.stateT * (fast ? 40 : 7))) * (fast ? 0.6 : 0.25));
      if (this.state !== 'windup') { this.eyeMat.emissive.setRGB(2.2, 0.1, 0.06); this.eyeGlow.material.color.setRGB(0.7, 0.05, 0.03); }
      // breathing abdomen, twitching feelers, bobbing head
      const br = 1 + Math.sin(this.gait * 0.35 + this.stateT) * 0.04;
      this.abdomen.scale.set(1.05 * br, 0.8 * br, 1.35 * (2 - br));
      for (const f of this.feelers) f.chain.forEach((seg, i) => {
        if (i === 0) return;
        seg.rotation.x = -0.25 + Math.sin(this.stateT * 3 + i + f.s) * 0.18 + (Math.random() < 0.01 ? (Math.random() - 0.5) : 0);
        seg.rotation.z = Math.sin(this.stateT * 2.3 + i * 0.7) * 0.12 * f.s;
      });
      this.head.rotation.y = Math.sin(this.stateT * 1.7) * 0.12;
      this.head.rotation.x = this.state === 'windup' ? -0.3 : Math.sin(this.stateT * 2.1) * 0.06;
      if (this.state !== 'stagger') this.body.rotation.z = Math.sin(this.gait * 0.5) * 0.04 * Math.min(1, hs / 3);
    }
    this.mesh.position.copy(this.pos);
    this.mesh.rotation.y = this.facing;
    // IK legs: feet plant on the floor and step in alternating tripods
    this.mesh.updateMatrixWorld(true);
    const planted = (this.alive && !['drop', 'leap'].includes(this.state));
    const tuck = !this.alive ? 0.45 : (this.state === 'leap' || this.state === 'drop') ? 0.2 : 0;
    const stepping = [false, false];
    for (const l of this.legs) if (l.stepping) stepping[l.group] = true;
    for (const l of this.legs) l.update(dt, this.pos.y, this.vel, planted, stepping[1 - l.group], tuck);
  }
}

// ============================================================================ Sentinel
class Sentinel extends Enemy {
  constructor(mgr, pos, opts = {}) {
    super(mgr, 'sentinel', pos);
    this.hp = this.maxHp = 50;
    this.radius = 0.7; this.centerY = 0;
    this.organic = false; this.dropCount = 3;
    this.scanInfo = { title: 'SENTINEL SN-7 // CORRUPTED', text: 'Station security drone. Firmware overwritten by the Bloom.\nFires slow plasma bolts. Strike a bolt, or guard just as it lands, to send it back.\nA returned bolt knocks the drone out of the air. Finish it while it is grounded.' };
    this.build();
    this.dormant = !!opts.dormant;
    this.home = pos.clone();
    this.orbitDir = Math.random() < 0.5 ? -1 : 1;
    this.fireCd = 1.5 + Math.random() * 1.5;
    this.humT = Math.random() * 2;
    this.bob = Math.random() * 10;
    this.setState(this.dormant ? 'dormant' : 'hover');
    if (this.dormant) { this.setEye(0.02, 0.02, 0.03); this.eyeGlow.visible = false; this.thrusterGlow.visible = false; }
  }

  build() {
    this.rig = buildSentinel(this, this.game.fx.glow);
    this.mesh.add(this.rig);
    this.thrustT = 0;
  }

  setEye(r, g, b) { this.irisU.color.value.setRGB(r, g, b); this.trimMat.color.setRGB(r * 0.6, g * 0.6, b * 0.6); }

  activate() {
    if (!this.dormant) return;
    this.setState('boot');
    this.game.audio.sentinelBoot(this.pos);
  }

  stagger(t = 2.2) {
    if (!this.alive) return;
    this.setState('stagger'); this.staggerDur = t;
    this.game.audio.sentinelDie(this.pos);
  }

  onHurt(dmg, dir, kind) {
    const g = this.game;
    g.fx.sparks(this.center(), dir, 10);
    if (kind === 'reflect' || kind === 'wave') this.stagger(2.4);
    else if (this.state !== 'stagger') { this.vel.addScaledVector(dir, 4); }
  }

  onDie() {
    const g = this.game;
    g.audio.sentinelDie(this.pos);
    this.setEye(0.05, 0.02, 0.02);
    this.eyeGlow.visible = false;
    this.thrusterGlow.visible = false;
    this.vel.y = 1;
  }

  fire() {
    const g = this.game, P = g.player;
    const from = this.center().clone().add(new THREE.Vector3(-Math.sin(this.facing), 0, -Math.cos(this.facing)).multiplyScalar(0.6));
    const tgt = P.eyePos().add(new THREE.Vector3(0, -0.3, 0)).addScaledVector(P.vel, 0.35);
    const v = tgt.sub(from).normalize().multiplyScalar(12.5);
    this.mgr.spawnBolt(from, v, this);
    g.audio.sentinelShot(from);
  }

  update(dt) {
    const g = this.game, P = g.player, L = g.level;
    this.stateT += dt;
    this.updateFlash(dt);
    this.bob += dt;
    const eye = P.eyePos();
    const to = _a.subVectors(eye, this.pos);
    const dist = to.length();
    const flat = Math.hypot(to.x, to.z);
    const spin = this.state === 'charge' ? 9 : this.dormant ? 0 : 1.2;
    this.rings[0].ring.rotation.z += dt * spin; this.rings[1].ring.rotation.z -= dt * spin * 0.7;
    this.rings[0].holder.rotation.x += dt * spin * 0.3; this.rings[1].holder.rotation.y += dt * spin * 0.2;
    this.blink.color.setRGB(((this.bob * 1.3) % 1) < 0.15 && !this.dormant ? 4 : 0.1, 0.1, 0.1);

    switch (this.state) {
      case 'dormant':
        this.rig.rotation.x = 0.6;
        return this.sync();
      case 'boot': {
        const k = Math.min(1, this.stateT / 1.6);
        const flick = k < 0.6 ? (Math.random() < k ? 1 : 0.05) : 1;
        this.setEye(0.4 * flick, 2.5 * flick, 3.5 * flick); this.eyeGlow.visible = flick > 0.5; this.thrusterGlow.visible = true;
        this.rig.rotation.x = 0.6 * (1 - k);
        this.pos.y += dt * 0.8;
        // drift out from the wall toward the room
        const out = _b.subVectors(L.points.atriumCenter || P.position, this.pos).setY(0).normalize();
        this.pos.addScaledVector(out, dt * 1.6);
        this.facing = lerpAngle(this.facing, yawTo(to.x, to.z), dt * 3);
        if (this.stateT > 1.6) { this.dormant = false; this.setState('hover'); }
        break;
      }
      case 'hover':
      case 'charge': {
        this.facing = lerpAngle(this.facing, yawTo(to.x, to.z), dt * 5);
        const prefer = 8.5;
        const radial = flat > prefer + 1.5 ? 1 : flat < prefer - 2 ? -1 : 0;
        const fx = to.x / (flat || 1), fz = to.z / (flat || 1);
        const sp = this.state === 'charge' ? 0.8 : 3.2;
        const wantX = fx * radial * sp + (-fz) * this.orbitDir * sp * 0.8;
        const wantZ = fz * radial * sp + fx * this.orbitDir * sp * 0.8;
        const wantY = (P.position.y + 3.6 + Math.sin(this.bob * 1.3) * 0.5 - this.pos.y) * 1.5;
        this.vel.x += (wantX - this.vel.x) * Math.min(1, dt * 2);
        this.vel.z += (wantZ - this.vel.z) * Math.min(1, dt * 2);
        this.vel.y += (wantY - this.vel.y) * Math.min(1, dt * 2);
        if (Math.random() < dt * 0.2) this.orbitDir *= -1;
        this.humT -= dt;
        if (this.humT <= 0) { this.humT = 1.4; g.audio.sentinelHum(this.pos); }
        if (this.state === 'hover') {
          this.fireCd -= dt;
          this.irisU.color.value.lerp(new THREE.Color(0.4, 2.5, 3.5), dt * 4); this.trimMat.color.lerp(new THREE.Color(0.24, 1.5, 2.1), dt * 4); this.irisU.pupil.value += (0.25 - this.irisU.pupil.value) * dt * 4;
          if (this.fireCd <= 0 && dist < 26 && L.lineOfSight(this.center(), eye)) {
            this.setState('charge'); g.audio.sentinelCharge(this.pos);
          }
        } else {
          const k = Math.min(1, this.stateT / 0.9);
          this.setEye(0.4 + k * 5, 2.5 * (1 - k) + 0.6, 3.5 * (1 - k) + 0.3); this.irisU.pupil.value = 0.25 - k * 0.17;
          this.eyeGlow.material.color.setRGB(0.3 + k * 3, 1.5 * (1 - k) + 0.3, 2 * (1 - k));
          if (Math.random() < 0.6) {
            const p = this.center().clone().add(new THREE.Vector3((Math.random() - 0.5) * 2, (Math.random() - 0.5) * 2, (Math.random() - 0.5) * 2));
            const v = this.center().clone().sub(p).multiplyScalar(3);
            g.fx.emit(p, v, new THREE.Color(3, 1, 0.5), 0.08, 0.3);
          }
          if (this.stateT > 0.9) {
            this.fire();
            this.fireCd = 2.2 + Math.random() * 1.6;
            this.setState('hover');
            this.eyeGlow.material.color.setRGB(0.3, 1.5, 2);
          }
        }
        break;
      }
      case 'stagger': {
        // knocked out of the air: drop to the floor and fizzle (melee window)
        const k = this.stateT / this.staggerDur;
        const ground = L.groundAt(this.pos, 0.3, 0.2) + 0.85;
        this.vel.x *= 1 - dt * 3; this.vel.z *= 1 - dt * 3;
        if (k < 0.8) { this.vel.y -= 14 * dt; if (this.pos.y < ground) { this.pos.y = ground; this.vel.y = Math.abs(this.vel.y) * 0.25; } }
        else this.vel.y += (P.position.y + 3.5 - this.pos.y) * dt * 3;
        this.rig.rotation.z += dt * 6 * (1 - k);
        this.setEye(Math.random() < 0.5 ? 2 : 0.1, 0.3, 0.3);
        if (Math.random() < dt * 8) g.fx.sparks(this.center(), null, 4);
        if (this.stateT > this.staggerDur) { this.rig.rotation.z = 0; this.setState('hover'); this.fireCd = 1.5; }
        break;
      }
      case 'dead': {
        this.vel.y -= 16 * dt;
        this.rig.rotation.x += dt * 5; this.rig.rotation.z += dt * 3;
        if (Math.random() < dt * 20) g.fx.sparks(this.center(), null, 3);
        const ground = L.groundAt(this.pos, 0.3, 0.2) + 0.4;
        if (this.pos.y <= ground && !this.exploded) {
          this.exploded = true;
          g.audio.explosion(this.pos);
          g.fx.burst(this.pos, { count: 50, color: new THREE.Color(3, 1.6, 0.6), speed: 10, life: 0.8, grav: 8, size: 0.14 });
          g.fx.ring(this.pos.clone().setY(0.1), new THREE.Color(3, 1.5, 0.5), 5, 0.5);
          g.fx.lightFlash(this.pos, 0xffa050, 40, 0.3);
          g.fx.glowFlash(this.pos, new THREE.Color(3, 1.8, 0.8), 4, 0.35);
          this.mesh.visible = false;
          this.removeMe = true;
        }
        break;
      }
    }
    this.pos.addScaledVector(this.vel, dt);
    if (this.state !== 'dead') {
      L.resolveCircle(this.pos, this.radius, this.pos.y - 0.6, this.pos.y + 0.6);
      const ceil = L.ceilingAt(this.pos, 0.3, this.pos.y + 0.7);
      if (this.pos.y > ceil - 0.8) { this.pos.y = ceil - 0.8; this.vel.y = Math.min(0, this.vel.y); }
    }
    this.sync();
  }

  sync() {
    this.mesh.position.copy(this.pos);
    this.mesh.rotation.y = this.facing;
    // armour petals bloom open while charging
    const open = this.state === 'charge' ? 0.14 + Math.sin(this.stateT * 30) * 0.01 : this.state === 'stagger' ? 0.08 : 0.0;
    for (const p of this.petals) {
      const cur = p.pivot.position.length();
      p.pivot.position.copy(p.pivot.userData.dir).multiplyScalar(cur + (open - cur) * 0.2);
    }
    // thruster wash
    if (this.thrusterGlow.visible && this.alive) {
      this.thrusterGlow.scale.setScalar(0.55 + Math.random() * 0.25);
      this.thrustT -= 0.016;
      if (this.thrustT <= 0) {
        this.thrustT = 0.05;
        const p = this.mesh.localToWorld(new THREE.Vector3(0, -0.65, 0));
        this.game.fx.emit(p, new THREE.Vector3((Math.random() - 0.5) * 0.6, -2.5, (Math.random() - 0.5) * 0.6), new THREE.Color(0.2, 0.7, 1.6), 0.18, 0.35, 0, 2);
      }
    }
  }
}

// ============================================================================ Stalker (boss)
class Stalker extends Enemy {
  constructor(mgr, pos, opts = {}) {
    super(mgr, 'stalker', pos);
    this.hp = this.maxHp = 230;
    this.radius = 0.6; this.centerY = 1.5;
    this.organic = true; this.dropCount = 6;
    this.scanInfo = { title: 'STALKER // BLOOM APEX', text: 'Optical camouflage grown from living tissue. Invisible in the combat visor, visible in the scan visor.\nIt flanks, appears, shrieks, and lunges. Dash through the lunge, or parry it to break its guard.\nIt stays visible for a short time after attacking. Punish it then.' };
    this.build();
    this.speed = 3.6;
    this.stepT = 0; this.cycleT = 0; this.swipes = 0; this.swipeHit = false; this.enraged = false;
    this.setCloak(true, true);
    this.setState('emerge');
    if (opts.apparition) { this.apparition = true; this.dormant = true; this.scanInfo = null; this.setState('apparition'); }
  }

  build() {
    this.mesh.add(buildStalker(this, this.game.fx.glow));
  }

  setCloak(on, silent = false) {
    this.cloaked = on;
    for (const p of this.parts) p.material = on ? this.cloakMat : this.bodyMat;
    this.eye.visible = !on; this.eyeGlow.visible = !on;
    this.tipMat.color.setRGB(on ? 0 : 3, on ? 0 : 2.6, on ? 0 : 3.4);
    if (!silent) {
      this.game.audio.cloakShimmer(this.center());
      for (let i = 0; i < 30; i++) {
        const p = this.center().clone().add(new THREE.Vector3((Math.random() - 0.5) * 0.8, (Math.random() - 0.5) * 2.4, (Math.random() - 0.5) * 0.8));
        this.game.fx.emit(p, new THREE.Vector3(0, 0.5 + Math.random(), 0), new THREE.Color(0.6, 0.9, 1.6), 0.08, 0.6);
      }
    }
  }

  stagger(t = 1.6) {
    if (!this.alive) return;
    if (this.cloaked) this.setCloak(false);
    this.setState('stagger'); this.staggerDur = t;
    this.game.audio.stalkerShriek(this.center());
  }

  onHurt(dmg, dir, kind) {
    if (this.cloaked) { this.setCloak(false); this.stagger(0.7); }
    else if (kind === 'heavy' || kind === 'wave') { if (this.state !== 'lunge' && this.state !== 'stagger') this.stagger(0.45); }
    if (!this.enraged && this.hp < this.maxHp * 0.5) {
      this.enraged = true; this.speed = 4.6;
      this.game.audio.stalkerShriek(this.center());
      if (this.encounter && this.encounter.onEnrage) this.encounter.onEnrage(this);
    }
  }

  onDie() {
    const g = this.game;
    if (this.cloaked) this.setCloak(false, true);
    g.audio.stalkerDie(this.center());
    g.fx.ichor(this.center(), null, 90);
    g.fx.ring(this.pos.clone().setY(0.1), new THREE.Color(1.5, 0.3, 2.5), 9, 0.9);
    g.fx.lightFlash(this.center(), 0xb060ff, 50, 0.6);
    g.hitStop(0.3);
  }

  blinkTo() {
    const g = this.game, P = g.player, L = g.level;
    const back = new THREE.Vector3(Math.sin(P.yaw), 0, Math.cos(P.yaw));
    const side = new THREE.Vector3(Math.cos(P.yaw), 0, -Math.sin(P.yaw)).multiplyScalar(Math.random() < 0.5 ? -1 : 1);
    const cand = [back.clone().multiplyScalar(4.5), back.clone().add(side).normalize().multiplyScalar(4.5), side.clone().multiplyScalar(5)];
    g.audio.stalkerWhoosh(this.center());
    for (const off of cand) {
      const p = P.position.clone().add(off);
      const test = p.clone();
      L.resolveCircle(test, this.radius, 0.3, 2.5);
      if (test.distanceTo(p) < 0.2 && L.lineOfSight(P.eyePos(), test.clone().setY(1.5))) {
        this.pos.copy(test);
        g.audio.stalkerWhoosh(this.center());
        return true;
      }
    }
    return false;
  }

  update(dt) {
    const g = this.game, P = g.player, L = g.level;
    this.stateT += dt;
    this.updateFlash(dt);
    const cu = this.cloakMat.userData.cloak;
    cu.reveal.value += ((P.scanMode ? 1 : 0) - cu.reveal.value) * Math.min(1, dt * 6);
    cu.flash.value = this.flashT > 0 ? 0.6 : 0;
    const to = _a.subVectors(P.position, this.pos).setY(0);
    const dist = to.length();
    const dir = to.clone().divideScalar(dist || 1);
    const faceP = () => { this.facing = lerpAngle(this.facing, yawTo(dir.x, dir.z), dt * 8); };
    let walk = 0;
    let pose = 'idle';
    if (this.state === 'apparition') {
      // a shimmering silhouette at the end of the hall, watching
      faceP();
      cu.reveal.value = Math.max(cu.reveal.value, 0.3 + Math.sin(this.stateT * 9) * 0.08);
      if (this.stateT > 2.6 || dist < 8) {
        this.setCloak(true);
        g.audio.stalkerWhoosh(this.center());
        this.removeMe = true;
      }
      this.animate(dt, 0, 'idle');
      this.mesh.position.copy(this.pos);
      this.mesh.rotation.y = this.facing;
      return;
    }

    switch (this.state) {
      case 'emerge':
        faceP();
        if (this.stateT > 0.1 && !this.shrieked) { this.shrieked = true; g.audio.stalkerShriek(this.center()); }
        if (this.stateT > 1.5) this.setState('stalk');
        break;
      case 'stalk': {
        faceP();
        this.cycleT += dt;
        const want = dist > 5.5 ? dir.clone() : new THREE.Vector3(-dir.z, 0, dir.x).multiplyScalar(0.7);
        this.vel.x += (want.x * this.speed - this.vel.x) * Math.min(1, dt * 4);
        this.vel.z += (want.z * this.speed - this.vel.z) * Math.min(1, dt * 4);
        walk = 1;
        this.stepT -= dt;
        if (this.stepT <= 0) { this.stepT = 0.55; g.audio.stalkerStep(this.pos.clone().setY(0.1)); }
        if (Math.random() < dt * 0.4) g.audio.cloakShimmer(this.center());
        const window = this.enraged ? 1.6 : 2.6;
        if (this.cycleT > window + Math.random() * 1.5) {
          this.cycleT = 0;
          if (dist < 9 && Math.random() < 0.55) { if (this.blinkTo()) { this.setState('reveal'); this.setCloak(false); g.audio.stalkerShriek(this.center()); break; } }
          if (dist < 7) { this.setState('reveal'); this.setCloak(false); g.audio.stalkerShriek(this.center()); }
        }
        break;
      }
      case 'reveal':
        faceP();
        this.vel.multiplyScalar(1 - dt * 8);
        pose = 'raise';
        if (this.stateT > (this.enraged ? 0.42 : 0.6)) { this.setState('lunge'); this.swipes = 0; this.swipeHit = false; }
        break;
      case 'lunge': {
        faceP();
        const sp = this.enraged ? 15 : 13;
        this.vel.x = dir.x * sp; this.vel.z = dir.z * sp;
        pose = 'raise';
        if (dist < 1.9 || this.stateT > 0.45) this.setState('swipe');
        break;
      }
      case 'swipe':
        this.vel.multiplyScalar(1 - dt * 10);
        pose = 'swipe';
        if (!this.swipeHit && this.stateT > 0.08) {
          this.swipeHit = true;
          g.audio.stalkerWhoosh(this.center());
          if (dist < 2.6) {
            const fwd = new THREE.Vector3(-Math.sin(this.facing), 0, -Math.cos(this.facing));
            if (fwd.dot(dir) > 0.3) {
              const r = P.receiveHit(this.enraged ? 22 : 18, this.center(), 'melee', this);
              if (r === 'parry') break;
            }
          }
        }
        if (this.stateT > 0.3) {
          this.swipes++;
          if (this.swipes < (this.enraged ? 3 : 2) && dist < 3.5 && this.state === 'swipe') { this.setState('swipe'); this.swipeHit = false; this.facing += 0.01; }
          else this.setState('recover');
        }
        break;
      case 'recover':
        this.vel.multiplyScalar(1 - dt * 6);
        pose = 'slump';
        if (this.stateT > (this.enraged ? 1.0 : 1.4)) { this.setCloak(true); this.setState('stalk'); this.cycleT = 0; }
        break;
      case 'stagger':
        this.vel.multiplyScalar(1 - dt * 5);
        pose = 'stagger';
        if (this.stateT > this.staggerDur) this.setState('recover');
        break;
      case 'dead':
        pose = 'dead';
        this.vel.multiplyScalar(1 - dt * 4);
        if (this.stateT > 1.2 && Math.random() < dt * 30) g.fx.ichor(this.center().clone().add(new THREE.Vector3((Math.random() - 0.5), (Math.random() - 0.5) * 2, (Math.random() - 0.5))), null, 3);
        if (this.stateT > 2.5) { this.mesh.scale.multiplyScalar(1 - dt * 1.5); }
        if (this.stateT > 4) this.removeMe = true;
        break;
    }
    this.pos.x += this.vel.x * dt; this.pos.z += this.vel.z * dt;
    L.resolveCircle(this.pos, this.radius, 0.3, 2.6);
    if (this.alive) {
      const dx = this.pos.x - P.position.x, dz = this.pos.z - P.position.z, d = Math.hypot(dx, dz);
      if (d < 1.0 && d > 0.001) { this.pos.x += dx / d * (1.0 - d); this.pos.z += dz / d * (1.0 - d); }
    }
    this.animate(dt, walk, pose);
    this.mesh.position.copy(this.pos);
    this.mesh.rotation.y = this.facing;
  }

  animate(dt, walk, pose) {
    const t = (this.animT = (this.animT || 0) + dt * (2 + walk * 5));
    const k = Math.min(1, dt * 12);
    const L = (o, prop, v) => { o.rotation[prop] += (v - o.rotation[prop]) * k; };
    for (const leg of this.legs) {
      const ph = leg.s > 0 ? 0 : Math.PI;
      L(leg.hip, 'x', walk ? Math.sin(t + ph) * 0.6 - 0.2 : -0.25);
      L(leg.knee, 'x', walk ? 0.9 + Math.cos(t + ph) * 0.4 : 0.8);
      L(leg.ank, 'x', -0.5);
    }
    let shX = 0.3, elX = -0.6, torX = -0.35, neckX = 0.2, shZ = 0.25;
    if (pose === 'raise') { shX = -2.4; elX = -0.8; torX = -0.1; shZ = 0.55; neckX = -0.2; }
    if (pose === 'swipe') { shX = 0.9; elX = -0.2; torX = -0.7; shZ = 0.1; }
    if (pose === 'slump') { shX = 0.5; elX = -0.3; torX = -0.8 + Math.sin(this.stateT * 6) * 0.06; neckX = 0.6; }
    if (pose === 'stagger') { shX = -0.4; elX = -1.2; torX = 0.2 + Math.sin(this.stateT * 30) * 0.1; neckX = -0.6; }
    if (pose === 'dead') { torX = -1.4; shX = 1.4; neckX = 1.0; }
    L(this.torso, 'x', torX); L(this.neck, 'x', neckX);
    for (const a of this.arms) {
      L(a.sh, 'x', shX + (walk ? Math.sin(t + (a.s > 0 ? Math.PI : 0)) * 0.3 : 0));
      L(a.sh, 'z', a.s * shZ);
      L(a.el, 'x', elX);
    }
    if (pose === 'dead') { this.hips.position.y += (0.5 - this.hips.position.y) * Math.min(1, dt * 3); }
    else this.hips.position.y = 1.3 + (walk ? Math.abs(Math.sin(t)) * 0.05 : 0);
    // head twitch
    if (this.alive && Math.random() < dt * 2) this.neck.rotation.z = (Math.random() - 0.5) * 0.6;
    this.neck.rotation.z *= 1 - dt * 3;
    // split jaw gapes when it shrieks or strikes
    const gape = pose === 'raise' || pose === 'stagger' ? 0.55 + Math.sin(this.stateT * 40) * 0.08 : pose === 'swipe' ? 0.35 : 0.06;
    for (const j of this.jaw) j.g.rotation.y += (j.s * gape - j.g.rotation.y) * k;
    // tendrils: lagging wave down each chain
    const sway = Math.hypot(this.vel.x, this.vel.z);
    for (const td of this.tendrils) td.chain.forEach((seg, i) => {
      if (i === 0) return;
      seg.rotation.x = Math.sin(t * 0.8 + td.ph - i * 0.6) * (0.18 + sway * 0.03) + sway * 0.04;
      seg.rotation.z = Math.cos(t * 0.6 + td.ph - i * 0.5) * 0.15;
    });
  }
}

// ============================================================================ manager
export class EnemyManager {
  constructor(game) {
    this.game = game;
    this.list = [];
    this.bolts = [];
    this.boltTex = null;
  }

  spawn(type, pos, opts = {}) {
    let e;
    if (type === 'crawler') e = new Crawler(this, pos, opts);
    else if (type === 'sentinel') e = new Sentinel(this, pos, opts);
    else if (type === 'stalker') e = new Stalker(this, pos, opts);
    if (opts.encounter) { e.encounter = opts.encounter; }
    this.list.push(e);
    return e;
  }

  spawnBolt(pos, vel, owner) {
    const g = this.game;
    const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: g.fx.glow, color: new THREE.Color(4, 1.2, 0.5), blending: THREE.AdditiveBlending, depthWrite: false }));
    s.scale.setScalar(0.8);
    s.position.copy(pos);
    const core = new THREE.Sprite(new THREE.SpriteMaterial({ map: g.fx.glow, color: new THREE.Color(5, 4, 3), blending: THREE.AdditiveBlending, depthWrite: false }));
    core.scale.setScalar(0.3); s.add(core);
    g.scene.add(s);
    this.bolts.push({ pos: pos.clone(), vel: vel.clone(), owner, reflected: false, dead: false, mesh: s, life: 5, trailT: 0 });
  }

  reflectBolt(b) {
    b.reflected = true;
    const tgt = b.owner && b.owner.alive ? b.owner.center() : b.pos.clone().sub(b.vel);
    b.vel.subVectors(tgt, b.pos).normalize().multiplyScalar(24);
    b.mesh.material.color.setRGB(0.6, 3, 4);
    b.life = 3;
  }

  threatLevel(pos) {
    let t = 0;
    for (const e of this.list) {
      if (!e.alive || e.dormant) continue;
      const d = e.pos.distanceTo(pos);
      t = Math.max(t, 1 - Math.min(1, Math.max(0, (d - 3) / 25)));
    }
    return t;
  }

  activeCount() { return this.list.filter((e) => e.alive && !e.dormant).length; }

  onDeath(e) {
    if (this.game.player.lockTarget === e) this.game.player.lockTarget = null;
    if (e.encounter && e.encounter.onDeath) e.encounter.onDeath(e);
  }

  removeEncounter(enc) {
    for (const e of this.list) if (e.encounter === enc) { e.dispose(); e.removed = true; }
    this.list = this.list.filter((e) => !e.removed);
    for (const b of this.bolts) { b.dead = true; }
  }

  update(dt) {
    const g = this.game, P = g.player;
    creatureTime.value += dt;
    for (const e of this.list) e.update(dt);
    for (let i = this.list.length - 1; i >= 0; i--) if (this.list[i].removeMe) { this.list[i].dispose(); this.list.splice(i, 1); }

    // bolts
    const eye = P.eyePos();
    for (let i = this.bolts.length - 1; i >= 0; i--) {
      const b = this.bolts[i];
      if (!b.dead) {
        const prev = b.pos.clone();
        b.pos.addScaledVector(b.vel, dt);
        b.life -= dt;
        b.mesh.position.copy(b.pos);
        b.trailT -= dt;
        if (b.trailT <= 0) { b.trailT = 0.02; g.fx.emit(b.pos, new THREE.Vector3(), b.reflected ? new THREE.Color(0.5, 2, 3) : new THREE.Color(3, 0.8, 0.3), 0.25, 0.25); }
        if (!b.reflected) {
          if (b.pos.distanceTo(_a.copy(eye).setY(eye.y - 0.35)) < 0.75) {
            const r = P.receiveHit(15, b.pos, 'bolt');
            if (r === 'parry') { this.reflectBolt(b); g.hud.message('DEFLECT', 0.6); continue; }
            if (r === 'evaded') continue;
            b.dead = true;
            g.fx.burst(b.pos, { count: 16, color: new THREE.Color(3, 1, 0.4), speed: 5, life: 0.4, grav: 0, size: 0.1 });
          }
        } else {
          for (const e of this.list) {
            if (!e.alive || e.dormant) continue;
            if (e.center().distanceTo(b.pos) < e.radius + 0.45) {
              e.takeDamage(30, b.vel.clone().normalize(), 'reflect');
              g.audio.explosion(b.pos);
              g.fx.burst(b.pos, { count: 30, color: new THREE.Color(0.5, 2.5, 3.5), speed: 8, life: 0.5, grav: 0, size: 0.12 });
              g.fx.lightFlash(b.pos, 0x80f0ff, 30, 0.2);
              g.hitStop(0.08);
              b.dead = true; break;
            }
          }
        }
        if (!b.dead && !g.level.lineOfSight(prev, b.pos)) {
          b.dead = true;
          g.fx.burst(prev, { count: 12, color: new THREE.Color(3, 1, 0.4), speed: 4, life: 0.35, grav: 3, size: 0.08 });
          g.audio.tone({ freq: 400, freqEnd: 100, type: 'sawtooth', dur: 0.15, gain: 0.05, pos: prev, filter: 'lowpass', filterFreq: 1500 });
        }
        if (b.life <= 0) b.dead = true;
      }
      if (b.dead) { g.scene.remove(b.mesh); this.bolts.splice(i, 1); }
    }
  }
}
