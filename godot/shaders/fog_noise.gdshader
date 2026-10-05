shader_type fog;
// Drifting, height-weighted volumetric fog for a FogVolume (lights scatter through it).
uniform float density : hint_range(0.0, 8.0) = 1.0;
uniform vec4 albedo : source_color = vec4(0.8, 0.85, 0.95, 1.0);
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float height_falloff = 0.35;
uniform float base_y = 0.0;
uniform float noise_scale = 0.18;
uniform float edge_fade = 0.15;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fog() {
	vec3 p = WORLD_POSITION;
	float t = TIME;
	float n = vn(p * noise_scale + vec3(t * 0.04, -t * 0.015, t * 0.025)) * 0.65
	        + vn(p * noise_scale * 2.7 + vec3(-t * 0.06, t * 0.02, 0.0)) * 0.35;
	float h = exp(-max(p.y - base_y, 0.0) * height_falloff);
	vec3 e = abs(UVW - 0.5) * 2.0;
	float edge = smoothstep(0.0, edge_fade, 1.0 - max(max(e.x, e.y), e.z));
	DENSITY = density * (0.2 + h) * (0.35 + n * 1.3) * edge;
	ALBEDO = albedo.rgb;
	EMISSION = emission.rgb;
}
