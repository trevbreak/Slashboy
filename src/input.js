export class Input {
  constructor(canvas) {
    this.canvas = canvas;
    this.keys = new Set();
    this.pressed = new Set();
    this.mouseDown = [false, false, false];
    this.mousePressed = [false, false, false];
    this.mouseReleased = [false, false, false];
    this.dx = 0; this.dy = 0;
    this.locked = false;
    this.sensitivity = 0.0022;

    window.addEventListener('keydown', (e) => {
      if (e.repeat) return;
      if (['Space', 'Tab', 'ShiftLeft', 'ShiftRight'].includes(e.code)) e.preventDefault();
      this.keys.add(e.code); this.pressed.add(e.code);
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => { this.keys.clear(); this.mouseDown = [false, false, false]; });
    document.addEventListener('mousemove', (e) => {
      if (!this.locked) return;
      // ignore absurd spikes some browsers emit on pointer lock
      if (Math.abs(e.movementX) > 300 || Math.abs(e.movementY) > 300) return;
      this.dx += e.movementX; this.dy += e.movementY;
    });
    document.addEventListener('mousedown', (e) => {
      if (!this.locked) return;
      this.mouseDown[e.button] = true; this.mousePressed[e.button] = true;
    });
    document.addEventListener('mouseup', (e) => {
      if (this.mouseDown[e.button]) this.mouseReleased[e.button] = true;
      this.mouseDown[e.button] = false;
    });
    document.addEventListener('contextmenu', (e) => e.preventDefault());
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === this.canvas;
      if (!this.locked) { this.mouseDown = [false, false, false]; this.keys.clear(); }
      if (this.onLockChange) this.onLockChange(this.locked);
    });
  }

  requestLock() {
    const p = this.canvas.requestPointerLock({ unadjustedMovement: true });
    if (p && p.catch) p.catch(() => this.canvas.requestPointerLock());
  }

  down(code) { return this.keys.has(code); }
  just(code) { return this.pressed.has(code); }

  endFrame() {
    this.pressed.clear();
    this.mousePressed = [false, false, false];
    this.mouseReleased = [false, false, false];
    this.dx = 0; this.dy = 0;
  }
}
