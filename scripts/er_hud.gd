class_name ERHud
extends CanvasLayer
## Interface en jeu : viseur et ce qu'il désigne, carte du patient et chrono, liste « À faire »
## (objectifs du cas, cochés quand ils sont faits, ou étape du tutoriel), constantes du scope en
## mots simples avec couleurs de gravité et icônes, messages, objets en main (1 à 9), barre de
## progression des gestes, aide de la vue rapprochée ; panneaux : chariot d'urgence (matériel,
## seringues), poste informatique (dossier, examens, résultats, conclusion), interrogatoire, ECG,
## imagerie. Les éléments que le tutoriel peut montrer du doigt sont enregistrés dans « marks ».

var game: ERGame
var marks := {}  ## nom -> Control (surbrillance du tutoriel)
var zone := false
var tasks_hidden := false

var _root: Control
var _cross: Control
var _aim: Label
var _aim_verb: Label
var _clock: Label
var _head_chip: Label
var _tasks: PanelContainer
var _tasks_body: VBoxContainer
var _tasks_sig := ""
var _tasks_t := 0.0
var _vitals: PanelContainer
var _vit := {}  ## clé -> {icon, value, unit, dot, row}
var _vit_hint: Label
var _hotbar: HBoxContainer
var _toasts: VBoxContainer
var _progress: ProgressBar
var _progress_lbl: Label
var _zone_bar: HBoxContainer
var _zone_title: Label
var _zone_hint: Label
var _zone_hint_box: PanelContainer
var _keys: HBoxContainer
var _keys_box: PanelContainer
var _panel_host: Control
var _panel: Control
var _beat := 0.0


func build() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_build_crosshair()
	_build_header()
	_build_vitals()
	_build_toasts()
	_build_progress()
	_build_zone()
	_build_hotbar()
	_build_keys()
	_panel_host = Control.new()
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_host)


func _label(t: String, size: int, c: Color, w := 450) -> Label:
	var l := UIKit.text(t, size, c, w)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func mark(id: String, c: Control) -> void:
	marks[id] = c


func get_mark(id: String) -> Control:
	var c: Control = marks.get(id)
	if c and is_instance_valid(c) and c.is_visible_in_tree():
		return c
	return null


# ---------------------------------------------------------------- Construction

func _build_crosshair() -> void:
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func() -> void:
		var on := game.player.aimed != null
		if on:
			_cross.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, Color(0, 0, 0, 0.35), 5.0, true)
			_cross.draw_arc(Vector2.ZERO, 11.0, 0, TAU, 32, UIKit.ACCENT, 2.5, true)
			_cross.draw_circle(Vector2.ZERO, 2.5, UIKit.ACCENT)
		else:
			_cross.draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.35))
			_cross.draw_circle(Vector2.ZERO, 2.6, Color(1, 1, 1, 0.85)))
	_root.add_child(_cross)
	var aim := UIKit.vbox(2)
	aim.set_anchors_preset(Control.PRESET_CENTER)
	aim.offset_left = -420
	aim.offset_right = 420
	aim.offset_top = 30
	aim.offset_bottom = 110
	aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(aim)
	_aim = _label("", 23, UIKit.TEXT, 700)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim.add_theme_constant_override("outline_size", 8)
	_aim.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	aim.add_child(_aim)
	_aim_verb = _label("", 18, UIKit.ACCENT, 600)
	_aim_verb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim_verb.add_theme_constant_override("outline_size", 7)
	_aim_verb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	aim.add_child(_aim_verb)


func _build_header() -> void:
	var col := UIKit.vbox(12)
	col.position = Vector2(28, 26)
	col.custom_minimum_size.x = 440
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(col)
	if Story.is_tutorial():
		col.z_index = 2  # la consigne reste lisible au-dessus des panneaux (chariot, dossier)
	var head := UIKit.panel(UIKit.PANEL, 16, 20)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var hv := UIKit.vbox(6)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hv)
	var top := UIKit.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(top)
	var tag := "ENTRAÎNEMENT"
	if Story.active:
		tag = "TUTORIEL · PATIENT 1 / 3" if Story.is_tutorial() else "PATIENT %d / 3" % (Story.chapter + 1)
	_head_chip = UIKit.chip(tag, Color(UIKit.RED, 0.9), Color.WHITE, 13)
	top.add_child(_head_chip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	top.add_child(UIKit.icon("clock", 20, UIKit.TEXT_DIM))
	_clock = _label("00:00", 22, UIKit.TEXT, 700)
	top.add_child(_clock)
	var pr: Dictionary = game.case.profile
	hv.add_child(_label("%s, %d ans" % [String(pr["name"]).split(" ")[0], pr["age"]], 28, UIKit.TEXT, 800))
	hv.add_child(_label(game.case.name, 18, UIKit.TEXT_DIM, 500))
	# À faire
	_tasks = UIKit.panel(UIKit.PANEL, 16, 20)
	_tasks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_tasks)
	mark("tasks", _tasks)
	_tasks_body = UIKit.vbox(8)
	_tasks_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks.add_child(_tasks_body)


