// Peau du corps entier (maillage de l'atlas). Sur le champ opératoire (dessus du flanc droit), elle
// reçoit le badigeon, le bouton d'anesthésie et l'enfoncement sous les instruments ; elle laisse la
// place à la zone fendue de l'incision. Le thorax se soulève à chaque respiration.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/wound_common.gdshaderinc"
#include "res://shaders/skin_look.gdshaderinc"

uniform float table_top = 0.80;
// La plaie laisse voir les tissus : la coque interne de la peau y est ouverte
uniform vec3 reveal_c = vec3(0.0);
uniform vec3 reveal_axis = vec3(0.0, -1.0, 0.0);
uniform float reveal_r = 0.0;
uniform float atlas_lift = 1.14006; // repère de l'atlas : x = lift - Y, y = -Z - 0.004, z = X + 1.275

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
	float hfac = smoothstep(table_top + chest_h.x, table_top + chest_h.y, w.y);
	if (t > 0.0) {
		// Sur le champ opératoire, la peau suit exactement le relief de la zone de l'incision
		// (même hauteur et même normale) : aucune couture visible entre les deux maillages
		float e = 0.0025;
		float hx = surface_at(xz + vec2(e, 0.0)) - surface_at(xz - vec2(e, 0.0));
		float hz = surface_at(xz + vec2(0.0, e)) - surface_at(xz - vec2(0.0, e));
		vec3 nh = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
		n = normalize(mix(n, nh, t));
		float base = w.y + breath_now * chest_mask(xz) * hfac + local_relief(xz);
		w.y = mix(base, surface_at(xz), t);
	} else {
		w.y += breath_now * chest_mask(xz) * hfac;
	}
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
	if (reveal_r > 0.0 && topw < 0.5) {
		vec3 dr = wpos - reveal_c;
		float al = dot(dr, reveal_axis);
		if (al > 0.005 && length(dr - reveal_axis * al) < reveal_r * 1.3) {
			discard;
		}
	}
	vec3 n0 = normalize(wnorm) * (FRONT_FACING ? 1.0 : -1.0);
	vec3 col;
	float rough;
	float spec;
	vec3 nw;
	skin_shade(wpos, n0, p, topw, 1.0, 0.0, col, rough, spec, nw);
	// Tête : cheveux ras, sourcils, paupières fermées (cils), lèvres
	vec3 za = vec3(atlas_lift - wpos.y, -wpos.z - 0.004, wpos.x + 1.275);
	if (za.z > 1.45 && abs(za.x) < 0.11) {
		float n1 = bb_noise(wpos * 900.0);
		float n2 = bb_noise(wpos * 220.0);
		float hairline = 1.600 + 0.064 * smoothstep(-0.015, -0.085, za.y) - 0.05 * smoothstep(0.03, 0.09, za.y);
		float ear = smoothstep(0.062, 0.072, abs(za.x)) * (1.0 - smoothstep(1.615, 1.635, za.z)) * step(za.y, 0.035);
		float hair = smoothstep(hairline - 0.003, hairline + 0.005, za.z) * (1.0 - ear);
		hair *= 0.55 + 0.45 * n2;
		vec3 hair_col = vec3(0.045, 0.032, 0.025) * (0.7 + 0.6 * n1);
		col = mix(col, hair_col, clamp(hair * 0.92, 0.0, 1.0));
		rough = mix(rough, 0.62, hair);
		spec = mix(spec, 0.38, hair);
		for (int k = 0; k < 2; k++) {
			float sx = k == 0 ? -1.0 : 1.0;
			vec2 q = vec2(za.x * sx, za.z);
			// Sourcils
			float bx = (q.x - 0.012) / 0.042;
			float bz = 1.6095 + 0.0045 * sin(clamp(bx, 0.0, 1.0) * 3.0) - 0.002 * bx;
			float brow = step(0.0, bx) * step(bx, 1.0) * (1.0 - smoothstep(0.0022, 0.0034, abs(q.y - bz))) * step(za.y, -0.06);
			brow *= (1.0 - 0.5 * bx) * (0.6 + 0.4 * n1);
			col = mix(col, vec3(0.05, 0.035, 0.028), clamp(brow, 0.0, 1.0) * 0.85);
			// Paupières fermées : fente et cils
			float ex = (q.x - 0.0312) / 0.0135;
			float lid_z = 1.5895 - 0.0025 * ex * ex;
			float in_eye = (1.0 - smoothstep(0.85, 1.0, abs(ex))) * step(za.y, -0.072);
			float slit = (1.0 - smoothstep(0.0003, 0.0009, abs(q.y - lid_z))) * in_eye;
			float lash = (1.0 - smoothstep(0.0, 0.0018, lid_z - q.y)) * step(q.y, lid_z) * in_eye * step(0.45, n1);
			col = mix(col, vec3(0.04, 0.025, 0.02), max(slit, lash * 0.7));
			col *= 1.0 - 0.12 * in_eye * (1.0 - smoothstep(0.0, 0.006, abs(q.y - lid_z)));
		}
		// Lèvres et commissure
		float lx = za.x / 0.025;
		float lip_h = 0.0065 * max(0.0, 1.0 - lx * lx);
		float lips = (1.0 - smoothstep(lip_h * 0.7, lip_h, abs(za.z - 1.531))) * step(abs(lx), 1.0) * step(za.y, -0.078);
		col = mix(col, vec3(0.52, 0.24, 0.23), lips * 0.6);
		float mouth = (1.0 - smoothstep(0.0003, 0.0009, abs(za.z - 1.5312))) * step(abs(lx), 0.92) * step(za.y, -0.08);
		col = mix(col, vec3(0.16, 0.05, 0.05), mouth);
	}
	if (!FRONT_FACING) {
		col *= 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.22;
}
