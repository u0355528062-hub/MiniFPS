class_name Menus
extends CanvasLayer
## Écrans plein cadre : menu principal (sur la salle en fond), transmission du patient, pause,
## options, compte rendu de fin (devenir du patient, note, objectifs atteints ou manqués, erreurs).

signal case_chosen(case_id: String)
signal start_pressed
signal resume_pressed
signal restart_pressed
signal main_menu_pressed
signal quit_pressed

## Couleur de chaque note (médaille de fin, record au menu)
const GRADE_COLORS := {"S": Color(1.0, 0.82, 0.3), "A": Color(0.35, 0.95, 0.55), "B": Color(0.22, 0.92, 0.82), "C": Color(1.0, 0.78, 0.3), "D": Color(1.0, 0.36, 0.33)}

var game: Node
var root: Control
var _dim: ColorRect
var _main: Control
var _brief: Control
var _pause: Control
var _options: Control
var _end: Control
var _options_back: Callable
var _fade: ColorRect
var _brief_go: Button


func build() -> void:
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


func _case() -> Case:
	return game.get("case")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			if _pause.visible:
				resume_pressed.emit()
				get_viewport().set_input_as_handled()
			elif _brief.visible:
				main_menu_pressed.emit()
				get_viewport().set_input_as_handled()
			elif _options.visible and _options_back.is_valid():
				_options_back.call()
				get_viewport().set_input_as_handled()
		elif k == KEY_SPACE or k == KEY_ENTER:
			if _brief.visible:
				start_pressed.emit()
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
	grad.offset_right = 950.0
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(grad)
	var col := UIKit.vbox(10)
	col.position = Vector2(90, 64)
	c.add_child(col)
	col.add_child(UIKit.label("EMERGENCY SIMULATOR", 16, UIKit.ACCENT, true))
	col.add_child(UIKit.label("URGENCES", 72, UIKit.TEXT, true))
	col.add_child(UIKit.label("Tu es l'urgentiste de garde. Un patient t'attend au déchocage.", 19, UIKit.TEXT_DIM))
	var sp := Control.new()
	sp.custom_minimum_size.y = 8
	col.add_child(sp)
	for e in Case.CATALOG:
		col.add_child(_case_card(e))
	var sp2 := Control.new()
	sp2.custom_minimum_size.y = 12
	col.add_child(sp2)
	var row := UIKit.hbox(12)
	col.add_child(row)
	var b2 := UIKit.button("Options", 260)
	b2.pressed.connect(func() -> void: open_options(func() -> void: show_main()))
	row.add_child(b2)
	var b3 := UIKit.button("Quitter", 260)
	b3.pressed.connect(func() -> void: quit_pressed.emit())
	row.add_child(b3)
	var foot := UIKit.label("Anatomie : atlas Z-Anatomy (CC BY-SA 4.0, d'après BodyParts3D)   ·   Version 7.0", 13, Color(1, 1, 1, 0.4))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(90, -50)
	c.add_child(foot)
	return c


