shader_type spatial;
// Katana plasma edge flowing toward the tip.
render_mode unshaded, shadows_disabled, fog_disabled, cull_disabled;
uniform vec3 color : source_color = vec3(0.3, 1.6, 2.1);
uniform float flow_t = 0.0;

void fragment() {
	float y = UV.y;
	float flow = 0.65 + 0.35 * sin(y * 90.0 - flow_t * 18.0) * sin(y * 23.0 - flow_t * 7.0);
	float tip = smoothstep(1.0, 0.85, y) * smoothstep(0.0, 0.05, y);
	ALBEDO = color * flow * (0.6 + tip * 0.6);
}
