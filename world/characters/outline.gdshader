shader_type spatial;
render_mode cull_front, unshaded, depth_draw_opaque;
// Inverted-hull outline: the mesh is drawn again, pushed out along its normals, back faces only, in one flat colour.
// Used as the next pass of a character material so the silhouette reads against the dark city from the high camera.
uniform vec4 outline_color : source_color = vec4(1.0, 0.15, 0.1, 1.0);
uniform float width : hint_range(0.0, 0.5) = 0.04;

void vertex() {
	// width is in metres: divide out the scale of the model matrix (generated rigs carry scale factors).
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += normalize(NORMAL) * width / max(scale, 0.0001);
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
