class_name DialogueBox
extends CanvasLayer
## Boîte de dialogue en bas de l'écran : portrait dessiné, nom et rôle, texte qui s'écrit, clic /
## Espace / Entrée pour continuer (le premier appui termine la phrase), choix de réponse (1-3).
##   var choix := await dialogue.play([{"who": "sophie", "text": "…"}, {"who": "moi", "text": "…",
##       "choices": [{"text": "Oui", "id": "oui", "reply": [{…}]}, …]}])
## Mode « bulle » (bark) : une réplique courte qui ne bloque pas le jeu (patient, infirmière…).
## En autotest, tout défile tout seul (premier choix).

signal _advance
signal _chosen(i: int)

## Personnages : id -> nom, rôle, couleurs du portrait
const CAST := {
	"sophie": {"name": "Sophie", "role": "Infirmière", "accent": Color(0.42, 0.72, 1.0),
		"skin": Color(0.96, 0.8, 0.7), "hair": Color(0.32, 0.18, 0.1), "cloth": Color(0.27, 0.5, 0.82), "style": "chignon"},
	"marchand": {"name": "Dr Marchand", "role": "Médecin sénior", "accent": Color(1.0, 0.75, 0.35),
		"skin": Color(0.9, 0.72, 0.6), "hair": Color(0.72, 0.72, 0.74), "cloth": Color(0.95, 0.96, 0.97), "style": "court", "glasses": true, "coat": true},
	"moi": {"name": "Toi", "role": "Interne de garde", "accent": UIKit.ACCENT,
		"skin": Color(0.93, 0.76, 0.64), "hair": Color(0.12, 0.09, 0.07), "cloth": Color(0.3, 0.62, 0.55), "style": "court"},
	"patient": {"name": "Patient", "role": "Patient", "accent": Color(1.0, 0.9, 0.7),
		"skin": Color(0.95, 0.8, 0.72), "hair": Color(0.3, 0.22, 0.15), "cloth": Color(0.7, 0.8, 0.88), "style": "court", "gown": true},
	"famille": {"name": "Famille", "role": "Accompagnant", "accent": Color(0.85, 0.75, 1.0),
		"skin": Color(0.95, 0.82, 0.74), "hair": Color(0.5, 0.35, 0.2), "cloth": Color(0.55, 0.45, 0.7), "style": "long"},
	"narrateur": {"name": "", "role": "", "accent": UIKit.TEXT_DIM},
}

var auto := false  ## autotest : défile seul
var active := false
var patient_profile := {}  ## nom et couleurs du patient du cas en cours

