shader_type spatial;
// Molten metal: flowing glowing channels between cooling crust plates.
render_mode cull_disabled;
uniform vec2 flow = vec2(0.0, 0.25);
uniform float heat = 1.0;
varying vec3 wp;

float h2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float s = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { s += n2(p) * a; p *= 2.03; a *= 0.5; } return s; }

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wp.xz * 0.35 + flow * TIME;
	float n = fbm(p + fbm(p * 1.7 - TIME * 0.05) * 1.5);
	float crust = smoothstep(0.42, 0.62, n);
	vec3 hot = mix(vec3(1.0, 0.25, 0.02), vec3(1.0, 0.75, 0.2), smoothstep(0.2, 0.0, abs(n - 0.42)));
	ALBEDO = mix(vec3(0.05, 0.02, 0.01), vec3(0.02, 0.015, 0.012), crust);
	ROUGHNESS = mix(0.4, 0.95, crust);
	EMISSION = hot * (1.0 - crust) * 4.5 * heat + vec3(0.3, 0.05, 0.0) * crust * 0.3;
}
