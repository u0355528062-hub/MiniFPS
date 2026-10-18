class_name ERHud
extends CanvasLayer
## Interface en jeu : viseur et ce qu'il désigne, objets en main (1 à 9), chrono, constantes du scope
## (si branché), sous-titres (patient, infirmière), messages, barre de progression des gestes,
## aide de la vue rapprochée ; panneaux : chariot d'urgence (préparation des seringues), poste
## informatique (dossier, examens, résultats, conclusion), interrogatoire, ECG, imagerie.

var game: ERGame
var _root: Control
var _cross: Control
var _aim: Label
var _clock: Label
var _title: Label
var _help: Label
var _vitals: PanelContainer
var _vit_labels := {}
var _hotbar: HBoxContainer
var _toasts: VBoxContainer
var _sub: PanelContainer
var _sub_lbl: Label
var _sub_t := 0.0
var _progress: ProgressBar
var _progress_lbl: Label
var _zone_top: Label
var _zone_hint: Label
var _zone_back: Button
var _panel_host: Control
var _panel: Control
var zone := false


func build() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	# Viseur
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(func() -> void:
		var on := game.player.aimed != null
		_cross.draw_circle(Vector2.ZERO, 6.0 if on else 3.0, Color(1, 1, 1, 0.9) if on else Color(1, 1, 1, 0.6), false, 2.0 if on else -1.0, true))
	_root.add_child(_cross)
	_aim = _label("", 22, UIKit.TEXT, true)
	_aim.set_anchors_preset(Control.PRESET_CENTER)
	_aim.position = Vector2(-400, 24)
	_aim.size = Vector2(800, 60)
	_aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aim.add_theme_constant_override("outline_size", 6)
	_aim.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_root.add_child(_aim)
	# En-tête : cas, patient, chrono
	var head := UIKit.panel(UIKit.PANEL, 10, 14)
	head.position = Vector2(24, 20)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(head)
	var hv := UIKit.vbox(2)
	head.add_child(hv)
	_title = _label("%s — %s, %d ans" % [game.case.name, game.case.profile["name"], game.case.profile["age"]], 20, UIKit.TEXT, true)
	hv.add_child(_title)
	_clock = _label("00:00", 34, UIKit.ACCENT, true)
	hv.add_child(_clock)
	_help = _label("Clic / E : utiliser · T : parler au patient · Tab : dossier · 1-9 : objet en main · Échap : pause", 15, UIKit.TEXT_DIM)
	hv.add_child(_help)
	# Constantes (si le scope est branché)
	_vitals = UIKit.panel(Color(0.01, 0.02, 0.03, 0.82), 10, 12)
	_vitals.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_vitals.position = Vector2(-260, 20)
	_vitals.custom_minimum_size = Vector2(236, 0)
	_vitals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_vitals)
	var vg := GridContainer.new()
	vg.columns = 2
	vg.add_theme_constant_override("h_separation", 18)
	_vitals.add_child(vg)
	for k in [["FC", Color(0.3, 1.0, 0.45)], ["SpO2", Color(0.3, 0.85, 1.0)], ["PNI", Color(1, 0.45, 0.45)], ["FR", Color(1.0, 0.85, 0.25)]]:
		vg.add_child(_label(k[0], 16, k[1]))
		var v := _label("--", 28, k[1], true)
		vg.add_child(v)
		_vit_labels[k[0]] = v
	# Messages
	_toasts = UIKit.vbox(8)
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.position = Vector2(-600, 220)
	_toasts.custom_minimum_size = Vector2(576, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	# Sous-titres
	_sub = UIKit.panel(Color(0.0, 0.0, 0.0, 0.62), 10, 14)
	_sub.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub.position = Vector2(-520, -250)
	_sub.custom_minimum_size = Vector2(1040, 0)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.visible = false
	_root.add_child(_sub)
	_sub_lbl = _label("", 24, UIKit.TEXT)
	_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_child(_sub_lbl)
	# Progression d'un geste
	_progress = ProgressBar.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER)
	_progress.position = Vector2(-160, 70)
	_progress.size = Vector2(320, 10)
	_progress.show_percentage = false
	_progress.max_value = 1.0
	_progress.visible = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress.add_theme_stylebox_override("background", UIKit.box(Color(0, 0, 0, 0.5), 5, Color(0, 0, 0, 0), 0, 0))
	_progress.add_theme_stylebox_override("fill", UIKit.box(UIKit.ACCENT, 5, Color(0, 0, 0, 0), 0, 0))
	_root.add_child(_progress)
	_progress_lbl = _label("", 18, UIKit.TEXT, true)
	_progress_lbl.set_anchors_preset(Control.PRESET_CENTER)
	_progress_lbl.position = Vector2(-300, 86)
	_progress_lbl.size = Vector2(600, 30)
	_progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_lbl.visible = false
	_root.add_child(_progress_lbl)
	# Vue rapprochée : titre, aide, retour
	_zone_top = _label("", 26, UIKit.ACCENT, true)
	_zone_top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_zone_top.position = Vector2(-400, 22)
	_zone_top.size = Vector2(800, 40)
	_zone_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_top.visible = false
	_root.add_child(_zone_top)
	_zone_hint = _label("", 20, UIKit.TEXT)
	_zone_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_zone_hint.position = Vector2(-700, -150)
	_zone_hint.size = Vector2(1400, 40)
	_zone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone_hint.add_theme_constant_override("outline_size", 6)
	_zone_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_zone_hint.visible = false
	_root.add_child(_zone_hint)
	_zone_back = UIKit.button("◀  Revenir (Échap)", 240)
	_zone_back.position = Vector2(24, 190)
	_zone_back.visible = false
	_zone_back.pressed.connect(func() -> void: game.zone_view.exit())
	_root.add_child(_zone_back)
	# Objets en main
	_hotbar = UIKit.hbox(8)
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.position = Vector2(-700, -100)
	_hotbar.custom_minimum_size = Vector2(1400, 80)
	_hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(_hotbar)
	refresh_hotbar()
	# Panneaux
	_panel_host = Control.new()
	_panel_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_host)


