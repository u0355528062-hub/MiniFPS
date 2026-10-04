class_name Tex
## Textures partagées (générées par tools/gen_textures.py) et matériaux qui les utilisent.

static var _cache := {}


static func get_tex(tex_name: String) -> Texture2D:
	if not _cache.has(tex_name):
		_cache[tex_name] = load("res://assets/textures/%s.png" % tex_name)
	return _cache[tex_name]


## Champ non-tissé bleu (fenêtre optionnelle en coordonnées monde xz).
static func drape(color := Color(0.13, 0.36, 0.48), win_min := Vector2.ZERO, win_max := Vector2.ZERO, breathe := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/drape.gdshader")
	m.set_shader_parameter("fabric", color)
	m.set_shader_parameter("fabric_normal", get_tex("fabric_normal"))
	m.set_shader_parameter("fabric_detail", get_tex("fabric_detail"))
	m.set_shader_parameter("mottle", get_tex("tissue_mottle"))
	m.set_shader_parameter("breathe", breathe)
	if win_max != win_min:
		m.set_shader_parameter("window_min", win_min)
		m.set_shader_parameter("window_max", win_max)
		m.set_shader_parameter("has_window", 1.0)
	return m


## Tissu vivant (organes) : couleur de base, inflammation, fibrine.
static func tissue(base: Color, inflamed := 0.0, vessels := 0.6, fibrin := 0.0, scale := 14.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/tissue.gdshader")
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("inflamed", inflamed)
	m.set_shader_parameter("vessel_amount", vessels)
	m.set_shader_parameter("fibrin_amount", fibrin)
	m.set_shader_parameter("tex_scale", scale)
	m.set_shader_parameter("vessels", get_tex("vessels"))
	m.set_shader_parameter("tissue_normal", get_tex("tissue_normal"))
	m.set_shader_parameter("mottle", get_tex("tissue_mottle"))
	m.set_shader_parameter("fibrin", get_tex("fibrin"))
	return m
