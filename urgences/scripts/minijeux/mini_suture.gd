class_name MiniSuture
extends Control
## Suture d'une plaie : pour chaque point, piquer d'un côté de la plaie puis ressortir en face
## (deux clics dans les cercles), à distance régulière. La précision et la régularité donnent
## la note (bon affrontement des berges = cicatrice propre).

signal termine(succes: bool, qualite: float)

const POINTS := 6

var _plaie: PackedVector2Array
var _cibles := []           # [entrée, sortie] pour chaque point
var _i := 0
var _etape := 0             # 0 = entrée, 1 = sortie
var _precision := []
var _fils := []
var _peau: ImageTexture
var police: Font
var _message := "Cliquez sur le cercle d'entrée, puis sur le cercle de sortie, point après point."


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Plein écran quel que soit le parent (CanvasLayer, fenêtre…).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	police = ThemeHopital.theme().default_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_preparer.call_deferred()


func _preparer() -> void:
	var c := size * 0.5
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_plaie = PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		_plaie.append(c + Vector2(lerpf(-300, 300, t), sin(t * 3.0 + rng.randf()) * 24.0 - 10.0))
	for k in POINTS:
		var t := (k + 0.5) / POINTS
		var p := _point_plaie(t)
		var n := _normale(t)
		_cibles.append([p + n * 42.0, p - n * 42.0])
	# Texture de peau (bruit doux) générée une fois.
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var v := 0.9 + 0.06 * sin(x * 0.21 + y * 0.13) + rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(0.86 * v, 0.66 * v, 0.56 * v))
	_peau = ImageTexture.create_from_image(img)


func _point_plaie(t: float) -> Vector2:
	var f := t * (_plaie.size() - 1)
	var i := int(clampf(floor(f), 0, _plaie.size() - 2))
	return _plaie[i].lerp(_plaie[i + 1], f - i)


func _normale(t: float) -> Vector2:
	var d := _point_plaie(minf(t + 0.01, 1.0)) - _point_plaie(maxf(t - 0.01, 0.0))
	return Vector2(-d.y, d.x).normalized()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _i >= POINTS:
		return
	var cible: Vector2 = _cibles[_i][_etape]
	var d: float = event.position.distance_to(cible)
	if d > 60.0:
		_message = "Trop loin de la zone : piquez dans le cercle."
		return
	_precision.append(clampf(1.0 - d / 60.0, 0.0, 1.0))
	if _etape == 0:
		_etape = 1
		_message = "Ressortez de l'autre côté de la plaie."
	else:
		_fils.append([_cibles[_i][0], _cibles[_i][1]])
		_etape = 0
		_i += 1
		_message = "Point %d noué." % _i
		if _i >= POINTS:
			var q := 0.0
			for p in _precision:
				q += p
			q /= _precision.size()
			_message = "Suture terminée : qualité %d %%." % int(q * 100)
			get_tree().create_timer(2.0).timeout.connect(func():
				termine.emit(true, q)
				queue_free())
	queue_redraw()


func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.04, 0.06, 0.07, 0.95))
	if _peau == null:
		return
	var zone := Rect2(t * 0.5 - Vector2(420, 230), Vector2(840, 460))
	draw_texture_rect(_peau, zone, true)
	draw_rect(zone, Color(0.2, 0.5, 0.55), false, 6.0)   # champ stérile
	# Plaie : bords rouges et fond sombre.
	draw_polyline(_plaie, Color(0.45, 0.05, 0.05), 14.0, true)
	draw_polyline(_plaie, Color(0.75, 0.15, 0.15), 6.0, true)
	for f in _fils:
		draw_line(f[0], f[1], Color(0.1, 0.1, 0.25), 3.0, true)
		draw_circle(f[1] + (f[1] - f[0]).normalized() * 6.0, 4.0, Color(0.1, 0.1, 0.25))
	if _i < POINTS:
		for k in 2:
			var c: Vector2 = _cibles[_i][k]
			var col := Color(0.2, 0.9, 1.0) if k == _etape else Color(0.6, 0.8, 0.9, 0.4)
			draw_arc(c, 20.0, 0, TAU, 32, col, 3.0, true)
	draw_string(police, Vector2(60, 80), "Suture de la plaie — point %d / %d" % [mini(_i + 1, POINTS), POINTS],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	draw_string(police, Vector2(60, t.y - 60), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.5))
