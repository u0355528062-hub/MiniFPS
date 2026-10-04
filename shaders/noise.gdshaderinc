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

// ---------------------------------------------------------------- Textures en projection triplanaire
// (organes et tissus sans UV fiables : on projette selon les 3 axes du monde)

vec3 tri_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 1e-4);
}

vec4 tri_tex(sampler2D t, vec3 p, vec3 n, float scale) {
	vec3 w = tri_weights(n);
	return texture(t, p.zy * scale) * w.x + texture(t, p.xz * scale) * w.y + texture(t, p.xy * scale) * w.z;
}

// Normale monde perturbée par une carte de normales (mélange « whiteout »).
vec3 tri_normal(sampler2D t, vec3 p, vec3 n, float scale, float strength) {
	vec3 w = tri_weights(n);
	vec2 tx = (texture(t, p.zy * scale).xy * 2.0 - 1.0) * strength;
	vec2 ty = (texture(t, p.xz * scale).xy * 2.0 - 1.0) * strength;
	vec2 tz = (texture(t, p.xy * scale).xy * 2.0 - 1.0) * strength;
	vec3 nx = vec3(tx + n.zy, n.x).zyx;
	vec3 ny = vec3(ty + n.xz, n.y).xzy;
	vec3 nz = vec3(tz + n.xy, n.z);
	return normalize(nx * w.x + ny * w.y + nz * w.z);
}

// Normale monde perturbée par une carte projetée sur le plan horizontal (xz).
vec3 planar_normal(sampler2D t, vec2 uv, vec3 n, float strength) {
	vec2 d = (texture(t, uv).xy * 2.0 - 1.0) * strength;
	return normalize(n + vec3(d.x, 0.0, -d.y));
}
