// Cheveux courts, sourcils et barbe naissante du patient : coques superposées (« shells ») au-dessus
// de la peau, chacune découpée en points de poils de plus en plus fins vers la pointe. La densité
// vient de la carte des poils (R cheveux, G sourcils, B barbe), la couleur du cas.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://shaders/noise.gdshaderinc"

uniform sampler2D peau_poils : hint_default_black, filter_linear_mipmap;
uniform vec3 hair_col : source_color = vec3(0.045, 0.032, 0.025);
uniform float stubble = 0.3;
uniform float bald = 0.0;
uniform vec4 crown = vec4(0.44, 1.0, 0.0, 0.09);
// Longueur des cheveux (m) et sens de la coiffure (monde)
uniform float hair_len = 0.006;
uniform vec3 comb = vec3(1.0, 0.0, 0.0);
// Hauteur de cette coque (0 : racine, 1 : pointe)
instance uniform float shell = 0.5;

varying vec3 rest;
varying vec3 wrest;

float bald_mask(vec3 w) {
	float r = crown.w * bald;
	return 1.0 - smoothstep(r * 0.65, r * 1.05 + 0.002, length(w - crown.xyz));
}

void vertex() {
	rest = VERTEX;
	wrest = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 hw = texture(peau_poils, UV).rgb;
	// Les sourcils et la barbe sont plus courts et couchés
	float len = hair_len * mix(1.0, 0.45, smoothstep(0.1, 0.6, max(hw.g, hw.b)));
	vec3 n = NORMAL;
	vec3 c = (inverse(MODEL_MATRIX) * vec4(comb, 0.0)).xyz;
	c = normalize(c - n * dot(c, n) + vec3(1e-4));
	VERTEX += n * len * shell + c * len * shell * shell * 0.9;
}

void fragment() {
	vec3 hw = texture(peau_poils, UV).rgb;
	float scalp = smoothstep(0.3, 0.75, hw.r) * (1.0 - bald_mask(wrest));
	float brow = smoothstep(0.4, 0.9, hw.g) * step(shell, 0.22) * 0.45;
	float dens = max(scalp, brow);
	// Un poil par cellule (≈ 0,45 mm), rayon décroissant vers la pointe
	vec3 p = rest * 2200.0;
	vec3 cell = floor(p);
	vec3 f = fract(p) - 0.5;
	float r = bb_hash(cell);
	float r2 = bb_hash(cell + vec3(7.3));
	vec3 jitter = (vec3(r, r2, bb_hash(cell + vec3(3.1))) - 0.5) * 0.4;
	float d = length(f - jitter);
	float thick = mix(0.36, 0.14, shell) * mix(1.0, 0.8, brow);
	// De loin, un poil fait moins d'un pixel : on l'épaissit pour éviter le scintillement
	thick = max(thick, min(length(fwidth(p)) * 0.45, 0.5));
	float keep = step(d, thick) * step(r2, dens * mix(1.0, 0.8, shell));
	if (keep < 0.5) {
		discard;
	}
	// Racines plus sombres (ombre entre les cheveux), pointes plus claires, cheveux un peu différents
	vec3 col = hair_col * mix(0.7, 1.12, shell) * (0.9 + 0.2 * r);
	ALBEDO = col;
	ROUGHNESS = 0.42;
	SPECULAR = 0.5;
	AO = mix(0.5, 1.0, shell);
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = hair_col * 0.3;
}
