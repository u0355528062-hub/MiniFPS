// Peau du patient des urgences (maillage de l'atlas, couché sur le dos) : grain et pores, teint
// irrégulier, aréoles, cheveux, sourcils, paupières, lèvres, barbe naissante ; signes cliniques
// réglés par la physiologie (pâleur, cyanose, sueurs, marbrures, urticaire, rougeur du visage) ;
// le thorax se soulève à chaque respiration et s'enfonce sous les mains pendant le massage.
shader_type spatial;
render_mode cull_disabled, sss_mode_skin;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec3 skin_tint : source_color = vec3(0.99, 0.95, 0.94);
uniform vec3 hair_col : source_color = vec3(0.045, 0.032, 0.025);
uniform float stubble = 0.3;
uniform float bald = 0.0;
// Repère de l'atlas (visage, cheveux, mamelons) : za.x = dot(rx.xyz, w) + rx.w, etc.
uniform vec4 atlas_rx = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 atlas_ry = vec4(0.0, -1.0, 0.0, 0.95031);
uniform vec4 atlas_rz = vec4(1.0, 0.0, 0.0, 1.29927);

// Signes cliniques (0..1)
uniform float pallor = 0.0;
uniform float cyanosis = 0.0;
uniform float sweat = 0.0;
uniform float mottling = 0.0;
uniform float urticaria = 0.0;
uniform float flush = 0.0;
uniform float eyes_open = 0.0;
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

