// Aspect de la peau, partagé par le corps entier et la zone de l'incision : texture de peau (pores,
// grain, rougeurs), et sur le champ opératoire (`top` > 0) : badigeon de povidone iodée, tracé au
// feutre, bouton d'anesthésie, incision avec perles de sang, lèvres de la plaie, cicatrice suturée.
// À inclure après noise.gdshaderinc et wound_common.gdshaderinc.

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D iodine_mask : filter_linear, repeat_disable;
uniform float zone_u = 0.04;
uniform vec2 bleed = vec2(1.0, 0.0);
uniform float show_guide = 1.0;
uniform float stitched = 0.0;
uniform float iodine_wet = 1.0;
uniform float bleb_pale = 0.0;
uniform vec2 win_min = vec2(-0.085, -0.08);
uniform vec2 win_max = vec2(0.085, 0.08);
uniform vec3 skin_tint : source_color = vec3(0.95, 0.86, 0.82);
uniform vec3 pen_mark = vec3(0.0); // x, z, visible : point marqué au feutre
uniform float guide_on = 0.0; // le pointillé d'incision n'apparaît qu'une fois le point marqué

void skin_shade(vec3 wp, vec3 wn, vec2 p, float top, float edge_d, float open_here,
		out vec3 col, out float rough, out float spec, out vec3 nw) {
	float sc = 1.0 / 0.065;
	col = tri_col(skin_albedo, wp, wn, sc).rgb * skin_tint;
	col *= 0.94 + 0.1 * tri_tex(blood_tex, wp, wn, 3.0).r;
	// Teint irrégulier : marbrures légèrement rosées, zones plus pâles
	float mot = tri_tex(mottle, wp, wn, 3.2).r;
	col *= mix(vec3(0.97, 1.0, 1.01), vec3(1.05, 0.95, 0.93), smoothstep(0.35, 0.8, mot));
	rough = 0.58 + 0.36 * tri_tex(skin_rough, wp, wn, sc).r;
	spec = 0.16;
	nw = tri_normal(skin_normal, wp, wn, sc, 0.55);
	if (top <= 0.0) {
		return;
	}
	vec2 dv = inc_b - inc_a;
	float len = length(dv);
	vec2 dir = dv / len;
	float along = dot(p - inc_a, dir) / len;
	float t = clamp(along, 0.0, 1.0);
	float dist_line = length(p - (inc_a + dir * t * len));
	float in_line = step(0.0, along) * step(along, 1.0);

	// Bouton d'anesthésie : peau tendue, pâle, aspect « peau d'orange »
	vec2 db = p - bleb.xy;
	float wheal = exp(-dot(db, db) / max(bleb.z * bleb.z * 1.6, 1e-6)) * step(0.0001, bleb.w) * top;
	float pale = clamp(wheal * (0.45 + bleb_pale * 0.6), 0.0, 1.0);
	col = mix(col, col * vec3(1.12, 1.06, 1.02) + vec3(0.07, 0.06, 0.05), pale);
	rough = mix(rough, 0.35, wheal * 0.6);

	// Tracé au feutre (violet de gentiane), là où la peau n'est pas encore incisée
	float cut_on = step(cut.x, along) * step(along, cut.y) * step(cut.x, cut.y);
	float dash = smoothstep(0.35, 0.45, fract(t * 6.0)) * (1.0 - smoothstep(0.85, 0.95, fract(t * 6.0)));
	float ink_w = 0.0011 + 0.0003 * texture(blood_tex, p * 40.0).r;
	float guide = (1.0 - smoothstep(ink_w * 0.6, ink_w, dist_line)) * dash * show_guide * guide_on * in_line * (1.0 - cut_on) * top;
	// Croix au feutre sur le point d'entrée choisi
	if (pen_mark.z > 0.5) {
		vec2 dm = p - pen_mark.xy;
		vec2 r1 = vec2(dm.x + dm.y, dm.x - dm.y) * 0.7071;
		float arm = 1.0 - smoothstep(0.0028, 0.0034, max(abs(r1.x), abs(r1.y)));
		float line = 1.0 - smoothstep(0.0004, 0.0008, min(abs(r1.x), abs(r1.y)));
		guide = max(guide, arm * line * top * (1.0 - cut_on));
	}

	// Badigeon antiseptique : brun-rouge translucide, traînées du tampon, bord plus foncé
	vec2 muv = (p - patch_min) / patch_size;
	float iod = texture(iodine_mask, muv).r * top;
	float streak = texture(blood_tex, vec2(p.x * 9.0 + p.y * 3.0, p.y * 40.0)).r;
	float thick = clamp(iod * (0.75 + 0.5 * streak), 0.0, 1.0);
	float ring = smoothstep(0.15, 0.4, iod) * (1.0 - smoothstep(0.4, 0.75, iod));
	vec3 iod_col = mix(vec3(0.5, 0.22, 0.09), vec3(0.3, 0.09, 0.035), thick);
	iod_col = mix(iod_col, vec3(0.22, 0.06, 0.025), ring * 0.5);
	float iod_cov = smoothstep(0.05, 0.35, iod);
	float lum = dot(col, vec3(0.3, 0.5, 0.2)) / 0.45;
	col = mix(col, iod_col * lum, iod_cov * 0.88);
	rough = mix(rough, mix(0.34, 0.62, 1.0 - iodine_wet), iod_cov);
	spec = mix(spec, mix(0.3, 0.14, 1.0 - iodine_wet), iod_cov);
	col = mix(col, mix(vec3(0.30, 0.10, 0.42), vec3(0.18, 0.05, 0.2), iod_cov), guide * 0.85);

	// Incision : fente rouge sombre ; le sang perle derrière la lame, avec un temps de retard
	float bleed_on = step(bleed.x, along) * step(along, bleed.y) * step(bleed.x, bleed.y) * top;
	float cut_line = (1.0 - smoothstep(0.00035, 0.0009, dist_line)) * cut_on * (1.0 - smoothstep(0.0, 0.001, open_here)) * top;
	float drops = texture(blood_tex, p * 70.0).r;
	float bead = (1.0 - smoothstep(0.0006, 0.0006 + 0.003 * drops, dist_line)) * bleed_on * step(0.45, drops) * (1.0 - stitched * 0.7);
	float smear = (1.0 - smoothstep(0.0008, 0.006, dist_line)) * bleed_on * 0.35 * (1.0 - stitched);
	col = mix(col, vec3(0.38, 0.03, 0.03), smear);
	col = mix(col, vec3(0.30, 0.01, 0.015), bead);
	col = mix(col, vec3(0.12, 0.005, 0.008), cut_line);
	rough = mix(rough, 0.08, max(bead, cut_line));
	spec = mix(spec, 0.6, max(bead, cut_line));

	// Lèvres de la plaie écartée : derme blanc rosé puis bord humide et sanglant
	if (open_here > 0.0005) {
		float lip = 1.0 - smoothstep(0.0, 0.0035, edge_d);
		float rim = 1.0 - smoothstep(0.0, 0.0011, edge_d);
		col = mix(col, vec3(0.36, 0.12, 0.10), lip * 0.6);
		col = mix(col, vec3(0.30, 0.025, 0.025), rim * (0.6 + 0.4 * drops));
		rough = mix(rough, 0.42, lip);
		spec = mix(spec, 0.4, lip);
	}

	// Cicatrice suturée : bourrelet légèrement rouge
	float scar = (1.0 - smoothstep(0.0, 0.002, dist_line)) * stitched * cut_on * top;
	col = mix(col, vec3(0.5, 0.12, 0.1), scar * 0.6);
}
