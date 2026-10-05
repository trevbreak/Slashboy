shader_type spatial;
// Flickering scanline hologram showing a text panel rendered by a SubViewport.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform vec3 color : source_color = vec3(0.4, 1.0, 1.0);
uniform float gain = 2.2;
uniform float seed = 0.0;

float rnd(float x) { return fract(sin(x * 43.7) * 917.3); }

void vertex() {
	float glitch = step(0.985, rnd(floor(TIME * 9.0 + seed)));
	VERTEX.x += glitch * (rnd(floor(UV.y * 20.0) + TIME) - 0.5) * 0.15;
}

void fragment() {
	vec2 uv = UV;
	float band = step(0.97, fract(uv.y * 3.0 - TIME * 0.35 + seed));
	uv.x += band * 0.01;
	float t = texture(tex, uv).a;
	float scan = 0.65 + 0.35 * sin(uv.y * 300.0 - TIME * 8.0);
	float flick = 0.85 + 0.15 * sin(TIME * 37.0 + seed) * sin(TIME * 13.0);
	float edge = smoothstep(0.0, 0.05, uv.y) * smoothstep(1.0, 0.95, uv.y);
	ALBEDO = color * gain * (t * scan * flick + band * 0.15 + 0.025) * edge;
}
