shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha;
// Camera-facing particle puff for fire, smoke, flashes and embers. A scrolling noise texture eats the puff away as it
// ages, so every particle burns out in its own ragged way instead of fading as a smooth disc. Output is premultiplied,
// so `additive` slides the same shader from "adds light" (fire) to "covers what is behind" (smoke).
// Colour and fade come from the emitter's colour ramp (vertex colour); the Inspector values here set the look.

group_uniforms look;
/** 1 adds light (fire, flash, embers). 0 is normal alpha blending (smoke, dust). */
uniform float additive : hint_range(0.0, 1.0) = 1.0;
/** Brightness multiplier. Above 1 feeds the glow post effect. */
uniform float intensity : hint_range(0.0, 8.0) = 1.5;
/** Width of the soft fade at the edge of the puff. */
uniform float edge_softness : hint_range(0.01, 1.0) = 0.45;
/** Stretches the puff along its up axis. Above 1 turns round puffs into flame tongues. */
uniform float stretch_y : hint_range(0.5, 4.0) = 1.0;

group_uniforms noise;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
/** 0 is a smooth disc, 1 is fully broken up by the noise. */
uniform float noise_strength : hint_range(0.0, 1.0) = 0.8;
uniform float noise_scale : hint_range(0.1, 4.0) = 1.0;
/** Noise drift per second. Negative y makes it flow upward like flame. */
uniform vec2 noise_scroll = vec2(0.0, -0.4);
/** How much of the puff the noise has eaten by the end of the particle's life. */
uniform float erosion : hint_range(0.0, 1.0) = 0.5;

group_uniforms soft_particles;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
/** Fade out within this distance (metres) of solid geometry, so puffs do not slice into the ground. 0 turns it off. */
uniform float soft_distance : hint_range(0.0, 4.0) = 0.6;

varying float v_age;
varying float v_seed;

void vertex() {
	// INSTANCE_CUSTOM from ParticleProcessMaterial: x = rotation angle, y = age as 0..1 of the lifetime.
	float s = INSTANCE_CUSTOM.x;
	vec3 right = INV_VIEW_MATRIX[0].xyz * cos(s) + INV_VIEW_MATRIX[1].xyz * sin(s);
	vec3 up = INV_VIEW_MATRIX[1].xyz * cos(s) - INV_VIEW_MATRIX[0].xyz * sin(s);
	float size_x = length(MODEL_MATRIX[0].xyz);
	float size_y = length(MODEL_MATRIX[1].xyz) * stretch_y;
	mat4 facing = mat4(vec4(right * size_x, 0.0), vec4(up * size_y, 0.0), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	v_age = INSTANCE_CUSTOM.y;
	v_seed = fract(float(INSTANCE_ID) * 0.61803399);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float radial = 1.0 - smoothstep(1.0 - edge_softness, 1.0, r);

	vec2 nuv = UV * noise_scale + vec2(v_seed * 5.31, v_seed * 9.17) + noise_scroll * (TIME + v_seed * 8.0);
	float n = texture(noise_tex, nuv).r;
	float field = radial * mix(1.0, n * 1.7, noise_strength);
	float cut = erosion * v_age;
	float shape = smoothstep(cut, cut + 0.25, field);

	vec4 col = COLOR;
	float a = shape * col.a;

	if (soft_distance > 0.0) {
		float depth = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth * 2.0 - 1.0);
#else
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
		vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		scene.xyz /= scene.w;
		a *= clamp((-scene.z - (-VERTEX.z)) / soft_distance, 0.0, 1.0);
	}

	vec3 rgb = col.rgb * intensity * mix(0.8, 1.3, n);
	ALBEDO = rgb * a;
	ALPHA = a * (1.0 - additive);
}
