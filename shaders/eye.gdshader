// Yeux du patient (globes MakeHuman, texture CC0) : sclérotique, iris, pupille dont le diamètre suit
// la physiologie (myosis, mydriase), cornée brillante et humide.
shader_type spatial;
render_mode cull_back;

uniform sampler2D iris_tex : source_color, filter_linear_mipmap_anisotropic;
// Centres des deux iris dans la texture, rayon de l'iris, rayon de la pupille peinte
uniform vec4 centres = vec4(0.707, 0.297, 0.289, 0.707);
uniform float iris_r = 0.107;
uniform float pupil_tex = 0.035;
// Diamètre de la pupille (mm ; iris ≈ 12 mm)
uniform float pupil_mm = 4.0;
uniform float pallor = 0.0;

void fragment() {
	// La coque transparente de la cornée (zone sans opacité de la texture) n'est pas dessinée : le
	// globe lui-même est verni (clearcoat)
	if (texture(iris_tex, UV).a < 0.5) {
		discard;
	}
	vec2 c = distance(UV, centres.xy) < distance(UV, centres.zw) ? centres.xy : centres.zw;
	vec2 d = UV - c;
	float r = length(d);
	vec2 uv = UV;
	if (r < iris_r) {
		// L'iris se déforme autour de la pupille : la pupille peinte prend le diamètre voulu
		float p = clamp(pupil_mm / 12.0 * iris_r, 0.012, iris_r * 0.8);
		float r2 = r < p ? r * pupil_tex / p : pupil_tex + (r - p) * (iris_r - pupil_tex) / (iris_r - p);
		uv = c + d / max(r, 1e-5) * r2;
	}
	vec3 col = texture(iris_tex, uv).rgb;
	// Sclérotique un peu moins blanche (pas d'effet « émissif »)
	float sclera = smoothstep(iris_r * 1.02, iris_r * 1.25, r);
	col = mix(col, col * vec3(0.72, 0.7, 0.68), sclera);
	col = mix(col, vec3(dot(col, vec3(0.33))), pallor * 0.3 * sclera);
	ALBEDO = col;
	// Ombre de la paupière sur le haut du globe (le patient regarde le plafond : haut = +X)
	AO = mix(1.0, 0.55, smoothstep(0.2, 0.9, dot(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz), vec3(0.85, 0.5, 0.0))));
	AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = 0.06;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
