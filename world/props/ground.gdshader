shader_type spatial;
// Night-time city street, fully procedural in world space (no textures, so it tiles forever and stays tiny).
// Streets run along a regular grid (centre lines every `street_spacing` m from `grid_origin`); everything between
// them is pavement. Streets get asphalt grain, cracks, repair patches, wet puddles, lane lines, crosswalks and
// manholes; pavement gets slabs and kerbs. `detailed` = false keeps only the cheap grain for mobile and web.

group_uniforms palette;
uniform vec4 asphalt_color : source_color = vec4(0.3, 0.3, 0.31, 1.0);
uniform vec4 patch_color : source_color = vec4(0.19, 0.19, 0.2, 1.0);
uniform vec4 pavement_color : source_color = vec4(0.3, 0.29, 0.3, 1.0);
uniform vec4 kerb_color : source_color = vec4(0.3, 0.29, 0.28, 1.0);
uniform vec4 centre_line_color : source_color = vec4(0.85, 0.62, 0.08, 1.0);
uniform vec4 lane_line_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 puddle_tint : source_color = vec4(0.05, 0.08, 0.13, 1.0);

group_uniforms layout;
uniform vec2 grid_origin = vec2(0.0, 0.0);
uniform float street_spacing = 20.0;
uniform float street_width = 10.0;
uniform float kerb_width = 0.35;
uniform float slab_size = 1.6;

