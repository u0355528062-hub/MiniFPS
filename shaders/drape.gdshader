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
// Hauteur de la peau sur le champ opératoire (pour ne retirer que le drap au niveau de la fenêtre)
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec2 patch_min = vec2(0.0);
uniform vec2 patch_size = vec2(0.3);
uniform float breathe = 0.0; // amplitude (m) du soulèvement thoracique
uniform float breath_b = 0.0; // phase de la respiration (0..1), donnée par le patient
uniform float table_top = 0.80;
uniform vec4 chest_x = vec4(-0.34, -0.16, 0.08, 0.2);
uniform vec2 chest_z = vec2(0.1, 0.2);
uniform vec2 chest_h = vec2(0.10, 0.30);
// Bord adhésif autour de la fenêtre : sur cette largeur le drap est collé à plat sur la peau (pas
// de pli coupé net par la fenêtre)
uniform float frame_w = 0.045;
// Carte de hauteur de la peau de tout le corps (-1 hors du corps)
uniform sampler2D body_map : filter_linear, repeat_disable;
uniform vec2 body_min = vec2(0.0);
uniform vec3 body_cells = vec3(1.0, 1.0, 0.0025); // nx, nz, pas

varying vec3 wpos;
varying vec3 wnorm;
varying float glued;

float skin_at(vec2 xz) {
	vec2 uv = ((xz - body_min) / body_cells.z + 0.5) / body_cells.xy;
	return textureLod(body_map, uv, 0.0).r;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// Respiration : le flanc (thorax) se soulève à chaque inspiration
	float chest = smoothstep(chest_x.x, chest_x.y, w.x) * (1.0 - smoothstep(chest_x.z, chest_x.w, w.x)) * (1.0 - smoothstep(chest_z.x, chest_z.y, abs(w.z)));
	chest *= smoothstep(table_top + chest_h.x, table_top + chest_h.y, w.y);
	float lift = breathe * chest * breath_b;
	w.y += lift;
	// Épaisseur du non-tissé : les deux faces s'écartent un peu (la peau ne perce pas entre les
	// grands triangles du drap simulé)
	w += n * 0.003;
	glued = 0.0;
	if (has_window > 0.5) {
		vec2 outw = max(window_min - w.xz, w.xz - window_max);
		float d = length(max(outw, vec2(0.0)));
		float sy0 = skin_at(w.xz);
		if (d < frame_w && sy0 > 0.0) {
			float sy = sy0 + lift;
			// Seul le drap posé sur le dessus du corps est collé (pas celui qui pend sur le flanc)
			if (w.y > sy - 0.03) {
				float hx = (skin_at(w.xz + vec2(0.004, 0.0)) - skin_at(w.xz - vec2(0.004, 0.0))) / 0.008;
				float hz = (skin_at(w.xz + vec2(0.0, 0.004)) - skin_at(w.xz - vec2(0.0, 0.004))) / 0.008;
				vec3 ns = normalize(vec3(-hx, 1.0, -hz));
				// Collé seulement sur le dessus du corps ; plus de jeu là où la peau est bombée
				float k = (1.0 - smoothstep(frame_w * 0.5, frame_w, d)) * smoothstep(0.3, 0.55, ns.y);
				w.y = mix(w.y, sy + 0.003 + 0.01 * (1.0 - ns.y), k);
				ns *= dot(n, ns) < 0.0 ? -1.0 : 1.0;
				n = normalize(mix(n, ns, k));
				glued = k * (1.0 - smoothstep(0.0, 0.016, d));
			}
		}
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(n, 0.0)).xyz);
	wpos = w;
	wnorm = n;
}

void fragment() {
	vec2 p = wpos.xz;
	// Fenêtre : le drap y est retiré au niveau de la peau et au-dessus (plis compris) ; celui qui
	// descend sur le flanc, sous la même verticale, reste
	if (has_window > 0.5 && p.x > window_min.x && p.x < window_max.x && p.y > window_min.y && p.y < window_max.y) {
		float skin_y = textureLod(height_map, (p - patch_min) / patch_size, 0.0).r;
		if (wpos.y > skin_y - 0.008) {
			discard;
		}
	}
	float sc = 1.0 / 0.04;
	float det = tri_tex(fabric_detail, wpos, wnorm, sc).r;
	float mot = tri_tex(mottle, wpos, wnorm, 2.0).r;
	vec3 col = fabric * (0.88 + 0.16 * det) * (0.96 + 0.06 * mot);
	float rough = 0.93;
	vec3 nw = tri_normal(fabric_normal, wpos, normalize(wnorm * (FRONT_FACING ? 1.0 : -1.0)), sc, 0.9 - 0.5 * glued);

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
