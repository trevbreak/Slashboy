shader_type spatial;
// Additive billboard glow (streaks, bolts, beacons, pickups). Scale non-uniformly for streaks.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform vec3 color : source_color = vec3(1.0);
uniform float gain = 1.0;
uniform bool billboard = true;
uniform bool depth_test = true;

void vertex() {
	if (billboard) {
		vec3 sx = vec3(length(MODEL_MATRIX[0].xyz), 0.0, 0.0);
		float sy = length(MODEL_MATRIX[1].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx.x, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}

void fragment() {
	ALBEDO = color * gain * texture(tex, UV).a;
}
