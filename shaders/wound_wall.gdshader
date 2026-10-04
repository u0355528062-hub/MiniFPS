// Paroi de la plaie, de la surface vers le fond (UV.y = profondeur 0..1, UV.x = mètres le long du bord) :
// derme, graisse en lobules jaunes, aponévrose nacrée, muscle fibreux, péritoine. Coulures de sang.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D fat_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fat_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D muscle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D muscle_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float depth_m = 0.05;

void fragment() {
	float d = UV.y;
	vec2 uv = vec2(UV.x, d * depth_m); // en mètres
	vec3 fat = texture(fat_albedo, uv / 0.03).rgb * 0.78;
	vec2 fat_n = texture(fat_normal, uv / 0.03).xy * 2.0 - 1.0;
	float fib = texture(muscle, vec2(uv.x / 0.03, uv.y / 0.012)).r;
	vec2 mus_n = texture(muscle_normal, vec2(uv.x / 0.03, uv.y / 0.012)).xy * 2.0 - 1.0;

	vec3 dermis = vec3(0.7, 0.36, 0.32);
	vec3 fascia = vec3(0.92, 0.9, 0.84) * (0.9 + 0.15 * fib);
	vec3 musc = mix(vec3(0.45, 0.06, 0.07), vec3(0.68, 0.14, 0.13), fib);
	vec3 perit = vec3(0.86, 0.55, 0.5);

	float w_fat = smoothstep(0.05, 0.1, d) * (1.0 - smoothstep(0.44, 0.48, d));
	float w_fas = smoothstep(0.46, 0.5, d) * (1.0 - smoothstep(0.55, 0.58, d));
	float w_mus = smoothstep(0.56, 0.6, d) * (1.0 - smoothstep(0.84, 0.88, d));
	float w_per = smoothstep(0.86, 0.9, d);
	float w_der = 1.0 - smoothstep(0.04, 0.09, d);
	vec3 col = dermis * w_der + fat * w_fat + fascia * w_fas + musc * w_mus + perit * w_per;
	vec2 nt = fat_n * w_fat * 0.9 + mus_n * w_mus * 0.7 + mus_n * w_fas * 0.25;

	// Coulures de sang verticales qui s'accumulent vers le fond
	float drip = texture(blood_tex, vec2(UV.x / 0.02, d * 0.15)).r;
	float blood = smoothstep(0.52, 0.7, drip + d * 0.35) * 0.85;
	col = mix(col, vec3(0.36, 0.02, 0.03), blood);

	ALBEDO = col * 0.85;
	ROUGHNESS = mix(0.32, 0.12, blood);
	SPECULAR = 0.4;
	CLEARCOAT = 0.4 * smoothstep(0.1, 0.4, d);
	CLEARCOAT_ROUGHNESS = 0.08;
	NORMAL_MAP = vec3(nt * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	SSS_STRENGTH = 0.3;
}
