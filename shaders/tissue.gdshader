// Tissu vivant humide (organes) : couleur variée, vaisseaux fins, reflets humides, translucidité.
shader_type spatial;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.78, 0.36, 0.33);
uniform vec3 vessel_color : source_color = vec3(0.45, 0.05, 0.08);
uniform float vessel_amount = 0.6;
uniform float inflamed = 0.0;
uniform float wetness = 0.85;
uniform float bump_freq = 140.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = bb_fbm(wpos * 60.0);
	vec3 col = base_color * (0.85 + 0.3 * n);
	// Vaisseaux : lignes fines sinueuses
	float v1 = abs(bb_noise(wpos * 95.0) - 0.5);
	float v2 = abs(bb_noise(wpos * 210.0 + vec3(3.1)) - 0.5);
	float vessels = (1.0 - smoothstep(0.0, 0.025, v1)) * 0.8 + (1.0 - smoothstep(0.0, 0.018, v2)) * 0.5;
	col = mix(col, vessel_color, clamp(vessels * vessel_amount, 0.0, 1.0) * 0.55);
	// Inflammation : rouge sombre, zones violacées
	col = mix(col, vec3(0.55, 0.06, 0.07) * (0.8 + 0.4 * n), inflamed * 0.7);
	col = mix(col, vec3(0.35, 0.10, 0.22), inflamed * smoothstep(0.55, 0.8, bb_fbm(wpos * 30.0)) * 0.5);

	ALBEDO = col;
	ROUGHNESS = mix(0.45, 0.12, wetness);
	SPECULAR = 0.6;
	CLEARCOAT = wetness * 0.8;
	CLEARCOAT_ROUGHNESS = 0.08;
	NORMAL = bb_bump(NORMAL, wpos, bump_freq, 0.0025, VIEW_MATRIX);
	BACKLIGHT = base_color * 0.35;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