var _root: Control
var _box: PanelContainer
var _portrait: Portrait
var _name: Label
var _role: Label
var _text: Label
var _more: Label
var _choices: VBoxContainer
var _skip: Button
var _shade: TextureRect
var _bark: PanelContainer
var _bark_portrait: Portrait
var _bark_name: Label
var _bark_text: Label
var _bark_t := 0.0
var _typing: Tween
var _skip_all := false
var _portrait_on := true
var _bark_portrait_on := true


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	# Dégradé sombre en bas d'écran pour la lisibilité
	_shade = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0.01, 0.02, 0.0))
	g.add_point(0.5, Color(0, 0.01, 0.02, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0, 0.01, 0.02, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_shade.texture = gt
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)  # tout l'écran : un clic n'importe où fait avancer
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_click)
	_root.add_child(_shade)
	# Boîte principale
	_box = PanelContainer.new()
	var sb := UIKit.box(Color(0.045, 0.06, 0.085, 0.95), 18, Color(1, 1, 1, 0.1), 1, 0)
	sb.content_margin_left = 214
	sb.content_margin_right = 34
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.45)
	_box.add_theme_stylebox_override("panel", sb)
	_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_box.custom_minimum_size = Vector2(1280, 236)
	_box.offset_left = -640
	_box.offset_right = 640
	_box.offset_top = -280
	_box.offset_bottom = -44
	_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.gui_input.connect(_on_click)
	_root.add_child(_box)
	var v := UIKit.vbox(10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(v)
	var head := UIKit.hbox(14)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_name = UIKit.text("", 27, UIKit.ACCENT, 800)
	head.add_child(_name)
	_role = UIKit.chip("", Color(1, 1, 1, 0.1), UIKit.TEXT_DIM, 15)
	head.add_child(_role)
	_text = UIKit.para("", 25, UIKit.TEXT, 1020.0, 450)
	_text.add_theme_constant_override("line_spacing", 6)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)
	_more = UIKit.text("Cliquer ou Espace pour continuer  ▸", 16, UIKit.TEXT_FAINT, 600)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_more)
	# Portrait qui dépasse au-dessus de la boîte
	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(176, 176)
	_portrait.size = Vector2(176, 176)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_portrait)
	# Choix
	_choices = UIKit.vbox(10)
	_choices.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_choices.offset_left = 80
	_choices.offset_right = 640
	_choices.offset_bottom = -300
	_choices.offset_top = -300
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_choices)
	# Passer
	_skip = UIKit.link("Passer le dialogue  ⏭", 17)
	_skip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_skip.offset_left = 400
	_skip.offset_right = 640
	_skip.offset_top = -322
	_skip.offset_bottom = -290
	_skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.pressed.connect(func() -> void:
		_skip_all = true
		_advance.emit())
	_root.add_child(_skip)
	# Bulle (non bloquante)
	_bark = PanelContainer.new()
	var bsb := UIKit.box(Color(0.04, 0.055, 0.08, 0.9), 16, Color(1, 1, 1, 0.08), 1, 0)
	bsb.content_margin_left = 112
	bsb.content_margin_right = 26
	bsb.content_margin_top = 14
	bsb.content_margin_bottom = 16
	_bark.add_theme_stylebox_override("panel", bsb)
	_bark.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bark.offset_left = -470
	_bark.offset_right = 470
	_bark.offset_top = -330
	_bark.offset_bottom = -200
	_bark.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bark)
	var bv := UIKit.vbox(4)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bark.add_child(bv)
	_bark_name = UIKit.text("", 19, UIKit.ACCENT, 800)
	bv.add_child(_bark_name)
	_bark_text = UIKit.para("", 22, UIKit.TEXT, 790.0, 450)
	bv.add_child(_bark_text)
	_bark_portrait = Portrait.new()
	_bark_portrait.custom_minimum_size = Vector2(88, 88)
	_bark_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bark_portrait)
	_set_visible(false)
	_bark.visible = false


func _set_visible(on: bool) -> void:
	_box.visible = on
	_shade.visible = on
	_skip.visible = on
	_choices.visible = on


func _process(delta: float) -> void:
	# Le portrait est placé à gauche de la boîte, dépassant en haut
	_portrait.visible = _box.visible and _portrait_on
	_bark_portrait.visible = _bark.visible and _bark_portrait_on
	if _box.visible:
		_portrait.position = _box.position + Vector2(24, -34)
		_portrait.size = Vector2(170, 170)
		_more.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006) if _text.visible_ratio >= 1.0 and _choices.get_child_count() == 0 else 0.0
		_portrait.talking = _text.visible_ratio < 1.0
	if _bark.visible:
		_bark_portrait.position = _bark.position + Vector2(14, 14)
		_bark_portrait.size = Vector2(84, 84)
		_bark_portrait.modulate.a = _bark.modulate.a
		_bark_t -= delta
		if _bark_t <= 0.0:
			_bark.visible = false
		elif _bark_t < 0.4:
			_bark.modulate.a = _bark_t / 0.4


func _cast(who: String) -> Dictionary:
	var c: Dictionary = CAST.get(who, CAST["narrateur"]).duplicate()
	if who == "patient" and not patient_profile.is_empty():
		c["name"] = String(patient_profile.get("name", "Patient")).split(" ")[0]
		c["role"] = "Patient, %d ans" % int(patient_profile.get("age", 50))
		c["skin"] = (patient_profile.get("skin", c["skin"]) as Color).darkened(0.05)
		c["hair"] = patient_profile.get("hair", c["hair"])
		c["bald"] = float(patient_profile.get("bald", 0.0))
	return c


