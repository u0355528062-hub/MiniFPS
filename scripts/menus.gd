class_name Menus
extends CanvasLayer
## Écrans plein cadre : menu principal (sur la salle en fond), briefing du patient, pause,
## options, bilan de fin (note, temps, erreurs, précision des gestes).

signal play_pressed
signal op_chosen(op_id: String)
signal start_pressed
signal resume_pressed
signal restart_pressed
signal main_menu_pressed
signal quit_pressed

## Couleur de chaque note (médaille de fin, record au menu)
const GRADE_COLORS := {"S": Color(1.0, 0.82, 0.3), "A": Color(0.35, 0.95, 0.55), "B": Color(0.22, 0.92, 0.82), "C": Color(1.0, 0.78, 0.3), "D": Color(1.0, 0.36, 0.33)}

var op: Operation
var root: Control
var _dim: ColorRect
var _main: Control
var _brief: Control
var _pause: Control
var _options: Control
var _end: Control
var _options_back: Callable
var _fade: ColorRect


func build(p_op: Operation) -> void:
	op = p_op
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.0, 0.02, 0.03, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_main = _build_main()
	_brief = _build_briefing()
	_pause = _build_pause()
	_options = _build_options()
	_end = Control.new()
	_end.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_end)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	hide_all()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			if _pause.visible:
				resume_pressed.emit()
				get_viewport().set_input_as_handled()
			elif _options.visible and _options_back.is_valid():
				_options_back.call()
				get_viewport().set_input_as_handled()
		elif k == KEY_SPACE:
			if _brief.visible:
				start_pressed.emit()
				get_viewport().set_input_as_handled()
			elif _end.visible:
				restart_pressed.emit()
				get_viewport().set_input_as_handled()


func hide_all() -> void:
	for c in [_main, _brief, _pause, _options, _end]:
		c.visible = false
	_dim.visible = false


func any_open() -> bool:
	for c in [_main, _brief, _pause, _options, _end]:
		if c.visible:
			return true
	return false


func _show(c: Control, dim := true) -> void:
	hide_all()
	c.visible = true
	_dim.visible = dim
	UIKit.pop_in(c, 0.35)
	var first := _first_button(c)
	if first:
		first.grab_focus.call_deferred()


func _first_button(n: Node) -> Button:
	for ch in n.get_children():
		if ch is Button and (ch as Button).visible:
			return ch
		var b := _first_button(ch)
		if b:
			return b
	return null


## Fondu au noir puis retour (transitions).
func fade(to_black: bool, dur := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, dur)
	await tw.finished


func _center_panel(w: float, parent: Control) -> PanelContainer:
	var p := UIKit.panel(UIKit.PANEL_SOLID, 18, 28)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- Menu principal

