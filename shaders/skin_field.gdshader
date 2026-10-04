// Peau du champ opératoire : grain de peau, badigeon antiseptique peint, tracé au feutre,
// incision progressive et ouverture de la plaie.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D iodine_mask : filter_linear, repeat_disable;
uniform vec2 patch_min = vec2(0.0);
uniform vec2 patch_size = vec2(0.3);
uniform vec2 inc_a = vec2(0.0);
uniform vec2 inc_b = vec2(0.0, 0.06);
uniform float incision_progress = 0.0;
uniform float show_guide = 1.0;
uniform float opening = 0.0;
uniform float stitched = 0.0;
uniform vec3 skin_color : source_color = vec3(0.86, 0.66, 0.55);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 d = inc_b - inc_a;
	float len = length(d);
	vec2 dir = d / len;
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 c = (inc_a + inc_b) * 0.5;
	float u = dot(p - c, dir);
	float v = dot(p - c, perp);
	float t = clamp(dot(p - inc_a, dir) / len, 0.0, 1.0);
	float dist_line = length(p - (inc_a + dir * t * len));

	// Plaie ouverte : ellipse le long de l'incision
	float half_len = len * 0.5 + 0.004;
	float half_w = max(opening, 0.0001) * 0.03;
	float ell = (u * u) / (half_len * half_len) + (v * v) / (half_w * half_w);
	if (opening > 0.01 && ell < 1.0) {
		discard;
	}

	// Peau : variations, rougeurs, pores
	float n = bb_fbm(wpos * 180.0);
	float blotch = bb_fbm(wpos * 22.0);
	vec3 col = skin_color * (0.92 + 0.12 * n);
	col = mix(col, col * vec3(1.06, 0.88, 0.86), smoothstep(0.45, 0.75, blotch) * 0.5);
	float rough = 0.55 + 0.1 * n;
	float spec = 0.35;

	// Badigeon antiseptique (povidone iodée)
	vec2 muv = (p - patch_min) / patch_size;
	float iod = texture(iodine_mask, muv).r;
	float streak = bb_fbm(vec3(p * 90.0, 1.0));
	vec3 iod_col = mix(vec3(0.42, 0.16, 0.04), vec3(0.62, 0.30, 0.08), streak);
	col = mix(col, iod_col, iod * 0.92);
	rough = mix(rough, 0.18, iod);
	spec = mix(spec, 0.6, iod);

	// Tracé au feutre chirurgical (pointillés)
	float dash = step(0.5, fract(t * 9.0));
	float guide = (1.0 - smoothstep(0.0007, 0.0013, dist_line)) * dash * show_guide * step(incision_progress, t + 0.001);
	col = mix(col, vec3(0.28, 0.08, 0.42), guide * 0.9);

	// Incision déjà réalisée
	float cut = (1.0 - smoothstep(0.0004, 0.0011, dist_line)) * step(t, incision_progress) * step(0.001, incision_progress);
	float ooze = (1.0 - smoothstep(0.0008, 0.004, dist_line)) * step(t, incision_progress) * step(0.001, incision_progress) * (1.0 - stitched);
	col = mix(col, vec3(0.45, 0.04, 0.03), ooze * 0.55 * (0.6 + 0.4 * bb_noise(vec3(p * 900.0, 2.0))));
	col = mix(col, vec3(0.16, 0.01, 0.01), cut);
	rough = mix(rough, 0.12, max(cut, ooze * 0.7));

	// Bord de plaie humide et rosé
	if (opening > 0.01) {
		float rim = 1.0 - smoothstep(1.0, 1.9, ell);
		col = mix(col, vec3(0.62, 0.18, 0.15), rim * 0.65);
		rough = mix(rough, 0.15, rim);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = bb_bump(NORMAL, wpos, 260.0, 0.0015, VIEW_MATRIX);
	BACKLIGHT = vec3(0.35, 0.08, 0.05) * 0.4;
}
