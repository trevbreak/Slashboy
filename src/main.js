import * as THREE from 'three';
import { fogParams } from './fog.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { createPipeline } from './post.js';
import { AudioEngine } from './audio.js';
import { Input } from './input.js';
import { buildLevel } from './level.js';
import { Player } from './player.js';
import { EnemyManager } from './enemies.js';
import { HUD } from './hud.js';
import { FX } from './fx.js';
import { Director } from './director.js';

const canvas = document.getElementById('game');

const game = {
  state: 'title',
  flags: {},
  scannedTypes: new Set(),
  controlsEnabled: false,
  hitStopT: 0,
  stats: { deaths: 0, start: 0 },
  fogTarget: 0.04,
  fogColorTarget: new THREE.Color(0x111a24),
  exposureTarget: 1.45,
  envTarget: 0.7,
  steamV: 0,
};
window.SLASHBOY = game; // handy for debugging in the console

// ---------------------------------------------------------------- scene & cameras
const scene = game.scene = new THREE.Scene();
scene.background = new THREE.Color(0x010204);
scene.fog = new THREE.FogExp2(0x111a24, 0.04);
const camera = game.camera = new THREE.PerspectiveCamera(75, innerWidth / innerHeight, 0.05, 3500);
camera.rotation.order = 'YXZ';
const vmScene = game.vmScene = new THREE.Scene();
const vmCamera = game.vmCamera = new THREE.PerspectiveCamera(55, innerWidth / innerHeight, 0.01, 10);

const pipe = createPipeline(canvas, scene, camera, vmScene, vmCamera);
game.renderer = pipe.renderer;
game.visor = pipe.visor;
game.pipe = pipe;
const QUALITY_NAMES = Object.keys(pipe.QUALITY);
game.quality = new URLSearchParams(location.search).get('quality')?.toUpperCase() || 'HIGH';
if (!pipe.QUALITY[game.quality]) game.quality = 'HIGH';
pipe.setQuality(game.quality);

// faint environment so metals catch some sheen in the dark
const pmrem = new THREE.PMREMGenerator(game.renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.06;

// ---------------------------------------------------------------- systems
game.audio = new AudioEngine();
game.input = new Input(canvas);
game.fx = new FX(game);
game.hud = new HUD(game);
game.level = buildLevel(game);
game.enemies = new EnemyManager(game);
game.player = new Player(game);
game.director = new Director(game);

game.hitStop = (t) => { game.hitStopT = Math.max(game.hitStopT, t); };
game.onPlayerDeath = () => game.director.onDeath();
game.respawnAtCheckpoint = () => game.director.respawn(false);

game.player.respawn(game.level.points.start, 0);
game.player.updateCamera(0.016);

// per-zone reflection probes (rooms reflect themselves: neon in puddles, light on metal)
game.level.bakeProbes(game.renderer);
const bayZone = game.level.zones.find((z) => z.id === 'bay');
scene.environment = bayZone.env;
scene.environmentIntensity = game.envTarget;
console.info('[slashboy] merged', game.level.mergedCount);

// warm up shaders while the title is showing
game.renderer.compile(scene, camera);

// ---------------------------------------------------------------- UI flow
const $ = (id) => document.getElementById(id);

$('start-btn').addEventListener('click', () => {
  game.audio.init();
  game.input.requestLock();
  $('title').classList.add('hidden');
  game.hud.show();
  game.state = 'playing';
  game.stats.start = performance.now();
  game.director.start();
});

game.input.onLockChange = (locked) => {
  if (!locked && game.state === 'playing') {
    game.state = 'paused';
    $('pause').classList.remove('hidden');
    game.audio.suspend();
  } else if (locked && game.state === 'paused') {
    game.state = 'playing';
    $('pause').classList.add('hidden');
    game.audio.resume();
  }
};
$('pause').addEventListener('click', () => game.input.requestLock());
canvas.addEventListener('click', () => { if (game.state === 'playing' && !game.input.locked) game.input.requestLock(); });

// ---------------------------------------------------------------- loop
const clock = new THREE.Clock();
let focusV = 0, scanV = 0;

function frame() {
  requestAnimationFrame(frame);
  const realDt = Math.min(0.05, clock.getDelta());
  const P = game.player;

  if (game.input.just('KeyG')) {
    game.quality = QUALITY_NAMES[(QUALITY_NAMES.indexOf(game.quality) + 1) % QUALITY_NAMES.length];
    pipe.setQuality(game.quality);
    game.hud.message(`GRAPHICS: ${game.quality}`, 1.5);
  }

  if (game.state === 'playing' || game.state === 'ending') {
    let ws = P.focusActive ? 0.3 : 1;
    let ps = P.focusActive ? 0.85 : 1;
    if (game.hitStopT > 0) { game.hitStopT -= realDt; ws *= 0.04; ps *= 0.15; }
    const wdt = realDt * ws;

    if (game.state === 'ending') P.updateCamera(realDt);
    else P.update(realDt * ps, realDt);
    game.enemies.update(wdt);
    game.level.update(wdt, P.position);
    game.fx.update(wdt, camera.position, P);
    game.director.update(realDt);
    game.hud.update(realDt);
    game.audio.update(realDt, camera, P.position);

    // fog / exposure / ambient transitions between zones
    const zk = Math.min(1, realDt * 0.8);
    scene.fog.density += (game.fogTarget - scene.fog.density) * zk;
    scene.fog.color.lerp(game.fogColorTarget, zk);
    game.renderer.toneMappingExposure += (game.exposureTarget - game.renderer.toneMappingExposure) * zk;
    scene.environmentIntensity += (game.envTarget - scene.environmentIntensity) * zk;
    fogParams.x += realDt;

    // dust catches nearby light; steam vents fog the visor
    game.fx.setDustLights(game.level.pool, P.bladeLight);
    const vents = game.level.points.steamVents;
    game.fx.steam(vents, camera.position, wdt);
    let nearSteam = false;
    for (const v of vents) if (Math.hypot(P.position.x - v.x, P.position.z - v.z) < 1.1 && P.position.y < 2) nearSteam = true;
    game.steamV = nearSteam ? Math.min(1, game.steamV + realDt * 1.6) : Math.max(0, game.steamV - realDt * 0.3);
    pipe.visor.steam.value = game.steamV;

    focusV += ((P.focusActive ? 1 : 0) - focusV) * Math.min(1, realDt * 6);
    scanV += ((P.scanMode ? 1 : 0) - scanV) * Math.min(1, realDt * 8);
    const u = game.visor;
    u.time.value += realDt;
    u.damage.value = game.hud.damageV;
    u.stat.value = P.statV;
    u.focus.value = focusV;
    u.scan.value = scanV;
    u.lowhp.value = P.hp < 30 ? 1 : 0;
    u.dash.value = P.dashV;
  } else if (game.state === 'title') {
    // slow idle drift so the first frame after start is warm
    game.level.update(realDt * 0.2, P.position);
  }

  pipe.composer.render();
  pipe.adapt(realDt);
  game.input.endFrame();
}
frame();
