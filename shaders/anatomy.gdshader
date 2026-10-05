// Tissus internes réels (atlas) : os, cartilage, muscle fibreux, tendon, plèvre et poumon humides,
// cœur avec graisse dans les sillons, vaisseaux, nerfs. Ils n'apparaissent que dans la plaie (ou
// en vue anatomique). La pince de Kelly creuse un trajet : les tissus mous y sont coupés et leur
// tranche (rouge) se voit sur les bords. Le poumon droit s'affaisse vers son hile (pneumothorax)
// puis se regonfle ; le cœur bat.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.7, 0.3, 0.28);
uniform vec3 alt_color : source_color = vec3(0.6, 0.25, 0.22);
uniform vec3 cut_color : source_color = vec3(0.45, 0.06, 0.05);
uniform float rough = 0.35;
uniform float wetness = 0.6;
uniform float sss = 0.3;
uniform float tex_scale = 30.0;
uniform float fiber = 0.0;
uniform float spots = 0.0;
uniform float vessel_amount = 0.0;
uniform float fat_grooves = 0.0;
uniform float alt_mix = 1.0;  // part de la seconde couleur dans le grain du tissu
uniform float cuttable = 1.0;
uniform float is_pleura = 0.0;
uniform sampler2D detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fibers : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fibers_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D vessels : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
// Visibilité : -1 caché, 0 seulement dans la plaie, 1 partout (vue anatomique)
uniform float show_all = 0.0;
uniform vec3 reveal_c = vec3(0.0);
uniform vec3 reveal_axis = vec3(0.0, -1.0, 0.0);
uniform float reveal_r = 0.0;
uniform vec3 tract_a = vec3(0.0);
uniform vec3 tract_b = vec3(0.0);
uniform float tract_r = 0.0;
uniform float pleura_open = 0.0;
// Mouvements
uniform float collapse = 0.0;
uniform vec3 hilum = vec3(0.0);
uniform float breath = 0.0;
uniform float beat = 0.0;
uniform vec3 beat_c = vec3(0.0);
// Thoracotomie : brèche dans la paroi le long de l'espace intercostal (polyligne ap_pts : x, hauteur
// de la peau, z, part de l'écartement à cet endroit), coupée de ap_t0 à ap_t1 (0..1 le long du
// tracé). L'écarteur repousse la paroi de part et d'autre (côtes, muscles, plèvre : spreadable) de
// ap_spread au plus ; dans la brèche (demi-largeur ap_w0 + écartement), les tissus de la paroi
// (wall_tissue : muscles, intercostaux, plèvre pariétale) sont ouverts jusqu'à ap_depth.
uniform vec4 ap_pts[10];
uniform vec2 ap_slope[10];  // pente de la peau (dh/dx, dh/dz) en chaque point du tracé
uniform int ap_n = 0;
uniform float ap_t0 = 0.0;
uniform float ap_t1 = 0.0;
uniform float ap_w0 = 0.0;
uniform float ap_spread = 0.0;
uniform float ap_depth = 0.045;
uniform float spreadable = 0.0;
uniform float wall_tissue = 0.0;  // 1 : muscles, intercostaux, plèvre ; 2 : nerfs et vaisseaux de la paroi
uniform float cavity_blood = 0.0;  // hémothorax : du sang stagne au fond de la cavité ouverte
// Péricarde ouvert aux ciseaux : fenêtre le long de pc_a → pc_b, demi-largeur pc_w ; distendu par
// le sang avant (teinte bleu-violet)
uniform vec3 pc_a = vec3(0.0);
uniform vec3 pc_b = vec3(0.0);
uniform float pc_w = 0.0;
uniform float tense = 0.0;
// Plaie du cœur : centre et demi-longueur (xyz, w), direction ; refermée (0..1)
uniform vec4 heart_wound = vec4(0.0);
uniform vec3 heart_wound_dir = vec3(1.0, 0.0, 0.0);
uniform float heart_wound_closed = 0.0;
// Massage cardiaque : compression du cœur entre les mains (0..1)
uniform float squeeze = 0.0;

varying vec3 wpos;
varying vec3 wnorm;
varying vec3 rpos;  // position au repos (avant battement, écrasement, écartement) : plaie, fenêtre