func _build_vitals() -> void:
	_vitals = UIKit.panel(Color(0.03, 0.045, 0.065, 0.88), 16, 18)
	_vitals.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vitals.offset_left = -404
	_vitals.offset_right = -28
	_vitals.offset_top = 26
	_vitals.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vitals)
	mark("vitals", _vitals)
	var v := UIKit.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vitals.add_child(v)
	var top := UIKit.hbox(8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UIKit.icon("ecg", 22, UIKit.ACCENT))
	top.add_child(UIKit.caption("Constantes du patient", UIKit.ACCENT, 14))
	for k in ["FC", "SpO2", "PNI", "FR"]:
		var info: Array = Lexique.VITALS[k]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIKit.flat(Color(1, 1, 1, 0.04), 10, 10))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		var h := UIKit.hbox(12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var ic := UIKit.icon(info[3], 30, UIKit.TEXT_FAINT)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var names := UIKit.vbox(0)
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(names)
		names.add_child(_label(info[0], 20, UIKit.TEXT, 600))
		var sub := _label(info[1], 14, UIKit.TEXT_FAINT, 500)
		names.add_child(sub)
		var val := _label("--", 34, UIKit.TEXT_FAINT, 800)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(val)
		var unit := _label(info[2], 15, UIKit.TEXT_FAINT, 500)
		unit.custom_minimum_size.x = 48
		unit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(unit)
		_vit[k] = {"icon": ic, "value": val, "unit": unit, "sub": sub, "row": row}
	_vit_hint = UIKit.para("", 16, UIKit.TEXT_DIM, 330.0, 500)
	_vit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_vit_hint)


func _build_toasts() -> void:
	_toasts = UIKit.vbox(8)
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.offset_left = -560
	_toasts.offset_right = -28
	_toasts.offset_top = 470
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)


func _build_progress() -> void:
	_progress = ProgressBar.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER)
	_progress.offset_left = -170
	_progress.offset_right = 170
	_progress.offset_top = 74
	_progress.offset_bottom = 84
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.visible = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_progress)
	_progress_lbl = _label("", 19, UIKit.TEXT, 700)
	_progress_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_progress_lbl.offset_left = -360
	_progress_lbl.offset_right = 360
	_progress_lbl.offset_top = 90
	_progress_lbl.offset_bottom = 120
	_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_lbl.add_theme_constant_override("outline_size", 7)
	_progress_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_progress_lbl.visible = false
	_root.add_child(_progress_lbl)


