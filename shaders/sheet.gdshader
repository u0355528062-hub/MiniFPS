// Drap de coton blanc (posé sur les jambes du patient) : trame fine, légère transluminescence.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"

uniform vec3 cloth : source_color = vec3(0.86, 0.89, 0.92);
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fabric_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX += NORMAL * 0.003;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = n;
}

void fragment() {
	vec3 n0 = normalize(wnorm) * (FRONT_FACING ? 1.0 : -1.0);
	float d = tri_tex(fabric_detail, wpos, n0, 9.0).r;
	float big = bb_fbm(wpos * 6.0);
	ALBEDO = cloth * (0.93 + 0.07 * d) * (0.97 + 0.05 * big);
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	vec3 nw = tri_normal(fabric_normal, wpos, n0, 14.0, 0.35);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.15;
}