// Point du tracé le plus proche (projection verticale) : x = distance signée (+ vers la tête),
// y = profondeur sous la peau, z = position le long du tracé (0..1), w = part de l'écartement ;
// dir = direction horizontale qui s'éloigne du tracé, du côté du point.
vec4 ap_near(vec3 p, out vec2 dir, out vec2 slope) {
	float best = 1e9;
	vec4 res = vec4(1e9, 0.0, -1.0, 0.0);
	dir = vec2(0.0);
	slope = vec2(0.0);
	for (int k = 0; k < 9; k++) {
		if (k + 1 >= ap_n) {
			break;
		}
		vec4 a = ap_pts[k];
		vec4 b = ap_pts[k + 1];
		vec2 ab = b.xz - a.xz;
		vec2 ap = p.xz - a.xz;
		float t = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-10), 0.0, 1.0);
		float d = length(ap - ab * t);
		if (d < best) {
			best = d;
			float side = ab.y * ap.x - ab.x * ap.y >= 0.0 ? 1.0 : -1.0;
			vec2 nrm = normalize(vec2(ab.y, -ab.x)) * side;
			dir = nrm;
			slope = mix(ap_slope[k], ap_slope[k + 1], t);
			res = vec4(d * side, mix(a.y, b.y, t) - p.y, (float(k) + t) / float(ap_n - 1), mix(a.w, b.w, t));
		}
	}
	return res;
}

void vertex() {
	vec3 v = VERTEX;
	rpos = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	if (hilum != vec3(0.0)) {
		float k = mix(1.0, 0.56, collapse) * (1.0 + 0.025 * breath);
		v = hilum + (v - hilum) * k;
	}
	if (beat_c != vec3(0.0)) {
		v = beat_c + (v - beat_c) * (1.0 + beat);
		// Compression d'avant en arrière (le cœur s'aplatit entre les mains)
		vec3 r = v - beat_c;
		v = beat_c + vec3(r.x * (1.0 + 0.08 * squeeze), r.y * (1.0 - 0.32 * squeeze), r.z * (1.0 + 0.1 * squeeze));
	}
	if (ap_n > 1 && ap_spread > 0.0 && spreadable > 0.5) {
		// L'écarteur pousse la paroi : ce qui est près de la brèche part d'un côté ou de l'autre
		vec3 wp0 = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
		vec2 dir;
		vec2 slope;
		vec4 nr = ap_near(wp0, dir, slope);
		float fall = 1.0 - smoothstep(0.014, 0.085, abs(nr.x));
		float deep = 1.0 - smoothstep(0.045, 0.075, nr.y);
		float shallow = smoothstep(-0.03, -0.01, nr.y);
		float amount = ap_spread * nr.w * fall * deep * shallow;
		// On glisse le long de la paroi (même profondeur sous la peau), pas à l'horizontale
		vec2 dxz = dir * amount;
		vec3 off = vec3(dxz.x, dot(slope, dxz), dxz.y);
		v += inverse(mat3(MODEL_MATRIX)) * off;
	}
	VERTEX = v;
	wpos = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float seg_dist(vec3 p, vec3 a, vec3 b) {
	vec3 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-10), 0.0, 1.0);
	return length(p - (a + ab * t));
}

