// Géométrie commune peau / plaie (mêmes formules que Patient.edge_open côté GDScript).
// Repère de l'incision : u le long de A -> B (mètres, 0 au milieu), v en travers (v < 0 : bord gauche).

uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec2 patch_min = vec2(0.0);
uniform vec2 patch_size = vec2(0.3);
uniform vec2 inc_a = vec2(0.0);
uniform vec2 inc_b = vec2(0.0, 0.06);
uniform vec2 cut = vec2(1.0, 0.0); // intervalle incisé (t de 0 à 1), vide si x > y
uniform vec2 open_lr = vec2(0.0); // ouverture de chaque bord (0 fermé, 1 écarté)
uniform float wound_w = 0.022; // écart d'un bord à ouverture 1 (m)
uniform float zone_v = 0.07; // la peau s'étire jusqu'à cette distance du trait
uniform vec4 press_a = vec4(0.0); // x, z, rayon, profondeur : peau enfoncée par un instrument
uniform vec4 press_b = vec4(0.0);
uniform vec4 bleb = vec4(0.0); // x, z, rayon, hauteur : bouton d'anesthésie
uniform float breath_now = 0.0; // soulèvement actuel du thorax (m)
uniform vec4 abscess = vec4(0.0); // x, z, rayon, hauteur : dôme d'un abcès

float chest_mask(vec2 xz) {
	return (1.0 - smoothstep(-0.25, -0.05, xz.x)) * smoothstep(-0.7, -0.5, xz.x) * (1.0 - smoothstep(0.12, 0.3, abs(xz.y)));
}

vec2 inc_dir() {
	return normalize(inc_b - inc_a);
}

vec2 inc_perp() {
	vec2 d = inc_dir();
	return vec2(-d.y, d.x);
}

vec2 inc_center() {
	return (inc_a + inc_b) * 0.5;
}

float gap_profile(float u) {
	float half_len = length(inc_b - inc_a) * 0.5;
	float u0 = (cut.x - 0.5) * 2.0 * half_len;
	float u1 = (cut.y - 0.5) * 2.0 * half_len;
	if (u1 <= u0) {
		return 0.0;
	}
	float hl = (u1 - u0) * 0.5 + 0.003;
	float k = (u - (u0 + u1) * 0.5) / hl;
	return sqrt(max(0.0, 1.0 - k * k));
}

// Écart du bord `side` (-1 / +1) au point u : ellipse le long de la partie incisée, contour irrégulier.
float edge_open(float u, float side) {
	float o = side < 0.0 ? open_lr.x : open_lr.y;
	float shape = 1.0 + 0.07 * sin(u * 90.0 + side * 1.3) + 0.04 * sin(u * 210.0 + 2.1);
	return max(o, 0.0) * wound_w * gap_profile(u) * shape;
}

float height_at(vec2 xz) {
	return textureLod(height_map, (xz - patch_min) / patch_size, 0.0).r;
}

// Relief ajouté : peau enfoncée sous la pression, bouton d'anesthésie.
float relief(vec2 xz) {
	vec2 da = xz - press_a.xy;
	vec2 db = xz - press_b.xy;
	vec2 dl = xz - bleb.xy;
	float h = -press_a.w * exp(-dot(da, da) / max(press_a.z * press_a.z, 1e-6));
	h -= press_b.w * exp(-dot(db, db) / max(press_b.z * press_b.z, 1e-6));
	h += bleb.w * exp(-dot(dl, dl) / max(bleb.z * bleb.z, 1e-6));
	h += breath_now * chest_mask(xz);
	if (abscess.w > 0.0) {
		float d = length(xz - abscess.xy) / abscess.z;
		float k = max(0.0, 1.0 - d * d);
		h += abscess.w * k * k;
	}
	return h;
}

float surface_at(vec2 xz) {
	return height_at(xz) + relief(xz);
}

// Hauteur ajoutée près d'un bord écarté : bourrelet de la peau repoussée, bord qui s'arrondit.
float edge_lift(float D, float f, float edge_d) {
	float comp = 2.0 * D / zone_v * f;
	float lip = 1.0 - smoothstep(0.0, 0.003, edge_d);
	return comp * 0.003 - lip * min(D, 0.004) * 0.5;
}
