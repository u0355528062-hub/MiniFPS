// Peau du champ opératoire : texture de peau (pores, grain, capillaires), badigeon de povidone
// iodée peint à la main, tracé au feutre, incision avec perles de sang, plaie ouverte.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D iodine_mask : filter_linear, repeat_disable;
uniform vec2 patch_min = vec2(0.0);
uniform vec2 patch_size = vec2(0.3);
uniform vec2 inc_a = vec2(0.0);
uniform vec2 inc_b = vec2(0.0, 0.06);
uniform float incision_progress = 0.0;
uniform float show_guide = 1.0;
uniform float opening = 0.0;
uniform float stitched = 0.0;
uniform float iodine_wet = 1.0;
uniform float bleed = 0.0; // 0..1 : sang qui perle le long de l'incision
uniform vec2 win_min = vec2(0.0, -0.02);
uniform vec2 win_max = vec2(0.25, 0.22);
uniform vec3 skin_tint : source_color = vec3(0.78, 0.72, 0.68);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Contour irrégulier de la plaie (même formule que Patient.wound_shape côté GDScript)
float wound_shape(float a) {
	return 1.0 + 0.07 * sin(3.0 * a + 0.7) + 0.04 * sin(5.0 * a + 2.1) + 0.025 * sin(9.0 * a + 0.3);
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

	// Plaie ouverte : ellipse au contour irrégulier
	float half_len = len * 0.5 + 0.004;
	float half_w = max(opening, 0.0001) * 0.022;
	float ang = atan(v / half_w, u / half_len);
	float rs = wound_shape(ang);
	float ell = ((u * u) / (half_len * half_len) + (v * v) / (half_w * half_w)) / (rs * rs);
	if (opening > 0.01 && ell < 1.0) {
		discard;
	}

	// Peau
	vec2 suv = p / 0.065;
	vec3 col = texture(skin_albedo, suv).rgb * skin_tint;
	col *= 0.94 + 0.1 * texture(blood_tex, p * 3.0).r; // grandes variations de teint
	float rough = 0.3 + texture(skin_rough, suv).r;
	float spec = 0.07;
	vec3 nw = planar_normal(skin_normal, suv, normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), 0.55);

	// Tracé au feutre chirurgical (violet de gentiane), légèrement baveux
	float dash = smoothstep(0.35, 0.45, fract(t * 9.0)) * (1.0 - smoothstep(0.85, 0.95, fract(t * 9.0)));
	float ink_w = 0.0011 + 0.0003 * texture(blood_tex, p * 40.0).r;
	float guide = (1.0 - smoothstep(ink_w * 0.6, ink_w, dist_line)) * dash * show_guide * step(incision_progress, t + 0.001);
	guide *= step(t, 1.0) * step(0.0, dot(p - inc_a, dir)) * step(dot(p - inc_a, dir), len);

	// Badigeon antiseptique : brun-rouge translucide, traînées du tampon, bord plus foncé
	vec2 muv = (p - patch_min) / patch_size;
	float iod = texture(iodine_mask, muv).r;
	float streak = texture(blood_tex, vec2(p.x * 9.0 + p.y * 3.0, p.y * 40.0)).r;
	float thick = clamp(iod * (0.75 + 0.5 * streak), 0.0, 1.0);
	float ring = smoothstep(0.15, 0.4, iod) * (1.0 - smoothstep(0.4, 0.75, iod));
	vec3 iod_col = mix(vec3(0.5, 0.22, 0.09), vec3(0.3, 0.09, 0.035), thick);
	iod_col = mix(iod_col, vec3(0.22, 0.06, 0.025), ring * 0.5);
	float iod_cov = smoothstep(0.05, 0.35, iod);
	float lum = dot(col, vec3(0.3, 0.5, 0.2)) / 0.45;
	col = mix(col, iod_col * lum, iod_cov * 0.88);
	rough = mix(rough, mix(0.45, 0.62, 1.0 - iodine_wet), iod_cov);
	spec = mix(spec, 0.12, iod_cov);
	col = mix(col, mix(vec3(0.30, 0.10, 0.42), vec3(0.18, 0.05, 0.2), iod_cov), guide * 0.85);

	// Incision déjà faite : fente rouge sombre + perles de sang
	float cut_on = step(t, incision_progress) * step(0.001, incision_progress) * step(0.0, dot(p - inc_a, dir));
	float cut = (1.0 - smoothstep(0.00035, 0.0009, dist_line)) * cut_on;
	float drops = texture(blood_tex, p * 70.0).r;
	float bead = (1.0 - smoothstep(0.0006, 0.0006 + 0.0028 * drops * bleed, dist_line)) * cut_on * step(0.45, drops) * (1.0 - stitched * 0.7);
	float smear = (1.0 - smoothstep(0.0008, 0.005, dist_line)) * cut_on * 0.35 * bleed * (1.0 - stitched);
	col = mix(col, vec3(0.38, 0.03, 0.03), smear);
	col = mix(col, vec3(0.30, 0.01, 0.015), bead);
	col = mix(col, vec3(0.12, 0.005, 0.008), cut);
	rough = mix(rough, 0.08, max(bead, cut));
	spec = mix(spec, 0.6, max(bead, cut));

	// Lèvres de la plaie : derme blanc rosé puis bord humide sanglant
	if (opening > 0.01) {
		float lip = 1.0 - smoothstep(1.0, 1.25, ell);
		float rim = 1.0 - smoothstep(1.0, 1.08, ell);
		col = mix(col, vec3(0.62, 0.3, 0.27), lip * 0.6);
		col = mix(col, vec3(0.36, 0.03, 0.03), rim * (0.6 + 0.4 * drops));
		rough = mix(rough, 0.3, lip);
	}

	// Cicatrice suturée : bourrelet légèrement rouge
	float scar = (1.0 - smoothstep(0.0, 0.002, dist_line)) * stitched * cut_on;
	col = mix(col, vec3(0.5, 0.12, 0.1), scar * 0.6);

	// Ombre douce sous le bord du champ
	vec2 wd = min(p - win_min, win_max - p);
	float edge = min(wd.x, wd.y);
	col *= mix(0.45, 1.0, smoothstep(0.0, 0.016, edge));

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.25;
}
