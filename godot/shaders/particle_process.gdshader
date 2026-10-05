shader_type particles;
// CPU-emitted bursts (GPUParticles3D.emit_particle): gravity, drag, floor bounce, fade.
// CUSTOM.x = lifetime scale (set at emit), CUSTOM.y = age, CUSTOM.w = fade (read by draw shader)
uniform float gravity = 9.0;
uniform float drag = 1.0;
uniform float floor_y = 0.02;
uniform bool bounce = true;

void start() {
	// only particles emitted from code (with an explicit velocity) live; auto-spawns die at birth
	if (RESTART_VELOCITY) { ACTIVE = false; }
	CUSTOM.y = 0.0;
	CUSTOM.w = 1.0;
	if (CUSTOM.x <= 0.0) { CUSTOM.x = 1.0; }
}

void process() {
	CUSTOM.y += DELTA;
	float life = CUSTOM.y / (LIFETIME * CUSTOM.x);
	VELOCITY.y -= gravity * DELTA;
	VELOCITY *= max(0.0, 1.0 - drag * DELTA);
	if (bounce && TRANSFORM[3].y < floor_y && VELOCITY.y < 0.0) {
		TRANSFORM[3].y = floor_y;
		VELOCITY.y *= -0.3;
	}
	CUSTOM.w = clamp(1.0 - life, 0.0, 1.0);
	if (life >= 1.0) { ACTIVE = false; }
}
