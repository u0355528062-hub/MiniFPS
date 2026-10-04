class_name GuideUI
extends Control
## Interface de guidage : liste des étapes, consigne en grand, instrument demandé,
## progression, chrono, erreurs, messages, écran de fin. Utilisée sur le panneau 3D (VR)
## et en surimpression (mode écran).

const W := 1400.0
const H := 820.0
const ACCENT := Color(0.22, 0.95, 0.84)
const GOOD := Color(0.35, 0.95, 0.5)
const BAD := Color(1.0, 0.36, 0.33)
const TEXT := Color(0.93, 0.97, 0.98)
const DIM := Color(0.6, 0.7, 0.74)

var font: Font
var bold: FontVariation
var _step_rows: Array[Label] = []
var _step_icons: Array[Label] = []
var _step_no: Label
var _title: Label
var _text: Label
var _inst_name: Label
var _inst_card: PanelContainer
var _bar_fill: Panel
var _bar_label: Label
var _hint: Label
var _timer: Label
var _errors: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_style: StyleBoxFlat
var _end: Control
var _end_title: Label
var _end_stats: Label
var _end_stars: Label
var _toast_tween: Tween
var _shown_progress := 0.0
var _target_progress := 0.0


func _init() -> void:
	size = Vector2(W, H)
	font = load("res://assets/fonts/Inter.ttf")
	bold = FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.9
	_build()


static func _box(bg: Color, radius := 22, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.anti_aliasing = true
	return s


func _label(text: String, sz: int, col: Color, f: Font = null, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = f if f else font
	ls.font_size = sz
	ls.font_color = col
	l.label_settings = ls
	(parent if parent else self).add_child(l)
	return l


func _build() -> void:
	var bg := Panel.new()
	bg.size = size
	bg.add_theme_stylebox_override("panel", _box(Color(0.025, 0.055, 0.07, 0.95), 34, Color(ACCENT, 0.45), 3))
	add_child(bg)
	# Bandeau supérieur
	var head := _label("BLOC 2  ·  APPENDICECTOMIE  ·  VOIE DE McBURNEY", 26, ACCENT, bold)
	head.position = Vector2(44, 30)
	_timer = _label("00:00", 30, TEXT, bold)
	_timer.position = Vector2(W - 330, 26)
	_errors = _label("Erreurs : 0", 26, DIM)
	_errors.position = Vector2(W - 200, 30)
	var sep := ColorRect.new()
	sep.color = Color(ACCENT, 0.25)
	sep.position = Vector2(40, 82)
	sep.size = Vector2(W - 80, 2)
	add_child(sep)

	# Colonne des étapes
	var col := Panel.new()
	col.position = Vector2(36, 104)
	col.size = Vector2(380, H - 140)
	col.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.035), 24))
	add_child(col)

	# Zone principale
	_step_no = _label("", 28, ACCENT, bold)
	_step_no.position = Vector2(460, 110)
	_title = _label("", 66, TEXT, bold)
	_title.position = Vector2(456, 148)
	_title.size = Vector2(900, 90)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text = _label("", 34, Color(0.84, 0.9, 0.92))
	_text.position = Vector2(460, 250)
	_text.size = Vector2(900, 200)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.label_settings.line_spacing = 6

	_inst_card = PanelContainer.new()
	_inst_card.position = Vector2(460, 470)
	_inst_card.size = Vector2(900, 96)
	var cs := _box(Color(ACCENT, 0.1), 20, Color(ACCENT, 0.7), 2)
	cs.content_margin_left = 26
	cs.content_margin_top = 12
	_inst_card.add_theme_stylebox_override("panel", cs)
	add_child(_inst_card)
	var vb := VBoxContainer.new()
	_inst_card.add_child(vb)
	_label("INSTRUMENT À PRENDRE  (il brille sur la table)", 20, ACCENT, null, vb)
	_inst_name = _label("", 38, TEXT, bold, vb)

	var bar := Panel.new()
	bar.position = Vector2(460, 600)
	bar.size = Vector2(900, 22)
	bar.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.08), 11))
	add_child(bar)
	_bar_fill = Panel.new()
	_bar_fill.position = Vector2(0, 0)
	_bar_fill.size = Vector2(0, 22)
	_bar_fill.add_theme_stylebox_override("panel", _box(ACCENT, 11))
	bar.add_child(_bar_fill)
	_bar_label = _label("", 22, DIM)
	_bar_label.position = Vector2(460, 630)

	_hint = _label("", 24, DIM)
	_hint.position = Vector2(460, H - 120)
	_hint.size = Vector2(900, 80)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Message temporaire
	_toast = PanelContainer.new()
	_toast_style = _box(Color(GOOD, 0.9), 30)
	_toast_style.content_margin_left = 30
	_toast_style.content_margin_right = 30
	_toast_style.content_margin_top = 12
	_toast_style.content_margin_bottom = 12
	_toast.add_theme_stylebox_override("panel", _toast_style)
	_toast.position = Vector2(460, 660)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_toast_label = _label("", 32, Color(0.02, 0.05, 0.06), bold, _toast)

	# Écran de fin
	_end = Panel.new()
	_end.size = size
	(_end as Panel).add_theme_stylebox_override("panel", _box(Color(0.02, 0.05, 0.06, 0.97), 34, Color(GOOD, 0.6), 3))
	_end.visible = false
	add_child(_end)
	_end_title = _label("Opération réussie", 80, GOOD, bold, _end)
	_end_title.position = Vector2(0, 150)
	_end_title.size = Vector2(W, 100)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stars = _label("", 110, Color(1.0, 0.82, 0.25), bold, _end)
	_end_stars.position = Vector2(0, 270)
	_end_stars.size = Vector2(W, 140)
	_end_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats = _label("", 38, TEXT, null, _end)
	_end_stats.position = Vector2(0, 450)
	_end_stats.size = Vector2(W, 200)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_stats.label_settings.line_spacing = 10