func _build_main() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	# Dégradé sombre à gauche pour la lisibilité
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.02, 0.03, 0.92))
	g.set_color(1, Color(0.0, 0.02, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size = Vector2(900, 0)
	grad.offset_right = 900.0  # pleine hauteur par les ancres, 900 px de large
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(grad)
	var col := UIKit.vbox(10)
	col.position = Vector2(90, 70)
	c.add_child(col)
	var kicker := UIKit.label("SIMULATEUR CHIRURGICAL", 16, UIKit.ACCENT, true)
	col.add_child(kicker)
	var title := UIKit.label("BLOC  URGENCES", 66, UIKit.TEXT, true)
	title.add_theme_constant_override("outline_size", 0)
	col.add_child(title)
	var sub := UIKit.label("Choisis une intervention", 19, UIKit.TEXT_DIM)
	col.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size.y = 8
	col.add_child(sp)
	for e in Operation.CATALOG:
		col.add_child(_op_card(e))
	var sp2 := Control.new()
	sp2.custom_minimum_size.y = 12
	col.add_child(sp2)
	var b2 := UIKit.button("Options", 380)
	b2.pressed.connect(func() -> void: open_options(func() -> void: show_main()))
	col.add_child(b2)
	var b3 := UIKit.button("Quitter", 380)
	b3.pressed.connect(func() -> void: quit_pressed.emit())
	col.add_child(b3)
	var foot := UIKit.label("Anatomie : atlas Z-Anatomy (CC BY-SA 4.0, d'après BodyParts3D)   ·   Version 6.0", 13, Color(1, 1, 1, 0.4))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(90, -50)
	c.add_child(foot)
	return c


## Carte d'une intervention : nom, résumé, difficulté et durée ; « bientôt » si pas encore jouable.
func _op_card(e: Dictionary) -> Button:
	var ready: bool = e["ready"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(660, 66)
	b.focus_mode = Control.FOCUS_ALL
	b.disabled = not ready
	var cur: bool = e["id"] == op.id
	var normal := UIKit.box(Color(0.03, 0.06, 0.075, 0.82), 10, UIKit.ACCENT_DIM if cur else Color(1, 1, 1, 0.07), 2 if cur else 1, 16)
	var hover := UIKit.box(Color(0.05, 0.13, 0.14, 0.92), 10, UIKit.ACCENT, 2, 16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", UIKit.box(Color(0.03, 0.05, 0.06, 0.55), 10, Color(1, 1, 1, 0.04), 1, 16))
	var row := UIKit.hbox(16)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var txt := UIKit.vbox(2)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(txt)
	var t := UIKit.label(e["name"], 22, UIKit.TEXT if ready else UIKit.TEXT_DIM, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(t)
	var tg := UIKit.label(e["tag"], 14, UIKit.TEXT_DIM if ready else Color(1, 1, 1, 0.3))
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(tg)
	var right := UIKit.vbox(2)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var lvl: int = e["level"]
	var dots := UIKit.label("●".repeat(lvl) + "○".repeat(3 - lvl), 15, UIKit.ACCENT if ready else Color(1, 1, 1, 0.25))
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(dots)
	var info := UIKit.label(("~%d min" % e["minutes"]) if ready else "BIENTÔT", 13, UIKit.TEXT_DIM if ready else UIKit.WARN, not ready)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(info)
	# Meilleur résultat obtenu sur cette intervention
	var rec: Dictionary = Records.best(e["id"]) if ready else {}
	if not rec.is_empty():
		var g: String = rec["grade"]
		var bl := UIKit.label("RECORD  %s  ·  %s" % [g, UIKit.fmt_time(rec["time"])], 12, GRADE_COLORS.get(g, UIKit.TEXT), true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(bl)
	if ready:
		var op_id: String = e["id"]
		b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
		b.pressed.connect(func() -> void:
			Sfx.play("clic", Vector3.INF, -12.0, 1.0)
			op_chosen.emit(op_id))
	return b


func show_main() -> void:
	_show(_main, false)


# ---------------------------------------------------------------- Briefing

func _build_briefing() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := _center_panel(1040, c)
	var v := UIKit.vbox(16)
	p.add_child(v)
	var head := UIKit.hbox(14)
	v.add_child(head)
	var tag := UIKit.label(op.urgency, 15, Color(0.05, 0.05, 0.05), true)
	var tsb := UIKit.box(UIKit.BAD, 6, Color(0, 0, 0, 0), 0, 10)
	tsb.shadow_size = 0
	tsb.content_margin_top = 4
	tsb.content_margin_bottom = 4
	tag.add_theme_stylebox_override("normal", tsb)
	head.add_child(tag)
	head.add_child(UIKit.label(op.intro_title.to_upper() + "  ·  " + op.header.split("·")[1].strip_edges() if op.header.contains("·") else op.intro_title, 15, UIKit.TEXT_DIM, true))
	v.add_child(UIKit.label(op.patient_line, 34, UIKit.TEXT, true))
	var cols := UIKit.hbox(28)
	v.add_child(cols)
	var left := UIKit.vbox(12)
	left.custom_minimum_size.x = 560
	cols.add_child(left)
	var story := UIKit.label(op.intro_text, 18, Color(0.85, 0.9, 0.92))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size.x = 560
	left.add_child(story)
	left.add_child(UIKit.label("DÉROULÉ", 14, UIKit.ACCENT, true))
	var steps_txt := ""
	for i in op.steps.size():
		steps_txt += "%d.  %s\n" % [i + 1, op.steps[i]["list"]]
	left.add_child(UIKit.label(steps_txt.strip_edges(), 17, UIKit.TEXT))
	var right := UIKit.vbox(10)
	right.custom_minimum_size.x = 380
	cols.add_child(right)
	right.add_child(UIKit.label("CONSTANTES À L'ARRIVÉE", 14, UIKit.ACCENT, true))
	var vit := GridContainer.new()
	vit.columns = 2
	vit.add_theme_constant_override("h_separation", 24)
	vit.add_theme_constant_override("v_separation", 6)
	right.add_child(vit)
	# Couleur selon la valeur : normale, inquiétante, critique ; non mesurable en arrêt cardiaque
	var hr := float(op.vitals["hr"])
	var spo2 := float(op.vitals["spo2"])
	var sys := int(op.vitals["sys"])
	var fr := op.breath_rate
	var rows := [
		["Fréquence cardiaque", "%d /min" % int(hr), _level(hr < 40.0 or hr > 130.0, hr < 55.0 or hr > 100.0)],
		["Saturation (SpO₂)", ("%d %%" % int(spo2)) if spo2 > 0.0 else "non mesurable", _level(spo2 < 90.0, spo2 < 95.0)],
		["Tension", ("%d / %d" % [sys, op.vitals["dia"]]) if sys > 0 else "imprenable", _level(sys < 80 or sys > 180, sys < 100 or sys > 150)],
		["Ventilation (intubé)", "%d /min" % int(fr), UIKit.OK] if op.ventilated else
			["Respiration", "%d /min" % int(fr), _level(fr > 30.0 or fr < 8.0, fr > 20.0 or fr < 10.0)]]
	for row in rows:
		vit.add_child(UIKit.label(row[0], 17, UIKit.TEXT_DIM))
		vit.add_child(UIKit.label(row[1], 19, row[2], true))
	right.add_child(UIKit.label("IMAGERIE", 14, UIKit.ACCENT, true))
	if op.imaging_tex != "":
		var xr := XRayCard.new()
		xr.tex = load(op.imaging_tex)
		xr.caption = op.imaging_caption
		xr.side = op.imaging_side
		xr.custom_minimum_size = Vector2(380, 300)
		right.add_child(xr)
	else:
		var no := UIKit.label(op.imaging_text, 16, UIKit.TEXT)
		no.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no.custom_minimum_size = Vector2(380, 0)
		right.add_child(no)
	var keys := UIKit.label("ZQSD marcher · Souris regarder · Clic prendre / appuyer · Clic droit précision · V vue anatomique · Échap pause", 14, UIKit.TEXT_DIM)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 960
	v.add_child(keys)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var go := UIKit.button("Commencer  (Espace)", 320)
	go.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(go)
	return c


static func _level(critical: bool, worrying: bool) -> Color:
	return UIKit.BAD if critical else (UIKit.WARN if worrying else UIKit.OK)


func show_briefing() -> void:
	_show(_brief, true)


# ---------------------------------------------------------------- Pause

func _build_pause() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := _center_panel(440, c)
	var v := UIKit.vbox(12)
	p.add_child(v)
	var t := UIKit.label("PAUSE", 34, UIKit.TEXT, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for item in [["Reprendre", func() -> void: resume_pressed.emit()],
			["Options", func() -> void: open_options(func() -> void: show_pause())],
			["Recommencer l'intervention", func() -> void: restart_pressed.emit()],
			["Menu principal", func() -> void: main_menu_pressed.emit()],
			["Quitter le jeu", func() -> void: quit_pressed.emit()]]:
		var b := UIKit.button(item[0], 380)
		b.pressed.connect(item[1])
		v.add_child(b)
	return c


func show_pause() -> void:
	_show(_pause, true)


# ---------------------------------------------------------------- Options

func _build_options() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := _center_panel(640, c)
	var v := UIKit.vbox(12)
	p.add_child(v)
	var t := UIKit.label("OPTIONS", 30, UIKit.TEXT, true)
	v.add_child(t)
	v.add_child(UIKit.label("GRAPHISMES", 14, UIKit.ACCENT, true))
	var q := OptionButton.new()
	for i in Settings.PRESETS.size():
		q.add_item(Settings.PRESETS[i], i)
	q.selected = Settings.quality
	q.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		Settings.reapply())
	v.add_child(_row("Qualité", q))
	v.add_child(_slider_row("Résolution de rendu", 50, 100, Settings.render_scale * 100.0, "%d %%", func(x: float) -> void:
		Settings.render_scale = x / 100.0
		Settings.reapply()))
	v.add_child(_check_row("Plein écran", Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.reapply()))
	v.add_child(_check_row("Synchronisation verticale", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.reapply()))
	v.add_child(UIKit.label("CONTRÔLES", 14, UIKit.ACCENT, true))
	v.add_child(_slider_row("Champ de vision", 60, 95, Settings.fov, "%d°", func(x: float) -> void:
		Settings.fov = x
		Settings.reapply()))
	v.add_child(_slider_row("Sensibilité de la souris", 20, 300, Settings.sensitivity * 100.0, "%d %%", func(x: float) -> void:
		Settings.sensitivity = x / 100.0
		Settings.reapply()))
	v.add_child(_check_row("Inverser l'axe vertical", Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on
		Settings.reapply()))
	v.add_child(_check_row("Balancement de la tête", Settings.head_bob, func(on: bool) -> void:
		Settings.head_bob = on
		Settings.reapply()))
	v.add_child(_check_row("Afficher l'aide des commandes", Settings.show_hints, func(on: bool) -> void:
		Settings.show_hints = on
		Settings.reapply()))
	v.add_child(UIKit.label("SON", 14, UIKit.ACCENT, true))
	v.add_child(_slider_row("Volume général", 0, 100, Settings.volume * 100.0, "%d %%", func(x: float) -> void:
		Settings.volume = x / 100.0
		Settings.reapply()))
	var back := UIKit.button("Retour", 200)
	back.pressed.connect(func() -> void:
		if _options_back.is_valid():
			_options_back.call())
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(back)
	v.add_child(row)
	return c


func _row(text: String, ctrl: Control) -> Control:
	var h := UIKit.hbox(16)
	var l := UIKit.label(text, 18, UIKit.TEXT)
	l.custom_minimum_size.x = 260
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	return h


func _slider_row(text: String, lo: float, hi: float, val: float, fmt: String, cb: Callable) -> Control:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 1
	s.value = val
	s.custom_minimum_size = Vector2(220, 28)
	var vl := UIKit.label(fmt % int(val), 16, UIKit.TEXT_DIM)
	vl.custom_minimum_size.x = 64
	s.value_changed.connect(func(x: float) -> void:
		vl.text = fmt % int(x)
		cb.call(x))
	var h := _row(text, s)
	h.add_child(vl)
	return h


func _check_row(text: String, on: bool, cb: Callable) -> Control:
	var c := CheckButton.new()
	c.text = ""
	c.button_pressed = on
	c.toggled.connect(cb)
	return _row(text, c)


func open_options(back: Callable) -> void:
	_options_back = back
	_show(_options, true)


# ---------------------------------------------------------------- Bilan

func show_end(elapsed: float, errors: int, grade: String, summary: String, log: Array, quality: Dictionary) -> void:
	for ch in _end.get_children():
		ch.queue_free()
	var p := _center_panel(860, _end)
	var v := UIKit.vbox(16)
	p.add_child(v)
	var top := UIKit.hbox(28)
	v.add_child(top)
	var badge := GradeBadge.new()
	badge.grade = grade
	badge.custom_minimum_size = Vector2(150, 150)
	top.add_child(badge)
	var info := UIKit.vbox(8)
	top.add_child(info)
	var head := UIKit.hbox(12)
	info.add_child(head)
	# Patient sauvé dans tous les cas ; avec trop d'erreurs, le geste est à revoir
	var good := grade in ["S", "A", "B"]
	head.add_child(UIKit.label("INTERVENTION RÉUSSIE" if good else "INTERVENTION TERMINÉE  ·  GESTE À REVOIR", 15, UIKit.OK if good else UIKit.WARN, true))
	if quality.get("record", false):
		var rec := UIKit.label("NOUVEAU RECORD", 13, Color(0.05, 0.05, 0.05), true)
		var rsb := UIKit.box(Color(1.0, 0.82, 0.3), 6, Color(0, 0, 0, 0), 0, 8)
		rsb.shadow_size = 0
		rsb.content_margin_top = 2
		rsb.content_margin_bottom = 2
		rec.add_theme_stylebox_override("normal", rsb)
		head.add_child(rec)
	info.add_child(UIKit.label(op.name, 36, UIKit.TEXT, true))
	var s := UIKit.label(summary, 17, Color(0.85, 0.9, 0.92))
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 600
	info.add_child(s)
	var grid := GridContainer.new()
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	# Seules les mesures qui ont un sens pour cette intervention (repère au feutre, incision)
	var stats := [["TEMPS  ·  RÉF. %s" % UIKit.fmt_time(op.reference_time()), UIKit.fmt_time(elapsed)],
		["ERREURS", str(errors)], ["ÉTAPES", str(op.steps.size())]]
	if quality.has("mark_mm"):
		stats.append(["REPÈRE", "%d mm" % int(quality["mark_mm"])])
	if quality.has("incision_dev_mm"):
		stats.append(["INCISION", "± %.1f mm" % quality["incision_dev_mm"]])
	grid.columns = stats.size()
	for stt in stats:
		grid.add_child(UIKit.label(stt[0], 13, UIKit.TEXT_DIM, true))
	for stt in stats:
		grid.add_child(UIKit.label(stt[1], 28, UIKit.TEXT, true))
	if quality.has("score"):
		# Comment la note est calculée : 100, moins les pénalités, plus les bonus de précision
		var parts := "100"
		var ne := int(round(float(quality["pen_errors"]) / 12.0))
		if ne > 0:
			parts += "  − %d (%d erreur%s)" % [int(quality["pen_errors"]), ne, "s" if ne > 1 else ""]
		var np := int(round(float(quality["pen_picks"]) / 6.0))
		if np > 0:
			parts += "  − %d (%d mauvais instrument%s)" % [int(quality["pen_picks"]), np, "s" if np > 1 else ""]
		if float(quality["pen_time"]) >= 0.5:
			parts += "  − %d (temps)" % int(round(float(quality["pen_time"])))
		if quality.get("bonus", 0.0) > 0.0:
			parts += "  + %d (précision)" % int(quality["bonus"])
		var pts := UIKit.label("POINTS   %s  =  %d" % [parts, int(round(float(quality["score"])))], 15, UIKit.TEXT_DIM)
		pts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pts.custom_minimum_size.x = 800
		v.add_child(pts)
	v.add_child(UIKit.label("COMPTE RENDU", 14, UIKit.ACCENT, true))
	var lt := ""
	if log.is_empty():
		lt = "Aucune erreur : gestes sûrs, dans le bon ordre, au bon endroit."
	else:
		for e in log:
			lt += "•  " + str(e) + "\n"
	var ll := UIKit.label(lt.strip_edges(), 16, UIKit.TEXT if not log.is_empty() else UIKit.OK)
	ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ll.custom_minimum_size.x = 800
	v.add_child(ll)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var b1 := UIKit.button("Menu principal", 240)
	b1.pressed.connect(func() -> void: main_menu_pressed.emit())
	row.add_child(b1)
	var b2 := UIKit.button("Rejouer  (Espace)", 260)
	b2.pressed.connect(func() -> void: restart_pressed.emit())
	row.add_child(b2)
	_show(_end, true)
	b2.grab_focus.call_deferred()


## Médaille de la note (S, A, B, C, D) : cercle lumineux.
class GradeBadge:
	extends Control
	var grade := "A"
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		var col: Color = Menus.GRADE_COLORS.get(grade, UIKit.TEXT)
		draw_circle(c, r, Color(col, 0.12))
		var k := clampf(_t / 0.8, 0.0, 1.0)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 64, col, 5.0, true)
		var f := UIKit.bold()
		var fs := int(r * 1.2)
		var w := f.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Radiographie du thorax de face (calculée sur l'atlas) : poumon droit rétracté, liseré pleural.
class XRayCard:
	extends Control
	var tex: Texture2D
	var caption := ""
	var side := "D"

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.0, 0.0, 0.0))
		var ts := tex.get_size()
		var k := minf(size.x / ts.x, size.y / ts.y)
		var w := ts * k
		draw_texture_rect(tex, Rect2((size - w) * 0.5, w), false)
		var f := UIKit.font()
		if side != "":
			draw_string(f, Vector2((size.x - w.x) * 0.5 + 8, 22), side, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
		draw_string(f, Vector2(8, size.y - 10), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))