func _label(t: String, size: int, c: Color, b := false) -> Label:
	var l := UIKit.label(t, size, c, b)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh_hotbar() -> void:
	if _hotbar == null:
		return
	for c in _hotbar.get_children():
		c.queue_free()
	var inv := game.inv
	for i in inv.items.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(136, 72)
		b.text = "%d\n%s" % [i + 1, inv.label(i)]
		b.add_theme_font_size_override("font_size", 15)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		var sel := i == inv.selected
		b.add_theme_stylebox_override("normal", UIKit.box(Color(0.1, 0.32, 0.32, 0.92) if sel else Color(0.04, 0.07, 0.09, 0.78), 8, UIKit.ACCENT if sel else Color(1, 1, 1, 0.08), 2 if sel else 1, 8))
		var idx := i
		b.pressed.connect(func() -> void: inv.select(idx))
		_hotbar.add_child(b)


func zone_mode(on: bool) -> void:
	zone = on
	_zone_top.visible = on
	_zone_hint.visible = on
	_zone_back.visible = on
	_cross.visible = not on
	_aim.visible = not on
	if on:
		_zone_top.text = game.zone_view.title


func toast(text: String, ok := true) -> void:
	var p := UIKit.panel(Color(0.04, 0.12, 0.1, 0.88) if ok else Color(0.18, 0.05, 0.05, 0.9), 8, 12)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, 19, UIKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 540
	p.add_child(l)
	_toasts.add_child(p)
	UIKit.pop_in(p)
	while _toasts.get_child_count() > 5:
		_toasts.get_child(0).queue_free()
		_toasts.remove_child(_toasts.get_child(0))
	var tw := p.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func say(text: String, who := "patient") -> void:
	var name := "Patient" if who == "patient" else ("Infirmière" if who == "ide" else "")
	_sub_lbl.text = ("%s : « %s »" % [name, text]) if name != "" else text
	_sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8) if who == "patient" else Color(0.75, 0.95, 1.0))
	_sub.visible = true
	_sub_t = 5.0 + text.length() * 0.04