func _build_zone() -> void:
	_zone_bar = UIKit.hbox(12)
	_zone_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_bar.offset_left = -300
	_zone_bar.offset_right = 300
	_zone_bar.offset_top = 26
	_zone_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_zone_bar.visible = false
	_root.add_child(_zone_bar)
	_zone_title = UIKit.chip("", Color(0.04, 0.06, 0.085, 0.9), UIKit.ACCENT, 22)
	(_zone_title.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_left = 22
	(_zone_title.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_right = 22
	(_zone_title.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_top = 10
	(_zone_title.get_theme_stylebox("normal") as StyleBoxFlat).content_margin_bottom = 11
	_zone_bar.add_child(_zone_title)
	var back := UIKit.button("Revenir  (Échap)", 220)
	back.custom_minimum_size.y = 48
	back.pressed.connect(func() -> void: game.zone_view.exit())
	_zone_bar.add_child(back)
	_zone_hint_box = PanelContainer.new()
	_zone_hint_box.add_theme_stylebox_override("panel", UIKit.flat(Color(0.02, 0.03, 0.045, 0.82), 14, 18))
	_zone_hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_zone_hint_box.offset_left = -640
	_zone_hint_box.offset_right = 640
	_zone_hint_box.offset_top = -186
	_zone_hint_box.offset_bottom = -132
	_zone_hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_zone_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_hint_box.visible = false
	_root.add_child(_zone_hint_box)
	_zone_hint = _label("", 20, UIKit.TEXT, 500)
	_zone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_hint_box.add_child(_zone_hint)


func _build_hotbar() -> void:
	_hotbar = UIKit.hbox(8)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -700
	_hotbar.offset_right = 700
	_hotbar.offset_top = -118
	_hotbar.offset_bottom = -24
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_hotbar)
	refresh_hotbar()


func _build_keys() -> void:
	_keys_box = PanelContainer.new()
	_keys_box.add_theme_stylebox_override("panel", UIKit.flat(Color(0.03, 0.045, 0.065, 0.78), 12, 12))
	_keys_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys_box.offset_left = 28
	_keys_box.offset_top = -74
	_keys_box.offset_bottom = -28
	_keys_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_keys_box)
	_keys = UIKit.hbox(8)
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_box.add_child(_keys)
	for kv in [["E", "Utiliser"], ["T", "Parler"], ["Tab", "Dossier"], ["O", "Liste"], ["Échap", "Pause"]]:
		_keys.add_child(UIKit.key(kv[0], 15))
		_keys.add_child(_label(kv[1], 16, UIKit.TEXT_DIM, 500))
		_keys.add_child(UIKit.spacer(0, 6))


func refresh_hotbar() -> void:
	if _hotbar == null:
		return
	for c in _hotbar.get_children():
		c.queue_free()
	var inv := game.inv
	for i in inv.items.size():
		var it: Dictionary = inv.items[i]
		var id: String = it["id"]
		var sel := i == inv.selected
		var b := Button.new()
		b.custom_minimum_size = Vector2(132, 90)
		b.focus_mode = Control.FOCUS_NONE
		var st := UIKit.box(Color(0.12, 0.36, 0.34, 0.94) if sel else Color(0.04, 0.06, 0.085, 0.86), 12, UIKit.ACCENT if sel else Color(1, 1, 1, 0.08), 2 if sel else 1, 8)
		st.shadow_size = 8
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", UIKit.box(Color(0.1, 0.22, 0.24, 0.94), 12, UIKit.ACCENT_DIM, 2, 8))
		b.add_theme_stylebox_override("pressed", st)
		var v := UIKit.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -8
		v.offset_top = 6
		v.offset_bottom = -6
		b.add_child(v)
		var num := _label(str(i + 1), 14, UIKit.ACCENT if sel else UIKit.TEXT_FAINT, 800)
		v.add_child(num)
		var nm := Lexique.item_name(id, inv.label(i))
		var uses := int(it["uses"])
		if int(Inventory.ITEMS[id]["uses"]) > 1:
			nm += " (%d)" % uses
		var l := _label(nm, 15, Color.WHITE if sel else UIKit.TEXT, 600 if sel else 500)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 112
		l.max_lines_visible = 3
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(l)
		UIKit.pass_mouse(v)
		var idx := i
		b.pressed.connect(func() -> void: inv.select(idx))
		_hotbar.add_child(b)
		mark("hotbar:" + id, b)


func zone_mode(on: bool) -> void:
	zone = on
	_zone_bar.visible = on
	_zone_hint_box.visible = on
	_cross.visible = not on
	_aim.visible = not on
	_aim_verb.visible = not on
	if on:
		_zone_title.text = game.zone_view.title


# ---------------------------------------------------------------- Messages

func toast(text: String, ok := true) -> void:
	text = Lexique.simple(text)
	var col := UIKit.OK if ok else UIKit.WARN
	var p := PanelContainer.new()
	var sb := UIKit.box(Color(0.04, 0.06, 0.085, 0.92), 12, Color(col, 0.35), 1, 14)
	sb.border_width_left = 5
	sb.border_color = Color(col, 0.9)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIKit.hbox(12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := UIKit.icon("check" if ok else "warn", 22, col)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var l := _label(text, 19, UIKit.TEXT, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 450
	h.add_child(l)
	_toasts.add_child(p)
	UIKit.pop_in(p)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(6.5)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)
	if not ok:
		Sfx.play("erreur", Vector3.INF, -22.0, 1.3)


## Une réplique (patient, infirmière) : bulle avec portrait.
func say(text: String, who := "patient") -> void:
	if game.dialogue:
		game.dialogue.bark({"ide": "sophie", "infirmiere": "sophie"}.get(who, who), text)


func set_progress(v: float, label: String) -> void:
	_progress.visible = v > 0.0
	_progress_lbl.visible = v > 0.0
	_progress.value = v
	_progress_lbl.text = Lexique.simple(label)


# ---------------------------------------------------------------- Mise à jour

func _process(delta: float) -> void:
	if not visible:
		return
	var t := game.physio.time
	_clock.text = UIKit.fmt_time(t)
	_cross.queue_redraw()
	var a := game.player.aimed
	_aim.text = Lexique.simple(a.label) if a else ""
	_aim_verb.text = ("Clic  ·  %s" % a.verb) if a else ""
	if zone:
		_zone_hint.text = Lexique.simple(game.gestures.hint)
		_zone_hint_box.visible = _zone_hint.text != ""
	_keys_box.visible = Settings.show_hints and not zone
	_tasks_t -= delta
	if _tasks_t <= 0.0:
		_tasks_t = 0.25
		_refresh_tasks()
	_update_vitals(delta)


func _update_vitals(delta: float) -> void:
	var m := game.monitor
	var ph := game.physio
	var ecg := m.has_ecg()
	var spo := m.has_spo2()
	var cuff := m.has_cuff()
	var vals := {}
	if ecg:
		vals["FC"] = ["FV" if ph.rhythm == "fv" else ("0" if ph.in_arrest() else str(int(ph.hr))), 2 if ph.in_arrest() else Lexique.severity("FC", ph.hr)]
	elif spo and ph.pulse():
		vals["FC"] = [str(int(ph.hr)), Lexique.severity("FC", ph.hr)]
	if spo:
		vals["SpO2"] = [str(int(ph.spo2)), Lexique.severity("SpO2", ph.spo2)] if ph.pulse() and ph.spo2 > 30.0 else ["?", 1]
	if cuff and m.nibp != Vector2.ZERO:
		vals["PNI"] = ["%d/%d" % [int(m.nibp.x), int(m.nibp.y)], Lexique.severity("PNI", m.nibp.x, m.nibp.y)]
	elif cuff:
		vals["PNI"] = ["…", 0]
	if ecg:
		vals["FR"] = [str(int(ph.rr)), Lexique.severity("FR", ph.rr)] if not ph.in_arrest() else ["0", 2]
	var blink := 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.012)
	_beat = maxf(0.0, _beat - delta * 4.0)
	if vals.has("FC") and ph.pulse():
		var period := 60.0 / maxf(ph.hr, 20.0)
		if fmod(ph.time, period) < delta * 1.5:
			_beat = 1.0
	for k in _vit:
		var e: Dictionary = _vit[k]
		var lv: Label = e["value"]
		var ic: UIIcon = e["icon"]
		if vals.has(k):
			var sev: int = vals[k][1]
			var col := Lexique.severity_color(sev)
			lv.text = vals[k][0]
			(e["unit"] as Label).modulate.a = 1.0
			lv.add_theme_color_override("font_color", col)
			lv.modulate.a = blink if sev == 2 else 1.0
			ic.color = col
			(e["sub"] as Label).text = "%s · %s" % [Lexique.VITALS[k][1], Lexique.severity_text(sev)]
			(e["sub"] as Label).add_theme_color_override("font_color", Color(col, 0.85))
			var row: PanelContainer = e["row"]
			row.add_theme_stylebox_override("panel", UIKit.flat(Color(col, 0.13 if sev == 2 else (0.08 if sev == 1 else 0.05)), 10, 10))
		else:
			lv.text = "--"
			(e["unit"] as Label).modulate.a = 0.0
			lv.add_theme_color_override("font_color", UIKit.TEXT_FAINT)
			lv.modulate.a = 1.0
			ic.color = UIKit.TEXT_FAINT
			(e["sub"] as Label).text = "%s · pas de capteur" % Lexique.VITALS[k][1]
			(e["sub"] as Label).add_theme_color_override("font_color", UIKit.TEXT_FAINT)
			(e["row"] as PanelContainer).add_theme_stylebox_override("panel", UIKit.flat(Color(1, 1, 1, 0.035), 10, 10))
		if k == "FC":
			ic.pulse = _beat
			ic.queue_redraw()
	if vals.is_empty():
		_vit_hint.text = "Rien n'est branché. Au chariot, onglet « Surveillance » : électrodes du scope, pince à oxygène, brassard."
	elif not (ecg and spo and cuff):
		var miss := []
		if not ecg:
			miss.append("électrodes")
		if not spo:
			miss.append("pince à oxygène")
		if not cuff:
			miss.append("brassard")
		_vit_hint.text = "Manque : " + ", ".join(miss)
	else:
		_vit_hint.text = ""
	_vit_hint.visible = _vit_hint.text != ""


## Liste « À faire » : étape du tutoriel, ou objectifs du cas cochés au fur et à mesure.
func _refresh_tasks() -> void:
	_tasks.visible = not tasks_hidden
	if tasks_hidden:
		return
	var guide: Guide = game.guide
	var data := guide.tasks() if guide else {}
	var sig := ""
	if data.get("mode", "") == "tutorial":
		sig = "T%d|%s" % [data["index"], data["title"]]
	else:
		var objs := game.case.objectives()
		for o in objs:
			sig += "%s%d" % [o[0], 1 if o[2] else 0]
		data = {"mode": "objectives", "list": objs}
	if sig == _tasks_sig:
		return
	_tasks_sig = sig
	for c in _tasks_body.get_children():
		c.queue_free()
	if data["mode"] == "tutorial":
		var top := UIKit.hbox(8)
		_tasks_body.add_child(top)
		top.add_child(UIKit.icon("target", 18, UIKit.WARN))
		top.add_child(UIKit.caption("Tutoriel  ·  étape %d / %d" % [int(data["index"]) + 1, data["count"]], UIKit.WARN, 14))
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(400, 6)
		pb.max_value = float(data["count"])
		pb.value = float(data["index"])
		pb.add_theme_stylebox_override("fill", UIKit.flat(UIKit.WARN, 3, 0))
		_tasks_body.add_child(pb)
		_tasks_body.add_child(UIKit.spacer(2))
		var tl := UIKit.para(data["title"], 26, UIKit.TEXT, 400.0, 800)
		_tasks_body.add_child(tl)
		_tasks_body.add_child(UIKit.para(data["text"], 19, Color(0.86, 0.9, 0.94), 400.0, 450))
		var keys: Array = data.get("keys", [])
		if not keys.is_empty():
			var kr := UIKit.hbox(6)
			_tasks_body.add_child(kr)
			for k in keys:
				kr.add_child(UIKit.key(k, 16))
		if data.get("next", "") != "":
			_tasks_body.add_child(UIKit.spacer(4))
			_tasks_body.add_child(UIKit.rule())
			var nx := UIKit.para("Ensuite : " + String(data["next"]), 16, UIKit.TEXT_FAINT, 400.0, 500)
			_tasks_body.add_child(nx)
		UIKit.pop_in(_tasks, 0.3)
		Sfx.play("etape", Vector3.INF, -20.0)
	else:
		var top2 := UIKit.hbox(8)
		_tasks_body.add_child(top2)
		top2.add_child(UIKit.icon("list", 18, UIKit.ACCENT))
		top2.add_child(UIKit.caption("À faire", UIKit.ACCENT, 14))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top2.add_child(sp)
		var objs2: Array = data["list"]
		var n_done := 0
		for o in objs2:
			if o[2]:
				n_done += 1
		top2.add_child(_label("%d / %d" % [n_done, objs2.size()], 15, UIKit.TEXT_DIM, 700))
		for o in objs2:
			var row := UIKit.hbox(10)
			_tasks_body.add_child(row)
			var done: bool = o[2]
			var ic := UIKit.icon("check" if done else "dot", 20, UIKit.OK if done else Color(1, 1, 1, 0.25))
			if not done:
				ic.kind = "ring"
			ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(ic)
			var l := UIKit.para(o[0], 17, UIKit.TEXT_FAINT if done else UIKit.TEXT, 370.0, 500)
			row.add_child(l)
	UIKit.pass_mouse(_tasks_body)


# ---------------------------------------------------------------- Clavier

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_9 and game.state == "play":
			game.inv.select(kc - KEY_1)
			get_viewport().set_input_as_handled()
		elif kc == KEY_O and game.state == "play" and _panel == null:
			tasks_hidden = not tasks_hidden
			_tasks_sig = ""
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Panneaux

func any_panel_open() -> bool:
	return _panel != null


func close_panels() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	if not game.zone_view.active and game.state == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		game.player.enabled = true


func _open(p: Control) -> void:
	if _panel:
		_panel.queue_free()
	_panel = p
	_panel_host.add_child(p)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.player.enabled = false
	UIKit.pop_in(p, 0.2)


## Fenêtre : fond assombri, panneau centré, titre avec icône, bouton Fermer.
func _frame(title: String, icon_kind: String, w := 1100.0, h := 760.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.02, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p := UIKit.panel(UIKit.PANEL_SOLID, 20, 28)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, h)
	# En tutoriel, la fenêtre se décale à droite pour laisser la consigne visible
	var shift := 0.0
	if Story.is_tutorial():
		var half := _root.size.x * 0.5
		shift = clampf(500.0 - (half - w * 0.5), 0.0, maxf(0.0, half - 12.0 - w * 0.5))
	p.offset_left = -w * 0.5 + shift
	p.offset_top = -h * 0.5
	p.offset_right = w * 0.5 + shift
	p.offset_bottom = h * 0.5
	dim.add_child(p)
	var v := UIKit.vbox(16)
	p.add_child(v)
	var top := UIKit.hbox(14)
	v.add_child(top)
	var ic := UIKit.icon(icon_kind, 30, UIKit.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var tl := UIKit.text(title, 30, UIKit.TEXT, 800)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	var close := UIKit.button("Fermer  (Échap)", 210)
	close.pressed.connect(close_panels)
	top.add_child(close)
	v.add_child(UIKit.rule())
	return [dim, v]


## Barre d'onglets (boutons à bascule).
func _tabs(names: Array, prefix: String, on_tab: Callable) -> HBoxContainer:
	var row := UIKit.hbox(6)
	var group := ButtonGroup.new()
	for n in names:
		var b := UIKit.button(n, 0)
		b.custom_minimum_size = Vector2(0, 48)
		b.toggle_mode = true
		b.button_group = group
		b.add_theme_font_size_override("font_size", 18)
		var tname: String = n
		b.pressed.connect(func() -> void: on_tab.call(tname))
		row.add_child(b)
		mark(prefix + tname, b)
	(row.get_child(0) as Button).button_pressed = true
	return row


func _select_tab(row: HBoxContainer, idx: int) -> void:
	(row.get_child(idx) as Button).button_pressed = true


# ---- Chariot d'urgence

const CART := {
	"Surveillance": ["electrodes", "spo2", "brassard", "pads"],
	"Perfusion": ["garrot", "antiseptique", "catheter18", "catheter20", "tubes", "perfuseur"],
	"Respiration": ["bavu", "masque_o2", "lunettes_o2"],
	"Examen": ["glucometre", "thermometre"],
	"Massage": ["lucas"],
}
const CART_TABS := ["Surveillance", "Perfusion", "Respiration", "Médicaments", "Aérosol", "Examen", "Massage"]


func open_cart(which: String) -> void:
	var fr := _frame("Chariot d'urgence" if which == "chariot" else "Armoire de matériel", "plus", 1240, 820)
	var v: VBoxContainer = fr[1]
	var info := UIKit.para("Prends ce dont tu as besoin : 9 objets en main au plus (touches 1 à 9). Les médicaments se préparent en seringue : produit, dose, voie.", 18, UIKit.TEXT_DIM, 1180.0)
	v.add_child(info)
	var body := UIKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var status := _label("", 19, UIKit.OK, 600)
	var show_tab := func(tab: String) -> void:
		for c in body.get_children():
			c.queue_free()
		if tab == "Médicaments":
			_drug_prep(body, status)
			return
		if tab == "Aérosol":
			_neb_prep(body, status)
			return
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		body.add_child(grid)
		for id in CART[tab]:
			grid.add_child(_item_card(id, status))
	var tabs := _tabs(CART_TABS, "cart:tab:", show_tab)
	v.add_child(tabs)
	v.add_child(body)
	v.add_child(status)
	show_tab.call("Surveillance")
	_open(fr[0])


func _item_card(id: String, status: Label) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(580, 84)
	b.focus_mode = Control.FOCUS_ALL
	var h := UIKit.hbox(14)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20
	h.offset_right = -16
	b.add_child(h)
	var tv := UIKit.vbox(2)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UIKit.text(Lexique.item_name(id), 21, UIKit.TEXT, 700))
	tv.add_child(UIKit.text(Lexique.item_desc(id), 16, UIKit.TEXT_DIM, 450))
	var got := game.inv.has(id)
	var state := UIKit.text("En main ✔" if got else "Prendre", 16, UIKit.OK if got else UIKit.ACCENT, 700)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(state)
	UIKit.pass_mouse(h)
	b.disabled = got
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void:
		if game.inv.full():
			status.text = "Tu as les mains pleines (9 objets) : utilise quelque chose d'abord"
			status.add_theme_color_override("font_color", UIKit.BAD)
		elif game.inv.add(id):
			status.text = "Pris : " + Lexique.item_name(id)
			status.add_theme_color_override("font_color", UIKit.OK)
			b.disabled = true
			state.text = "En main ✔"
			state.add_theme_color_override("font_color", UIKit.OK)
			Sfx.play("prise", Vector3.INF, -10.0))
	mark("cart:item:" + id, b)
	return b


