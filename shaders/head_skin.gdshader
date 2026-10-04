// Peau du visage scanné : couleur désaturée et naturelle (le scan d'origine tire sur l'orange),
// mate, légère transluminescence.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tone : source_color = vec3(0.86, 0.72, 0.66);
uniform float desaturate = 0.55;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float g = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, vec3(g), desaturate);
	// Normalise la luminosité puis applique un teint chair un peu pâle (patient endormi)
	c = c / max(g, 0.05) * 0.5 * tone;
	ALBEDO = clamp(c, 0.0, 1.0);
	ROUGHNESS = 0.72;
	SPECULAR = 0.28;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	SSS_STRENGTH = 0.2;
}
