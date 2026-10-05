// Vignettage léger posé sur l'image 3D (sous l'interface) : les bords s'assombrissent doucement,
// le regard va au centre, comme à travers une optique.
shader_type canvas_item;

uniform float strength = 0.3;

void fragment() {
	vec2 uv = SCREEN_UV - 0.5;
	uv.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(uv);
	float v = smoothstep(0.38, 0.95, r);
	COLOR = vec4(0.0, 0.0, 0.0, v * v * strength);
}