func set_progress(v: float, label: String) -> void:
	# En vue rapprochée, la barre passe en bas de l'écran (elle ne cache pas le geste)
	var dy := maxf(70.0, _root.size.y * 0.5 - 170.0) if zone else 70.0
	_progress.position.y = dy
	_progress_lbl.position.y = dy + 16.0
	_progress.visible = v > 0.0
	_progress_lbl.visible = v > 0.0
	_progress.value = v
	_progress_lbl.text = label


func _process(delta: float) -> void:
	if not visible:
		return
	var t := game.physio.time
	_clock.text = UIKit.fmt_time(t)
	_cross.queue_redraw()
	var a := game.player.aimed
	_aim.text = ("%s\nClic : %s" % [a.label, a.verb]) if a else ""
	if zone:
		var h := game.gestures.hint
		_zone_hint.text = h
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			_sub.visible = false
	# Constantes : seulement ce que mesurent les capteurs
	var m := game.monitor
	var ph := game.physio
	_vitals.visible = m.has_ecg() or m.has_spo2() or m.has_cuff()
	_vit_labels["FC"].text = ("---" if ph.rhythm == "fv" else str(int(ph.hr))) if m.has_ecg() else ("%d" % int(ph.hr) if m.has_spo2() and ph.pulse() else "--")
	_vit_labels["SpO2"].text = ("%d %%" % int(ph.spo2)) if m.has_spo2() and ph.pulse() and ph.spo2 > 30.0 else "--"
	_vit_labels["PNI"].text = ("%d/%d" % [int(m.nibp.x), int(m.nibp.y)]) if m.has_cuff() and m.nibp != Vector2.ZERO else "--"
	_vit_labels["FR"].text = str(int(ph.rr)) if m.has_ecg() and not ph.in_arrest() else "--"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc >= KEY_1 and kc <= KEY_9:
			game.inv.select(kc - KEY_1)
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
	UIKit.pop_in(p)


