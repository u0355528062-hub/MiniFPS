// Surfaces de la salle : sol vinyle coulé, murs en panneaux, plafond en dalles (mode choisi par "kind").
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform int kind = 0; // 0 = sol, 1 = mur, 2 = plafond
uniform vec3 tint : source_color = vec3(0.6, 0.7, 0.7);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = tint;
	float rough = 0.5;
	float spec = 0.5;
	if (kind == 0) {
		// Vinyle moucheté, joints soudés tous les 2 m, légère usure
		float speck = bb_noise(wpos * 260.0);
		float speck2 = step(0.82, bb_noise(wpos * 120.0 + vec3(5.0)));
		col = tint * (0.9 + 0.12 * speck) * (1.0 - 0.08 * speck2);
		col = mix(col, vec3(0.92), step(0.9, bb_noise(wpos * 400.0)) * 0.15);
		vec2 g = abs(fract(wpos.xz / 2.0 + 0.5) - 0.5) * 2.0;
		float seam = 1.0 - smoothstep(0.0, 0.004, min(1.0 - g.x, 1.0 - g.y));
		col *= 1.0 - seam * 0.25;
		float wear = bb_fbm(wpos * 1.5);
		rough = mix(0.18, 0.42, wear);
		spec = 0.6;
	} else if (kind == 1) {
		// Panneaux muraux 1,2 m avec joints, peinture satinée
		float px = fract(wpos.x / 1.2 + wpos.z / 1.2);
		float py = fract(wpos.y / 1.2);
		float jx = 1.0 - smoothstep(0.0, 0.004, min(px, 1.0 - px) * 1.2);
		float jy = 1.0 - smoothstep(0.0, 0.004, min(py, 1.0 - py) * 1.2);
		float joint = max(jx, jy);
		col = tint * (0.96 + 0.06 * bb_fbm(wpos * 4.0));
		col *= 1.0 - joint * 0.18;
		rough = 0.38;
		spec = 0.45;
	} else {
		// Dalles de plafond 0,6 m
		vec2 g = abs(fract(wpos.xz / 0.6) - 0.5) * 2.0;
		float joint = 1.0 - smoothstep(0.0, 0.03, min(1.0 - g.x, 1.0 - g.y));
		col = tint * (0.97 + 0.05 * bb_noise(wpos * 80.0));
		col *= 1.0 - joint * 0.25;
		rough = 0.8;
		spec = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = bb_bump(NORMAL, wpos, kind == 0 ? 120.0 : 40.0, kind == 0 ? 0.0006 : 0.0012, VIEW_MATRIX);
}
