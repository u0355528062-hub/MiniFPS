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

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 v = VERTEX;
	if (hilum != vec3(0.0)) {
		float k = mix(1.0, 0.56, collapse) * (1.0 + 0.025 * breath);
		v = hilum + (v - hilum) * k;
	}
	if (beat_c != vec3(0.0)) {
		v = beat_c + (v - beat_c) * (1.0 + beat);
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
	if (show_all < 0.5) {
		vec3 d = wpos - reveal_c;
		float along = dot(d, reveal_axis);
		float lat = length(d - reveal_axis * along);
		if (reveal_r <= 0.0 || along < 0.0 || lat > reveal_r) {
			discard;
		}
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
		vec3 col = mix(base_color, alt_color, smoothstep(0.3, 0.8, det));
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
		vec3 nd = tri_normal(detail_normal, wpos, n0, tex_scale, 0.6);
		vec3 nf = tri_normal(fibers_normal, wpos, n0, tex_scale * 0.8, 0.8);
		vec3 nw = normalize(mix(nd, nf, clamp(fiber, 0.0, 1.0)));
		ALBEDO = col;
		ROUGHNESS = mix(rough, 0.14, wetness * 0.5);
		SPECULAR = 0.42;
		CLEARCOAT = wetness * 0.5;
		CLEARCOAT_ROUGHNESS = 0.12;
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
		SSS_STRENGTH = sss;
		RIM = 0.15;
		RIM_TINT = 0.6;
	}
}