func _drug_prep(body: VBoxContainer, status: Label) -> void:
	var row := UIKit.hbox(24)
	body.add_child(row)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(sc)
	var list := UIKit.vbox(6)
	list.custom_minimum_size.x = 540
	sc.add_child(list)
	var right := UIKit.vbox(14)
	right.custom_minimum_size.x = 580
	row.add_child(right)
	right.add_child(UIKit.caption("Dose", UIKit.TEXT_DIM))
	var doses := UIKit.hbox(8)
	right.add_child(doses)
	mark("cart:dose", doses)
	right.add_child(UIKit.caption("Voie", UIKit.TEXT_DIM))
	var routes := UIKit.hbox(8)
	right.add_child(routes)
	mark("cart:route", routes)
	right.add_child(UIKit.spacer(6))
	var sel := {"drug": "", "dose": 0.0, "route": ""}
	var summary := UIKit.para("Choisis un produit dans la liste", 23, UIKit.TEXT, 560.0, 700)
	right.add_child(summary)
	var purpose := UIKit.para("", 17, UIKit.TEXT_DIM, 560.0)
	right.add_child(purpose)
	var prep := UIKit.button("Préparer la seringue", 560, true)
	prep.disabled = true
	right.add_child(prep)
	mark("cart:prep", prep)
	var upd := func() -> void:
		var ready: bool = sel["drug"] != "" and sel["dose"] > 0.0 and sel["route"] != ""
		summary.text = "%s %s — %s" % [Drugs.name_of(sel["drug"]), Drugs.dose_text(sel["drug"], sel["dose"]), Lexique.route(sel["route"]).to_lower()] if ready else ("Choisis la dose et la voie" if sel["drug"] != "" else "Choisis un produit dans la liste")
		prep.disabled = not ready
	var group := ButtonGroup.new()
	for id in Drugs.LIST:
		var d: Dictionary = Drugs.LIST[id]
		if d["routes"] == ["NEB"] or d["routes"] == ["PERF"]:
			continue
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(530, 64)
		var h := UIKit.hbox(12)
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -12
		b.add_child(h)
		var sw := ColorRect.new()
		sw.color = d["col"]
		sw.custom_minimum_size = Vector2(6, 36)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(sw)
		var tv := UIKit.vbox(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tv)
		tv.add_child(UIKit.text(d["name"], 19, UIKit.TEXT, 700))
		tv.add_child(UIKit.text(Lexique.DRUG_INFO.get(id, d["pres"]), 15, UIKit.TEXT_DIM, 450))
		UIKit.pass_mouse(h)
		mark("cart:drug:" + id, b)
		list.add_child(b)
		var did: String = id
		b.pressed.connect(func() -> void:
			sel["drug"] = did
			sel["dose"] = 0.0
			sel["route"] = ""
			purpose.text = "%s · %s" % [Lexique.DRUG_INFO.get(did, ""), d["pres"]]
			for c in doses.get_children():
				c.queue_free()
			for c in routes.get_children():
				c.queue_free()
			var dg := ButtonGroup.new()
			for dv in d["doses"]:
				var db := UIKit.button(Drugs.dose_text(did, dv), 120)
				db.toggle_mode = true
				db.button_group = dg
				db.pressed.connect(func() -> void:
					sel["dose"] = dv
					upd.call())
				doses.add_child(db)
				mark("cart:dose:%s" % Drugs.dose_text(did, dv), db)
			var rg := ButtonGroup.new()
			for r in d["routes"]:
				var rb := UIKit.button(Lexique.route(r), 230)
				rb.toggle_mode = true
				rb.button_group = rg
				rb.pressed.connect(func() -> void:
					sel["route"] = r
					upd.call())
				routes.add_child(rb)
				mark("cart:route:" + r, rb)
			upd.call())
	prep.pressed.connect(func() -> void:
		var label := Drugs.label(sel["drug"], sel["dose"], sel["route"])
		var name := "Seringue : " + label
		if game.inv.add("seringue", {"drug": sel["drug"], "dose": sel["dose"], "route": sel["route"], "name": name}):
			status.text = "Seringue prête : " + Lexique.simple(label) + ". Elle est dans tes mains (barre du bas)."
			status.add_theme_color_override("font_color", UIKit.OK)
			game.event("preparation", "Seringue préparée : " + label)
			Sfx.play("prise", Vector3.INF, -10.0)
		else:
			status.text = "Tu as les mains pleines"
			status.add_theme_color_override("font_color", UIKit.BAD))


