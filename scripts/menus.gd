class_name Menus
extends CanvasLayer
## Écrans plein cadre : menu principal (sur la salle animée en fond), entraînement libre (choix
## d'un des 6 cas), transmission du patient (entraînement), carton de chapitre (histoire), pause,
## options, bilan de fin (note, objectifs atteints ou manqués avec explications simples, erreurs,
## avis du chef) et fin de l'histoire.

signal story_pressed(fresh: bool)
signal case_chosen(case_id: String)
signal start_pressed
signal resume_pressed
signal restart_pressed
signal next_pressed
signal main_menu_pressed
signal training_pressed
signal quit_pressed

## Couleur de chaque note (médaille de fin, record)
const GRADE_COLORS := {"S": Color(1.0, 0.82, 0.3), "A": Color(0.38, 0.87, 0.53), "B": Color(0.25, 0.86, 0.79), "C": Color(1.0, 0.75, 0.3), "D": Color(1.0, 0.4, 0.4)}
const GRADE_WORDS := {"S": "Parfait", "A": "Très bien", "B": "Bien", "C": "Passable", "D": "À revoir"}

var game: Node
var root: Control
var _dim: ColorRect
var _main: Control
var _training: Control
var _brief: Control
var _pause: Control
var _options: Control
var _end: Control
var _card: Control
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
	_dim.color = Color(0.0, 0.015, 0.03, 0.62)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_main = _build_main()
	_training = _build_training()
	_brief = _build_briefing()
	_pause = _build_pause()
	_options = _build_options()
	_end = _full()
	_card = _full()
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	hide_all()


func _full() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


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
			elif _training.visible:
				show_main()
				get_viewport().set_input_as_handled()
		elif k == KEY_SPACE or k == KEY_ENTER:
			if _brief.visible:
				start_pressed.emit()
				get_viewport().set_input_as_handled()


func hide_all() -> void:
	for c in [_main, _training, _brief, _pause, _options, _end, _card]:
		c.visible = false
	_dim.visible = false


func any_open() -> bool:
	for c in [_main, _training, _brief, _pause, _options, _end, _card]:
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
		if ch is Button and (ch as Button).visible and not (ch as Button).disabled:
			return ch
		var b := _first_button(ch)
		if b:
			return b
	return null


func fade(to_black: bool, dur := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0 if to_black else 0.0, dur)
	await tw.finished


func set_black(on: bool) -> void:
	_fade.color.a = 1.0 if on else 0.0


func _center_panel(w: float, parent: Control, pad := 32) -> PanelContainer:
	var p := UIKit.panel(UIKit.PANEL_SOLID, 22, pad)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, 0)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(p)
	return p


