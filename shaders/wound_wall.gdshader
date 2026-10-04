// Paroi de la plaie : couches peau / graisse / aponévrose / muscle / péritoine selon la profondeur (UV.y).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = UV.y; // 0 = surface, 1 = fond
	float n = bb_fbm(wpos * 300.0);
	vec3 skin = vec3(0.70, 0.30, 0.26);
	vec3 fat = vec3(0.93, 0.78, 0.40) * (0.85 + 0.3 * bb_noise(wpos * 700.0));
	vec3 fascia = vec3(0.90, 0.86, 0.80);
	vec3 muscle = vec3(0.55, 0.10, 0.10) * (0.8 + 0.4 * bb_noise(vec3(wpos.x * 900.0, wpos.y * 120.0, wpos.z * 900.0)));
	vec3 perit = vec3(0.80, 0.45, 0.42);
	vec3 col = skin;
	col = mix(col, fat, smoothstep(0.06, 0.12, d));
	col = mix(col, fascia, smoothstep(0.45, 0.5, d) * (1.0 - smoothstep(0.52, 0.56, d)));
	col = mix(col, muscle, smoothstep(0.54, 0.6, d));
	col = mix(col, perit, smoothstep(0.85, 0.92, d));
	// Petits saignements
	col = mix(col, vec3(0.4, 0.02, 0.03), smoothstep(0.72, 0.85, n) * 0.6);
	ALBEDO = col * (0.85 + 0.2 * n);
	ROUGHNESS = 0.18;
	SPECULAR = 0.55;
	CLEARCOAT = 0.6;
	CLEARCOAT_ROUGHNESS = 0.1;
	NORMAL = bb_bump(NORMAL, wpos, 220.0, 0.002, VIEW_MATRIX);
}
