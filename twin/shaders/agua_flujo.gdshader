// Agua fluyendo por un caño. La malla (look_tecnico.gd: malla_tubo) trae en
// UV.x la distancia recorrida desde el inicio del recorrido.
//  - avance: hasta dónde llegó el frente de agua (lo anima modo_pasos.gd)
//  - franjas claras que se mueven en el sentido de la corriente; cada una se
//    aclara hacia adelante y corta de golpe, como una punta de flecha, así se
//    lee la dirección.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.08, 0.45, 1.0);
uniform vec3 color_franja : source_color = vec3(0.70, 0.92, 1.0);
uniform float avance = 100000.0;
uniform float velocidad = 1.9;
uniform float largo_franja = 0.32;

void fragment() {
	float d = UV.x;
	if (d > avance) {
		discard;
	}
	float f = fract((d - TIME * velocidad) / largo_franja);
	float brillo = smoothstep(0.15, 0.9, f) * (1.0 - smoothstep(0.9, 1.0, f));
	// el frente que avanza, un poco más claro
	float frente = 1.0 - smoothstep(0.0, 0.25, avance - d);
	vec3 c = mix(color, color_franja, max(brillo * 0.75, frente * 0.6));
	ALBEDO = c;
	EMISSION = c * 0.55;
	ROUGHNESS = 0.15;
}
