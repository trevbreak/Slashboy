import * as THREE from 'three';

const V = (x, y, z) => new THREE.Vector3(x, y, z);

const FOG = {
  bay:      { d: 0.040, c: 0x111a24, e: 1.45, env: 0.7 },
  spine:    { d: 0.050, c: 0x0e141c, e: 1.5,  env: 0.65 },
  junction: { d: 0.050, c: 0x0e141c, e: 1.5,  env: 0.65 },
  atrium:   { d: 0.014, c: 0x161f30, e: 1.4,  env: 0.9 },
  funnel:   { d: 0.060, c: 0x1a0c12, e: 1.45, env: 0.6 },
  arena:    { d: 0.030, c: 0x0c1610, e: 1.4,  env: 0.6 },
  final:    { d: 0.022, c: 0x15111a, e: 1.3,  env: 0.7 },
};

// An encounter: sequential waves, each must be cleared before the next.
class Encounter {
  constructor(dir, id, def) {
    this.dir = dir; this.game = dir.game; this.id = id; this.def = def;
    this.state = 'idle'; this.run = 0; this.wave = -1; this.pending = 0; this.waveDelay = 0;
    if (def.setup) def.setup(this);
  }
  spawn(type, pos, opts = {}) {
    return this.game.enemies.spawn(type, pos, { ...opts, encounter: this });
  }
  // delayed spawn that counts toward the current wave and is cancelled on reset
  spawnLater(t, type, pos, opts = {}, after = null) {
    this.pending++;
    const run = this.run;
    this.dir.after(t, () => {
      if (run !== this.run) return;
      this.pending--;
      const e = this.spawn(type, pos, opts);
      if (after) after(e);
    });
  }
  later(t, fn) { const run = this.run; this.dir.after(t, () => { if (run === this.run) fn(); }); }
  alive() { return this.game.enemies.list.filter((e) => e.encounter === this && e.alive && !e.dormant).length; }
  begin() {
    if (this.state !== 'idle') return;
    this.state = 'active';
    this.wave = -1;
    if (this.def.start) this.def.start(this);
    this.nextWave(this.def.firstDelay ?? 0);
  }
  nextWave(delay) {
    this.wave++;
    if (this.wave >= this.def.waves.length) { this.finish(); return; }
    this.pending++;
    this.later(delay, () => { this.pending--; this.def.waves[this.wave](this); });
  }
  update() {
    if (this.state !== 'active') return;
    if (this.pending === 0 && this.alive() === 0 && !this.waitingNext) {
      this.waitingNext = true;
      const gap = (this.def.gaps && this.def.gaps[this.wave]) ?? 2;
      this.later(0.01, () => { this.waitingNext = false; this.nextWave(gap); });
    }
  }
  onDeath() {}
  finish() {
    this.state = 'done';
    if (this.def.clear) this.def.clear(this);
  }
  reset() {
    if (this.state === 'done') return;
    this.run++;
    this.pending = 0; this.waitingNext = false;
    this.game.enemies.removeEncounter(this);
    this.state = 'idle';
    if (this.def.reset) this.def.reset(this);
    if (this.def.setup) this.def.setup(this);
  }
}

export class Director {
  constructor(game) {
    this.game = game;
    this.events = [];
    this.triggers = [];
    this.encounters = {};
    this.zone = null;
    this.visited = new Set();
    this.checkpoint = { pos: V(0, 0, -2.5), yaw: 0 };
    this.time = 0;
    this.atriumTime = 0;
    this.onLift = 0;
    this.setup();
  }

  after(t, fn) { this.events.push({ t: this.time + t, fn }); }

  trigger(box, fn, opts = {}) {
    const t = { box, fn, once: opts.once !== false, fired: false, cond: opts.cond || null, id: opts.id };
    this.triggers.push(t);
    return t;
  }

