shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha;
// Velocity-stretched streak for sparks and blood drops. The emitter must have "Align Y" on, which points the particle's
// Y axis along its velocity; this shader keeps that axis and turns the quad to face the camera around it. The quad mesh
// is long and thin (see streak_quad.tres), so fast particles read as streaks with a bright head and a fading tail.

group_uniforms look;
/** 1 adds light (sparks). 0 is normal alpha blending (blood). */
uniform float additive : hint_range(0.0, 1.0) = 1.0;
/** Brightness multiplier. Above 1 feeds the glow post effect. */
uniform float intensity : hint_range(0.0, 8.0) = 3.0;
/** Multiplies the emitter's colour ramp. Set from code to recolour a shared effect (bullet colour). */
uniform vec4 tint : source_color = vec4(1.0);
/** How fast the streak fades from head to tail. Higher is a shorter bright head. */
uniform float tail_falloff : hint_range(0.2, 4.0) = 1.4;

void vertex() {
	vec3 y_axis = MODEL_MATRIX[1].xyz;
	float length_y = length(y_axis);
	vec3 along = y_axis / max(length_y, 0.00001);
	vec3 to_camera = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	vec3 across = normalize(cross(along, to_camera));
	vec3 depth_axis = cross(across, along);
	float width = length(MODEL_MATRIX[0].xyz);
	mat4 aligned = mat4(vec4(across * width, 0.0), vec4(along * length_y, 0.0), vec4(depth_axis, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * aligned;
}

void fragment() {
	float side = 1.0 - abs(UV.x * 2.0 - 1.0);
	float head_to_tail = pow(clamp(1.0 - UV.y, 0.0, 1.0), tail_falloff);
	float a = smoothstep(0.0, 0.6, side) * head_to_tail * COLOR.a * tint.a;
	ALBEDO = COLOR.rgb * tint.rgb * intensity * a;
	ALPHA = a * (1.0 - additive);
}
