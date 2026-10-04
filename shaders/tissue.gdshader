// Tissu vivant humide (séreuse des organes) : réseau vasculaire, marbrures, film humide,
// translucidité, inflammation (hyperhémie, zones violacées, fausses membranes de fibrine).
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.82, 0.48, 0.42);
uniform vec3 vessel_color : source_color = vec3(0.42, 0.04, 0.08);
uniform float vessel_amount = 0.7;
uniform float inflamed = 0.0;
uniform float fibrin_amount = 0.0;
uniform float wetness = 0.9;
uniform float tex_scale = 14.0; // répétitions par mètre (~7 cm)
uniform float normal_strength = 0.7;
uniform float clip_y = 100.0; // rien n'est dessiné au-dessus (organes sous la peau)
uniform sampler2D vessels : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tissue_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fibrin : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (wpos.y > clip_y) {
		discard;
	}
	vec3 n0 = normalize(wnorm);
	vec4 ves = tri_tex(vessels, wpos, n0, tex_scale);
	float mot = tri_tex(mottle, wpos, n0, tex_scale * 0.5).r;
	vec3 col = base_color * (0.8 + 0.4 * mot);

	// Vaisseaux : gros troncs violacés, branches rouges, capillaires fins
	float va = vessel_amount * (1.0 + inflamed * 0.8);
	col = mix(col, vessel_color * 0.8, clamp(ves.r * va, 0.0, 1.0) * 0.85);
	col = mix(col, vessel_color * 1.4, clamp(ves.g * va, 0.0, 1.0) * 0.6);
	col = mix(col, vec3(0.75, 0.12, 0.12), clamp(ves.b * va, 0.0, 1.0) * (0.25 + inflamed * 0.45));

	// Inflammation : rouge sombre congestif, plaques violacées
	vec3 hot = vec3(0.58, 0.08, 0.08) * (0.75 + 0.5 * mot);
	col = mix(col, hot, inflamed * 0.6);
	col = mix(col, vec3(0.32, 0.08, 0.2), inflamed * smoothstep(0.62, 0.85, mot) * 0.55);

	// Fausses membranes de fibrine (jaune blanchâtre, mates)
	float fib = tri_tex(fibrin, wpos, n0, tex_scale * 1.6).r * fibrin_amount;
	col = mix(col, vec3(0.92, 0.84, 0.6), fib * 0.8);

	vec3 nw = tri_normal(tissue_normal, wpos, n0, tex_scale, normal_strength);
	ALBEDO = col;
	ROUGHNESS = mix(mix(0.6, 0.4, wetness), 0.78, fib);
	SPECULAR = 0.28;
	CLEARCOAT = wetness * 0.4 * (1.0 - fib);
	CLEARCOAT_ROUGHNESS = 0.2;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.6;
	BACKLIGHT = base_color * 0.3;
	RIM = 0.2;
	RIM_TINT = 0.7;
}
