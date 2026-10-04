// Peau du corps entier (maillage de l'atlas). Sur le champ opératoire (dessus du flanc droit), elle
// reçoit le badigeon, le bouton d'anesthésie et l'enfoncement sous les instruments ; elle laisse la
// place à la zone fendue de l'incision. Le thorax se soulève à chaque respiration.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/wound_common.gdshaderinc"
#include "res://shaders/skin_look.gdshaderinc"

uniform float table_top = 0.80;

varying vec3 wpos;
varying vec3 wnorm;
varying float topw;

float local_relief(vec2 xz) {
	return relief(xz) - breath_now * chest_mask(xz);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 xz = w.xz;
	vec2 uvp = (xz - patch_min) / patch_size;
	vec2 eb = min(uvp, 1.0 - uvp);
	float inside = step(0.0, min(eb.x, eb.y));
	float t = inside * smoothstep(0.0, 0.06, min(eb.x, eb.y));
	t *= (1.0 - smoothstep(0.003, 0.008, abs(w.y - height_at(xz)))) * smoothstep(0.25, 0.5, n.y);
	topw = t;
	float rel = 0.0;
	if (t > 0.0) {
		rel = local_relief(xz) * t;
		float e = 0.002;
		float gx = (local_relief(xz + vec2(e, 0.0)) - local_relief(xz - vec2(e, 0.0))) / (2.0 * e);
		float gz = (local_relief(xz + vec2(0.0, e)) - local_relief(xz - vec2(0.0, e))) / (2.0 * e);
		n = normalize(n + vec3(-gx, 0.0, -gz) * t);
	}
	float hfac = smoothstep(table_top + 0.10, table_top + 0.30, w.y);
	w.y += rel + breath_now * chest_mask(xz) * hfac;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(w, 1.0)).xyz;
	NORMAL = normalize((inverse(MODEL_MATRIX) * vec4(n, 0.0)).xyz);
	wpos = w;
	wnorm = n;
}

void fragment() {
	vec2 p = wpos.xz;
	if (topw > 0.5) {
		vec2 q = p - inc_center();
		if (abs(dot(q, inc_dir())) < zone_u - 0.0007 && abs(dot(q, inc_perp())) < zone_v - 0.0007) {
			discard;
		}
	}
	vec3 n0 = normalize(wnorm) * (FRONT_FACING ? 1.0 : -1.0);
	vec3 col;
	float rough;
	float spec;
	vec3 nw;
	skin_shade(wpos, n0, p, topw, 1.0, 0.0, col, rough, spec, nw);
	if (!FRONT_FACING) {
		col *= 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.35;
}