void fragment() {
	if (show_all < -0.5) {
		discard;
	}
	// Brèche de la thoracotomie : distance au tracé, profondeur sous la peau, largeur ouverte
	bool in_open = false;
	float open_depth = 0.0;
	if (ap_n > 1 && ap_t1 > ap_t0) {
		vec2 dir;
		vec2 slope;
		vec4 nr = ap_near(wpos, dir, slope);
		float gap = ap_w0 + ap_spread * nr.w;
		bool along = nr.z >= ap_t0 - 0.02 && nr.z <= ap_t1 + 0.02;
		open_depth = nr.y;
		// Nerfs et vaisseaux intercostaux : coupés un peu plus profond (rien ne pend dans la brèche)
		float wall_d = ap_depth + (wall_tissue > 1.5 ? 0.06 : 0.0);
		if (wall_tissue > 0.5 && along && abs(nr.x) < gap && nr.y < wall_d) {
			discard;
		}
		// La plèvre est ouverte sur toute la hauteur de la brèche (jusque devant le péricarde)
		if (is_pleura > 0.5 && ap_spread > 0.0 && along && abs(nr.x) < gap * 1.1 + 0.004) {
			discard;
		}
		// Ce qu'on voit par la brèche : un cône qui s'élargit en profondeur (regard oblique)
		// (la paroi elle-même ne se voit que sur les bords de la brèche)
		float cone = wall_tissue > 0.5 ? 0.0 : max(nr.y, 0.0) * 0.7;
		in_open = along && nr.y > -0.01 && abs(nr.x) < gap * 1.15 + 0.012 + cone;
	}
	if (show_all < 0.5) {
		vec3 d = wpos - reveal_c;
		float along_r = dot(d, reveal_axis);
		float lat = length(d - reveal_axis * along_r);
		bool in_reveal = reveal_r > 0.0 && along_r >= 0.0 && lat <= reveal_r;
		if (!in_reveal && !in_open) {
			discard;
		}
	}
	if (pc_w > 0.0 && seg_dist(rpos, pc_a, pc_b) < pc_w) {
		discard;
	}
	bool cuts = cuttable > 0.5 && tract_r > 0.0 && (is_pleura < 0.5 || pleura_open > 0.5);
	if (cuts && seg_dist(wpos, tract_a, tract_b) < tract_r) {
		discard;
	}
	vec3 n0 = normalize(wnorm);
	if (!FRONT_FACING) {
		// Tranche du tissu : intérieur d'un muscle coupé, humide
		float nn = bb_fbm(wpos * 700.0);
		ALBEDO = cut_color * (0.7 + 0.45 * nn);
		ROUGHNESS = 0.28;
		SPECULAR = 0.45;
		SSS_STRENGTH = 0.25;
	} else {
		float det = tri_tex(detail, wpos, n0, tex_scale).r;
		vec3 col = mix(base_color, alt_color, smoothstep(0.3, 0.8, det) * alt_mix);
		if (fiber > 0.0) {
			float fb = tri_tex(fibers, wpos, n0, tex_scale * 0.8).r;
			col = mix(col, col * (0.68 + 0.62 * fb), fiber);
		}
		if (spots > 0.0) {
			// Poumon : lobules, dépôts d'anthracose
			float v = tri_tex(detail, wpos, n0, tex_scale * 3.1).r;
			float lob = tri_tex(detail, wpos, n0, tex_scale * 0.7).g;
			col *= 0.88 + 0.24 * smoothstep(0.2, 0.7, lob);
			col = mix(col, vec3(0.22, 0.15, 0.17), smoothstep(0.74, 0.92, v) * 0.55 * spots);
		}
		if (fat_grooves > 0.0) {
			float g = smoothstep(0.55, 0.78, tri_tex(detail, wpos, n0, tex_scale * 0.45).r);
			col = mix(col, alt_color, g * 0.75 * fat_grooves);
		}
		if (vessel_amount > 0.0) {
			vec4 ves = tri_tex(vessels, wpos, n0, tex_scale * 0.5);
			col = mix(col, vec3(0.5, 0.06, 0.08), clamp(ves.g * vessel_amount, 0.0, 1.0) * 0.6);
			col = mix(col, vec3(0.3, 0.06, 0.2), clamp(ves.r * vessel_amount, 0.0, 1.0) * 0.4);
		}
		if (tense > 0.0) {
			// Péricarde distendu : le sang en dessous le teinte en bleu violacé, tendu et luisant
			col = mix(col, vec3(0.24, 0.12, 0.26) * (0.85 + 0.3 * det), tense * 0.8);
		}
		if (heart_wound.w > 0.0) {
			vec3 dw = rpos - heart_wound.xyz;
			float al = dot(dw, heart_wound_dir);
			float ac = length(dw - heart_wound_dir * al);
			if (length(dw) < heart_wound.w + 0.012) {
				float u = al / heart_wound.w;
				float gap = 0.0013 * max(0.0, 1.0 - u * u) * (1.0 - 0.85 * heart_wound_closed);
				float slit = (1.0 - smoothstep(gap * 0.5, gap + 0.0005, ac)) * step(abs(u), 1.0);
				float rim = 1.0 - smoothstep(0.0, 0.007, length(vec2(max(abs(al) - heart_wound.w, 0.0), ac)));
				col = mix(col, col * vec3(0.72, 0.42, 0.42), rim * 0.55);
				col = mix(col, vec3(0.14, 0.0, 0.01), slit);
			}
		}
		float pooled = 0.0;
		if (cavity_blood > 0.0 && in_open && beat_c == vec3(0.0)) {
			// Le sang stagne sur ce qui regarde vers le haut, au fond ; quelques éclaboussures
			float nz = bb_fbm(wpos * 120.0);
			float pool = smoothstep(0.028, 0.055, open_depth) * smoothstep(0.05, 0.6, n0.y);
			pool *= smoothstep(0.3, 0.55, nz + 0.3 * pool);
			pool = max(pool, smoothstep(0.72, 0.86, nz) * 0.55 * smoothstep(0.03, 0.05, open_depth));
			pooled = clamp(pool * cavity_blood, 0.0, 1.0);
			col = mix(col, mix(vec3(0.17, 0.0, 0.01), vec3(0.3, 0.02, 0.03), nz * 0.5), pooled);
		}
		vec3 nd = tri_normal(detail_normal, wpos, n0, tex_scale, 0.6);
		vec3 nf = tri_normal(fibers_normal, wpos, n0, tex_scale * 0.8, 0.8);
		vec3 nw = normalize(mix(nd, nf, clamp(fiber, 0.0, 1.0)));
		ALBEDO = col;
		ROUGHNESS = mix(mix(rough, 0.14, wetness * 0.5), 0.05, pooled);
		SPECULAR = 0.42;
		CLEARCOAT = max(wetness * 0.5, pooled);
		CLEARCOAT_ROUGHNESS = 0.12;
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		SSS_STRENGTH = sss;
		RIM = 0.15;
		RIM_TINT = 0.6;
	}
}
