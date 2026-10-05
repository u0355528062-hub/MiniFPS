class_name GameHUD
extends CanvasLayer
## Interface en jeu : carte de l'étape (haut gauche), liste des étapes, constantes vitales (haut
## droite), chrono et erreurs (haut centre), viseur contextuel, message d'aide près du viseur,
## légende de progression, barre d'instruments (bas), messages brefs (réussites, erreurs).

var monitor: VitalMonitor
var hand: PlayerHand
var player: Player
var instruments: Array[Instrument] = []
var required_id := ""

var root: Control
var _card: PanelContainer
var _step_tag: Label
var _title: Label
var _text: Label
var _inst_chip: Label
var _steps_box: VBoxContainer
var _step_rows: Array[Label] = []
var _status: Label
var _caption: Label
var _prompt: Label
var _toast_box: VBoxContainer
var _hotbar: HBoxContainer
var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _vitals: VitalsWidget
var _cross: Crosshair
var _help: Label
var _view_tag: Label
var _echo_panel: PanelContainer
var _echo_rect: TextureRect
var _echo_tag: Label
var _current_step := -1
var _details := true


func build() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.theme()
	add_child(root)

	# --- Carte de l'étape
	_card = UIKit.panel(UIKit.PANEL, 14, 18)
	_card.position = Vector2(24, 24)
	_card.custom_minimum_size = Vector2(430, 0)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	var cv := UIKit.vbox(8)
	_card.add_child(cv)
	_step_tag = UIKit.label("BRIEFING", 14, UIKit.ACCENT, true)
	cv.add_child(_step_tag)
	_title = UIKit.label("", 26, UIKit.TEXT, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 400
	cv.add_child(_title)
	_text = UIKit.label("", 17, Color(0.82, 0.88, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = 400
	cv.add_child(_text)
	var chip_row := UIKit.hbox(8)
	cv.add_child(chip_row)
	_inst_chip = UIKit.label("", 15, Color(0.05, 0.08, 0.09), true)
	var chip_style := UIKit.box(UIKit.ACCENT, 6, Color(0, 0, 0, 0), 0, 8)
	chip_style.shadow_size = 0
	chip_style.content_margin_top = 3
	chip_style.content_margin_bottom = 3
	_inst_chip.add_theme_stylebox_override("normal", chip_style)
	chip_row.add_child(_inst_chip)
	var htip := UIKit.label("H : masquer le texte", 13, UIKit.TEXT_DIM)
	chip_row.add_child(htip)

	# --- Liste des étapes
	_steps_box = UIKit.vbox(4)
	_steps_box.position = Vector2(30, 0)
	root.add_child(_steps_box)

	# --- Chrono / erreurs
	_status = UIKit.label("00:00", 20, UIKit.TEXT, true)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status.position = Vector2(-160, 22)
	_status.custom_minimum_size = Vector2(320, 0)
	var st_style := UIKit.box(UIKit.PANEL, 18, Color(1, 1, 1, 0.06), 1, 14)
	st_style.content_margin_top = 6
	st_style.content_margin_bottom = 6
	_status.add_theme_stylebox_override("normal", st_style)
	root.add_child(_status)
	_view_tag = UIKit.label("", 15, Color(0.4, 0.85, 1.0), true)
	_view_tag.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_view_tag.position = Vector2(-160, 66)
	_view_tag.custom_minimum_size = Vector2(320, 0)
	_view_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_view_tag)

	# --- Constantes vitales
	_vitals = VitalsWidget.new()
	_vitals.monitor = monitor
	_vitals.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vitals.position = Vector2(-344, 24)
	_vitals.custom_minimum_size = Vector2(320, 168)
	_vitals.size = Vector2(320, 168)
	root.add_child(_vitals)

	# --- Échographie (quand une sonde est posée)
	_echo_panel = UIKit.panel(Color(0.02, 0.025, 0.03, 0.94), 12, 10)
	_echo_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_echo_panel.position = Vector2(-404, 206)
	_echo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_echo_panel.visible = false
	root.add_child(_echo_panel)
	var ev := UIKit.vbox(6)
	_echo_panel.add_child(ev)
	_echo_tag = UIKit.label("ÉCHOGRAPHIE", 13, UIKit.ACCENT, true)
	ev.add_child(_echo_tag)
	_echo_rect = TextureRect.new()
	_echo_rect.custom_minimum_size = Vector2(360, 270)
	_echo_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_echo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ev.add_child(_echo_rect)
	var foot := UIKit.label("Sonde cardiaque  ·  3,5 MHz  ·  profondeur 16 cm", 12, UIKit.TEXT_DIM)
	ev.add_child(foot)

	# --- Viseur et aide contextuelle
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.position = Vector2(-40, -40)
	_cross.size = Vector2(80, 80)
	_cross.hand = hand
	root.add_child(_cross)
	_prompt = UIKit.label("", 17, UIKit.TEXT, true)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 34)
	_prompt.custom_minimum_size = Vector2(600, 0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	root.add_child(_prompt)

	# --- Légende de progression
	_caption = UIKit.label("", 19, UIKit.TEXT, true)
	_caption.anchor_left = 0.5
	_caption.anchor_right = 0.5
	_caption.anchor_top = 1.0
	_caption.anchor_bottom = 1.0
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_top = -112
	_caption.offset_bottom = -112
	_caption.custom_minimum_size = Vector2(800, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_caption.add_theme_constant_override("outline_size", 7)
	root.add_child(_caption)

	# --- Messages brefs
	_toast_box = UIKit.vbox(8)
	_toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_box.position = Vector2(-280, 110)
	_toast_box.custom_minimum_size = Vector2(560, 0)
	root.add_child(_toast_box)

	# --- Barre d'instruments
	_hotbar = UIKit.hbox(8)
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.offset_top = -22
	_hotbar.offset_bottom = -22
	root.add_child(_hotbar)
	for i in instruments.size():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(128, 64)
		slot.add_theme_stylebox_override("panel", UIKit.box(UIKit.PANEL, 10, Color(1, 1, 1, 0.06), 1, 8))
		var v := UIKit.vbox(2)
		slot.add_child(v)
		var num := UIKit.label(str(i + 1), 13, UIKit.TEXT_DIM, true)
		v.add_child(num)
		var nm := UIKit.label(_short(instruments[i].label), 15, UIKit.TEXT)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size.x = 112
		v.add_child(nm)
		_hotbar.add_child(slot)
		_slots.append(slot)
		_slot_labels.append(nm)

	# --- Aide des commandes (F1)
	_help = UIKit.label("ZQSD : marcher  ·  Souris : regarder  ·  Clic : prendre / appuyer / serrer  ·  Clic droit : précision\nMolette : lever / baisser  ·  R : reposer  ·  1-7 : instrument  ·  Ctrl : se pencher  ·  V : vue anatomique  ·  Échap : pause", 14, UIKit.TEXT_DIM)
	var hsb := UIKit.box(Color(0.02, 0.04, 0.05, 0.55), 8, Color(1, 1, 1, 0.04), 1, 10)
	hsb.shadow_size = 0
	_help.add_theme_stylebox_override("normal", hsb)
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_left = 24
	_help.offset_top = -110
	_help.offset_bottom = -110
	root.add_child(_help)
	_help.visible = Settings.show_hints
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_H:
				_details = not _details
				_text.visible = _details
			KEY_F1:
				_help.visible = not _help.visible


static func _short(t: String) -> String:
	return t.replace(" thoracique", "").replace(" dermographique", "").replace(" + fil 0", "").replace(" de lidocaïne 1 %", "")


# ---------------------------------------------------------------- Interface de la procédure

func set_header(_h: String) -> void:
	pass


func set_steps(titles: Array) -> void:
	for c in _steps_box.get_children():
		c.queue_free()
	_step_rows.clear()
	for i in titles.size():
		var l := UIKit.label("○  " + str(titles[i]), 15, UIKit.TEXT_DIM)
		_steps_box.add_child(l)
		_step_rows.append(l)
	_refresh_steps()


func _refresh_steps() -> void:
	for i in _step_rows.size():
		var l := _step_rows[i]
		var t: String = l.text.substr(3)
		if i < _current_step:
			l.text = "✓  " + t
			l.add_theme_color_override("font_color", UIKit.OK)
		elif i == _current_step:
			l.text = "●  " + t
			l.add_theme_color_override("font_color", UIKit.ACCENT)
		else:
			l.text = "○  " + t
			l.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	await get_tree().process_frame
	_steps_box.position.y = _card.position.y + _card.size.y + 14


func show_step(step: int, total: int, title: String, text: String, inst_label: String, _hint: String) -> void:
	_current_step = step
	if step < 0:
		_step_tag.text = "BRIEFING"
	else:
		_step_tag.text = "ÉTAPE %d / %d" % [step + 1, total]
	_title.text = title
	_text.text = text
	_text.visible = _details
	_inst_chip.text = "  " + inst_label + "  " if inst_label != "" else ""
	_inst_chip.visible = inst_label != ""
	UIKit.pop_in(_card, 0.3)
	_refresh_steps()


func set_progress(_v: float, text: String) -> void:
	_caption.text = text


func toast(text: String, ok := true) -> void:
	var p := PanelContainer.new()
	var c := UIKit.OK if ok else UIKit.BAD
	var sb := UIKit.box(Color(0.03, 0.06, 0.07, 0.88), 10, c, 2, 14)
	sb.border_width_left = 6
	p.add_theme_stylebox_override("panel", sb)
	var l := UIKit.label(("✔  " if ok else "✖  ") + text, 18, UIKit.TEXT, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	_toast_box.add_child(p)
	while _toast_box.get_child_count() > 3:
		_toast_box.get_child(0).queue_free()
		_toast_box.remove_child(_toast_box.get_child(0))
	p.modulate.a = 0.0
	p.scale = Vector2(0.96, 0.96)
	var tw := p.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.25)
	tw.tween_interval(3.2 if ok else 4.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func set_status(elapsed: float, errors: int) -> void:
	var e := "aucune erreur" if errors == 0 else ("%d erreur%s" % [errors, "s" if errors > 1 else ""])
	_status.text = "%s   ·   %s" % [UIKit.fmt_time(elapsed), e]
	_status.add_theme_color_override("font_color", UIKit.TEXT if errors == 0 else UIKit.WARN)


func show_end(_elapsed: float, _errors: int, _grade: String, _summary: String, _log: Array, _quality: Dictionary) -> void:
	_caption.text = ""


## Image d'échographie en direct (null : masquée).
func show_echo(tex: Texture2D, title := "") -> void:
	if tex == null:
		_echo_panel.visible = false
		return
	if not _echo_panel.visible:
		_echo_panel.visible = true
		UIKit.pop_in(_echo_panel)
	_echo_rect.texture = tex
	if title != "":
		_echo_tag.text = title


func set_view_tag(t: String) -> void:
	_view_tag.text = t


# ---------------------------------------------------------------- Mise à jour

func _process(_delta: float) -> void:
	if hand == null:
		return
	for i in _slots.size():
		var inst := instruments[i]
		var held := hand.held == inst
		var req := inst.id == required_id
		var bg := UIKit.PANEL
		var border := Color(1, 1, 1, 0.06)
		var bw := 1
		if held:
			bg = Color(0.1, 0.3, 0.3, 0.92)
			border = Color.WHITE
			bw = 2
		elif req:
			var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
			border = Color(UIKit.ACCENT.r, UIKit.ACCENT.g, UIKit.ACCENT.b, pulse)
			bw = 2
		elif inst.parked:
			bg = Color(0.03, 0.05, 0.06, 0.5)
		var sb := _slots[i].get_theme_stylebox("panel") as StyleBoxFlat
		sb.bg_color = bg
		sb.border_color = border
		sb.set_border_width_all(bw)
		_slot_labels[i].add_theme_color_override("font_color", UIKit.TEXT_DIM if inst.parked else UIKit.TEXT)
	var pr := ""
	if hand.held == null and hand.hovered:
		pr = "Clic gauche · Prendre  « %s »" % hand.hovered.label
	elif hand.held and not hand.on_patient and hand.held.id == required_id:
		pr = "Vise la zone sur le patient"
	_prompt.text = pr
