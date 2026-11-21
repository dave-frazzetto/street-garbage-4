shader_type spatial;
render_mode cull_disabled;
// Chain-link mesh: a diamond lattice cut out with alpha scissor (cheap, no sorting), with a faint sodium-lamp sheen.

uniform vec4 wire_color : source_color = vec4(0.45, 0.47, 0.5, 1.0);
uniform vec4 sheen_color : source_color = vec4(1.0, 0.62, 0.2, 1.0);
uniform float sheen_strength : hint_range(0.0, 1.0) = 0.12;
// Panel size in metres (set by the Fence script) so the lattice keeps its proportions at any length.
uniform vec2 panel_size = vec2(10.0, 2.5);
uniform float cell_size = 0.35;
uniform float wire_width : hint_range(0.02, 0.5) = 0.14;

void fragment() {
	vec2 m = UV * panel_size / cell_size;
	vec2 dg = vec2(m.x + m.y, m.x - m.y) * 0.5;
	vec2 f = abs(fract(dg) - 0.5);
	float w = fwidth(dg.x) + 0.0001;
	float dist = min(0.5 - f.x, 0.5 - f.y);
	float a = 1.0 - smoothstep(wire_width * 0.5, wire_width * 0.5 + w * 1.5, dist);
	ALPHA = a;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ALBEDO = wire_color.rgb;
	METALLIC = 0.7;
	ROUGHNESS = 0.45;
	EMISSION = sheen_color.rgb * sheen_strength * a;
}