## Joue une suite de répliques ; rend la liste des identifiants des choix faits.
func play(lines: Array) -> Array:
	var picked: Array = []
	active = true
	_skip_all = false
	_set_visible(true)
	UIKit.pop_in(_box, 0.2)
	await _play_lines(lines, picked)
	_set_visible(false)
	active = false
	return picked


func _play_lines(lines: Array, picked: Array) -> void:
	for ln in lines:
		var line: Dictionary = ln
		var choices: Array = line.get("choices", [])
		if _skip_all and choices.is_empty():
			continue
		var who: String = line.get("who", "narrateur")
		var c := _cast(who)
		_name.text = c["name"]
		_name.add_theme_color_override("font_color", c["accent"])
		_role.text = c["role"]
		_role.visible = c["role"] != ""
		_portrait_on = who != "narrateur"
		_portrait.cast = c
		_portrait.queue_redraw()
		var sb := _box.get_theme_stylebox("panel") as StyleBoxFlat
		sb.content_margin_left = 214 if who != "narrateur" else 40
		var txt: String = line.get("text", "")
		_text.text = txt
		_text.add_theme_font_override("font", UIKit.weight(400) if who == "narrateur" else UIKit.weight(450))
		_text.add_theme_color_override("font_color", UIKit.TEXT_DIM if who == "narrateur" else UIKit.TEXT)
		_text.visible_ratio = 0.0
		if _typing:
			_typing.kill()
		var dur := 0.0 if auto else clampf(txt.length() * 0.022, 0.2, 3.5)
		if dur > 0.0:
			_typing = create_tween()
			_typing.tween_property(_text, "visible_ratio", 1.0, dur)
		else:
			_text.visible_ratio = 1.0
		if auto:
			await get_tree().process_frame
		else:
			Sfx.play("survol", Vector3.INF, -20.0, 0.8)
		if choices.is_empty():
			if not auto:
				await _advance
				if _text.visible_ratio < 1.0 and not _skip_all:
					_typing.kill()
					_text.visible_ratio = 1.0
					await _advance
			continue
		# Choix de réponse
		if _typing and not auto:
			await _typing.finished
		_text.visible_ratio = 1.0
		var idx := 0
		if not auto:
			for i in choices.size():
				var ch: Dictionary = choices[i]
				var b := UIKit.button("%d   %s" % [i + 1, ch["text"]], 560)
				b.alignment = HORIZONTAL_ALIGNMENT_LEFT
				b.add_theme_font_size_override("font_size", 21)
				var k := i
				b.pressed.connect(func() -> void: _chosen.emit(k))
				_choices.add_child(b)
				UIKit.pop_in(b, 0.2 + i * 0.08)
			(_choices.get_child(0) as Button).grab_focus.call_deferred()
			idx = await _chosen
			for b in _choices.get_children():
				b.queue_free()
		var chosen: Dictionary = choices[idx]
		picked.append(chosen.get("id", str(idx)))
		_skip_all = false
		var said := {"who": "moi", "text": chosen.get("say", chosen["text"])}
		var reply: Array = [said] + chosen.get("reply", [])
		await _play_lines(reply, picked)


func _on_click(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _choices.get_child_count() == 0:
			_advance.emit()
		get_viewport().set_input_as_handled()


func _input(ev: InputEvent) -> void:
	if not active or not _box.visible:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).physical_keycode
		if _choices.get_child_count() > 0:
			if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _choices.get_child_count():
				_chosen.emit(k - KEY_1)
				get_viewport().set_input_as_handled()
			return
		if k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			_advance.emit()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()


## Réplique courte qui ne bloque pas (sous-titre avec portrait).
func bark(who: String, text: String, dur := 0.0) -> void:
	var c := _cast(who)
	_bark_name.text = c["name"] if c["name"] != "" else ""
	_bark_name.add_theme_color_override("font_color", c["accent"])
	_bark_text.text = text
	_bark_portrait.cast = c
	_bark_portrait_on = who != "narrateur"
	_bark_portrait.queue_redraw()
	_bark.visible = true
	_bark.modulate.a = 1.0
	UIKit.pop_in(_bark, 0.2)
	_bark_t = dur if dur > 0.0 else 4.5 + text.length() * 0.045


