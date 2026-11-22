shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_premul_alpha;
// Expanding ground ring (explosion shockwave). Use it on a quad mesh lying flat (orientation Face Y) and let the
// emitter's scale curve grow it. Fade comes from the colour ramp.

/** 1 adds light, 0 is normal alpha blending. */
uniform float additive : hint_range(0.0, 1.0) = 1.0;
uniform float intensity : hint_range(0.0, 8.0) = 2.0;
/** Ring thickness as a fraction of its radius. */
uniform float thickness : hint_range(0.02, 0.6) = 0.18;

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float inner = smoothstep(1.0 - thickness, 1.0 - thickness * 0.35, r);
	float outer = 1.0 - smoothstep(1.0 - thickness * 0.35, 1.0, r);
	float a = inner * outer * COLOR.a;
	ALBEDO = COLOR.rgb * intensity * a;
	ALPHA = a * (1.0 - additive);
}