func _frame(title: String, w := 1100.0, h := 760.0) -> Array:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p := UIKit.panel(UIKit.PANEL_SOLID, 14, 22)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.custom_minimum_size = Vector2(w, h)
	p.position = Vector2(-w * 0.5, -h * 0.5)
	dim.add_child(p)
	var v := UIKit.vbox(14)
	p.add_child(v)
	var top := UIKit.hbox(12)
	v.add_child(top)
	var tl := UIKit.label(title, 30, UIKit.ACCENT, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	var close := UIKit.button("Fermer (Échap)", 200)
	close.pressed.connect(close_panels)
	top.add_child(close)
	return [dim, v]


# ---- Chariot d'urgence

const CART := {
	"Monitorage": [["electrodes", "Électrodes du scope (3)"], ["spo2", "Capteur de SpO2"], ["brassard", "Brassard à tension"], ["pads", "Électrodes de défibrillation (2)"]],
	"Voie veineuse": [["garrot", "Garrot"], ["antiseptique", "Compresses + antiseptique"], ["catheter18", "Cathéter 18G (vert)"], ["catheter20", "Cathéter 20G (rose)"],
		["tubes", "Tubes de prélèvement"], ["perfuseur", "NaCl 0,9 % 500 mL + tubulure"]],
	"Ventilation": [["bavu", "BAVU (ballon autoremplisseur + masque)"], ["masque_o2", "Masque à haute concentration"], ["lunettes_o2", "Lunettes à oxygène"]],
	"Examen": [["glucometre", "Lecteur de glycémie + autopiqueur"], ["thermometre", "Thermomètre tympanique"]],
	"Massage": [["lucas", "LUCAS (massage cardiaque automatique)"]],
}


func open_cart(which: String) -> void:
	var fr := _frame("Chariot d'urgence" if which == "chariot" else "Armoire de matériel", 1200, 800)
	var v: VBoxContainer = fr[1]
	var info := UIKit.label("Prends ce dont tu as besoin (9 objets en main au plus). Médicaments : prépare la seringue (produit, dose, voie).", 18, UIKit.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(info)
	var tabs := UIKit.hbox(8)
	v.add_child(tabs)
	var body := UIKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var status := UIKit.label("", 18, UIKit.OK)
	v.add_child(status)
	var show_tab := func(tab: String) -> void:
		for c in body.get_children():
			c.queue_free()
		if tab == "Médicaments":
			_drug_prep(body, status)
			return
		if tab == "Nébulisation":
			_neb_prep(body, status)
			return
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 12)
		body.add_child(grid)
		for e in CART[tab]:
			var b := UIKit.button(e[1], 540)
			var id: String = e[0]
			b.disabled = game.inv.has(id)
			b.pressed.connect(func() -> void:
				if game.inv.full():
					status.text = "Tu as les mains pleines (9 objets) : pose ou utilise quelque chose"
					status.add_theme_color_override("font_color", UIKit.BAD)
				elif game.inv.add(id):
					status.text = "Pris : " + e[1]
					status.add_theme_color_override("font_color", UIKit.OK)
					b.disabled = true
					Sfx.play("prise", Vector3.INF, -10.0))
			grid.add_child(b)
	for tab in ["Monitorage", "Voie veineuse", "Ventilation", "Médicaments", "Nébulisation", "Examen", "Massage"]:
		var tb := UIKit.button(tab, 150)
		var tname: String = tab
		tb.pressed.connect(func() -> void: show_tab.call(tname))
		tabs.add_child(tb)
	show_tab.call("Monitorage")
	_open(fr[0])


func _drug_prep(body: VBoxContainer, status: Label) -> void:
	var row := UIKit.hbox(16)
	body.add_child(row)
	var drugs := ItemList.new()
	drugs.custom_minimum_size = Vector2(520, 520)
	drugs.add_theme_font_size_override("font_size", 19)
	var ids := []
	for id in Drugs.LIST:
		var d: Dictionary = Drugs.LIST[id]
		if d["routes"] == ["NEB"] or d["routes"] == ["PERF"]:
			continue
		drugs.add_item("%s — %s" % [d["name"], d["pres"]])
		ids.append(id)
	row.add_child(drugs)
	var right := UIKit.vbox(12)
	row.add_child(right)
	right.add_child(UIKit.label("Dose", 20, UIKit.TEXT_DIM))
	var doses := UIKit.hbox(8)
	right.add_child(doses)
	right.add_child(UIKit.label("Voie", 20, UIKit.TEXT_DIM))
	var routes := UIKit.hbox(8)
	right.add_child(routes)
	var sel := {"drug": "", "dose": 0.0, "route": ""}
	var summary := UIKit.label("Choisis un produit", 22, UIKit.TEXT, true)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 520
	right.add_child(summary)
	var prep := UIKit.button("Préparer la seringue", 520)
	prep.disabled = true
	right.add_child(prep)
	var upd := func() -> void:
		summary.text = Drugs.label(sel["drug"], sel["dose"], sel["route"]) if sel["drug"] != "" and sel["dose"] > 0.0 and sel["route"] != "" else "Choisis la dose et la voie"
		prep.disabled = not (sel["drug"] != "" and sel["dose"] > 0.0 and sel["route"] != "")
	drugs.item_selected.connect(func(i: int) -> void:
		sel["drug"] = ids[i]
		sel["dose"] = 0.0
		sel["route"] = ""
		for c in doses.get_children():
			c.queue_free()
		for c in routes.get_children():
			c.queue_free()
		var d: Dictionary = Drugs.LIST[ids[i]]
		for dv in d["doses"]:
			var b := UIKit.button(Drugs.dose_text(ids[i], dv), 120)
			b.toggle_mode = true
			b.pressed.connect(func() -> void:
				sel["dose"] = dv
				for o in doses.get_children():
					(o as Button).button_pressed = o == b
				upd.call())
			doses.add_child(b)
		for r in d["routes"]:
			var rb := UIKit.button(r, 120)
			rb.toggle_mode = true
			rb.pressed.connect(func() -> void:
				sel["route"] = r
				for o in routes.get_children():
					(o as Button).button_pressed = o == rb
				upd.call())
			routes.add_child(rb)
		upd.call())
	prep.pressed.connect(func() -> void:
		var name := "Seringue : " + Drugs.label(sel["drug"], sel["dose"], sel["route"])
		if game.inv.add("seringue", {"drug": sel["drug"], "dose": sel["dose"], "route": sel["route"], "name": name}):
			status.text = "Préparée : " + name
			status.add_theme_color_override("font_color", UIKit.OK)
			game.event("preparation", "Seringue préparée : " + Drugs.label(sel["drug"], sel["dose"], sel["route"]))
			Sfx.play("prise", Vector3.INF, -10.0)
		else:
			status.text = "Tu as les mains pleines"
			status.add_theme_color_override("font_color", UIKit.BAD))


func _neb_prep(body: VBoxContainer, status: Label) -> void:
	body.add_child(UIKit.label("Masque de nébulisation (à brancher sur l'oxygène, 6 à 8 L/min)", 20, UIKit.TEXT_DIM))
	var checks := []
	for e in [["salbutamol", 5.0], ["salbutamol", 2.5], ["ipratropium", 0.5]]:
		var c := CheckButton.new()
		c.text = "%s %s" % [Drugs.name_of(e[0]), Drugs.dose_text(e[0], e[1])]
		body.add_child(c)
		checks.append([c, e])
	var b := UIKit.button("Préparer la nébulisation", 520)
	body.add_child(b)
	b.pressed.connect(func() -> void:
		var ds := []
		var names := []
		for ce in checks:
			if (ce[0] as CheckButton).button_pressed:
				ds.append(ce[1])
				names.append((ce[0] as CheckButton).text)
		if ds.is_empty():
			status.text = "Coche au moins un produit"
			return
		var nm := "Nébulisation : " + ", ".join(names)
		if game.inv.add("nebuliseur", {"drugs": ds, "name": nm}):
			status.text = "Préparée : " + nm
			status.add_theme_color_override("font_color", UIKit.OK))


# ---- Poste informatique

func open_computer() -> void:
	var fr := _frame("Dossier patient — %s, %d ans" % [game.case.profile["name"], game.case.profile["age"]], 1400, 860)
	var v: VBoxContainer = fr[1]
	var tabs := UIKit.hbox(8)
	v.add_child(tabs)
	var body := UIKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
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
	for tab in ["Dossier", "Examens", "Résultats", "Conclusion"]:
		var tb := UIKit.button(tab, 200)
		var tname: String = tab
		tb.pressed.connect(func() -> void: show.call(tname))
		tabs.add_child(tb)
	show.call("Dossier")
	_open(fr[0])


func _scroll(body: VBoxContainer) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(1340, 640)
	body.add_child(sc)
	var v := UIKit.vbox(8)
	v.custom_minimum_size.x = 1300
	sc.add_child(v)
	return v


func _tab_dossier(body: VBoxContainer) -> void:
	var v := _scroll(body)
	v.add_child(UIKit.label("Transmission", 22, UIKit.ACCENT, true))
	var tr := UIKit.label(game.case.arrival + "\n" + game.case.arrival_vitals, 18, UIKit.TEXT)
	tr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tr.custom_minimum_size.x = 1280
	v.add_child(tr)
	v.add_child(UIKit.label("Observations et traitements", 22, UIKit.ACCENT, true))
	var notes := game.journal.notes()
	if notes.is_empty():
		v.add_child(UIKit.label("Rien de noté pour l'instant.", 18, UIKit.TEXT_DIM))
	for e in notes:
		var l := UIKit.label("%s   %s" % [UIKit.fmt_time(e["t"]), e["text"]], 18, UIKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1280
		v.add_child(l)


func _tab_exams(body: VBoxContainer) -> void:
	var info := UIKit.label("Biologie : il faut d'abord prélever des tubes sur le cathéter. Les résultats arrivent en quelques minutes.", 18, UIKit.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(info)
	var status := UIKit.label("", 18, UIKit.OK)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	body.add_child(grid)
	for ex in Labs.BIO + ["radio"]:
		var b := UIKit.button(Labs.NAMES[ex], 420)
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
	if game.results.is_empty():
		v.add_child(UIKit.label("Aucun résultat pour l'instant.", 18, UIKit.TEXT_DIM))
	for r in game.results:
		v.add_child(UIKit.label("%s   %s" % [UIKit.fmt_time(r[2]), Labs.NAMES.get(r[0], r[0])], 20, UIKit.ACCENT, true))
		var l := UIKit.label(r[1], 19, UIKit.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1280
		v.add_child(l)
	for p in game.lab_pending:
		v.add_child(UIKit.label("En attente : %s" % Labs.NAMES.get(p[0], p[0]), 18, UIKit.WARN))
	var ecg := game.journal.last("ecg12")
	if not ecg.is_empty():
		var b := UIKit.button("Revoir l'ECG", 300)
		b.pressed.connect(func() -> void: show_ecg(ecg["data"], game.flags.get("ecg12_bad", [])))
		v.add_child(b)


func _tab_conclusion(body: VBoxContainer) -> void:
	body.add_child(UIKit.label("Diagnostic", 22, UIKit.ACCENT, true))
	var diag := OptionButton.new()
	diag.add_theme_font_size_override("font_size", 20)
	diag.custom_minimum_size = Vector2(900, 50)
	diag.add_item("— choisir —")
	for d in Case.DIAGNOSES:
		diag.add_item(d)
	body.add_child(diag)
	body.add_child(UIKit.label("Orientation", 22, UIKit.ACCENT, true))
	var orient := OptionButton.new()
	orient.add_theme_font_size_override("font_size", 20)
	orient.custom_minimum_size = Vector2(900, 50)
	orient.add_item("— choisir —")
	for o in Case.ORIENTATIONS:
		orient.add_item(o)
	body.add_child(orient)
	var warn := UIKit.label("Valider termine la prise en charge.", 18, UIKit.TEXT_DIM)
	body.add_child(warn)
	var ok := UIKit.button("Valider et transmettre", 420)
	ok.pressed.connect(func() -> void:
		if diag.selected <= 0 or orient.selected <= 0:
			warn.text = "Choisis un diagnostic et une orientation"
			warn.add_theme_color_override("font_color", UIKit.BAD)
			return
		close_panels()
		game.conclude(Case.DIAGNOSES[diag.selected - 1], Case.ORIENTATIONS[orient.selected - 1]))
	body.add_child(ok)


# ---- Interrogatoire

func open_dialogue() -> void:
	var fr := _frame("Parler au patient", 1000, 640)
	var v: VBoxContainer = fr[1]
	var qs: Array = game.case.questions
	if not game.physio.speaks:
		v.add_child(UIKit.label("Il ne peut pas vous répondre.", 22, UIKit.TEXT_DIM))
	elif qs.is_empty():
		v.add_child(UIKit.label("Il est trop gêné pour vous répondre longuement.", 22, UIKit.TEXT_DIM))
	else:
		for i in qs.size():
			var b := UIKit.button(qs[i][0], 940)
			var idx := i
			b.pressed.connect(func() -> void:
				game.ask(idx)
				b.disabled = true)
			v.add_child(b)
	_open(fr[0])


# ---- ECG et imagerie

func show_ecg(e: Dictionary, bad: Array) -> void:
	var fr := _frame("ECG 12 dérivations", 1600, 900)
	var v: VBoxContainer = fr[1]
	var paper := EcgPaper.new()
	paper.data = e
	paper.bad = bad
	paper.custom_minimum_size = Vector2(1540, 680)
	v.add_child(paper)
	var t := UIKit.label("Interprétation automatique : " + String(e.get("text", "")), 19, UIKit.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 1520
	v.add_child(t)
	_open(fr[0])


func show_image(tex: Texture2D, text: String) -> void:
	var fr := _frame("Imagerie", 1200, 860)
	var v: VBoxContainer = fr[1]
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(1140, 660)
	v.add_child(tr)
	var l := UIKit.label(text, 19, UIKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1140
	v.add_child(l)
	_open(fr[0])
