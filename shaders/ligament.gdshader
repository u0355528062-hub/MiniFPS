// Ligament annulaire du carpe vu à l'endoscope : fibres blanches nacrées tendues en travers du
// poignet. La lame le fend en long : les deux berges s'écartent et laissent voir la graisse.
shader_type spatial;
render_mode cull_disabled;

uniform float cut_x0 = 1.0; // partie coupée [cut_x0, cut_x1] le long du bras (x monde)
uniform float cut_x1 = 0.0;
uniform float center_z = 0.38;
uniform float gap = 0.0026;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float in_cut = step(cut_x0, wpos.x) * step(wpos.x, cut_x1);
	float dz = abs(wpos.z - center_z);
	if (in_cut > 0.5 && dz < gap) {
		discard;
	}
	// Fibres en travers (le long de z), ondulées
	float fib = 0.5 + 0.5 * sin(wpos.z * 2600.0 + sin(wpos.x * 900.0) * 2.5);
	float fine = 0.5 + 0.5 * sin(wpos.z * 7100.0 + wpos.x * 310.0);
	vec3 col = mix(vec3(0.78, 0.76, 0.72), vec3(0.96, 0.95, 0.92), fib * 0.7 + fine * 0.3);
	// Fins vaisseaux rosés
	col = mix(col, vec3(0.75, 0.45, 0.42), 0.15 * smoothstep(0.92, 1.0, sin(wpos.x * 520.0 + wpos.z * 130.0)));
	// Berges de la coupe : rouges, un peu de sang
	float edge = in_cut * (1.0 - smoothstep(gap, gap + 0.0015, dz));
	col = mix(col, vec3(0.55, 0.12, 0.1), edge * 0.8);
	ALBEDO = col;
	ROUGHNESS = mix(0.32, 0.2, edge);
	SPECULAR = 0.5;
	CLEARCOAT = 0.5;
	CLEARCOAT_ROUGHNESS = 0.15;
}