func hide_bark() -> void:
	_bark.visible = false


## Portrait dessiné (style illustration plate) : fond rond, épaules, visage, cheveux, yeux qui
## clignent, bouche qui bouge quand il parle, lunettes et blouse pour le médecin.
class Portrait:
	extends Control
	var cast := {}
	var talking := false
	var _t := 0.0
	var _blink := 3.0

	func _process(delta: float) -> void:
		_t += delta
		_blink -= delta
		if _blink < -0.12:
			_blink = randf_range(2.0, 4.5)
		if visible:
			queue_redraw()

	func _draw() -> void:
		if cast.is_empty() or not cast.has("skin"):
			return
		var s := minf(size.x, size.y)
		var c := Vector2(s, s) * 0.5
		var acc: Color = cast.get("accent", UIKit.ACCENT)
		# Fond
		draw_circle(c, s * 0.5, Color(0.08, 0.11, 0.15))
		draw_circle(c, s * 0.47, acc.darkened(0.55))
		draw_circle(c + Vector2(0, -s * 0.06), s * 0.36, Color(acc.darkened(0.4), 0.6))
		var skin: Color = cast["skin"]
		var hair: Color = cast["hair"]
		var cloth: Color = cast["cloth"]
		var style: String = cast.get("style", "court")
		# Cheveux longs derrière
		if style == "long":
			_ellipse(c + Vector2(0, s * 0.02), Vector2(s * 0.24, s * 0.3), hair)
		# Épaules (masquées par le cercle)
		var sh := PackedVector2Array()
		for i in 25:
			var a := PI + PI * i / 24.0
			sh.append(c + Vector2(cos(a) * s * 0.36, s * 0.5 + sin(a) * s * 0.2))
		_clip_poly(sh, c, s * 0.47, cloth)
		if cast.get("coat", false):
			# Blouse ouverte sur une chemise bleue
			_clip_poly(PackedVector2Array([c + Vector2(-s * 0.08, s * 0.3), c + Vector2(s * 0.08, s * 0.3), c + Vector2(s * 0.04, s * 0.5), c + Vector2(-s * 0.04, s * 0.5)]), c, s * 0.47, Color(0.45, 0.6, 0.85))
			draw_line(c + Vector2(-s * 0.08, s * 0.3), c + Vector2(-s * 0.02, s * 0.47), Color(0.75, 0.78, 0.8), 2.0, true)
			draw_line(c + Vector2(s * 0.08, s * 0.3), c + Vector2(s * 0.02, s * 0.47), Color(0.75, 0.78, 0.8), 2.0, true)
			# Stéthoscope autour du cou
			draw_arc(c + Vector2(0, s * 0.3), s * 0.13, 0.2, PI - 0.2, 16, Color(0.15, 0.17, 0.2), 3.0, true)
		elif cast.get("gown", false):
			for k in 3:
				draw_circle(c + Vector2(-s * 0.16 + k * s * 0.16, s * 0.42), s * 0.025, Color(cloth.darkened(0.25)))
		else:
			# Encolure en V de la tenue
			_clip_poly(PackedVector2Array([c + Vector2(-s * 0.07, s * 0.3), c + Vector2(s * 0.07, s * 0.3), c + Vector2(0, s * 0.4)]), c, s * 0.47, skin.darkened(0.08))
		# Cou
		draw_rect(Rect2(c + Vector2(-s * 0.055, s * 0.12), Vector2(s * 0.11, s * 0.18)), skin.darkened(0.1))
		# Tête
		_ellipse(c + Vector2(0, -s * 0.02), Vector2(s * 0.17, s * 0.21), skin)
		# Oreilles
		_ellipse(c + Vector2(-s * 0.17, s * 0.0), Vector2(s * 0.03, s * 0.045), skin.darkened(0.06))
		_ellipse(c + Vector2(s * 0.17, s * 0.0), Vector2(s * 0.03, s * 0.045), skin.darkened(0.06))
		# Cheveux
		var bald := float(cast.get("bald", 0.0))
		var top := PackedVector2Array()
		var span := PI * (1.0 - bald * 0.5)
		for i in 21:
			var a2 := PI + (PI - span) * 0.5 + span * i / 20.0
			top.append(c + Vector2(cos(a2) * s * 0.185, -s * 0.03 + sin(a2) * s * 0.215))
		if bald < 0.5:
			top.append(c + Vector2(s * 0.16, -s * 0.07))
			top.append(c + Vector2(s * 0.05, -s * 0.13))
			top.append(c + Vector2(-s * 0.12, -s * 0.1))
			top.append(c + Vector2(-s * 0.17, -s * 0.02))
			draw_colored_polygon(top, hair)
		else:
			_ellipse(c + Vector2(-s * 0.16, -s * 0.04), Vector2(s * 0.035, s * 0.07), hair)
			_ellipse(c + Vector2(s * 0.16, -s * 0.04), Vector2(s * 0.035, s * 0.07), hair)
		if style == "chignon":
			draw_circle(c + Vector2(s * 0.02, -s * 0.25), s * 0.075, hair)
		if style == "long":
			_ellipse(c + Vector2(-s * 0.17, s * 0.06), Vector2(s * 0.05, s * 0.14), hair)
			_ellipse(c + Vector2(s * 0.17, s * 0.06), Vector2(s * 0.05, s * 0.14), hair)
		# Yeux (clignent)
		var eye_h := s * 0.022 if _blink > 0.0 else s * 0.004
		for sd in [-1.0, 1.0]:
			var ep := c + Vector2(sd * s * 0.065, -s * 0.01)
			_ellipse(ep, Vector2(s * 0.018, eye_h), Color(0.12, 0.1, 0.1))
			draw_line(ep + Vector2(-s * 0.03, -s * 0.045), ep + Vector2(s * 0.03, -s * 0.05 + sd * 0.0), hair.darkened(0.2), maxf(2.0, s * 0.014), true)
		if cast.get("glasses", false):
			for sd2 in [-1.0, 1.0]:
				draw_arc(c + Vector2(sd2 * s * 0.068, -s * 0.008), s * 0.045, 0, TAU, 24, Color(0.15, 0.15, 0.18), maxf(1.5, s * 0.011), true)
			draw_line(c + Vector2(-s * 0.023, -s * 0.012), c + Vector2(s * 0.023, -s * 0.012), Color(0.15, 0.15, 0.18), maxf(1.5, s * 0.01), true)
		# Nez, joues, bouche (qui bouge en parlant)
		draw_line(c + Vector2(0, s * 0.01), c + Vector2(-s * 0.012, s * 0.06), skin.darkened(0.2), maxf(1.5, s * 0.01), true)
		draw_circle(c + Vector2(-s * 0.1, s * 0.06), s * 0.025, Color(1.0, 0.5, 0.5, 0.18))
		draw_circle(c + Vector2(s * 0.1, s * 0.06), s * 0.025, Color(1.0, 0.5, 0.5, 0.18))
		var open := (0.5 + 0.5 * sin(_t * 22.0)) * s * 0.022 if talking else 0.0
		if open > s * 0.004:
			_ellipse(c + Vector2(0, s * 0.11), Vector2(s * 0.035, open), Color(0.35, 0.12, 0.12))
		else:
			draw_arc(c + Vector2(0, s * 0.085), s * 0.04, 0.35, PI - 0.35, 12, Color(0.45, 0.2, 0.2), maxf(1.5, s * 0.012), true)
		# Liseré
		draw_arc(c, s * 0.485, 0, TAU, 64, Color(acc, 0.9), maxf(2.0, s * 0.02), true)

	func _ellipse(p: Vector2, r: Vector2, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			pts.append(p + Vector2(cos(a) * r.x, sin(a) * r.y))
		draw_colored_polygon(pts, col)

	## Polygone limité au disque du portrait.
	func _clip_poly(poly: PackedVector2Array, c: Vector2, r: float, col: Color) -> void:
		var circle := PackedVector2Array()
		for i in 48:
			var a := TAU * i / 48.0
			circle.append(c + Vector2(cos(a), sin(a)) * r)
		for part in Geometry2D.intersect_polygons(poly, circle):
			draw_colored_polygon(part, col)
