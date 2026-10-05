shader_type spatial;
// Additive, camera-facing glow quad for burst particles. HDR vertex color drives bloom.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform sampler2D tex : source_color, filter_linear;
varying float fade;

void vertex() {
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s, INV_VIEW_MATRIX[1] * s, INV_VIEW_MATRIX[2] * s, MODEL_MATRIX[3]);
	fade = INSTANCE_CUSTOM.w;
}

void fragment() {
	float a = texture(tex, UV).a;
	ALBEDO = COLOR.rgb * a * fade;
}
