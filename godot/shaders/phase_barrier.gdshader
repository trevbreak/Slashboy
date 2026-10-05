shader_type spatial;
// Crackling hex energy wall. Only a Phase Step dash passes through.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.12, 0.3);
varying vec3 wp;

float hex(vec2 p) {
	p.x *= 1.1547; p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}
float h1(float x) { return fract(sin(x * 91.7) * 4375.5); }

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 uv = vec2(wp.x + wp.z, wp.y) * 2.2;
	float e = 1.0 - smoothstep(0.0, 0.08, hex(uv));
	float scan = 0.5 + 0.5 * sin(wp.y * 8.0 - TIME * 5.0);
	float arc = step(0.985, h1(floor(TIME * 18.0) + floor(uv.y * 3.0))) * 2.0;
	float fr = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	ALBEDO = color * (0.06 + e * (0.35 + scan * 0.35) + fr * 0.4 + arc);
}
