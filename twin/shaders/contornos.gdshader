// Líneas de aristas estilo CAD (tipo Onshape). Las genera
// scripts/look_tecnico.gd como mallas de líneas sobre las aristas vivas de cada
// pieza. Se acercan apenas a la cámara para que no queden tapadas por la
// propia superficie sobre la que están.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color_linea : source_color = vec3(0.09, 0.10, 0.11);

void vertex() {
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz *= 0.997;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	ALBEDO = color_linea;
}
