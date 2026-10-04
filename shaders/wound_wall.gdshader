// Parois de la plaie, générées ici à partir de l'ouverture de chaque bord (aucun calcul processeur) :
// derme, graisse en lobules jaunes, aponévrose nacrée, muscle fibreux, péritoine. Coulures de sang.
// UV.x = u le long de l'incision (m), UV.y = profondeur 0..1, UV2.x = côté (-1 / +1).
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/wound_common.gdshaderinc"

uniform sampler2D fat_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fat_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D muscle : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D muscle_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D blood_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float depth_m = 0.05;

vec3 wall_point(float u, float f, float side) {
	vec2 d = inc_dir();
	vec2 pp = inc_perp();
	vec2 c = inc_center();
	float D = edge_open(u, side);
	vec2 rim = c + d * u + pp * side * D;
	float top = surface_at(rim) + edge_lift(D, 1.0, 0.0);
	vec2 xz = c + d * u * (1.0 - 0.08 * f) + pp * side * D * (1.0 - 0.72 * f);
	float depth = depth_m * f * smoothstep(0.0, 0.0015, D);
	return vec3(xz.x, top - depth, xz.y);
}

void vertex() {
	float side = UV2.x;
	vec3 p = wall_point(UV.x, UV.y, side);
	vec3 pu = wall_point(UV.x + 0.001, UV.y, side);
	vec3 pf = wall_point(UV.x, UV.y + 0.03, side);
	vec3 n = cross(pf - p, pu - p);
	// La normale regarde vers l'intérieur de la plaie
	vec2 pp = inc_perp();
	if (dot(n.xz, pp * side) > 0.0) {
		n = -n;
	}
	VERTEX = p;
	NORMAL = length(n) > 1e-9 ? normalize(n) : vec3(0.0, 1.0, 0.0);
	vec3 tu = pu - p;
	TANGENT = length(tu) > 1e-9 ? normalize(tu) : vec3(1.0, 0.0, 0.0);
	BINORMAL = cross(NORMAL, TANGENT);
}

void fragment() {
	// La normale est déjà tournée vers l'intérieur de la plaie : on annule l'inversion des faces arrière
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	float d = UV.y;
	vec2 uv = vec2(UV.x, d * depth_m); // en mètres
	vec3 fat = mix(texture(fat_albedo, uv / 0.03).rgb, vec3(0.78, 0.62, 0.36), 0.35) * 0.72;
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
	// Lobules de graisse moins réguliers : deux échelles mélangées
	float lob = texture(fat_albedo, uv / 0.071 + vec2(0.37, 0.11)).g;
	col = mix(col, col * (0.85 + 0.3 * lob), w_fat);
	vec2 nt = fat_n * w_fat * 0.45 + mus_n * w_mus * 0.6 + mus_n * w_fas * 0.2;

	// Coulures de sang verticales qui s'accumulent vers le fond
	float drip = texture(blood_tex, vec2(UV.x / 0.035 + UV2.x * 0.37, d * 0.12)).r;
	float blood = smoothstep(0.55, 0.8, drip + d * 0.3) * 0.6;
	col = mix(col, vec3(0.30, 0.02, 0.025), blood);

	ALBEDO = col * 0.85;
	ROUGHNESS = mix(0.32, 0.12, blood);
	SPECULAR = 0.4;
	CLEARCOAT = 0.25 * smoothstep(0.3, 0.6, d);
	CLEARCOAT_ROUGHNESS = 0.08;
	NORMAL_MAP = vec3(nt * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
}
