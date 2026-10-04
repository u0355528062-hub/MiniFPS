// Vue anatomique : la peau devient une silhouette translucide (contour lumineux), on voit à travers.
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.35, 0.78, 1.0);
uniform float strength = 0.6;

void fragment() {
	float f = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.6);
	float lines = 0.85 + 0.15 * sin(FRAGCOORD.y * 1.4 + TIME * 8.0);
	ALBEDO = tint * (0.025 + f * strength) * lines;
}