func _neb_prep(body: VBoxContainer, status: Label) -> void:
	body.add_child(UIKit.para("Masque d'aérosol : le médicament est respiré. Il se branche sur l'oxygène, ouvert à 6-8 L/min au débitmètre mural.", 19, UIKit.TEXT_DIM, 1100.0))
	var checks := []
	for e in [["salbutamol", 5.0], ["salbutamol", 2.5], ["ipratropium", 0.5]]:
		var c := CheckBox.new()
		c.text = "  %s %s — %s" % [Drugs.name_of(e[0]), Drugs.dose_text(e[0], e[1]), Lexique.DRUG_INFO.get(e[0], "")]
		c.add_theme_font_size_override("font_size", 20)
		body.add_child(c)
		checks.append([c, e])
	var b := UIKit.button("Préparer l'aérosol", 520, true)
	body.add_child(b)
	b.pressed.connect(func() -> void:
		var ds := []
		var names := []
		for ce in checks:
			if (ce[0] as CheckBox).button_pressed:
				ds.append(ce[1])
				names.append("%s %s" % [Drugs.name_of(ce[1][0]), Drugs.dose_text(ce[1][0], ce[1][1])])
		if ds.is_empty():
			status.text = "Coche au moins un produit"
			status.add_theme_color_override("font_color", UIKit.BAD)
			return
		var nm := "Aérosol : " + ", ".join(names)
		if game.inv.add("nebuliseur", {"drugs": ds, "name": nm}):
			status.text = "Prêt : " + nm
			status.add_theme_color_override("font_color", UIKit.OK))


