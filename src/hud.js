import * as THREE from 'three';

const $ = (id) => document.getElementById(id);

export class HUD {
  constructor(game) {
    this.game = game;
    this.el = {
      hud: $('hud'), vitals: $('vitals'), hpNum: $('hp-num'), hpBar: $('hp-bar'), hpGhost: $('hp-ghost'), kiBar: $('ki-bar'),
      threat: $('threat-fill'), mode: $('visor-mode'), reticle: $('reticle'), lock: $('lock'),
      chargeRing: $('charge-ring'), chargeArc: $('charge-arc'),
      markers: $('scan-markers'), scanProg: $('scan-progress'), scanFill: $('scan-fill'),
      scanPanel: $('scan-panel'), scanTitle: $('scan-title'), scanText: $('scan-text'),
      boss: $('boss'), bossName: $('boss-name'), bossFill: $('boss-fill'),
      area: $('area-name'), msg: $('message'), hint: $('hint'), dmg: $('damage-flash'), focus: $('focus-overlay'), fade: $('fade'),
    };
    this.markerPool = [];
    this.msgTimer = 0; this.hintTimer = 0; this.areaTimer = 0;
    this.damageV = 0;
    this._v = new THREE.Vector3();
  }

  show() { this.el.hud.classList.remove('hidden'); }

  fadeTo(v, seconds = 2) {
    this.el.fade.style.transition = `opacity ${seconds}s`;
    this.el.fade.style.opacity = v;
  }

  area(title, sub) {
    this.el.area.innerHTML = `${title}<small>${sub || ''}</small>`;
    this.el.area.classList.add('show');
    this.areaTimer = 4;
  }

  message(text, seconds = 2.5, warn = false) {
    this.el.msg.textContent = text;
    this.el.msg.classList.toggle('warn', warn);
    this.el.msg.classList.add('show');
    this.msgTimer = seconds;
  }

  hint(text, seconds = 5) {
    this.el.hint.innerHTML = text;
    this.el.hint.classList.add('show');
    this.hintTimer = seconds;
  }

  damage(amount) {
    this.damageV = Math.min(1, this.damageV + amount / 30);
  }

  hitMarker() {
    const r = this.el.reticle;
    r.classList.add('hit');
    clearTimeout(this._hitT);
    this._hitT = setTimeout(() => r.classList.remove('hit'), 120);
  }

  boss(enemy, name) {
    this.bossEnemy = enemy;
    if (enemy) { this.el.bossName.textContent = name; this.el.boss.classList.remove('hidden'); }
    else this.el.boss.classList.add('hidden');
  }

  openScan(s) {
    this.el.scanTitle.textContent = s.title;
    this.el.scanText.textContent = s.text;
    this.el.scanPanel.classList.remove('hidden');
  }
  closeScan() { this.el.scanPanel.classList.add('hidden'); }

  project(p, camera) {
    const v = this._v.copy(p).project(camera);
    if (v.z > 1) return null;
    return { x: (v.x * 0.5 + 0.5) * window.innerWidth, y: (-v.y * 0.5 + 0.5) * window.innerHeight, behind: v.z > 1 };
  }

  update(dt) {
    const g = this.game, p = g.player, cam = g.camera;
    if (!p) return;
    // vitals
    const hp = Math.max(0, Math.ceil(p.hp));
    if (this._hp !== hp) {
      this.el.hpNum.textContent = String(hp).padStart(2, '0');
      this.el.hpBar.style.width = `${(p.hp / p.maxHp) * 100}%`;
      this.el.hpGhost.style.width = `${(p.hp / p.maxHp) * 100}%`;
      this.el.vitals.classList.toggle('low', p.hp < 30);
      this._hp = hp;
    }
    this.el.kiBar.style.width = `${p.ki}%`;
    // threat
    const threat = g.enemies.threatLevel(p.position);
    this.el.threat.style.width = `${threat * 100}%`;
    // visor mode
    this.el.mode.textContent = p.scanMode ? 'SCAN VISOR' : 'COMBAT VISOR';
    this.el.mode.classList.toggle('scan', p.scanMode);
    this.el.reticle.classList.toggle('scan', p.scanMode);

    // lock-on reticle
    if (p.lockTarget && p.lockTarget.alive) {
      const s = this.project(p.lockTarget.center(), cam);
      if (s) { this.el.lock.classList.remove('hidden'); this.el.lock.style.left = s.x + 'px'; this.el.lock.style.top = s.y + 'px'; }
      else this.el.lock.classList.add('hidden');
    } else this.el.lock.classList.add('hidden');

    // charge ring
    if (p.chargeT > 0.25) {
      this.el.chargeRing.classList.remove('hidden');
      const k = Math.min(1, (p.chargeT - 0.25) / (p.chargeNeed - 0.25));
      this.el.chargeArc.style.strokeDashoffset = `${251 * (1 - k)}`;
      this.el.chargeRing.classList.toggle('full', k >= 1);
    } else this.el.chargeRing.classList.add('hidden');

    // scan markers
    let used = 0;
    if (p.scanMode) {
      const items = g.player.scanCandidates || [];
      for (const it of items) {
        const s = this.project(it.pos, cam);
        if (!s) continue;
        let m = this.markerPool[used];
        if (!m) { m = document.createElement('div'); this.el.markers.appendChild(m); this.markerPool.push(m); }
        m.style.display = 'block';
        m.style.left = s.x + 'px'; m.style.top = s.y + 'px';
        m.className = (it.scanned ? 'done' : '') + (it === p.scanTarget ? ' target' : '') + (it.enemy ? ' enemy' : '');
        used++;
      }
    }
    for (let i = used; i < this.markerPool.length; i++) this.markerPool[i].style.display = 'none';

    // scan progress
    if (p.scanMode && p.scanProgress > 0 && p.scanTarget && !p.scanTarget.scanned) {
      this.el.scanProg.classList.remove('hidden');
      this.el.scanFill.style.width = `${p.scanProgress * 100}%`;
    } else this.el.scanProg.classList.add('hidden');

    // boss bar
    if (this.bossEnemy) {
      this.el.bossFill.style.width = `${Math.max(0, this.bossEnemy.hp / this.bossEnemy.maxHp) * 100}%`;
      if (!this.bossEnemy.alive) this.boss(null);
    }

    // timers
    if (this.msgTimer > 0) { this.msgTimer -= dt; if (this.msgTimer <= 0) this.el.msg.classList.remove('show'); }
    if (this.hintTimer > 0) { this.hintTimer -= dt; if (this.hintTimer <= 0) this.el.hint.classList.remove('show'); }
    if (this.areaTimer > 0) { this.areaTimer -= dt; if (this.areaTimer <= 0) this.el.area.classList.remove('show'); }

    this.damageV = Math.max(0, this.damageV - dt * 1.8);
    this.el.dmg.style.opacity = this.damageV;
    this.el.focus.style.opacity = p.focusActive ? 1 : 0;
  }
}
