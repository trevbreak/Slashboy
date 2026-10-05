shader_type spatial;
// Active camouflage: refracts what's behind it via the screen texture, with a shimmering
// fresnel edge. "reveal" (scan visor) turns it into a hot thermal silhouette.
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float reveal = 0.0;
uniform float flash = 0.0;
uniform float refraction = 0.05;
varying vec3 obj;

void vertex() { obj = VERTEX; }

void fragment() {
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float band = 0.5 + 0.5 * sin(obj.y * 22.0 - TIME * 6.0 + sin(obj.x * 9.0 + TIME) * 2.0);
	vec2 off = NORMAL.xy * refraction * (0.6 + band * 0.4);
	vec3 behind = texture(screen_tex, SCREEN_UV + off).rgb;
	vec3 shimmer = vec3(0.45, 0.65, 1.0) * fr * (0.03 + band * 0.07);
	vec3 thermal = mix(vec3(1.6, 0.5, 0.2), vec3(2.2, 1.6, 0.4), band) * (0.25 + fr * 1.2);
	ALBEDO = mix(behind + shimmer, thermal, reveal * 0.85) + vec3(flash);
	ALPHA = 1.0;
}
