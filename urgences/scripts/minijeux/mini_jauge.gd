class_name MiniJauge
extends Control
## Geste technique rapide (pose de voie veineuse, prise de sang, ponction) : un curseur
## parcourt une jauge, il faut l'arrêter dans la zone verte (Espace ou clic). Trois essais.

signal termine(succes: bool, qualite: float)

var titre := "Pose de voie veineuse périphérique"
var consigne := "Arrêtez le curseur dans la zone verte (Espace ou clic) : la veine est là."
var largeur_zone := 0.14
var _x := 0.0
var _sens := 1.0
var _vitesse := 0.9
var _zone := 0.5
var _essais := 0
var _fini := false
var _message := ""
var police: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Plein écran quel que soit le parent (CanvasLayer, fenêtre…).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	police = ThemeHopital.theme().default_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_zone = randf_range(0.25, 0.75)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_valider()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE:
		_valider()
		get_viewport().set_input_as_handled()


func _valider() -> void:
	if _fini:
		return
	_essais += 1
	var d := absf(_x - _zone)
	if d <= largeur_zone * 0.5:
		_fini = true
		var q := 1.0 - d / (largeur_zone * 0.5) * 0.5 - (_essais - 1) * 0.2
		_message = "Réussi au %s essai !" % ["premier", "deuxième", "troisième"][_essais - 1]
		get_tree().create_timer(1.2).timeout.connect(func():
			termine.emit(true, clampf(q, 0.1, 1.0))
			queue_free())
	elif _essais >= 3:
		_fini = true
		_message = "Échec après trois essais : un collègue prend le relais."
		get_tree().create_timer(1.6).timeout.connect(func():
			termine.emit(false, 0.0)
			queue_free())
	else:
		_message = "Raté… (essai %d / 3)" % _essais
		_vitesse *= 0.85


func _process(delta: float) -> void:
	if not _fini:
		_x += _sens * _vitesse * delta
		if _x > 1.0 or _x < 0.0:
			_sens = -_sens
			_x = clampf(_x, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.04, 0.06, 0.07, 0.9))
	draw_string(police, Vector2(t.x * 0.5 - 420, t.y * 0.5 - 140), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color.WHITE)
	draw_string(police, Vector2(t.x * 0.5 - 420, t.y * 0.5 - 90), consigne, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.75, 0.85, 0.9))
	var barre := Rect2(t.x * 0.5 - 420, t.y * 0.5 - 30, 840, 60)
	draw_rect(barre, Color(0.2, 0.22, 0.25))
	var z0 := barre.position.x + barre.size.x * (_zone - largeur_zone * 0.5)
	draw_rect(Rect2(z0, barre.position.y, barre.size.x * largeur_zone, barre.size.y), Color(0.15, 0.65, 0.35))
	var xc := barre.position.x + barre.size.x * _x
	draw_rect(Rect2(xc - 4, barre.position.y - 12, 8, barre.size.y + 24), Color.WHITE)
	draw_string(police, Vector2(t.x * 0.5 - 420, t.y * 0.5 + 90), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.9, 0.5))
