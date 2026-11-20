shader_type spatial;
// A painted area on the ground (basketball court, quarantine zone): fill, border and optional hazard stripes.

uniform vec4 fill_color : source_color = vec4(0.5, 0.28, 0.16, 0.8);
uniform vec4 line_color : source_color = vec4(1.0, 1.0, 1.0, 0.6);
uniform vec2 size = vec2(16.0, 9.5);
uniform float border = 0.15;
uniform bool striped = false;
uniform bool court_markings = true;

void fragment() {
	vec2 p = UV * size;
	float edge = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));
	vec3 col = fill_color.rgb;
	float a = fill_color.a;
	if (striped && edge < 1.0) {
		float s = step(0.5, fract((p.x + p.y) / 1.5));
		col = mix(vec3(0.05), vec3(1.0, 0.8, 0.1), s);
		a = 0.9;
	}
	if (court_markings) {
		vec2 c = p - size * 0.5;
		float centre_line = 1.0 - step(border * 0.5, abs(c.x));
		float circle = 1.0 - step(border * 0.5, abs(length(c) - min(size.x, size.y) * 0.18));
		float m = max(centre_line, circle);
		col = mix(col, line_color.rgb, m * line_color.a);
	}
	if (edge < border) {
		col = mix(col, line_color.rgb, line_color.a);
		a = max(a, line_color.a);
	}
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = 0.7;
}
