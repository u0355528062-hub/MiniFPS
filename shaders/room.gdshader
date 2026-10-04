// Surfaces de la salle : sol vinyle coulé moucheté, murs en panneaux, plafond en dalles (selon "kind").
// Textures précalculées (léger en VR), joints calculés.
shader_type spatial;

uniform int kind = 0; // 0 = sol, 1 = mur, 2 = plafond
uniform vec3 tint : source_color = vec3(0.6, 0.7, 0.7);
uniform sampler2D floor_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_rough : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wall_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 col = tint;
	float rough = 0.5;
	float spec = 0.5;
	if (kind == 0) {
		col = tint * texture(floor_detail, wpos.xz).r;
		vec2 g = abs(fract(wpos.xz / 2.0 + 0.5) - 0.5) * 2.0;
		float seam = 1.0 - smoothstep(0.0, 0.004, min(1.0 - g.x, 1.0 - g.y));
		col *= 1.0 - seam * 0.25;
		rough = texture(floor_rough, wpos.xz).r;
		spec = 0.55;
		vec2 d = (texture(floor_normal, wpos.xz).xy * 2.0 - 1.0) * 0.6;
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(d.x, 1.0, -d.y)), 0.0)).xyz);
	} else if (kind == 1) {
		vec2 uv = abs(wnorm.x) > 0.5 ? wpos.zy : wpos.xy;
		float px = fract(uv.x / 1.2);
		float py = fract(uv.y / 1.2);
		float jx = 1.0 - smoothstep(0.0, 0.004, min(px, 1.0 - px) * 1.2);
		float jy = 1.0 - smoothstep(0.0, 0.004, min(py, 1.0 - py) * 1.2);
		col = tint * texture(wall_detail, uv * 0.5).r;
		col *= 1.0 - max(jx, jy) * 0.18;
		rough = 0.4;
		spec = 0.45;
	} else {
		vec2 g = abs(fract(wpos.xz / 0.6) - 0.5) * 2.0;
		float joint = 1.0 - smoothstep(0.0, 0.03, min(1.0 - g.x, 1.0 - g.y));
		col = tint * texture(wall_detail, wpos.xz).r;
		col *= 1.0 - joint * 0.25;
		rough = 0.8;
		spec = 0.3;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
