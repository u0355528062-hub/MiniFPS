// Bruit procédural partagé (valeur 3D + fbm).

float bb_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float bb_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(bb_hash(i + vec3(0, 0, 0)), bb_hash(i + vec3(1, 0, 0)), f.x),
				   mix(bb_hash(i + vec3(0, 1, 0)), bb_hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(bb_hash(i + vec3(0, 0, 1)), bb_hash(i + vec3(1, 0, 1)), f.x),
				   mix(bb_hash(i + vec3(0, 1, 1)), bb_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float bb_fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * bb_noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// Normale perturbée par un relief procédural (en espace monde → vue).
vec3 bb_bump(vec3 n_view, vec3 wpos, float freq, float strength, mat4 view_matrix) {
	float e = 0.35 / freq;
	float h = bb_fbm(wpos * freq);
	float hx = bb_fbm((wpos + vec3(e, 0.0, 0.0)) * freq);
	float hy = bb_fbm((wpos + vec3(0.0, e, 0.0)) * freq);
	float hz = bb_fbm((wpos + vec3(0.0, 0.0, e)) * freq);
	vec3 g = vec3(hx - h, hy - h, hz - h) / e;
	vec3 g_view = (view_matrix * vec4(g, 0.0)).xyz;
	return normalize(n_view - g_view * strength);
}