  // ======================================================================= script
  setup() {
    const g = this.game, L = g.level, A = () => g.audio, H = () => g.hud;

    // ---------------- Spine scare: lights die, something runs overhead, a glimpse at the far end
    this.trigger([-1.6, -22.5, 1.6, -20], () => {
      const fx = L.fixtures.filter((f) => f.group === 'spine').sort((a, b) => a.pos.z - b.pos.z);
      const saved = fx.map((f) => f.mode);
      A().duck(0.15, 0.3);
      A().stinger('scare');
      fx.forEach((f, i) => this.after(0.15 + i * 0.18, () => { f.on = false; A().buzz(f.pos, 0.05); }));
      this.after(1.6, () => { A().ventBang(V(0, 3.2, -24)); g.player.addShake(0.35); });
      this.after(1.9, () => A().skitterPath(V(0, 3.4, -25), V(0, 3.4, -13), 1.3, 0.45));
      this.after(3.8, () => {
        A().lightsOn();
        fx.forEach((f, i) => { f.on = true; f.mode = saved[i]; });
        A().duck(1, 2);
      });
      this.after(4.6, () => {
        // something crosses the junction far ahead
        g.enemies.spawn('crawler', V(1.0, 0, -38.6), { scurry: V(13, 0, -38.6) });
        A().skitter(V(4, 0.3, -38.6), 0.6, 0.25);
      });
    });

    // ---------------- Junction ambush (first fight)
    this.encounters.junction = new Encounter(this, 'junction', {
      start: (e) => {
        L.doors.d2.lock();
        A().grateFall(L.points.junctionVent);
        A().duck(0.3, 0.2);
      },
      firstDelay: 0.7,
      waves: [
        (e) => {
          e.spawn('crawler', L.points.junctionVent.clone().setY(2.6), { drop: true });
          A().stinger('encounter'); A().setCombat(true); A().duck(1, 1);
          H().hint('<b>LMB</b> strike &nbsp;·&nbsp; <b>RMB</b> guard &nbsp;·&nbsp; <b>SHIFT</b> dash &nbsp;·&nbsp; <b>Q</b> lock-on', 7);
        },
      ],
      clear: () => {
        A().setCombat(false);
        this.after(1.2, () => { L.doors.d2.unlock(); A().stinger('clear'); H().message('LOCK RELEASED', 2); });
      },
      reset: () => { L.doors.d2.unlock(false); A().setCombat(false); },
    });
    this.trigger([8, -40, 14, -37], () => this.encounters.junction.begin(), { id: 'junction' });

    // ---------------- Concourse: two dormant sentinels wake
    this.encounters.atrium = new Encounter(this, 'atrium', {
      setup: (e) => {
        e.sentinels = [
          e.spawn('sentinel', L.points.sentinelA.clone(), { dormant: true }),
          e.spawn('sentinel', L.points.sentinelB.clone(), { dormant: true }),
        ];
      },
      start: (e) => {
        L.doors.d3.lock();
        A().duck(0.2, 0.4);
      },
      firstDelay: 0.3,
      waves: [
        (e) => {
          e.sentinels[0].activate();
          e.later(0.9, () => e.sentinels[1].activate());
          e.later(1.0, () => { A().stinger('encounter'); A().setCombat(true); A().duck(1, 1); });
          e.later(4, () => H().hint('Strike their plasma bolts to send them back &nbsp;·&nbsp; or <b>RMB</b> guard just as one hits', 7));
          // keep the wave "open" until they finish booting
          e.pending++; e.later(2.8, () => e.pending--);
        },
      ],
      clear: () => {
        A().setCombat(false);
        this.after(1.5, () => { L.doors.d3.unlock(); A().stinger('clear'); H().message('AREA SECURE', 2.5); });
      },
      reset: () => { L.doors.d3.unlock(false); A().setCombat(false); },
    });
    const wakeAtrium = () => this.encounters.atrium.begin();
    this.trigger([27, -47, 41, -33], wakeAtrium, { id: 'atriumCore' });
    this.trigger([28, -70, 40, -60], wakeAtrium, { id: 'atriumNorth' });
    // the leviathan passes beyond the glass
    this.trigger([44, -70, 54, -10], () => this.leviathan(), { id: 'leviathan' });

    // ---------------- Funnel apparition
    this.trigger([31.5, -84, 36.5, -81], () => {
      g.enemies.spawn('stalker', L.points.funnelGlimpse.clone(), { apparition: true });
      A().whisper(V(34, 1.6, -96));
      A().setTension(0.6);
      this.after(0.4, () => A().heartbeat(0.5));
      this.after(1.3, () => A().heartbeat(0.45));
      this.after(2.2, () => A().heartbeat(0.4));
    });
    this.trigger([32.75, -96, 35.25, -91], () => { this.checkpoint = { pos: V(34, 0, -95), yaw: 0 }; });

    // ---------------- Hydroponics vault: lockdown, darkness, three waves
    const vents = L.points.arenaVents;
    this.encounters.arena = new Encounter(this, 'arena', {
      start: (e) => {
        L.doors.d4.lock(true);
        A().duck(0.12, 0.6);
        A().setTension(0.7);
        e.later(2.6, () => { L.setGroup('arena', 'off'); A().lightsOut(); });
        e.later(4.4, () => { A().crawlerHiss(vents[0]); });
        e.later(5.0, () => { A().crawlerHiss(vents[3]); A().taps(vents[4]); });
        e.later(5.6, () => { A().skitter(vents[1], 0.8, 0.3); });
        e.later(6.4, () => {
          L.setGroup('alarm', 'on'); A().alarm(3); A().stinger('encounter'); A().setCombat(true); A().duck(1, 1);
          H().message('CONTAINMENT BREACH', 3, true);
        });
      },
      firstDelay: 6.8,
      gaps: [2.5, 3.0],
      waves: [
        (e) => {
          [0, 3, 4, 1].forEach((vi, i) => e.spawnLater(i * 0.7, 'crawler', vents[vi].clone(), { drop: true }, () => A().grateFall(vents[vi])));
        },
        (e) => {
          const sp = L.points.arenaSentinels;
          e.spawnLater(0, 'sentinel', sp[0].clone(), {}, (s) => A().sentinelBoot(s.pos));
          e.spawnLater(0.8, 'sentinel', sp[1].clone(), {}, (s) => A().sentinelBoot(s.pos));
          e.spawnLater(2.5, 'crawler', vents[2].clone(), { drop: true }, () => A().grateFall(vents[2]));
          e.spawnLater(3.2, 'crawler', vents[5].clone(), { drop: true }, () => A().grateFall(vents[5]));
        },
        (e) => {
          // a held breath before the apex arrives
          A().setCombat(false);
          L.setGroup('alarm', 'off');
          A().duck(0.1, 0.5);
          e.later(1.2, () => A().stalkerStep(V(24, 0.1, -125)));
          e.later(2.0, () => A().stalkerStep(V(44, 0.1, -125)));
          e.later(2.6, () => A().whisper(V(34, 2, -130)));
          e.spawnLater(3.6, 'stalker', L.points.stalkerSpawn.clone(), {}, (s) => {
            H().boss(s, 'STALKER // BLOOM APEX');
            L.setGroup('alarm', 'emergency');
            A().setCombat(true); A().duck(1, 1);
            if (!g.flags.stalkerHint) { g.flags.stalkerHint = true; this.after(4, () => H().hint('It hides from the combat visor. Press <b>E</b> to see it. Scan it to learn how to fight it.', 8)); }
          });
        },
      ],
      clear: () => {
        A().setCombat(false);
        this.after(2.5, () => {
          L.setGroup('alarm', 'off');
          L.setGroup('arena', 'on'); A().lightsOn();
          A().stinger('clear'); A().setTension(0);
          H().message('THREAT NEUTRALIZED', 3);
          L.doors.d4.unlock(false);
          L.doors.d5.unlock();
          this.checkpoint = { pos: V(34, 0, -128), yaw: 0 };
        });
      },
      reset: () => {
        L.doors.d4.unlock(false);
        L.setGroup('arena', 'on'); L.setGroup('alarm', 'off');
        A().setCombat(false); A().duck(1, 0.5); A().setTension(0);
        g.hud.boss(null);
      },
    });
    this.encounters.arena.def.onEnrageSpawn = true;
    this.trigger([20, -132, 48, -104], () => this.encounters.arena.begin(), { id: 'arena' });
    // enraged stalker calls for help
    this.encounters.arena.onEnrage = () => {
      const enc = this.encounters.arena;
      enc.spawnLater(0.5, 'crawler', vents[0].clone(), { drop: true }, () => A().grateFall(vents[0]));
      enc.spawnLater(1.1, 'crawler', vents[3].clone(), { drop: true }, () => A().grateFall(vents[3]));
    };
  }