vec3 atlas_pos(vec3 w) {
	return vec3(dot(atlas_rx.xyz, w) + atlas_rx.w, dot(atlas_ry.xyz, w) + atlas_ry.w, dot(atlas_rz.xyz, w) + atlas_rz.w);
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
	float sc = 1.0 / 0.065;
	vec3 grain = tri_col(skin_albedo, wp, n0, sc).rgb;
	vec3 col = mix(vec3(0.552, 0.282, 0.191), grain, 0.5) * skin_tint;
	float mot = tri_tex(mottle, wp, n0, 1.4).r;
	col *= mix(vec3(0.985, 1.0, 1.01), vec3(1.035, 0.965, 0.955), smoothstep(0.3, 0.85, mot));
	float rough = 0.5 + 0.28 * tri_tex(skin_rough, wp, n0, sc).r;
	float spec = 0.32;
	vec3 nw = tri_normal(skin_normal, wp, n0, sc, 0.42);
	nw = tri_normal(skin_normal, wp + vec3(0.37), nw, sc * 3.3, 0.18);

	vec3 za = atlas_pos(wp);
	float n1 = bb_noise(wp * 900.0);
	float n2 = bb_noise(wp * 220.0);
	float face = 0.0;
	float lips = 0.0;
	// Aréoles et mamelons
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
			nw = normalize(nw - (g.x * atlas_rx.xyz + g.y * atlas_rz.xyz));
			rough = mix(rough, 0.44, areola);
		}
	}
	// Tête : cheveux, sourcils, paupières, lèvres, barbe naissante
	if (za.z > 1.45 && abs(za.x) < 0.11) {
		face = smoothstep(1.47, 1.52, za.z) * step(za.y, -0.03);
		float hairline = 1.600 + 0.064 * smoothstep(-0.015, -0.085, za.y) - 0.05 * smoothstep(0.03, 0.09, za.y);
		hairline += bald * 0.06 * smoothstep(-0.02, -0.08, za.y);
		float ear = smoothstep(0.062, 0.072, abs(za.x)) * (1.0 - smoothstep(1.615, 1.635, za.z)) * step(za.y, 0.035);
		float hair = smoothstep(hairline - 0.003, hairline + 0.005, za.z) * (1.0 - ear);
		hair *= 0.55 + 0.45 * n2;
		col = mix(col, hair_col * (0.7 + 0.6 * n1), clamp(hair * 0.92, 0.0, 1.0));
		rough = mix(rough, 0.62, hair);
		spec = mix(spec, 0.38, hair);
		// Barbe naissante : joues, menton, lèvre supérieure
		float beard = step(za.y, -0.04) * (1.0 - smoothstep(1.545, 1.565, za.z)) * smoothstep(1.47, 1.49, za.z);
		beard *= smoothstep(0.0, 0.02, abs(za.x) - 0.0) * (1.0 - smoothstep(0.062, 0.07, abs(za.x)));
		beard = max(beard, step(za.y, -0.06) * (1.0 - smoothstep(1.49, 1.5, za.z)) * smoothstep(1.465, 1.475, za.z) * (1.0 - smoothstep(0.03, 0.04, abs(za.x))));
		col = mix(col, col * mix(vec3(1.0), hair_col * 6.0, 0.5), beard * stubble * (0.35 + 0.4 * step(0.55, n1)));
		for (int k = 0; k < 2; k++) {
			float sx = k == 0 ? -1.0 : 1.0;
			vec2 q = vec2(za.x * sx, za.z);
			float bx = (q.x - 0.012) / 0.042;
			float bz = 1.6095 + 0.0045 * sin(clamp(bx, 0.0, 1.0) * 3.0) - 0.002 * bx;
			float brow = step(0.0, bx) * step(bx, 1.0) * (1.0 - smoothstep(0.0022, 0.0034, abs(q.y - bz))) * step(za.y, -0.06);
			brow *= (1.0 - 0.5 * bx) * (0.6 + 0.4 * n1);
			col = mix(col, hair_col * 1.1, clamp(brow, 0.0, 1.0) * 0.85);
			// Paupières (fermées) ou œil entrouvert (sclérotique, iris, pupille)
			float ex = (q.x - 0.0312) / 0.0135;
			float lid_z = 1.5895 - 0.0025 * ex * ex;
			float in_eye = (1.0 - smoothstep(0.85, 1.0, abs(ex))) * step(za.y, -0.072);
			float slit = (1.0 - smoothstep(0.0003, 0.0009, abs(q.y - lid_z))) * in_eye;
			float lash = (1.0 - smoothstep(0.0, 0.0018, lid_z - q.y)) * step(q.y, lid_z) * in_eye * step(0.45, n1);
			if (eyes_open > 0.01) {
				float open_h = 0.0042 * eyes_open * max(0.0, 1.0 - ex * ex);
				float eye = (1.0 - smoothstep(open_h * 0.8, open_h, abs(q.y - lid_z))) * in_eye;
				vec2 ic = vec2((q.x - 0.0312) / 0.0055, (q.y - lid_z) / 0.0055);
				float iris = 1.0 - smoothstep(0.85, 1.0, length(ic));
				float pupil = 1.0 - smoothstep(0.32, 0.42, length(ic));
				vec3 ecol = mix(vec3(0.86, 0.84, 0.8), vec3(0.25, 0.17, 0.1) * (0.8 + 0.4 * n1), iris);
				ecol = mix(ecol, vec3(0.02), pupil);
				col = mix(col, ecol, eye);
				rough = mix(rough, 0.05, eye);
				spec = mix(spec, 0.8, eye);
				nw = normalize(mix(nw, n0, eye));
				slit = (1.0 - smoothstep(0.0, 0.0008, abs(abs(q.y - lid_z) - open_h))) * in_eye;
			}
			col = mix(col, vec3(0.04, 0.025, 0.02), max(slit, lash * 0.7));
			col *= 1.0 - 0.12 * in_eye * (1.0 - smoothstep(0.0, 0.006, abs(q.y - lid_z)));
		}
		float lx = za.x / 0.025;
		float lip_h = 0.0065 * max(0.0, 1.0 - lx * lx);
		lips = (1.0 - smoothstep(lip_h * 0.7, lip_h, abs(za.z - 1.531))) * step(abs(lx), 1.0) * step(za.y, -0.078);
		col = mix(col, vec3(0.52, 0.24, 0.23), lips * 0.6);
		float mouth = (1.0 - smoothstep(0.0003, 0.0009, abs(za.z - 1.5312))) * step(abs(lx), 0.92) * step(za.y, -0.078);
		col = mix(col, vec3(0.16, 0.05, 0.05), mouth);
		rough = mix(rough, 0.35, lips);
	}

	// Veines de l'avant-bras et du dos de la main (bleutées, en léger relief, gonflées sous garrot)
	if (vein_n > 0 && abs(wp.z) > 0.17 && wp.x < -0.2) {
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
		nw = normalize(nw + n0 * 0.0);
		rough = mix(rough, 0.42, v * 0.5);
	}

	// ---- Signes cliniques
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	// Rougeur (visage, cou, haut du thorax)
	float upper = smoothstep(1.2, 1.5, za.z);
	col = mix(col, col * vec3(1.18, 0.82, 0.8), flush * upper * 0.7);
	// Pâleur : moins de rouge, teint grisâtre
	col = mix(col, vec3(lum) * vec3(1.08, 1.04, 0.98) + 0.03, pallor * 0.75);
	// Cyanose : lèvres, oreilles, bouts des doigts, puis tout le visage
	float extremity = clamp(lips * 1.5 + smoothstep(-0.5, -0.6, wp.x) * smoothstep(0.2, 0.24, abs(wp.z)) + face * 0.45, 0.0, 1.0);
	col = mix(col, col * vec3(0.55, 0.62, 0.95) + vec3(0.0, 0.0, 0.04), cyanosis * extremity * 0.85);
	col = mix(col, col * vec3(0.82, 0.86, 1.0), cyanosis * 0.35);
	// Marbrures : réseau violacé (livedo) sur l'abdomen, les flancs, les genoux
	if (mottling > 0.0) {
		float net = bb_fbm(wp * 38.0);
		float lines = 1.0 - smoothstep(0.03, 0.09, abs(net - 0.5));
		float zone = smoothstep(1.15, 0.95, za.z) + smoothstep(0.18, 0.24, abs(wp.z));
		col = mix(col, col * vec3(0.72, 0.55, 0.78), lines * mottling * clamp(zone, 0.0, 1.0) * 0.8);
	}
	// Urticaire : plaques rouges en relief, centre plus pâle
	if (urticaria > 0.0) {
		float u = bb_fbm(wp * 26.0 + vec3(3.1));
		float plaque = smoothstep(0.56, 0.62, u) * urticaria;
		float centre = smoothstep(0.64, 0.7, u);
		col = mix(col, col * vec3(1.25, 0.72, 0.7), plaque * 0.8);
		col = mix(col, col * vec3(1.05, 1.0, 0.98), centre * plaque * 0.6);
		rough = mix(rough, 0.4, plaque);
	}
	// Sueurs : film brillant, gouttelettes
	if (sweat > 0.0) {
		// Film de sueur : la peau luit ; fines gouttelettes sur le front et le thorax
		float drop = smoothstep(0.86, 0.93, bb_noise(wp * 420.0)) * sweat * smoothstep(1.0, 1.25, za.z);
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
	SSS_STRENGTH = 0.3 * (1.0 - pallor * 0.5);
	RIM = 0.12;
	RIM_TINT = 0.6;
}
