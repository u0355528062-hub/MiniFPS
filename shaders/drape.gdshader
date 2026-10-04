// Champ opératoire stérile non-tissé (bleu), fenêtre adhésive autour de la zone opérée,
// léger mouvement respiratoire sur le thorax.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 fabric : source_color = vec3(0.13, 0.36, 0.48);
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fabric_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mottle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 window_min = vec2(0.0);
uniform vec2 window_max = vec2(0.0);
uniform float has_window = 0.0;
uniform float breathe = 0.0; // amplitude (m) du soulèvement thoracique
uniform float breath_b = 0.0; // phase de la respiration (0..1), donnée par le patient
uniform float table_top = 0.80;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Respiration : le flanc (thorax) se soulève à chaque inspiration
	float chest = smoothstep(-0.34, -0.16, w.x) * (1.0 - smoothstep(0.08, 0.2, w.x)) * (1.0 - smoothstep(0.1, 0.2, abs(w.z)));
	chest *= smoothstep(table_top + 0.10, table_top + 0.30, w.y);
	VERTEX.y += breathe * chest * breath_b;
	wpos = w;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = wpos.xz;
	if (has_window > 0.5 && p.x > window_min.x && p.x < window_max.x && p.y > window_min.y && p.y < window_max.y) {
		discard;
	}
	float sc = 1.0 / 0.04;
	float det = tri_tex(fabric_detail, wpos, wnorm, sc).r;
	float mot = tri_tex(mottle, wpos, wnorm, 2.0).r;
	vec3 col = fabric * (0.88 + 0.16 * det) * (0.96 + 0.06 * mot);
	float rough = 0.93;
	vec3 nw = tri_normal(fabric_normal, wpos, normalize(wnorm * (FRONT_FACING ? 1.0 : -1.0)), sc, 0.9);

	// Film adhésif transparent autour de la fenêtre (légèrement brillant, plis fins)
	if (has_window > 0.5) {
		vec2 inner = max(window_min - p, p - window_max);
		float e = max(inner.x, inner.y);
		float film = 1.0 - smoothstep(0.0, 0.03, e);
		col = mix(col, col * 1.08 + vec3(0.01), film * 0.5);
		rough = mix(rough, 0.5, film);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.12;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	BACKLIGHT = fabric * 0.12;
	RIM = 0.08;
	RIM_TINT = 0.9;
}