func _left_gradient(c: Control, width := 1100.0, alpha := 0.94) -> void:
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.01, 0.025, 0.04, alpha))
	g.add_point(0.55, Color(0.01, 0.025, 0.04, alpha * 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.01, 0.025, 0.04, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = width
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(grad)


## Logo : croix rouge, URGENCES, sous-titre.
func _logo(size := 96) -> Control:
	var v := UIKit.vbox(4)
	var top := UIKit.hbox(14)
	v.add_child(top)
	var cross := UIKit.icon("plus", 26, UIKit.RED)
	cross.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(cross)
	top.add_child(UIKit.caption("Emergency Simulator", UIKit.TEXT_DIM, 16))
	var t := UIKit.text("URGENCES", size, UIKit.TEXT, 800)
	t.add_theme_constant_override("outline_size", 0)
	v.add_child(t)
	var line := EcgLine.new()
	line.custom_minimum_size = Vector2(560, 46)
	v.add_child(line)
	return v


# ---------------------------------------------------------------- Menu principal

func _build_main() -> Control:
	var c := _full()
	_left_gradient(c)
	var col := UIKit.vbox(14)
	col.position = Vector2(110, 96)
	col.custom_minimum_size.x = 600
	c.add_child(col)
	col.add_child(_logo())
	col.add_child(UIKit.para("Une nuit aux urgences. Des patients qui comptent sur toi.", 22, UIKit.TEXT_DIM, 600.0, 450))
	col.add_child(UIKit.spacer(30))
	var st := Records.story()
	var ch: int = st["chapter"]
	var done: bool = st["done"]
	# Histoire
	var story_btn := _menu_button("Histoire : Première garde",
		("Continuer — patient %d sur 3" % (ch + 1)) if ch > 0 else ("Rejouer la garde" if done else "Nouvelle partie — commence ici"), "play", true)
	story_btn.pressed.connect(func() -> void: story_pressed.emit(ch == 0))
	col.add_child(story_btn)
	if ch > 0:
		var restart := UIKit.link("Recommencer l'histoire depuis le début", 17)
		restart.alignment = HORIZONTAL_ALIGNMENT_LEFT
		restart.pressed.connect(func() -> void: story_pressed.emit(true))
		col.add_child(restart)
	var train := _menu_button("Entraînement libre", "Les 6 patients, au choix" if done else "Les 6 patients, au choix (conseillé après l'histoire)", "list")
	train.pressed.connect(func() -> void: show_training())
	col.add_child(train)
	var opt := _menu_button("Options", "Graphismes, souris, son", "gear")
	opt.pressed.connect(func() -> void: open_options(func() -> void: show_main()))
	col.add_child(opt)
	var quit := _menu_button("Quitter", "", "exit")
	quit.pressed.connect(func() -> void: quit_pressed.emit())
	col.add_child(quit)
	# Progression de la garde (à droite, en bas)
	var prog := UIKit.panel(Color(0.03, 0.045, 0.065, 0.82), 18, 22)
	prog.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	prog.offset_left = -470
	prog.offset_right = -60
	prog.offset_top = -70
	prog.offset_bottom = -70
	prog.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	prog.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.add_child(prog)
	var pv := UIKit.vbox(10)
	prog.add_child(pv)
	pv.add_child(UIKit.caption("Ta première garde", UIKit.ACCENT, 14))
	var res: Dictionary = st["results"]
	for i in Story.CHAPTERS.size():
		var e: Dictionary = Story.CHAPTERS[i]
		var h := UIKit.hbox(12)
		pv.add_child(h)
		var r: Dictionary = res.get(i, {})
		var reached := done or i < ch or (i == ch)
		var finished := done or i < ch
		var ic := UIKit.icon("check" if finished else ("play" if reached else "lock"), 20, UIKit.OK if finished else (UIKit.ACCENT if reached else UIKit.TEXT_FAINT))
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UIKit.text("%s  ·  %s" % [e["time"], e["title"]], 18, UIKit.TEXT if reached else UIKit.TEXT_FAINT, 600))
		if not r.is_empty():
			var gr: String = r.get("grade", "D")
			h.add_child(UIKit.text(gr, 22, GRADE_COLORS.get(gr, UIKit.TEXT), 800))
	var foot := UIKit.text("Anatomie : atlas Z-Anatomy (CC BY-SA 4.0, d'après BodyParts3D)  ·  Police Inter  ·  Version 8.0", 14, Color(1, 1, 1, 0.38), 450)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 110
	foot.offset_top = -56
	foot.offset_bottom = -30
	c.add_child(foot)
	return c


## Gros bouton du menu : icône, titre, sous-titre.
func _menu_button(title: String, sub: String, icon_kind: String, primary := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(560, 84 if sub != "" else 64)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		var n := UIKit.box(Color(0.25, 0.86, 0.79, 0.95), 14, Color(0, 0, 0, 0), 0, 18)
		n.shadow_color = Color(0.25, 0.86, 0.79, 0.3)
		n.shadow_size = 18
		n.shadow_offset = Vector2.ZERO
		var hv := n.duplicate() as StyleBoxFlat
		hv.bg_color = Color(0.45, 0.95, 0.88)
		hv.shadow_size = 26
		var f := n.duplicate() as StyleBoxFlat
		f.border_color = Color.WHITE
		f.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", n)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_stylebox_override("focus", f)
	else:
		var n2 := UIKit.box(Color(0.05, 0.075, 0.1, 0.72), 14, Color(1, 1, 1, 0.09), 1, 18)
		n2.shadow_size = 0
		var h2 := UIKit.box(Color(0.25, 0.86, 0.79, 0.14), 14, UIKit.ACCENT, 2, 18)
		h2.shadow_size = 0
		var f2 := h2.duplicate() as StyleBoxFlat
		b.add_theme_stylebox_override("normal", n2)
		b.add_theme_stylebox_override("hover", h2)
		b.add_theme_stylebox_override("pressed", h2)
		b.add_theme_stylebox_override("focus", f2)
	var fg := Color(0.02, 0.09, 0.09) if primary else UIKit.TEXT
	var row := UIKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -20
	b.add_child(row)
	var ic := UIKit.icon(icon_kind, 26, fg)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var tv := UIKit.vbox(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tv)
	tv.add_child(UIKit.text(title, 25, fg, 800 if primary else 700))
	if sub != "":
		tv.add_child(UIKit.text(sub, 17, Color(fg, 0.75) if primary else UIKit.TEXT_DIM, 500))
	var arrow := UIKit.icon("arrow", 20, Color(fg, 0.6))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(arrow)
	UIKit.pass_mouse(row)
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void: Sfx.play("clic", Vector3.INF, -12.0, 1.0))
	return b


func show_main() -> void:
	_show(_main, false)


# ---------------------------------------------------------------- Entraînement libre

func _build_training() -> Control:
	var c := _full()
	_left_gradient(c, 1700.0, 0.96)
	var col := UIKit.vbox(18)
	col.position = Vector2(110, 80)
	c.add_child(col)
	var head := UIKit.hbox(16)
	col.add_child(head)
	var back := UIKit.button("Retour", 150)
	back.pressed.connect(func() -> void: show_main())
	head.add_child(back)
	var tv := UIKit.vbox(2)
	head.add_child(tv)
	tv.add_child(UIKit.text("Entraînement libre", 44, UIKit.TEXT, 800))
	tv.add_child(UIKit.text("Choisis un patient. La liste « À faire » t'indique ce qui est attendu ; ton meilleur résultat est gardé.", 19, UIKit.TEXT_DIM, 450))
	col.add_child(UIKit.spacer(6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	col.add_child(grid)
	for e in Case.CATALOG:
		grid.add_child(_case_card(e))
	return c


func _case_card(e: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(740, 150)
	b.focus_mode = Control.FOCUS_ALL
	var normal := UIKit.box(Color(0.04, 0.06, 0.085, 0.88), 16, Color(1, 1, 1, 0.08), 1, 20)
	var hover := UIKit.box(Color(0.06, 0.15, 0.16, 0.95), 16, UIKit.ACCENT, 2, 20)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	var row := UIKit.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -22
	row.offset_top = 18
	row.offset_bottom = -18
	b.add_child(row)
	var txt := UIKit.vbox(6)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	var chips := UIKit.hbox(8)
	txt.add_child(chips)
	var lvl: int = e["level"]
	chips.add_child(UIKit.chip(["", "Facile", "Moyen", "Difficile"][lvl], [UIKit.OK, UIKit.OK, UIKit.WARN, UIKit.BAD][lvl], Color(0.03, 0.05, 0.06), 15))
	chips.add_child(UIKit.chip("~%d min" % e["minutes"], Color(1, 1, 1, 0.1), UIKit.TEXT_DIM, 15))
	txt.add_child(UIKit.text(e["name"], 26, UIKit.TEXT, 800))
	txt.add_child(UIKit.para(e["tag"], 18, UIKit.TEXT_DIM, 540.0))
	var right := UIKit.vbox(2)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.custom_minimum_size.x = 110
	row.add_child(right)
	var rec: Dictionary = Records.best(e["id"])
	if not rec.is_empty():
		var gr: String = rec["grade"]
		var g := UIKit.text(gr, 46, GRADE_COLORS.get(gr, UIKit.TEXT), 800)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(g)
		var t := UIKit.text("record · " + UIKit.fmt_time(rec["time"]), 13, UIKit.TEXT_DIM, 600)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		right.add_child(t)
	else:
		var n := UIKit.text("Pas encore joué", 14, UIKit.TEXT_FAINT, 500)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(n)
	UIKit.pass_mouse(row)
	var cid: String = e["id"]
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void:
		Sfx.play("clic", Vector3.INF, -12.0, 1.0)
		case_chosen.emit(cid))
	return b


func show_training() -> void:
	_show(_training, false)


# ---------------------------------------------------------------- Transmission (entraînement)

func _build_briefing() -> Control:
	var cs := _case()
	var c := _full()
	var p := _center_panel(1180, c, 40)
	var v := UIKit.vbox(18)
	p.add_child(v)
	var head := UIKit.hbox(12)
	v.add_child(head)
	head.add_child(UIKit.chip("DÉCHOCAGE", UIKit.RED, Color.WHITE, 14))
	head.add_child(UIKit.text("%s, %d ans" % [cs.profile["name"], cs.profile["age"]], 20, UIKit.TEXT_DIM, 600))
	v.add_child(UIKit.text(cs.name, 46, UIKit.TEXT, 800))
	v.add_child(UIKit.para(cs.arrival, 21, Color(0.88, 0.92, 0.95), 1100.0))
	var vit := UIKit.panel(Color(1.0, 0.75, 0.3, 0.08), 12, 16)
	v.add_child(vit)
	var vh := UIKit.hbox(12)
	vit.add_child(vh)
	vh.add_child(UIKit.icon("ecg", 26, UIKit.WARN))
	vh.add_child(UIKit.para(Lexique.simple(cs.arrival_vitals), 20, UIKit.WARN, 1000.0, 600))
	v.add_child(UIKit.spacer(2))
	v.add_child(UIKit.caption("Commandes"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for kv in [[["Z", "Q", "S", "D"], "Marcher"], [["Souris"], "Regarder"], [["Clic", "E"], "Utiliser ce que vise le point central"],
			[["1-9"], "Choisir l'objet en main"], [["Clic droit"], "Vue rapprochée : tourner autour"], [["Molette"], "Vue rapprochée : zoomer"],
			[["T"], "Parler au patient"], [["Tab"], "Dossier, examens, conclusion"]]:
		var h := UIKit.hbox(6)
		for k in kv[0]:
			h.add_child(UIKit.key(k, 15))
		h.add_child(UIKit.spacer(0, 6))
		h.add_child(UIKit.text(kv[1], 18, UIKit.TEXT_DIM, 500))
		grid.add_child(h)
	var row := UIKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var back := UIKit.button("Menu  (Échap)", 220)
	back.pressed.connect(func() -> void: main_menu_pressed.emit())
	row.add_child(back)
	_brief_go = UIKit.button("Entrer dans le box  (Espace)", 380, true)
	_brief_go.pressed.connect(func() -> void: start_pressed.emit())
	row.add_child(_brief_go)
	return c


func show_briefing() -> void:
	_show(_brief, true)
	if _brief_go:
		_brief_go.grab_focus.call_deferred()


# ---------------------------------------------------------------- Carton de chapitre (histoire)

## Carton noir : « Patient 2 / 3 », titre, heure. Rendu à la fin du fondu.
func show_chapter_card(caption: String, title: String, time: String, hold := 2.2) -> void:
	for ch in _card.get_children():
		ch.queue_free()
	hide_all()
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.015, 0.025, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.add_child(bg)
	var v := UIKit.vbox(10)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.add_child(v)
	var cap := UIKit.caption(caption, UIKit.RED, 18)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(cap)
	var t := UIKit.text(title, 64, UIKit.TEXT, 800)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var line := EcgLine.new()
	line.custom_minimum_size = Vector2(720, 50)
	line.color = Color(UIKit.RED, 0.9)
	v.add_child(line)
	var tm := UIKit.text(time, 24, UIKit.TEXT_DIM, 600)
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tm)
	_card.visible = true
	_card.modulate.a = 0.0
	set_black(false)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.5)
	await tw.finished
	if hold > 0.0:
		await get_tree().create_timer(hold, true, false, true).timeout


func hide_chapter_card(dur := 0.6) -> void:
	if not _card.visible:
		return
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 0.0, dur)
	await tw.finished
	_card.visible = false


# ---------------------------------------------------------------- Pause

func _build_pause() -> Control:
	var c := _full()
	var p := _center_panel(500, c)
	var v := UIKit.vbox(12)
	p.add_child(v)
	var top := UIKit.hbox(12)
	v.add_child(top)
	top.add_child(UIKit.icon("pause", 28, UIKit.ACCENT))
	top.add_child(UIKit.text("Pause", 38, UIKit.TEXT, 800))
	v.add_child(UIKit.para("Le temps est arrêté : le patient t'attend.", 18, UIKit.TEXT_DIM, 430.0))
	v.add_child(UIKit.spacer(4))
	var items := [["Reprendre", func() -> void: resume_pressed.emit(), true],
			["Options", func() -> void: open_options(func() -> void: show_pause()), false],
			["Recommencer ce patient", func() -> void: restart_pressed.emit(), false],
			["Menu principal", func() -> void: main_menu_pressed.emit(), false],
			["Quitter le jeu", func() -> void: quit_pressed.emit(), false]]
	for item in items:
		var b := UIKit.button(item[0], 436, item[2])
		b.pressed.connect(item[1])
		v.add_child(b)
	return c


func show_pause() -> void:
	_show(_pause, true)


# ---------------------------------------------------------------- Options

func _build_options() -> Control:
	var c := _full()
	var p := _center_panel(1080, c, 36)
	var v := UIKit.vbox(14)
	p.add_child(v)
	var top := UIKit.hbox(12)
	v.add_child(top)
	top.add_child(UIKit.icon("gear", 30, UIKit.ACCENT))
	var t := UIKit.text("Options", 38, UIKit.TEXT, 800)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	v.add_child(UIKit.rule())
	var cols := UIKit.hbox(48)
	v.add_child(cols)
	var left := UIKit.vbox(12)
	left.custom_minimum_size.x = 480
	cols.add_child(left)
	var right := UIKit.vbox(12)
	right.custom_minimum_size.x = 480
	cols.add_child(right)
	left.add_child(UIKit.caption("Graphismes"))
	var q := OptionButton.new()
	for i in Settings.PRESETS.size():
		q.add_item(Settings.PRESETS[i], i)
	q.selected = Settings.quality
	q.custom_minimum_size.y = 46
	q.item_selected.connect(func(i: int) -> void:
		Settings.quality = i
		Settings.reapply())
	left.add_child(_row("Qualité", q))
	left.add_child(_slider_row("Résolution 3D", 50, 100, Settings.render_scale * 100.0, "%d %%", func(x: float) -> void:
		Settings.render_scale = x / 100.0
		Settings.reapply()))
	left.add_child(_check_row("Plein écran", Settings.fullscreen, func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.reapply()))
	left.add_child(_check_row("Synchronisation verticale", Settings.vsync, func(on: bool) -> void:
		Settings.vsync = on
		Settings.reapply()))
	left.add_child(UIKit.spacer(6))
	left.add_child(UIKit.caption("Son"))
	left.add_child(_slider_row("Volume général", 0, 100, Settings.volume * 100.0, "%d %%", func(x: float) -> void:
		Settings.volume = x / 100.0
		Settings.reapply()))
	right.add_child(UIKit.caption("Contrôles"))
	right.add_child(_slider_row("Champ de vision", 60, 95, Settings.fov, "%d°", func(x: float) -> void:
		Settings.fov = x
		Settings.reapply()))
	right.add_child(_slider_row("Sensibilité souris", 20, 300, Settings.sensitivity * 100.0, "%d %%", func(x: float) -> void:
		Settings.sensitivity = x / 100.0
		Settings.reapply()))
	right.add_child(_check_row("Inverser l'axe vertical", Settings.invert_y, func(on: bool) -> void:
		Settings.invert_y = on
		Settings.reapply()))
	right.add_child(_check_row("Balancement de la tête", Settings.head_bob, func(on: bool) -> void:
		Settings.head_bob = on
		Settings.reapply()))
	right.add_child(UIKit.spacer(6))
	right.add_child(UIKit.caption("Aide"))
	right.add_child(_check_row("Rappel des touches à l'écran", Settings.show_hints, func(on: bool) -> void:
		Settings.show_hints = on
		Settings.reapply()))
	v.add_child(UIKit.spacer(4))
	var back := UIKit.button("Retour", 220, true)
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
	var l := UIKit.text(text, 19, UIKit.TEXT, 500)
	l.custom_minimum_size.x = 230
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	s.custom_minimum_size = Vector2(160, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := UIKit.text(fmt % int(val), 17, UIKit.ACCENT, 700)
	vl.custom_minimum_size.x = 64
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	c.size_flags_horizontal = Control.SIZE_SHRINK_END
	var h := _row(text, c)
	c.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	return h


func open_options(back: Callable) -> void:
	_options_back = back
	_show(_options, true)


# ---------------------------------------------------------------- Bilan

## Bilan de fin : note, devenir, avis du chef, objectifs expliqués, erreurs.
func show_end(res: Dictionary) -> void:
	var cs := _case()
	for ch in _end.get_children():
		ch.queue_free()
	var story := Story.active
	var p := _center_panel(1500, _end, 34)
	var v := UIKit.vbox(18)
	p.add_child(v)
	# En-tête : médaille, devenir, résumé
	var top := UIKit.hbox(30)
	v.add_child(top)
	var badge := GradeBadge.new()
	badge.grade = res["grade"]
	badge.custom_minimum_size = Vector2(160, 160)
	top.add_child(badge)
	var info := UIKit.vbox(8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var head := UIKit.hbox(10)
	info.add_child(head)
	var alive: bool = res["alive"]
	head.add_child(UIKit.chip("PATIENT VIVANT" if alive else "PATIENT DÉCÉDÉ", UIKit.OK if alive else UIKit.BAD, Color(0.03, 0.05, 0.06), 14))
	if story:
		head.add_child(UIKit.chip("PATIENT %d / 3" % (Story.chapter + 1), Color(1, 1, 1, 0.1), UIKit.TEXT_DIM, 14))
	if res.get("record", false):
		head.add_child(UIKit.chip("NOUVEAU RECORD", Color(1.0, 0.82, 0.3), Color(0.1, 0.07, 0.0), 14))
	info.add_child(UIKit.text("%s — %s, %d ans" % [cs.name, String(cs.profile["name"]).split(" ")[0], cs.profile["age"]], 34, UIKit.TEXT, 800))
	info.add_child(UIKit.para(res["summary"], 19, Color(0.86, 0.9, 0.93), 1200.0))
	var stats := UIKit.hbox(26)
	info.add_child(stats)
	stats.add_child(_stat(GRADE_WORDS.get(res["grade"], ""), "%d / 100" % int(res["score"]), GRADE_COLORS.get(res["grade"], UIKit.TEXT)))
	stats.add_child(_stat("Durée", UIKit.fmt_time(res["time"]), UIKit.TEXT))
	var objs: Array = res["objectives"]
	var n_ok := 0
	for o in objs:
		if o[2]:
			n_ok += 1
	stats.add_child(_stat("Objectifs", "%d / %d" % [n_ok, objs.size()], UIKit.OK if n_ok == objs.size() else UIKit.TEXT))
	stats.add_child(_stat("Erreurs", str((res["errors"] as Array).size()), UIKit.OK if (res["errors"] as Array).is_empty() else UIKit.WARN))
	# Avis du chef
	var quote := String(res.get("chief", ""))
	if quote != "":
		var chief := UIKit.panel(Color(1.0, 0.75, 0.35, 0.07), 16, 18)
		v.add_child(chief)
		var chh := UIKit.hbox(20)
		chief.add_child(chh)
		var por := DialogueBox.Portrait.new()
		por.cast = DialogueBox.CAST["marchand"]
		por.custom_minimum_size = Vector2(92, 92)
		chh.add_child(por)
		var qv := UIKit.vbox(4)
		qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chh.add_child(qv)
		qv.add_child(UIKit.text("Ce qu'en pense le Dr Marchand", 17, Color(1.0, 0.75, 0.35), 700))
		qv.add_child(UIKit.para("« %s »" % quote, 20, UIKit.TEXT, 1240.0, 450))
	# Objectifs et erreurs
	var cols := UIKit.hbox(30)
	v.add_child(cols)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(900, 420)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc)
	var left := UIKit.vbox(8)
	left.custom_minimum_size.x = 880
	sc.add_child(left)
	left.add_child(UIKit.caption("Objectifs"))
	for o in objs:
		var ok: bool = o[2]
		var row := UIKit.hbox(12)
		left.add_child(row)
		var ic := UIKit.icon("check" if ok else "cross", 22, UIKit.OK if ok else UIKit.BAD)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var tv := UIKit.vbox(1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tv)
		var lbl: String = o[0] + ("  — pas nécessaire cette fois" if o.size() > 4 and o[4] else "")
		tv.add_child(UIKit.para(lbl, 20, UIKit.TEXT if ok else Color(1.0, 0.82, 0.8), 760.0, 600))
		if o.size() > 3 and String(o[3]) != "":
			tv.add_child(UIKit.para(o[3], 17, UIKit.TEXT_DIM, 760.0, 450))
		var pts := UIKit.text("%d pts" % int(o[1]), 15, UIKit.TEXT_FAINT, 600)
		pts.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(pts)
	var right := UIKit.vbox(8)
	right.custom_minimum_size.x = 480
	cols.add_child(right)
	right.add_child(UIKit.caption("À éviter la prochaine fois", UIKit.WARN))
	var errs: Array = res["errors"]
	if errs.is_empty():
		var nr := UIKit.hbox(10)
		right.add_child(nr)
		nr.add_child(UIKit.icon("star", 22, UIKit.OK))
		nr.add_child(UIKit.text("Aucune erreur. Bravo !", 19, UIKit.OK, 600))
	for e in errs:
		var er := UIKit.hbox(10)
		right.add_child(er)
		var wi := UIKit.icon("warn", 20, UIKit.WARN)
		wi.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		er.add_child(wi)
		er.add_child(UIKit.para("%s  (−%d)" % [Lexique.simple(e[0]), int(e[1])], 18, Color(1.0, 0.88, 0.7), 430.0, 500))
	# Boutons
	var row2 := UIKit.hbox(12)
	row2.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row2)
	var main_b: Button
	if story:
		var b0 := UIKit.button("Menu principal", 230)
		b0.pressed.connect(func() -> void: main_menu_pressed.emit())
		row2.add_child(b0)
		var b1 := UIKit.button("Rejouer ce patient", 270)
		b1.pressed.connect(func() -> void: restart_pressed.emit())
		row2.add_child(b1)
		var last := Story.chapter >= Story.CHAPTERS.size() - 1
		main_b = UIKit.button("Terminer la garde" if last else "Patient suivant", 330, true)
		main_b.pressed.connect(func() -> void: next_pressed.emit())
		row2.add_child(main_b)
	else:
		var b2 := UIKit.button("Menu principal", 230)
		b2.pressed.connect(func() -> void: main_menu_pressed.emit())
		row2.add_child(b2)
		var b3 := UIKit.button("Autre patient", 240)
		b3.pressed.connect(func() -> void: training_pressed.emit())
		row2.add_child(b3)
		main_b = UIKit.button("Rejouer ce patient", 300, true)
		main_b.pressed.connect(func() -> void: restart_pressed.emit())
		row2.add_child(main_b)
	_show(_end, true)
	main_b.grab_focus.call_deferred()
	Sfx.play("fin" if alive else "erreur", Vector3.INF, -10.0)


func _stat(label: String, value: String, col: Color) -> Control:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.text(value, 28, col, 800))
	v.add_child(UIKit.text(label, 15, UIKit.TEXT_DIM, 600))
	return v


# ---------------------------------------------------------------- Fin de l'histoire

func show_story_end() -> void:
	for ch in _end.get_children():
		ch.queue_free()
	var p := _center_panel(1240, _end, 40)
	var v := UIKit.vbox(18)
	p.add_child(v)
	var cap := UIKit.caption("Fin de la première garde", UIKit.RED, 16)
	v.add_child(cap)
	v.add_child(UIKit.text("Tu as tenu toute la nuit.", 48, UIKit.TEXT, 800))
	v.add_child(UIKit.para("Trois patients, trois histoires. Voici ce que retient le Dr Marchand de ta garde.", 20, UIKit.TEXT_DIM, 1100.0))
	var row := UIKit.hbox(18)
	v.add_child(row)
	var total := 0.0
	for i in Story.CHAPTERS.size():
		var e: Dictionary = Story.CHAPTERS[i]
		var r: Dictionary = Story.results.get(i, {})
		var card := UIKit.panel(UIKit.CARD, 16, 20)
		card.custom_minimum_size = Vector2(370, 0)
		row.add_child(card)
		var cv := UIKit.vbox(6)
		card.add_child(cv)
		cv.add_child(UIKit.text("%s · patient %d" % [e["time"], i + 1], 15, UIKit.TEXT_DIM, 600))
		cv.add_child(UIKit.text(e["title"], 22, UIKit.TEXT, 700))
		var gr: String = r.get("grade", "—")
		total += float(r.get("score", 0.0))
		var h := UIKit.hbox(12)
		cv.add_child(h)
		h.add_child(UIKit.text(gr, 44, GRADE_COLORS.get(gr, UIKit.TEXT_DIM), 800))
		var sv := UIKit.vbox(0)
		h.add_child(sv)
		sv.add_child(UIKit.text(GRADE_WORDS.get(gr, ""), 17, UIKit.TEXT, 600))
		sv.add_child(UIKit.text(("vivant" if r.get("alive", true) else "décédé"), 15, UIKit.OK if r.get("alive", true) else UIKit.BAD, 600))
	v.add_child(UIKit.text("Score de la garde : %d / 300" % int(total), 22, UIKit.ACCENT, 700))
	var unlock := UIKit.panel(Color(0.25, 0.86, 0.79, 0.08), 14, 18)
	v.add_child(unlock)
	var uh := UIKit.hbox(14)
	unlock.add_child(uh)
	uh.add_child(UIKit.icon("star", 26, UIKit.ACCENT))
	uh.add_child(UIKit.para("Entraînement libre débloqué : six patients, dont trois nouveaux (infarctus, overdose, crise d'asthme).", 19, UIKit.TEXT, 1000.0, 500))
	var br := UIKit.hbox(12)
	br.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(br)
	var b1 := UIKit.button("Menu principal", 240)
	b1.pressed.connect(func() -> void: main_menu_pressed.emit())
	br.add_child(b1)
	var b2 := UIKit.button("Entraînement libre", 300, true)
	b2.pressed.connect(func() -> void: training_pressed.emit())
	br.add_child(b2)
	_show(_end, true)
	b2.grab_focus.call_deferred()


## Médaille de la note (S, A, B, C, D) : cercle lumineux qui se remplit.
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
		draw_circle(c, r, Color(col, 0.1))
		draw_arc(c, r, 0, TAU, 64, Color(col, 0.2), 6.0, true)
		var k := clampf(_t / 0.9, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * k, 64, col, 6.0, true)
		var f := UIKit.weight(800)
		var fs := int(r * 1.15)
		var w := f.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Tracé d'ECG qui défile (décor du logo et des cartons).
class EcgLine:
	extends Control
	var color := Color(0.25, 0.86, 0.79, 0.85)
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _shape(x: float) -> float:
		var ph := fposmod(x, 1.0)
		if ph < 0.08:
			return sin(ph / 0.08 * PI) * 0.12
		if ph < 0.14:
			return 0.0
		if ph < 0.16:
			return -0.15
		if ph < 0.19:
			return 1.0
		if ph < 0.22:
			return -0.35
		if ph < 0.4:
			return 0.0
		if ph < 0.52:
			return sin((ph - 0.4) / 0.12 * PI) * 0.22
		return 0.0

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var n := 160
		var head := fposmod(_t * 0.35, 1.0)
		for i in n - 1:
			var a := float(i) / n
			var b := float(i + 1) / n
			var fade := clampf(1.0 - fposmod(head - a, 1.0) * 1.4, 0.0, 1.0)
			if fade <= 0.0:
				continue
			var ya := h * 0.62 - _shape(a * 2.2) * h * 0.55
			var yb := h * 0.62 - _shape(b * 2.2) * h * 0.55
			draw_line(Vector2(a * w, ya), Vector2(b * w, yb), Color(color, color.a * fade), 2.5, true)
		var hy := h * 0.62 - _shape(head * 2.2) * h * 0.55
		draw_circle(Vector2(head * w, hy), 4.0, color)
