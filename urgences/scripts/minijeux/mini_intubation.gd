class_name MiniIntubation
extends Control
## Intubation simplifiée (séquence rapide) : pré-oxygénation (maintenir Espace), choix des
## médicaments d'induction, laryngoscopie (aligner la lame sur la glotte et cliquer avant que
## la saturation ne chute), puis vérification de la position de la sonde.

signal termine(succes: bool, qualite: float)

var _etape := 0
var _preox := 0.0
var _spo2 := 92.0
var _score := 1.0
var _glotte := Vector2.ZERO
var _t := 0.0
var _message := ""
var _choix := []
var police: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Plein écran quel que soit le parent (CanvasLayer, fenêtre…).
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	police = ThemeHopital.theme().default_font
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message = "Pré-oxygénation : maintenez Espace jusqu'à 100 % de saturation."


func _process(delta: float) -> void:
	_t += delta
	match _etape:
		0:
			if Input.is_physical_key_pressed(KEY_SPACE):
				_preox += delta / 3.0
				_spo2 = lerpf(92.0, 100.0, clampf(_preox, 0, 1))
				if _preox >= 1.0:
					_etape = 1
					_message = "Induction en séquence rapide : choisissez les médicaments."
					_boutons_induction()
		2:
			_spo2 -= delta * 2.2
			_glotte = size * 0.5 + Vector2(sin(_t * 1.3) * 60.0, cos(_t * 0.9) * 40.0)
			if _spo2 < 85.0:
				_score -= 0.3
				_spo2 = 98.0
				_message = "Désaturation ! Ventilez au masque puis recommencez."
	queue_redraw()


func _boutons_induction() -> void:
	var opts := [["Étomidate + succinylcholine (célocurine)", true], ["Midazolam seul", false],
		["Propofol + morphine", false], ["Kétamine + rocuronium", true]]
	opts.shuffle()
	for i in opts.size():
		var b := Button.new()
		b.theme = ThemeHopital.theme()
		b.text = opts[i][0]
		b.position = Vector2(size.x * 0.5 - 300, size.y * 0.5 - 80 + i * 60)
		b.custom_minimum_size = Vector2(600, 48)
		var bon: bool = opts[i][1]
		b.pressed.connect(func():
			if not bon:
				_score -= 0.25
				_message = "Choix inadapté pour une séquence rapide. Recommencez."
				return
			for c in _choix:
				c.queue_free()
			_choix.clear()
			_etape = 2
			_t = 0.0
			_message = "Laryngoscopie : placez la lame (cercle) sur la glotte et cliquez.")
		add_child(b)
		_choix.append(b)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _etape == 2:
		var d: float = event.position.distance_to(_glotte)
		if d < 35.0:
			_etape = 3
			_message = "Sonde en place. Vérifiez : capnographie et auscultation symétrique… OK !"
			_score -= d / 35.0 * 0.2
			get_tree().create_timer(2.0).timeout.connect(func():
				termine.emit(true, clampf(_score, 0.1, 1.0))
				queue_free())
		else:
			_score -= 0.1
			_message = "Intubation œsophagienne ! Retirez, ventilez, recommencez."


func _draw() -> void:
	var t := size
	draw_rect(Rect2(Vector2.ZERO, t), Color(0.04, 0.05, 0.06, 0.94))
	draw_string(police, Vector2(60, 80), "Intubation orotrachéale", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
	draw_string(police, Vector2(t.x - 330, 80), "SpO₂ %d %%" % int(_spo2), HORIZONTAL_ALIGNMENT_LEFT, -1, 38,
		Color(0.3, 0.9, 1.0) if _spo2 > 90 else Color(1, 0.4, 0.3))
	if _etape == 0:
		draw_rect(Rect2(t.x * 0.5 - 300, t.y * 0.5, 600, 30), Color(0.2, 0.22, 0.25))
		draw_rect(Rect2(t.x * 0.5 - 300, t.y * 0.5, 600 * clampf(_preox, 0, 1), 30), Color(0.2, 0.7, 0.9))
	elif _etape >= 2:
		# Vue laryngoscopique stylisée : pharynx, épiglotte, glotte (cordes vocales en V).
		var c := t * 0.5
		draw_circle(c, 260, Color(0.35, 0.08, 0.08))
		draw_circle(c, 200, Color(0.55, 0.15, 0.15))
		draw_circle(_glotte + Vector2(0, -70), 50, Color(0.75, 0.35, 0.35))
		var g := _glotte
		draw_colored_polygon(PackedVector2Array([g + Vector2(-26, 30), g + Vector2(0, -32), g + Vector2(26, 30)]), Color(0.08, 0.02, 0.02))
		draw_line(g + Vector2(-26, 30), g + Vector2(0, -32), Color(0.95, 0.9, 0.85), 4.0)
		draw_line(g + Vector2(26, 30), g + Vector2(0, -32), Color(0.95, 0.9, 0.85), 4.0)
		var m := get_local_mouse_position()
		draw_arc(m, 35, 0, TAU, 40, Color(0.3, 1.0, 0.6), 3.0)
	draw_string(police, Vector2(60, t.y - 60), _message, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.9, 0.5))