func set_steps(titles: Array) -> void:
	for l in _step_rows:
		l.queue_free()
	for l in _step_icons:
		l.queue_free()
	_step_rows.clear()
	_step_icons.clear()
	for i in titles.size():
		var y := 128.0 + i * 64.0
		var icon := _label("○", 30, DIM, bold)
		icon.position = Vector2(62, y - 2)
		var row := _label(titles[i], 27, DIM)
		row.position = Vector2(104, y)
		_step_icons.append(icon)
		_step_rows.append(row)


func show_step(index: int, total: int, title: String, text: String, inst_label: String, hint: String) -> void:
	_end.visible = false
	for i in _step_rows.size():
		var done := i < index
		var cur := i == index
		_step_icons[i].text = "✓" if done else ("●" if cur else "○")
		_step_icons[i].label_settings.font_color = GOOD if done else (ACCENT if cur else DIM)
		_step_rows[i].label_settings.font_color = TEXT if cur else (Color(0.75, 0.85, 0.8) if done else DIM)
		_step_rows[i].label_settings.font = bold if cur else font
	_step_no.text = "ÉTAPE %d / %d" % [index + 1, total] if index >= 0 else "PRÉPARATION"
	_title.text = title
	_text.text = text
	_inst_card.visible = inst_label != ""
	_inst_name.text = inst_label
	_hint.text = hint
	set_progress(0.0, "")
	_shown_progress = 0.0


func set_progress(v: float, caption: String) -> void:
	_target_progress = clampf(v, 0.0, 1.0)
	_bar_label.text = caption


func set_status(seconds: float, errors: int) -> void:
	_timer.text = "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
	_errors.text = "Erreurs : %d" % errors
	_errors.label_settings.font_color = BAD if errors > 0 else DIM


func toast(text: String, ok := true) -> void:
	move_child(_toast, -1)
	_toast_label.text = text
	_toast_style.bg_color = Color(GOOD, 0.92) if ok else Color(BAD, 0.92)
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast.reset_size()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func show_end(seconds: float, errors: int, stars: int, restart_hint: String) -> void:
	move_child(_end, -1)
	_end.visible = true
	_end_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	_end_stats.text = "Durée : %02d:%02d     Erreurs : %d\nAppendice retiré, ligature en place, peau suturée.\n\n%s" % [int(seconds) / 60, int(seconds) % 60, errors, restart_hint]


func _process(delta: float) -> void:
	_shown_progress = lerpf(_shown_progress, _target_progress, 1.0 - exp(-delta * 10.0))
	_bar_fill.size.x = 900.0 * _shown_progress
	_bar_fill.visible = _shown_progress > 0.01
