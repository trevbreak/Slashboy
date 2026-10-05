shader_type spatial;
// Phantom hologram: translucent cyan scanlines, solidifies (brighter, opaque edges) while casting.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float solid = 0.0;
uniform vec3 tint_a = vec3(0.25, 0.8, 1.2);
uniform vec3 tint_b = vec3(0.9, 1.6, 2.4);
uniform float decoy = 0.0;
uniform float fade = 1.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float scan = 0.5 + 0.5 * sin(wp.y * 40.0 - TIME * 6.0);
	float glitch = step(0.97, fract(sin(floor(TIME * 12.0) * 91.3 + floor(wp.y * 6.0)) * 437.1));
	vec3 c = mix(tint_a, tint_b, solid);
	c = mix(c, vec3(1.6, 0.15, 0.1), decoy);
	float g2 = decoy * step(0.6, fract(sin(floor(TIME * 20.0) * 13.1 + floor(wp.y * 3.0)) * 917.3));
	ALBEDO = c * (0.05 + fr * (0.5 + solid) + scan * 0.08 + glitch * 0.6 + g2) * (0.6 + solid * 0.8) * fade * (1.0 - g2 * 0.7);
}
