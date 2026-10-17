// Peau du patient des urgences (maillage MakeHuman couché sur le dos, UV du modèle) : teint, lèvres,
// ongles, aréoles et pores cuits dans des textures (tools/blender/build_skin.py) ; cuir chevelu,
// sourcils et barbe naissante d'après la carte des poils (couleur choisie par le cas) ; grain fin
// en projection triplanaire pour les gros plans. Signes cliniques réglés par la physiologie
// (pâleur, cyanose, sueurs, marbrures, urticaire, rougeur du visage, veines sous garrot) ; le thorax
// se soulève à chaque respiration et s'enfonce sous les mains pendant le massage.
shader_type spatial;
render_mode cull_disabled, sss_mode_skin;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D peau_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D peau_normal : hint_normal, filter_linear_mipmap_anisotropic;
// R lèvres, G ongles, B visage
uniform sampler2D peau_masques : hint_default_black, filter_linear_mipmap;
// R cheveux courts, G sourcils, B barbe naissante
uniform sampler2D peau_poils : hint_default_black, filter_linear_mipmap;
// Grain fin (gros plans)
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 skin_tint : source_color = vec3(0.99, 0.95, 0.94);
uniform vec3 hair_col : source_color = vec3(0.045, 0.032, 0.025);
uniform float stubble = 0.3;
uniform float bald = 0.0;
// Calvitie : centre (monde) et rayon de la zone dégarnie (dessus et avant du crâne)
uniform vec4 crown = vec4(0.44, 1.0, 0.0, 0.09);
// Bouts des doigts (x, z gauche ; x, z droit) : cyanose des extrémités
uniform vec4 fingertips = vec4(-0.5, 0.23, -0.5, -0.23);

// Signes cliniques (0..1)
uniform float pallor = 0.0;
uniform float cyanosis = 0.0;
uniform float sweat = 0.0;
uniform float mottling = 0.0;
uniform float urticaria = 0.0;
uniform float flush = 0.0;
// Veines superficielles des avant-bras : points (x, y, z, largeur ; largeur < 0 = fin d'une veine)
uniform vec4 veins[24];
uniform int vein_n = 0;
uniform vec2 vein_vis = vec2(0.2); // visibilité bras gauche, bras droit (garrot : plus visible)

// Thorax : respiration et massage cardiaque
uniform float table_top = 0.80;
uniform vec4 chest_x = vec4(-0.36, -0.2, 0.08, 0.2);
uniform vec2 chest_z = vec2(0.1, 0.2);
uniform vec2 chest_h = vec2(0.06, 0.16);
uniform float breath = 0.0; // soulèvement du thorax (m)
uniform vec4 comp = vec4(0.0); // x, z, profondeur (m), rayon (m) : thorax enfoncé par les mains

varying vec3 wpos;
varying vec3 wnorm;

float chest_mask(vec2 xz) {
	return smoothstep(chest_x.x, chest_x.y, xz.x) * (1.0 - smoothstep(chest_x.z, chest_x.w, xz.x)) * (1.0 - smoothstep(chest_z.x, chest_z.y, abs(xz.y)));
}

