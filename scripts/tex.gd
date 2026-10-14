class_name Tex
## Textures partagées (générées par tools/gen_textures.py) 

static var _cache := {}


static func get_tex(tex_name: String) -> Texture2D:
	if not _cache.has(tex_name):
		_cache[tex_name] = load("res://assets/textures/%s.png" % tex_name)
	return _cache[tex_name]


static func get_tex_any(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
