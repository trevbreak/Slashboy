shader_type spatial;
// Sentinel eye: rotating ring segments, ripples and a pupil that contracts when charging.
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(0.4, 2.6, 3.6);
uniform float pupil = 0.25;
uniform float power = 0.6;

void fragment() {
	vec2 c = UV - 0.5; float r = length(c) * 2.0; float a = atan(c.y, c.x);
	float rings = 0.5 + 0.5 * sin(r * 40.0 - TIME * 3.0);
	float seg = step(0.5, fract(a * 6.0 / 6.2832 + TIME * 0.15)) * step(0.62, r) * step(r, 0.8);
	float iris = smoothstep(pupil, pupil + 0.05, r) * (1.0 - smoothstep(0.92, 1.0, r));
	vec3 col = color * (iris * (0.35 + 0.65 * rings) + seg * 0.8);
	col += vec3(1.0) * smoothstep(pupil + 0.03, pupil, r) * smoothstep(pupil - 0.06, pupil, r) * 2.0;
	if (r > 1.0) { discard; }
	ALBEDO = col * power;
}