func _case_card(e: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(720, 70)
	b.focus_mode = Control.FOCUS_ALL
	var cur: bool = e["id"] == _case().id
	var normal := UIKit.box(Color(0.03, 0.06, 0.075, 0.82), 10, UIKit.ACCENT_DIM if cur else Color(1, 1, 1, 0.07), 2 if cur else 1, 16)
	var hover := UIKit.box(Color(0.05, 0.13, 0.14, 0.92), 10, UIKit.ACCENT, 2, 16)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
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
	var t := UIKit.label(e["name"], 22, UIKit.TEXT, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(t)
	var tg := UIKit.label(e["tag"], 14, UIKit.TEXT_DIM)
	tg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.add_child(tg)
	var right := UIKit.vbox(2)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var lvl: int = e["level"]
	var dots := UIKit.label("●".repeat(lvl) + "○".repeat(3 - lvl), 15, UIKit.ACCENT)
	dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(dots)
	var info := UIKit.label("~%d min" % e["minutes"], 13, UIKit.TEXT_DIM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(info)
	var rec: Dictionary = Records.best(e["id"])
	if not rec.is_empty():
		var gr: String = rec["grade"]
		var bl := UIKit.label("RECORD  %s  ·  %s" % [gr, UIKit.fmt_time(rec["time"])], 12, GRADE_COLORS.get(gr, UIKit.TEXT), true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		right.add_child(bl)
	var cid: String = e["id"]
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void:
		Sfx.play("clic", Vector3.INF, -12.0, 1.0)
		case_chosen.emit(cid))
	return b


func show_main() -> void:
	_show(_main, false)


# ---------------------------------------------------------------- Transmission (briefing)

func _build_briefing() -> Control:
	var cs := _case()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var p := _center_panel(1120, c)
	var v := UIKit.vbox(16)
	p.add_child(v)
	var head := UIKit.hbox(14)
	v.add_child(head)
	var tag := UIKit.label("DÉCHOCAGE 1", 15, Color(0.05, 0.05, 0.05), true)
	var tsb := UIKit.box(Color(1.0, 0.36, 0.33), 6, Color(0, 0, 0, 0), 0, 10)
	tsb.shadow_size = 0
	tsb.content_margin_top = 3
	tsb.content_margin_bottom = 3
	tag.add_theme_stylebox_override("normal", tsb)
	head.add_child(tag)
	head.add_child(UIKit.label("%s, %d ans" % [cs.profile["name"], cs.profile["age"]], 20, UIKit.TEXT_DIM, true))
	v.add_child(UIKit.label(cs.name, 40, UIKit.TEXT, true))
	var story := UIKit.label(cs.arrival, 19, Color(0.88, 0.92, 0.94))
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size.x = 1060
	v.add_child(story)
	var vit := UIKit.label(cs.arrival_vitals, 19, UIKit.WARN, true)
	vit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vit.custom_minimum_size.x = 1060
	v.add_child(vit)
	var keys := UIKit.label("ZQSD : marcher · Souris : regarder · Clic ou E : utiliser ce que vise le viseur (zone du patient, chariot, défibrillateur, scope, débitmètre, ordinateur…)\n" +
		"Vue rapprochée : la souris est libre, clic gauche : geste avec l'objet en main (1-9), clic droit maintenu : tourner autour, molette : zoom, ZQSD : décaler, Échap : revenir\n" +
		"T : parler au patient · Tab : dossier, examens et conclusion (poste informatique)", 15, UIKit.TEXT_DIM)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size.x = 1060
	v.add_child(keys)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := UIKit.button("Menu (Échap)", 220)
	back.pressed.connect(func() -> void: main_menu_pressed.emit())
	row.add_child(back)
	_brief_go = UIKit.button("Entrer dans le box  (Espace)", 380)
	_brief_go.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(_brief_go)
	return c


func show_briefing() -> void:
	_show(_brief, true)
	if _brief_go:
		_brief_go.grab_focus.call_deferred()


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
			["Recommencer le cas", func() -> void: restart_pressed.emit()],
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


# ---------------------------------------------------------------- Compte rendu

func show_end(res: Dictionary) -> void:
	var cs := _case()
	for ch in _end.get_children():
		ch.queue_free()
	var p := _center_panel(1180, _end)
	var v := UIKit.vbox(14)
	p.add_child(v)
	var top := UIKit.hbox(28)
	v.add_child(top)
	var badge := GradeBadge.new()
	badge.grade = res["grade"]
	badge.custom_minimum_size = Vector2(150, 150)
	top.add_child(badge)
	var info := UIKit.vbox(8)
	top.add_child(info)
	var head := UIKit.hbox(12)
	info.add_child(head)
	var alive: bool = res["alive"]
	head.add_child(UIKit.label("PATIENT VIVANT" if alive else "PATIENT DÉCÉDÉ", 15, UIKit.OK if alive else UIKit.BAD, true))
	if res.get("record", false):
		head.add_child(UIKit.label("NOUVEAU RECORD", 13, Color(1.0, 0.82, 0.3), true))
	info.add_child(UIKit.label("%s — %s, %d ans" % [cs.name, cs.profile["name"], cs.profile["age"]], 32, UIKit.TEXT, true))
	var s := UIKit.label(res["summary"], 17, Color(0.85, 0.9, 0.92))
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size.x = 900
	info.add_child(s)
	info.add_child(UIKit.label("Note %s · %d / 100 · durée %s (référence %s)" % [res["grade"], int(res["score"]), UIKit.fmt_time(res["time"]), UIKit.fmt_time(cs.reference_time())], 18, UIKit.TEXT_DIM, true))
	var cols := UIKit.hbox(30)
	v.add_child(cols)
	var left := UIKit.vbox(4)
	left.custom_minimum_size.x = 640
	cols.add_child(left)
	left.add_child(UIKit.label("OBJECTIFS", 14, UIKit.ACCENT, true))
	for o in res["objectives"]:
		var l := UIKit.label("%s  %s  (%d pts)" % ["✔" if o[2] else "✘", o[0], int(o[1])], 16, UIKit.OK if o[2] else UIKit.BAD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 630
		left.add_child(l)
	var right := UIKit.vbox(4)
	right.custom_minimum_size.x = 460
	cols.add_child(right)
	right.add_child(UIKit.label("ERREURS", 14, UIKit.ACCENT, true))
	var errs: Array = res["errors"]
	if errs.is_empty():
		right.add_child(UIKit.label("Aucune erreur.", 16, UIKit.OK))
	for e in errs:
		var l2 := UIKit.label("•  %s  (−%d)" % [e[0], int(e[1])], 16, UIKit.WARN)
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l2.custom_minimum_size.x = 450
		right.add_child(l2)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var b1 := UIKit.button("Menu principal", 240)
	b1.pressed.connect(func() -> void: main_menu_pressed.emit())
	row.add_child(b1)
	var b2 := UIKit.button("Rejouer ce cas", 260)
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


