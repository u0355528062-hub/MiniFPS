// Zone de l'incision, fendue le long du trait : ses deux bords s'écartent et se détendent (la
// déformation est calculée ici, rien sur le processeur). UV = (u, v) au repos, UV2.x = côté.
// Le reste de la peau est dessiné par le corps (body_skin.gdshader), même aspect.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/noise.gdshaderinc"
#include "res://shaders/wound_common.gdshaderinc"
#include "res://shaders/skin_look.gdshaderinc"

varying vec3 rest3;
varying float edge_d;
varying float open_here;

void vertex() {
	vec2 d = inc_dir();
	vec2 pp = inc_perp();
	float side = UV2.x;
	float av = abs(UV.y);
	vec2 rest = inc_center() + d * UV.x + pp * UV.y;
	float D = edge_open(UV.x, side);
	float f = max(0.0, 1.0 - av / zone_v);
	float disp = D * f * f;
	vec2 pos = rest + pp * side * disp;
	edge_d = av + disp - D;
	open_here = D;
	// Le pourtour de la zone passe très légèrement sous la peau du corps (aucune fente visible)
	float border = smoothstep(0.85, 1.0, max(abs(UV.x) / zone_u, av / zone_v));
	VERTEX = vec3(pos.x, surface_at(pos) + edge_lift(D, f, edge_d) - border * 0.0003, pos.y);
	float e = 0.0025;
	float hx = surface_at(pos + vec2(e, 0.0)) - surface_at(pos - vec2(e, 0.0));
	float hz = surface_at(pos + vec2(0.0, e)) - surface_at(pos - vec2(0.0, e));
	NORMAL = normalize(vec3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)));
	rest3 = vec3(rest.x, height_at(rest), rest.y);
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col;
	float rough;
	float spec;
	vec3 nw;
	skin_shade(rest3, wn, rest3.xz, 1.0, edge_d, open_here, col, rough, spec, nw);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = spec;
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	SSS_STRENGTH = 0.35;
}
