shader_type spatial;
// Beetle-like armour: PBR skin + clearcoat + thin-film iridescence (view-angle hue shift).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D orm_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(0.55, 0.45, 0.65);
uniform float uv_scale = 2.0;
uniform float iridescence = 0.85;
uniform float flash = 0.0;
uniform vec3 emissive : source_color = vec3(0.0);

vec3 film(float x) {
	// cheap thin-film palette: cycles through teal / violet / gold
	return 0.5 + 0.5 * cos(6.28318 * (vec3(0.0, 0.33, 0.67) + x));
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 orm = texture(orm_tex, uv).rgb;
	vec3 base = texture(albedo_tex, uv).rgb * tint * 2.0;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 irid = film(ndv * 1.6 + 0.2);
	ALBEDO = mix(base, base * 0.3 + irid * 0.5, iridescence * (1.0 - ndv * 0.6));
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.9;
	ROUGHNESS = mix(0.25, 0.7, orm.g);
	METALLIC = 0.55;
	AO = orm.r;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.15;
	EMISSION = emissive + vec3(flash * 2.5);
}
