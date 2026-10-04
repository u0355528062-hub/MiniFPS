// Peau du champ opératoire : texture de peau (pores, grain, capillaires), badigeon de povidone
// iodée peint au contact, tracé au feutre, incision avec perles de sang, plaie dont les bords
// s'étirent et se détendent (déformation calculée ici, rien sur le processeur), peau qui s'enfonce
// sous la pression des instruments, bouton d'anesthésie.
// Deux maillages utilisent ce shader : la grande grille (is_zone = 0, trouée autour de l'incision)
// et la zone de l'incision, fendue le long du trait (is_zone = 1, UV = (u, v) au repos, UV2.x = côté).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/wound_common.gdshaderinc"

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D iodine_mask : filter_linear, repeat_disable;
uniform float is_zone = 0.0;
uniform float zone_u = 0.06;
uniform vec2 bleed = vec2(1.0, 0.0); // partie de l'incision qui saigne déjà (suit la lame avec retard)
uniform float show_guide = 1.0;
uniform float stitched = 0.0;
uniform float iodine_wet = 1.0;
uniform float bleb_pale = 0.0; // blanchiment de la peau quand l'anesthésie agit
uniform vec2 win_min = vec2(0.0, -0.02);
uniform vec2 win_max = vec2(0.25, 0.22);
uniform vec3 skin_tint : source_color = vec3(0.78, 0.72, 0.68);

varying vec2 rest;
varying float edge_d;
varying float open_here;

void vertex() {
	vec2 d = inc_dir();
	vec2 pp = inc_perp();
	vec2 pos;
	edge_d = 1.0;
	open_here = 0.0;
	if (is_zone > 0.5) {
		float side = UV2.x;
		float av = abs(UV.y);
		rest = inc_center() + d * UV.x + pp * UV.y;
		float D = edge_open(UV.x, side);
		float f = max(0.0, 1.0 - av / zone_v);
		float disp = D * f * f;
		pos = rest + pp * side * disp;
		edge_d = av + disp - D;
		open_here = D;
		VERTEX = vec3(pos.x, surface_at(pos) + edge_lift(D, f, edge_d), pos.y);
	} else {
		rest = VERTEX.xz;
		pos = rest;
		VERTEX.y += relief(pos);
	}
	float e = 0.0025;
	float hx = surface_at(pos + vec2(e, 0.0)) - surface_at(pos - vec2(e, 0.0));
	float hz = surface_at(pos + vec2(0.0, e)) - surface_at(pos - vec2(0.0, e));
	NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
}

void fragment() {
	vec2 p = rest;
	vec2 dv = inc_b - inc_a;
	float len = length(dv);
	vec2 dir = dv / len;
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 c = inc_center();
	if (is_zone < 0.5) {
		// La grande grille laisse la place à la zone fendue de l'incision
		vec2 q = p - c;
		if (abs(dot(q, dir)) < zone_u - 0.0008 && abs(dot(q, perp)) < zone_v - 0.0008) {
			discard;
		}
	}
	float along = dot(p - inc_a, dir) / len;
	float t = clamp(along, 0.0, 1.0);
	float dist_line = length(p - (inc_a + dir * t * len));
	float in_line = step(0.0, along) * step(along, 1.0);

	// Peau
	vec2 suv = p / 0.065;
	vec3 col = texture(skin_albedo, suv).rgb * skin_tint;
	col *= 0.94 + 0.1 * texture(blood_tex, p * 3.0).r;
	float rough = 0.3 + texture(skin_rough, suv).r;
	float spec = 0.07;
	vec3 nw = planar_normal(skin_normal, suv, normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), 0.55);

	// Bouton d'anesthésie : peau tendue, pâle, aspect « peau d'orange »
	vec2 db = p - bleb.xy;
	float wheal = exp(-dot(db, db) / max(bleb.z * bleb.z * 1.6, 1e-6)) * step(0.0001, bleb.w);
	float pale = clamp(wheal * (0.45 + bleb_pale * 0.6), 0.0, 1.0);
	col = mix(col, col * vec3(1.12, 1.06, 1.02) + vec3(0.07, 0.06, 0.05), pale);
	rough = mix(rough, 0.35, wheal * 0.6);

	// Tracé au feutre (violet de gentiane), seulement là où la peau n'est pas encore incisée
	float cut_on = step(cut.x, along) * step(along, cut.y) * step(cut.x, cut.y);
	float dash = smoothstep(0.35, 0.45, fract(t * 9.0)) * (1.0 - smoothstep(0.85, 0.95, fract(t * 9.0)));
	float ink_w = 0.0011 + 0.0003 * texture(blood_tex, p * 40.0).r;
	float guide = (1.0 - smoothstep(ink_w * 0.6, ink_w, dist_line)) * dash * show_guide * in_line * (1.0 - cut_on);

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

	// Incision : fente rouge sombre ; le sang perle derrière la lame, avec un temps de retard
	float bleed_on = step(bleed.x, along) * step(along, bleed.y) * step(bleed.x, bleed.y);
	float cut_line = (1.0 - smoothstep(0.00035, 0.0009, dist_line)) * cut_on * (1.0 - smoothstep(0.0, 0.001, open_here));
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
		spec = mix(spec, 0.22, lip);
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
}
