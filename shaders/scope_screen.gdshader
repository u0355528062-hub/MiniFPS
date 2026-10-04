// Écran de la colonne d'endoscopie : image ronde de la caméra (léger fish-eye, bords assombris),
// fond noir autour, comme sur un vrai moniteur de bloc.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D view : source_color, filter_linear;
uniform float on = 0.0;
uniform float aspect = 1.6667;

void fragment() {
	vec2 c = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(c);
	float circle = 1.0 - smoothstep(0.445, 0.455, r);
	vec2 q = c / 0.9;
	q *= 1.0 + 0.22 * dot(q, q);
	vec3 col = texture(view, q + 0.5).rgb * circle * on;
	col *= 1.0 - 0.45 * smoothstep(0.28, 0.45, r);
	// Petit grain de capteur
	float n = fract(sin(dot(UV * 800.0 + TIME, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * 0.02 * on * circle;
	ALBEDO = col + vec3(0.008, 0.01, 0.013);
}