group_uniforms wear;
uniform bool detailed = true;
uniform float grain_scale = 6.0;
uniform float crack_scale = 0.35;
uniform float crack_width = 0.035;
uniform float patch_amount : hint_range(0.0, 1.0) = 0.35;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.3;
uniform float puddle_scale = 0.045;

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 17.3));
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Gap between the nearest and second nearest worley points: thin lines along the cell borders (cracks).
float crack(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float dd = length(g + hash22(i + g) - f);
			if (dd < d1) {
				d2 = d1;
				d1 = dd;
			} else if (dd < d2) {
				d2 = dd;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec2 q = p - grid_origin;
	vec2 local = mod(q + street_spacing * 0.5, street_spacing) - street_spacing * 0.5; // offset from the nearest street centre lines
	vec2 d = abs(local);
	float half_w = street_width * 0.5;
	float in_x = step(d.x, half_w); // inside a street that runs along Z
	float in_z = step(d.y, half_w); // inside a street that runs along X
	float street = max(in_x, in_z);

	float grain = vnoise(p * grain_scale) * 0.6 + vnoise(p * grain_scale * 3.1) * 0.4;
	float rough = 0.55;
	float wet = 0.0;
	vec3 col;

	if (street > 0.5) {
		// Asphalt: fine grain, large blotchy mottling, light aggregate speckles and darker tyre-wear bands along the street.
		float mottle = vnoise(p * 0.45) * 0.6 + vnoise(p * 1.3) * 0.4;
		float speck = step(0.93, hash21(floor(p * 14.0)));
		float wear_band = vnoise(vec2(mix(q.x, q.y, in_x * (1.0 - in_z)) * 0.12, mix(d.y, d.x, in_x * (1.0 - in_z)) * 1.4));
		col = asphalt_color.rgb * (0.55 + 0.7 * grain) * (0.75 + 0.5 * mottle) * (0.85 + 0.3 * wear_band);
		col += vec3(0.1) * speck * grain;
		if (detailed) {
			// Repair patches: blocky darker areas with hard edges.
			vec2 pc = floor(p * 0.28);
			float patch_on = step(1.0 - patch_amount * 0.35, hash21(pc));
			vec2 pl = fract(p * 0.28);
			float inside = step(0.1, pl.x) * step(pl.x, 0.9) * step(0.1, pl.y) * step(pl.y, 0.9);
			col = mix(col, patch_color.rgb * (0.8 + 0.4 * grain), patch_on * inside);
			// Cracks, only in some areas.
			float cr = 1.0 - smoothstep(crack_width * 0.5, crack_width, crack(p * crack_scale) / crack_scale);
			cr *= step(0.55, vnoise(p * 0.15 + 9.0));
			col = mix(col, vec3(0.015), cr * 0.9);
			// Wet puddles: low roughness and a cold sky tint.
			float pn = vnoise(p * puddle_scale * 3.0) * 0.65 + vnoise(p * puddle_scale * 9.0) * 0.35;
			wet = smoothstep(1.0 - puddle_amount * 0.5, 1.0 - puddle_amount * 0.5 + 0.06, pn);
			col = mix(col, col * 0.55 + puddle_tint.rgb, wet);
		}
		rough = mix(0.62 - grain * 0.18, 0.05, wet);

		// Markings on straight segments only; the junction stays clear.
		float mark = 0.0;
		vec3 mark_col = lane_line_color.rgb;
		float straight_x = in_x * (1.0 - in_z); // street along Z: lanes depend on d.x, travel coordinate is q.y
		float straight_z = in_z * (1.0 - in_x);
		float across = mix(d.y, d.x, straight_x); // distance from the street centre line
		float travel = mix(q.x, q.y, straight_x); // coordinate along the street
		float cross_travel = mix(q.y, q.x, straight_x); // coordinate across the street (crosswalk bars)
		float along_d = mix(d.x, d.y, straight_x); // distance to the cross street centre
		if (straight_x + straight_z > 0.5) {
			float dbl = step(0.1, across) * step(across, 0.28);
			float dash = step(abs(across - half_w * 0.5), 0.07) * step(fract(travel / 3.0), 0.5);
			float edge_ln = step(abs(across - (half_w - 0.4)), 0.05);
			float cw = step(5.6, along_d) * step(along_d, 7.6) * step(fract(cross_travel), 0.5) * step(across, half_w - 0.8);
			if (dbl + dash + edge_ln > 0.0) {
				mark = 1.0;
				mark_col = dbl > 0.0 ? centre_line_color.rgb : lane_line_color.rgb;
			}
			if (cw > 0.0) {
				mark = 1.0;
				mark_col = lane_line_color.rgb * 1.15;
			}
		}
		// Worn paint: grain eats into the markings.
		mark *= smoothstep(0.25, 0.55, grain + 0.25);
		col = mix(col, mark_col * (0.55 + 0.45 * grain), mark * 0.9);
		rough = mix(rough, 0.5, mark);

		// One manhole in the middle of each straight segment, off the centre line.
		if (detailed && straight_x + straight_z > 0.5) {
			vec2 seg = mod(q, street_spacing) - street_spacing * 0.5; // offset from the middle of the block cell
			vec2 mh = mix(vec2(seg.x, local.y + 2.5), vec2(local.x - 2.5, seg.y), straight_x);
			float md = length(mh);
			float lid = 1.0 - smoothstep(0.42, 0.46, md);
			float ring = smoothstep(0.36, 0.40, md) * lid;
			col = mix(col, vec3(0.03, 0.03, 0.035) + ring * 0.09, lid);
			rough = mix(rough, 0.35, lid);
		}
	} else {
		// Pavement: slabs and a raised kerb along the street edges.
		vec2 sl = abs(fract(q / slab_size) - 0.5);
		float joint = 1.0 - smoothstep(0.0, 0.025, 0.5 - max(sl.x, sl.y));
		col = pavement_color.rgb * (0.75 + 0.5 * grain) * (0.9 + 0.2 * hash21(floor(q / slab_size)));
		col = mix(col, col * 0.45, joint);
		float edge = min(d.x - half_w, d.y - half_w); // both are positive here: distance to the nearest street edge
		float kerb = 1.0 - smoothstep(kerb_width, kerb_width + 0.04, edge);
		col = mix(col, kerb_color.rgb * (0.8 + 0.4 * grain), kerb);
		rough = 0.8 - grain * 0.2;
		if (detailed) {
			float pn = vnoise(p * puddle_scale * 5.0 + 3.0);
			wet = smoothstep(1.0 - puddle_amount * 0.25, 1.0 - puddle_amount * 0.25 + 0.05, pn);
			col = mix(col, col * 0.6 + puddle_tint.rgb * 0.5, wet);
			rough = mix(rough, 0.1, wet);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = mix(0.4, 0.9, wet);
}
