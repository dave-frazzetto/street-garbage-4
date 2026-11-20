shader_type spatial;
// Wet night asphalt with a faint grid of paving joints.

uniform vec4 base_color : source_color = vec4(0.11, 0.11, 0.13, 1.0);
uniform vec4 line_color : source_color = vec4(0.16, 0.16, 0.18, 1.0);
uniform float grid_step = 5.0;
uniform float line_width = 0.06;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = abs(fract(world_pos.xz / grid_step - 0.5) - 0.5) * grid_step;
	float line = 1.0 - smoothstep(line_width * 0.5, line_width, min(cell.x, cell.y));
	ALBEDO = mix(base_color.rgb, line_color.rgb, line);
	ROUGHNESS = 0.45;
	SPECULAR = 0.6;
}