# ---- Poste informatique

func open_computer() -> void:
	var fr := _frame("Dossier de %s, %d ans" % [String(game.case.profile["name"]).split(" ")[0], game.case.profile["age"]], "book", 1400, 860)
	var v: VBoxContainer = fr[1]
	var body := UIKit.vbox(12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var show := func(tab: String) -> void:
		for c in body.get_children():
			c.queue_free()
		match tab:
			"Dossier":
				_tab_dossier(body)
			"Examens":
				_tab_exams(body)
			"Résultats":
				_tab_results(body)
			"Conclusion":
				_tab_conclusion(body)
	var tabs := _tabs(["Dossier", "Examens", "Résultats", "Conclusion"], "comp:tab:", show)
	v.add_child(tabs)
	v.add_child(body)
	show.call("Dossier")
	_open(fr[0])


func _scroll(body: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(1340, 620)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var v := UIKit.vbox(10)
	v.custom_minimum_size.x = 1310
	sc.add_child(v)
	return v


func _tab_dossier(body: VBoxContainer) -> void:
	var v := _scroll(body)
	v.add_child(UIKit.caption("Transmission à l'arrivée"))
	v.add_child(UIKit.para(game.case.arrival, 19, UIKit.TEXT, 1290.0))
	v.add_child(UIKit.para(Lexique.simple(game.case.arrival_vitals), 19, UIKit.WARN, 1290.0, 600))
	v.add_child(UIKit.spacer(8))
	v.add_child(UIKit.caption("Ce qui a été fait et constaté"))
	var notes := game.journal.notes()
	if notes.is_empty():
		v.add_child(UIKit.text("Rien de noté pour l'instant.", 19, UIKit.TEXT_DIM))
	for e in notes:
		var h := UIKit.hbox(16)
		v.add_child(h)
		var tl := UIKit.text(UIKit.fmt_time(e["t"]), 18, UIKit.ACCENT, 700)
		tl.custom_minimum_size.x = 70
		h.add_child(tl)
		h.add_child(UIKit.para(Lexique.simple(e["text"]), 18, UIKit.TEXT, 1200.0))


func _tab_exams(body: VBoxContainer) -> void:
	body.add_child(UIKit.para("Analyses de sang : il faut d'abord une prise de sang (tubes, sur le cathéter). Les résultats arrivent en quelques minutes dans l'onglet Résultats.", 18, UIKit.TEXT_DIM, 1300.0))
	var status := _label("", 19, UIKit.OK, 600)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for ex in Labs.BIO + ["radio"]:
		var b := UIKit.button(Lexique.lab_name(ex), 430)
		b.add_theme_font_size_override("font_size", 18)
		var exam: String = ex
		b.disabled = game.journal.has("exam:" + exam)
		b.pressed.connect(func() -> void:
			var r := game.order_exam(exam)
			status.text = r
			if game.journal.has("exam:" + exam):
				b.disabled = true)
		grid.add_child(b)
	body.add_child(status)


func _tab_results(body: VBoxContainer) -> void:
	var v := _scroll(body)
	if game.results.is_empty() and game.lab_pending.is_empty():
		v.add_child(UIKit.text("Aucun résultat pour l'instant.", 19, UIKit.TEXT_DIM))
	for r in game.results:
		var card := UIKit.panel(UIKit.CARD, 12, 16)
		v.add_child(card)
		var cv := UIKit.vbox(4)
		card.add_child(cv)
		cv.add_child(UIKit.text("%s   ·   %s" % [Lexique.lab_name(r[0]), UIKit.fmt_time(r[2])], 19, UIKit.ACCENT, 700))
		cv.add_child(UIKit.para(r[1], 19, UIKit.TEXT, 1260.0))
	for p in game.lab_pending:
		v.add_child(UIKit.text("En attente : %s…" % Lexique.lab_name(p[0]), 18, UIKit.WARN, 600))
	var ecg := game.journal.last("ecg12")
	if not ecg.is_empty():
		var b := UIKit.button("Revoir l'ECG", 300)
		b.pressed.connect(func() -> void: show_ecg(ecg["data"], game.flags.get("ecg12_bad", [])))
		v.add_child(b)


func _tab_conclusion(body: VBoxContainer) -> void:
	body.add_child(UIKit.para("Dernière étape : qu'est-ce qu'il a, et où doit-il aller ? Valider termine la prise en charge.", 19, UIKit.TEXT_DIM, 1300.0))
	body.add_child(UIKit.caption("Diagnostic : ce qu'il a"))
	var diag := OptionButton.new()
	diag.add_theme_font_size_override("font_size", 20)
	diag.custom_minimum_size = Vector2(1000, 54)
	diag.add_item("— choisir —")
	for d in Case.DIAGNOSES:
		diag.add_item(Lexique.diag(d))
	body.add_child(diag)
	mark("comp:diag", diag)
	body.add_child(UIKit.spacer(4))
	body.add_child(UIKit.caption("Orientation : où il va"))
	var orient := OptionButton.new()
	orient.add_theme_font_size_override("font_size", 20)
	orient.custom_minimum_size = Vector2(1000, 54)
	orient.add_item("— choisir —")
	for o in Case.ORIENTATIONS:
		orient.add_item(Lexique.orient(o))
	body.add_child(orient)
	mark("comp:orient", orient)
	var warn := _label("", 18, UIKit.TEXT_DIM, 500)
	body.add_child(UIKit.spacer(6))
	var ok := UIKit.button("Valider et terminer", 420, true)
	ok.pressed.connect(func() -> void:
		if diag.selected <= 0 or orient.selected <= 0:
			warn.text = "Choisis un diagnostic et une orientation"
			warn.add_theme_color_override("font_color", UIKit.BAD)
			return
		close_panels()
		game.conclude(Case.DIAGNOSES[diag.selected - 1], Case.ORIENTATIONS[orient.selected - 1]))
	body.add_child(ok)
	mark("comp:ok", ok)
	body.add_child(warn)


# ---- Interrogatoire

func open_dialogue() -> void:
	var fr := _frame("Parler à %s" % String(game.case.profile["name"]).split(" ")[0], "chat", 1040, 620)
	var v: VBoxContainer = fr[1]
	var qs: Array = game.case.questions
	if not game.physio.speaks:
		v.add_child(UIKit.para("Il ne peut pas te répondre pour l'instant.", 22, UIKit.TEXT_DIM, 980.0))
	elif qs.is_empty():
		v.add_child(UIKit.para("Il est trop gêné pour te répondre longuement. Soigne-le d'abord.", 22, UIKit.TEXT_DIM, 980.0))
	else:
		v.add_child(UIKit.para("Choisis une question : sa réponse s'affiche en bas de l'écran et est notée dans le dossier.", 18, UIKit.TEXT_DIM, 980.0))
		for i in qs.size():
			var b := UIKit.button("« %s »" % qs[i][0], 980)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var idx := i
			b.pressed.connect(func() -> void:
				game.ask(idx)
				b.disabled = true)
			v.add_child(b)
			mark("question:%d" % i, b)
	_open(fr[0])


# ---- ECG et imagerie

func show_ecg(e: Dictionary, bad: Array) -> void:
	var fr := _frame("Électrocardiogramme (ECG 12 dérivations)", "ecg", 1640, 920)
	var v: VBoxContainer = fr[1]
	var paper := EcgPaper.new()
	paper.data = e
	paper.bad = bad
	paper.custom_minimum_size = Vector2(1580, 680)
	v.add_child(paper)
	v.add_child(UIKit.para("Lecture automatique : " + String(e.get("text", "")), 19, UIKit.TEXT, 1560.0))
	_open(fr[0])


func show_image(tex: Texture2D, text: String) -> void:
	var fr := _frame("Imagerie", "info", 1200, 860)
	var v: VBoxContainer = fr[1]
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(1140, 640)
	v.add_child(tr)
	v.add_child(UIKit.para(text, 19, UIKit.TEXT, 1140.0))
	_open(fr[0])
