shader_type spatial;
// Cheap night skyline for the backdrop: dark facades with procedurally lit windows. Windows come from world position
// (object space scaled to metres) so the shader works on any box size; per-instance colour (rgb) is the facade, alpha the fraction of lit windows.

uniform float window_width = 1.0;
uniform float floor_height = 1.6;
uniform float window_energy = 1.3;
uniform vec4 warm_light : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 cool_light : source_color = vec4(0.45, 0.85, 1.0, 1.0);

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 tint;
varying flat float inst;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	// Object space scaled to metres (the instance size arrives in INSTANCE_CUSTOM.xyz); y = height above the ground.
	wpos = VERTEX * INSTANCE_CUSTOM.xyz + vec3(0.0, INSTANCE_CUSTOM.y * 0.5, 0.0);
	wnrm = NORMAL;
	tint = COLOR;
	inst = float(INSTANCE_ID);
}

void fragment() {
	float wall = 1.0 - step(0.5, abs(wnrm.y));
	vec2 cell = vec2((wpos.x + wpos.z) / window_width, wpos.y / floor_height);
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float win = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75) * step(1.0, id.y);
	float r = hash21(id + inst * 7.31);
	float lit = step(1.0 - tint.a, r) * win * wall;
	vec3 light_col = mix(warm_light.rgb, cool_light.rgb, step(0.85, hash21(id * 1.7 + inst)));
	ALBEDO = tint.rgb * mix(1.0, 0.35, win * wall);
	ROUGHNESS = 0.85;
	EMISSION = light_col * lit * window_energy;
}