  leviathan() {
    const g = this.game;
    g.level.startLeviathan();
    this.after(2, () => g.audio.leviathanHorn());
    this.after(6, () => g.player.addShake(0.15));
  }

  // ======================================================================= flow
  start() {
    const g = this.game, H = g.hud, A = g.audio;
    H.fadeTo(0, 4);
    A.setZone('bay');
    g.controlsEnabled = false;
    this.after(1.2, () => { g.controlsEnabled = true; });
    this.after(2.2, () => H.area('ARRIVAL BAY 03', 'KUROGANE-9 // DOCKING RING C'));
    this.after(6.5, () => H.hint('<b>WASD</b> move &nbsp;·&nbsp; <b>MOUSE</b> look &nbsp;·&nbsp; <b>SPACE</b> jump', 6));
    this.after(14, () => { if (g.level.doors.d1.target === 0) H.hint('The door seal is dead. <b>LMB</b> to strike the lock open.', 7); });
    this.after(24, () => { if (!g.flags.scanHinted) H.hint('<b>E</b> scan visor: study your surroundings', 6); });
    this.visited.add('bay');
    this.zone = 'bay';
  }

  onDeath() {
    const g = this.game;
    g.stats.deaths++;
    g.controlsEnabled = false;
    document.getElementById('death').classList.remove('hidden');
    g.audio.setCombat(false);
    g.audio.duck(0.2, 0.3);
    this.after(3.2, () => this.respawn(true));
  }

