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
// Couleur de l'antiseptique (film fin, couche épaisse, bord) : bétadine brune par défaut
uniform vec3 anti_thin = vec3(0.5, 0.22, 0.09);
uniform vec3 anti_thick = vec3(0.3, 0.09, 0.035);
uniform vec3 anti_ring = vec3(0.22, 0.06, 0.025);
uniform float bleb_pale = 0.0;
uniform vec2 win_min = vec2(-0.085, -0.08);
uniform vec2 win_max = vec2(0.085, 0.08);
uniform vec3 skin_tint : source_color = vec3(0.99, 0.95, 0.94);
uniform vec3 drape_col : source_color = vec3(0.17, 0.42, 0.53); // couleur du champ (bord adhésif)
uniform float frame_on = 1.0; // 0 : pas de champ fenêtré (urgence), pas de bord adhésif
uniform vec3 pen_mark = vec3(0.0); // x, z, visible : point marqué au feutre
uniform float guide_on = 0.0; // le pointillé d'incision n'apparaît qu'une fois le point marqué

// Bord adhésif du champ, collé à plat tout autour de la fenêtre (sur le dessus du corps) : le
// contour reste net même là où le tissu forme un pli
float drape_frame(vec2 p, vec3 wn) {
	vec2 outw = max(win_min - p, p - win_max);
	float eo = max(outw.x, outw.y);
	return frame_on * step(0.0, eo) * (1.0 - smoothstep(0.016, 0.02, eo)) * smoothstep(0.15, 0.35, wn.y);
}

void apply_frame(float frame, vec2 p, vec3 wn, inout vec3 col, inout float rough, inout float spec, inout vec3 nw) {
	if (frame <= 0.0) {
		return;
	}
	float weave = texture(blood_tex, p * 55.0).r;
	col = mix(col, drape_col * (1.02 + 0.08 * weave) + vec3(0.008), frame);
	rough = mix(rough, 0.5, frame);
	spec = mix(spec, 0.2, frame);
	nw = normalize(mix(nw, wn, frame));
}

// Repère de l'atlas (visage, cheveux, mamelons) : za.x = dot(rx.xyz, w) + rx.w, etc.
uniform vec4 atlas_rx = vec4(0.0, -1.0, 0.0, 1.14006);
uniform vec4 atlas_ry = vec4(0.0, 0.0, -1.0, -0.004);
uniform vec4 atlas_rz = vec4(1.0, 0.0, 0.0, 1.275);
// Marque de la ceinture de sécurité (accident de voiture) : segment x0 z0 x1 z1 (monde), nul = rien
uniform vec4 belt = vec4(0.0);
// Plaie par arme blanche : x, z (monde), angle (rad), longueur (m) ; nulle = rien
uniform vec4 stab = vec4(0.0);

vec3 atlas_pos(vec3 w) {
	return vec3(dot(atlas_rx.xyz, w) + atlas_rx.w, dot(atlas_ry.xyz, w) + atlas_ry.w, dot(atlas_rz.xyz, w) + atlas_rz.w);
}

