shader_type spatial;
// Organic flesh: PBR skin, sheen-like rim and glowing veins that pulse along the body.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.7, 0.35, 0.8);
uniform float uv_scale = 2.0;
uniform vec3 vein_color : source_color = vec3(0.7, 0.25, 1.0);
uniform float vein_strength = 2.6;
uniform float vein_freq = 6.0;
uniform float pulse_speed = 2.4;
uniform vec3 rim_color : source_color = vec3(0.8, 0.3, 1.0);
uniform float rim = 0.4;
uniform float roughness = 0.6;
uniform float metallic = 0.0;
uniform float clearcoat = 0.6;
uniform float flash = 0.0;
varying vec3 obj;

float h3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vn(vec3 x) {
	vec3 i = floor(x); vec3 f = fract(x); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() { obj = VERTEX; }

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 orm = texture(orm_tex, uv).rgb;
	ALBEDO = texture(albedo_tex, uv).rgb * tint * 2.0;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	ROUGHNESS = roughness * (0.5 + orm.g);
	METALLIC = metallic;
	AO = orm.r;
	CLEARCOAT = clearcoat;
	CLEARCOAT_ROUGHNESS = 0.3;
	vec3 q = obj * vein_freq;
	float n1 = vn(q + vec3(0.0, TIME * 0.05, 0.0));
	float n2 = vn(q * 2.3 + 4.1);
	float v = (1.0 - smoothstep(0.0, 0.045, abs(n1 - 0.5))) + (1.0 - smoothstep(0.0, 0.03, abs(n2 - 0.5))) * 0.55;
	float pulse = 0.45 + 0.55 * pow(0.5 + 0.5 * sin(TIME * pulse_speed - obj.z * 7.0 - obj.y * 3.0), 2.0);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vein_color * v * pulse * vein_strength + rim_color * fr * rim + vec3(flash * 2.5);
}