// Zone dégarnie du crâne (0 : cheveux, 1 : peau nue)
float bald_mask(vec3 w) {
	float r = crown.w * bald;
	return 1.0 - smoothstep(r * 0.65, r * 1.05 + 0.002, length(w - crown.xyz));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float hfac = smoothstep(table_top + chest_h.x, table_top + chest_h.y, w.y);
	w.y += breath * chest_mask(w.xz) * hfac;
	if (comp.z > 0.0) {
		// Enfoncement : creux sous les mains, tout le devant du thorax suit un peu
		vec2 d = w.xz - comp.xy;
		float k = exp(-dot(d, d) / (comp.w * comp.w));
		float broad = exp(-dot(d, d) / (comp.w * comp.w * 5.0)) * 0.45;
		w.y -= comp.z * max(k, broad) * smoothstep(table_top + 0.04, table_top + 0.14, w.y);
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	wpos = w;
	wnorm = n;
}

void fragment() {
	vec3 n0 = normalize(wnorm) * (FRONT_FACING ? 1.0 : -1.0);
	vec3 wp = wpos;
	// Teint de la texture un peu trop orangé : ramené vers un rose-beige plus naturel
	vec3 col = texture(peau_albedo, UV).rgb * vec3(0.96, 1.1, 1.13) * skin_tint;
	vec3 msk = texture(peau_masques, UV).rgb;
	vec3 hairs = texture(peau_poils, UV).rgb;
	float lips = smoothstep(0.25, 0.8, msk.r);
	float nails = smoothstep(0.25, 0.8, msk.g);
	float face = msk.b;
	// Teint légèrement irrégulier (taches, rougeurs diffuses)
	float mot = tri_tex(mottle, wp, n0, 1.4).r;
	col *= mix(vec3(0.985, 1.0, 1.01), vec3(1.03, 0.97, 0.96), smoothstep(0.3, 0.85, mot));
	float sc = 1.0 / 0.065;
	float rough = 0.48 + 0.22 * tri_tex(skin_rough, wp, n0, sc).r;
	float spec = 0.34;
	// Grain fin en projection triplanaire (relief monde), les pores cuits passent par NORMAL_MAP
	vec3 nw = tri_normal(skin_normal, wp, n0, sc * 3.3, 0.16);

	float n1 = bb_noise(wp * 2400.0);
	float n2 = bb_noise(wp * 260.0);
	// Cuir chevelu : racines sombres entre les cheveux (les mèches sont des coques à part)
	float scalp = smoothstep(0.2, 0.7, hairs.r) * (1.0 - bald_mask(wp));
	col = mix(col, col * 0.45 + hair_col * 0.35, scalp * (0.55 + 0.25 * n2));
	rough = mix(rough, 0.6, scalp);
	// Sourcils : poils couchés vers l'extérieur
	float brow = smoothstep(0.15, 0.8, hairs.g);
	float strands = smoothstep(0.35, 0.75, bb_noise(vec3(wp.x * 600.0, wp.y * 2600.0, wp.z * 900.0)));
	col = mix(col, hair_col * (0.8 + 0.4 * n2), clamp(brow * (0.3 + 0.35 * strands), 0.0, 1.0));
	// Barbe naissante : ombre bleutée et points des poils coupés ras
	float beard = smoothstep(0.05, 0.6, hairs.b) * stubble;
	col *= mix(vec3(1.0), vec3(0.86, 0.86, 0.9), beard * 0.7);
	float dots = smoothstep(0.7, 0.85, n1);
	col = mix(col, mix(col, hair_col, 0.6), beard * dots * 0.6);
	// Lèvres et ongles : plus lisses, un peu brillants
	rough = mix(rough, 0.42, lips);
	spec = mix(spec, 0.38, lips);
	rough = mix(rough, 0.22, nails);
	spec = mix(spec, 0.55, nails);

	// Veines de l'avant-bras et du dos de la main (bleutées, gonflées sous garrot)
	if (vein_n > 0 && abs(wp.z) > 0.15 && wp.x < 0.0) {
		float best = 1.0;
		float wv = 0.0025;
		for (int i = 0; i < vein_n - 1; i++) {
			vec4 a = veins[i];
			vec4 b = veins[i + 1];
			if (a.w < 0.0 || b.w < 0.0) {
				continue;
			}
			vec3 ab = b.xyz - a.xyz;
			float k = clamp(dot(wp - a.xyz, ab) / dot(ab, ab), 0.0, 1.0);
			float d = length(wp - (a.xyz + ab * k));
			if (d < best) {
				best = d;
				wv = a.w;
			}
		}
		float vis = wp.z > 0.0 ? vein_vis.x : vein_vis.y;
		float v = (1.0 - smoothstep(wv * 0.4, wv * 1.3, best)) * vis;
		col = mix(col, col * vec3(0.72, 0.8, 1.02), v * 0.75);
		rough = mix(rough, 0.42, v * 0.5);
	}

	// ---- Signes cliniques
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	// Rougeur (visage, cou, haut du thorax)
	float upper = max(face, smoothstep(-0.04, 0.2, wp.x) * (1.0 - scalp) * 0.8);
	col = mix(col, col * vec3(1.18, 0.82, 0.8), flush * upper * 0.7);
	// Pâleur : moins de rouge, teint grisâtre ; lèvres décolorées
	col = mix(col, vec3(lum) * vec3(1.08, 1.04, 0.98) + 0.03, pallor * (0.7 + 0.2 * lips));
	// Cyanose : lèvres, ongles, bouts des doigts, puis tout le visage
	float tips = max(1.0 - smoothstep(0.02, 0.06, length(wp.xz - fingertips.xy)), 1.0 - smoothstep(0.02, 0.06, length(wp.xz - fingertips.zw)));
	float extremity = clamp(lips * 1.5 + nails * 1.2 + tips * 0.6 + face * 0.45, 0.0, 1.0);
	col = mix(col, col * vec3(0.55, 0.62, 0.95) + vec3(0.0, 0.0, 0.04), cyanosis * extremity * 0.85);
	col = mix(col, col * vec3(0.82, 0.86, 1.0), cyanosis * 0.35);
	// Marbrures : réseau violacé (livedo) sur l'abdomen, les flancs, les bras
	if (mottling > 0.0) {
		float net = bb_fbm(wp * 38.0);
		float lines = 1.0 - smoothstep(0.03, 0.09, abs(net - 0.5));
		float zone = smoothstep(0.0, -0.2, wp.x) + smoothstep(0.18, 0.24, abs(wp.z));
		col = mix(col, col * vec3(0.72, 0.55, 0.78), lines * mottling * clamp(zone, 0.0, 1.0) * 0.8);
	}
	// Urticaire : plaques rouges en relief, centre plus pâle
	if (urticaria > 0.0) {
		float u = bb_fbm(wp * 26.0 + vec3(3.1));
		float plaque = smoothstep(0.56, 0.62, u) * urticaria * (1.0 - scalp);
		float centre = smoothstep(0.64, 0.7, u);
		col = mix(col, col * vec3(1.25, 0.72, 0.7), plaque * 0.8);
		col = mix(col, col * vec3(1.05, 1.0, 0.98), centre * plaque * 0.6);
		rough = mix(rough, 0.4, plaque);
	}
	// Sueurs : film brillant, fines gouttelettes sur le front et le thorax
	if (sweat > 0.0) {
		float drop = smoothstep(0.86, 0.93, bb_noise(wp * 420.0)) * sweat * smoothstep(-0.15, 0.05, wp.x) * (1.0 - scalp);
		rough = mix(rough, 0.3, sweat * 0.6);
		rough = mix(rough, 0.12, drop * 0.6);
		spec = mix(spec, 0.45, sweat * 0.5 + drop * 0.2);
	}
	if (!FRONT_FACING) {
		col = vec3(0.2, 0.045, 0.04);
		rough = 0.45;
		spec = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	NORMAL_MAP = texture(peau_normal, UV).rgb;
	NORMAL_MAP_DEPTH = 1.0 - 0.6 * scalp;
	SSS_STRENGTH = 0.32 * (1.0 - pallor * 0.5);
	RIM = 0.12;
	RIM_TINT = 0.6;
}
