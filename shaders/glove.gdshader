shader_type spatial;
// Gant chirurgical en latex : crème, légèrement translucide et satiné ; taché de sang à partir du
// bout des doigts (bords irréguliers, sang frais luisant, plus sombre là où il sèche).

uniform vec3 latex : source_color = vec3(0.88, 0.80, 0.64);
uniform float blood = 0.0;
uniform float blood_z = 0.035;  // au-delà (vers le bout des doigts), le gant est ensanglanté

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	float n = vnoise(lpos * 160.0) * 0.6 + vnoise(lpos * 520.0) * 0.4;
	// Les doigts sont pleins de sang ; ailleurs, des traînées et des taches (couverture selon blood)
	float m = smoothstep(-0.012, 0.012, lpos.z - blood_z + (n - 0.5) * 0.05) * blood;
	m = max(m, smoothstep(0.62 - 0.45 * blood, 0.7 - 0.45 * blood, n) * blood);
	m = max(m, smoothstep(0.78, 0.86, vnoise(lpos * 240.0 + 7.0)) * blood * 0.9);
	float dry = smoothstep(0.4, 0.8, vnoise(lpos * 90.0 + 3.0));
	vec3 bl = mix(vec3(0.40, 0.02, 0.03), vec3(0.22, 0.02, 0.02), dry);
	// Plis du latex : fines rides
	float wr = vnoise(vec3(lpos.x * 900.0, lpos.y * 300.0, lpos.z * 120.0));
	vec3 col = latex * (0.94 + 0.08 * wr);
	ALBEDO = mix(col, bl, m);
	ROUGHNESS = mix(0.46, 0.16, m);
	SPECULAR = 0.5;
	CLEARCOAT = 0.2 + 0.55 * m;
	CLEARCOAT_ROUGHNESS = 0.18;
	SSS_STRENGTH = 0.25 * (1.0 - m);
	RIM = 0.1;
	RIM_TINT = 0.5;
}