  respawn(fromDeath) {
    const g = this.game;
    for (const enc of Object.values(this.encounters)) {
      if (enc.state === 'active') {
        enc.reset();
        for (const t of this.triggers) if (t.id && t.fn && t.id.startsWith(enc.id)) t.fired = false;
      }
    }
    g.player.respawn(this.checkpoint.pos, this.checkpoint.yaw);
    g.hud.boss(null);
    if (fromDeath) {
      document.getElementById('death').classList.add('hidden');
      g.hud.fadeTo(1, 0);
      this.after(0.2, () => g.hud.fadeTo(0, 1.5));
      g.audio.duck(1, 1);
      g.controlsEnabled = true;
    }
  }

  update(dt) {
    const g = this.game, P = g.player, L = g.level;
    this.time += dt;
    // timed events
    for (let i = this.events.length - 1; i >= 0; i--) {
      if (this.time >= this.events[i].t) { const e = this.events[i]; this.events.splice(i, 1); e.fn(); }
    }
    if (g.state !== 'playing') return;
    const p = P.position;
    // triggers
    for (const t of this.triggers) {
      if (t.fired && t.once) continue;
      const [x0, z0, x1, z1] = t.box;
      if (p.x >= x0 && p.x <= x1 && p.z >= z0 && p.z <= z1 && !P.dead) { t.fired = true; t.fn(); }
    }
    for (const enc of Object.values(this.encounters)) enc.update(dt);

    // zones
    const z = L.zoneAt(p);
    if (z && z.id !== this.zone) {
      this.zone = z.id;
      g.audio.setZone(z.amb);
      L.moonTarget = z.moon;
      const fog = FOG[z.id];
      if (fog) { g.fogTarget = fog.d; g.fogColorTarget.set(fog.c); g.exposureTarget = fog.e; g.envTarget = fog.env; }
      if (z.env) g.scene.environment = z.env;
      if (!this.visited.has(z.id)) {
        this.visited.add(z.id);
        if (z.title) g.hud.area(z.title, z.sub);
        const cps = {
          spine: { pos: V(0, 0, -14), yaw: 0 },
          atrium: { pos: V(17, 0, -38.5), yaw: -Math.PI / 2 },
          funnel: { pos: V(34, 0, -73), yaw: 0 },
          final: { pos: V(34, 0, -135), yaw: 0 },
        };
        if (cps[z.id]) this.checkpoint = cps[z.id];
      }
    }
    if (this.zone === 'atrium') {
      this.atriumTime += dt;
      if (this.atriumTime > 45) { const t = this.triggers.find((t) => t.id === 'leviathan'); if (t && !t.fired) { t.fired = true; this.leviathan(); } }
    }

    // ambient tension follows threat when not scripted
    const threat = g.enemies.threatLevel(p);
    if (this.zone !== 'funnel' || threat > 0) g.audio.setTension(threat * 0.9);

    // the lift
    if (this.zone === 'final' && L.doors.d5 && !L.doors.d5.locked) {
      const d = Math.hypot(p.x - L.points.liftCenter.x, p.z - L.points.liftCenter.z);
      if (d < 2.2 && P.onGround) {
        this.onLift += dt;
        if (this.onLift > 1.2 && !this.ending) this.endSequence();
      } else this.onLift = 0;
    }
  }

  endSequence() {
    const g = this.game;
    this.ending = true;
    g.controlsEnabled = false;
    g.audio.doorClose(g.level.points.liftCenter);
    g.audio.leviathanHorn();
    g.state = 'ending';
    g.hud.message('DESCENDING', 4);
    const startY = g.player.position.y;
    const t0 = this.time;
    const sink = () => {
      const k = this.time - t0;
      g.player.position.y = startY - k * k * 0.6;
      g.player.vel.set(0, 0, 0);
      if (k < 7) requestAnimationFrame(sink);
    };
    sink();
    this.after(2.5, () => g.hud.fadeTo(1, 4));
    this.after(7, () => {
      const secs = Math.round((performance.now() - g.stats.start) / 1000);
      const scans = g.level.scannables.filter((s) => s.scanned).length + g.scannedTypes.size;
      document.getElementById('end-stats').textContent =
        `TIME ${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}  ·  DEATHS ${g.stats.deaths}  ·  SCANS ${scans}/${g.level.scannables.length + 3}`;
      document.getElementById('end').classList.remove('hidden');
      g.audio.duck(0.3, 2);
      g.audio.setCombat(false);
      document.exitPointerLock();
    });
  }
}
