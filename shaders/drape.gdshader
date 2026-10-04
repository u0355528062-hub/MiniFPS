// Champ opératoire stérile (non-tissé bleu-vert), fenêtre adhésive autour de la zone opérée.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 fabric : source_color = vec3(0.18, 0.42, 0.50);
uniform vec2 window_min = vec2(0.0);
uniform vec2 window_max = vec2(0.0);
uniform float has_window = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	if (has_window > 0.5 && p.x > window_min.x && p.x < window_max.x && p.y > window_min.y && p.y < window_max.y) {
		discard;
	}
	// Non-tissé mat : seulement des variations douces (pas de bruit fin, qui scintille en VR)
	float mottle = bb_fbm(wpos * 6.0);
	vec3 col = fabric * (0.9 + 0.12 * mottle);
	float rough = 0.96;
	// Bande adhésive transparente autour de la fenêtre
	if (has_window > 0.5) {
		vec2 inner = max(window_min - p, p - window_max);
		float edge = max(inner.x, inner.y);
		float film = 1.0 - smoothstep(0.0, 0.03, edge);
		col = mix(col, col * 1.06, film * 0.6);
		rough = mix(rough, 0.7, film);
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.12;
	NORMAL = bb_bump(NORMAL, wpos, 14.0, 0.006, VIEW_MATRIX);
	BACKLIGHT = fabric * 0.1;
}