// Détails propres au corps : aréoles et mamelons, signe de la ceinture
void skin_marks(vec3 wp, vec3 wn, vec2 p, inout vec3 col, inout float rough, inout vec3 nw) {
	vec3 za = atlas_pos(wp);
	// Aréoles et mamelons (absents du maillage de l'atlas) : 4e espace intercostal, un peu en
	// dehors de la ligne médio-claviculaire ; petit dôme en relief, grain des tubercules
	if (za.y < -0.02 && abs(za.z - 1.271) < 0.03) {
		for (int k = 0; k < 2; k++) {
			vec2 d = vec2(za.x - (k == 0 ? -0.098 : 0.098), za.z - 1.271);
			float r = length(d * vec2(1.0, 1.1));
			float nb = bb_noise(wp * 520.0);
			float areola = 1.0 - smoothstep(0.0105, 0.0128 + 0.0012 * nb, r);
			float papilla = 1.0 - smoothstep(0.0026, 0.0040, r);
			col = mix(col, col * vec3(0.80, 0.60, 0.58) * (0.94 + 0.12 * nb), areola * 0.9);
			col = mix(col, col * vec3(0.84, 0.66, 0.64), papilla);
			float s2 = 0.0034 * 0.0034;
			vec2 g = -d * exp(-dot(d, d) / s2) * (2.0 * 0.0024 / s2);
			g += -d * exp(-dot(d, d) / 0.00011) * (2.0 * 0.0006 / 0.00011) * areola;
			nw = normalize(nw - (g.x * atlas_rx.xyz + g.y * atlas_rz.xyz));
			rough = mix(rough, 0.44, areola);
		}
	}
	// Signe de la ceinture : ecchymose rouge violacé en bande, plus foncée par plaques, trame de la
	// sangle imprimée dans la peau, éraflures au milieu
	if (belt != vec4(0.0) && wn.y > 0.15) {
		vec2 ab = belt.zw - belt.xy;
		float bt = clamp(dot(p - belt.xy, ab) / dot(ab, ab), 0.0, 1.0);
		vec2 across = normalize(vec2(-ab.y, ab.x));
		float sd = dot(p - belt.xy, across);
		float nn = bb_noise(wp * 55.0);
		float band = 1.0 - smoothstep(0.014, 0.028, abs(sd) + (nn - 0.5) * 0.014);
		band *= smoothstep(0.0, 0.1, bt) * (1.0 - smoothstep(0.88, 1.0, bt));
		float weave = 0.5 + 0.5 * sin(sd * 3200.0);
		float deep = smoothstep(0.35, 0.75, nn);
		vec3 tint = mix(vec3(0.86, 0.62, 0.74), vec3(0.66, 0.42, 0.62), deep);
		col *= mix(vec3(1.0), tint, band * (0.82 + 0.18 * weave));
		// Liseré plus rouge au bord de l'ecchymose
		float rim = band * (1.0 - band) * 4.0;
		col *= mix(vec3(1.0), vec3(1.04, 0.86, 0.86), rim * 0.6);
		// Éraflures : traînées fines dans le sens de la sangle
		vec2 bdir = normalize(ab);
		float along_m = dot(p - belt.xy, bdir);
		float streak = bb_noise(vec3(along_m * 35.0, sd * 900.0, 3.7));
		float abr = band * smoothstep(0.7, 0.8, streak) * (1.0 - smoothstep(0.005, 0.012, abs(sd))) * step(0.3, bt) * step(bt, 0.7);
		col = mix(col, vec3(0.42, 0.06, 0.05), abr * 0.55);
		rough = mix(rough, 0.32, abr);
	}
	// Plaie au couteau : fente fusiforme sombre, bords ecchymotiques, filet de sang qui coule vers
	// le flanc
	if (stab.w > 0.0 && wn.y > 0.2) {
		vec2 sd2 = p - stab.xy;
		vec2 ax = vec2(cos(stab.z), sin(stab.z));
		vec2 lq = vec2(dot(sd2, ax), dot(sd2, vec2(-ax.y, ax.x)));
		float hl = stab.w * 0.5;
		float u = lq.x / hl;
		float gap = 0.0017 * max(0.0, 1.0 - u * u);
		float slit = (1.0 - smoothstep(gap * 0.5, gap + 0.0004, abs(lq.y))) * step(abs(u), 1.0);
		float rim = 1.0 - smoothstep(0.0, 0.007, length(vec2(max(abs(lq.x) - hl, 0.0), lq.y)));
		vec2 dn = normalize(vec2(-0.3, 1.0));
		float ta = dot(sd2, dn);
		float tc = dot(sd2, vec2(-dn.y, dn.x));
		float wig = sin(ta * 150.0) * 0.0011 + sin(ta * 47.0) * 0.0016;
		float trickle = step(0.002, ta) * (1.0 - smoothstep(0.02, 0.055, ta)) * (1.0 - smoothstep(0.0007, 0.002, abs(tc - wig - 0.002)));
		float dried = (1.0 - smoothstep(0.004, 0.012, length(sd2))) * 0.5;
		col = mix(col, col * vec3(0.84, 0.56, 0.62), rim * 0.65);
		col = mix(col, vec3(0.30, 0.03, 0.03), max(trickle * 0.8, dried * (1.0 - slit)));
		col = mix(col, vec3(0.10, 0.008, 0.01), slit);
		rough = mix(rough, 0.22, max(slit, trickle));
	}
}

void skin_shade(vec3 wp, vec3 wn, vec2 p, float top, float edge_d, float open_here,
		out vec3 col, out float rough, out float spec, out vec3 nw) {
	float sc = 1.0 / 0.065;
	// Grain de la peau : les petites taches de la texture sont adoucies (de loin la peau est unie,
	// sans motif qui se répète) ; le relief fin des pores vient des cartes de normales
	vec3 grain = tri_col(skin_albedo, wp, wn, sc).rgb;
	col = mix(vec3(0.552, 0.282, 0.191), grain, 0.5) * skin_tint;
	// Teint irrégulier à grande échelle : zones un peu plus rosées, d'autres plus pâles
	float mot = tri_tex(mottle, wp, wn, 1.4).r;
	col *= mix(vec3(0.985, 1.0, 1.01), vec3(1.035, 0.965, 0.955), smoothstep(0.3, 0.85, mot));
	rough = 0.5 + 0.28 * tri_tex(skin_rough, wp, wn, sc).r;
	spec = 0.32;
	nw = tri_normal(skin_normal, wp, wn, sc, 0.42);
	nw = tri_normal(skin_normal, wp + vec3(0.37), nw, sc * 3.3, 0.18);
	float frame = drape_frame(p, wn);
	if (top <= 0.0) {
		apply_frame(frame, p, wn, col, rough, spec, nw);
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
	vec3 iod_col = mix(anti_thin, anti_thick, thick);
	iod_col = mix(iod_col, anti_ring, ring * 0.5);
	float iod_cov = smoothstep(0.05, 0.35, iod);
	float lum = dot(col, vec3(0.3, 0.5, 0.2)) / 0.45;
	col = mix(col, iod_col * lum, iod_cov * 0.88);
	// Film liquide : comble les pores (relief adouci), brillant tant qu'il est humide, mat une fois sec
	nw = normalize(mix(nw, wn, iod_cov * mix(0.25, 0.7, iodine_wet)));
	rough = mix(rough, mix(0.26, 0.6, 1.0 - iodine_wet), iod_cov);
	spec = mix(spec, mix(0.3, 0.12, 1.0 - iodine_wet), iod_cov);
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
	apply_frame(frame, p, wn, col, rough, spec, nw);
}
