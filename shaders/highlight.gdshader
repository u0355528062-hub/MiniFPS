// Surbrillance pulsée (instrument ou cible à utiliser) : liseré lumineux selon l'angle de vue.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec3 glow : source_color = vec3(0.2, 0.95, 0.85);
uniform float strength = 1.0;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float pulse = 0.55 + 0.45 * sin(TIME * 4.0);
	ALBEDO = glow * (0.15 + f) * pulse * strength;
}
