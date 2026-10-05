shader_type canvas_item;
// Visor post-process over the final frame: aberration, grain, vignette, damage static,
// Kage Focus / scan visor grades, dash blur and Prime-style steam condensation.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float damage = 0.0;
uniform float stat = 0.0;
uniform float focus = 0.0;
uniform float scan = 0.0;
uniform float lowhp = 0.0;
uniform float dash = 0.0;
uniform float steam = 0.0;
uniform float fade = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	uv = 0.5 + c * (1.0 - 0.03 * r2);
	float drop = 0.0;
	if (steam > 0.01) {
		vec2 g = uv * vec2(res.x / res.y, 1.0) * 14.0;
		vec2 id = floor(g); vec2 f = fract(g) - 0.5;
		float rnd = hash(id);
		vec2 o = vec2(hash(id + 3.1), hash(id + 7.7)) - 0.5;
		float d = length(f - o * 0.6);
		float rad = 0.12 + rnd * 0.22;
		drop = smoothstep(rad, rad * 0.6, d) * step(1.0 - steam, rnd + 0.15);
		uv += (f - o * 0.6) * drop * 0.05;
	}
	if (stat > 0.01) {
		float line = floor(uv.y * 90.0 + TIME * 40.0);
		float j = (hash(vec2(line, floor(TIME * 30.0))) - 0.5) * stat * 0.04;
		uv.x += j * step(0.6, hash(vec2(line * 1.3, floor(TIME * 20.0))));
	}
	float ab = 0.0008 + damage * 0.01 + focus * 0.003 + dash * 0.006 + r2 * 0.004;
	vec3 col;
	if (dash > 0.01) {
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 6; i++) {
			vec2 u = 0.5 + (uv - 0.5) * (1.0 - float(i) * 0.012 * dash);
			acc += vec3(texture(screen_tex, u + c * ab).r, texture(screen_tex, u).g, texture(screen_tex, u - c * ab).b);
		}
		col = acc / 6.0;
	} else {
		col = vec3(texture(screen_tex, uv + c * ab).r, texture(screen_tex, uv).g, texture(screen_tex, uv - c * ab).b);
	}
	if (steam > 0.01) {
		vec3 b = vec3(0.0);
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785;
			b += texture(screen_tex, uv + vec2(cos(a), sin(a) * res.x / res.y) * 0.012 * steam).rgb;
		}
		b = b / 8.0 + vec3(0.06, 0.07, 0.08) * steam;
		col = mix(col, b, steam * 0.85 * (1.0 - drop));
		col += drop * 0.04;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * vec3(0.85, 0.9, 1.25), focus * 0.65);
	col = mix(col, vec3(l * 1.3, l * 0.95, l * 0.5) + vec3(0.02, 0.012, 0.0), scan * 0.55);
	col *= 1.0 - 0.03 * sin(uv.y * res.y * 1.5);
	col += (hash(uv * res + fract(TIME * 13.7) * 100.0) - 0.5) * (0.028 + stat * 0.25);
	float vig = smoothstep(0.85, 0.2, length(c * vec2(1.1, 1.0)));
	col *= mix(0.72, 1.0, vig);
	float edge = smoothstep(0.15, 0.75, length(c));
	col = mix(col, vec3(0.6, 0.02, 0.05), edge * (damage * 0.7 + lowhp * (0.25 + 0.15 * sin(TIME * 6.0))));
	col *= 1.0 - fade;
	COLOR = vec4(col, 1.0);
}
