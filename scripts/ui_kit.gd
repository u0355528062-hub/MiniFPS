class_name UIKit
## Charte graphique de l'interface : panneaux bleu nuit translucides à coins arrondis, accent
## turquoise « hôpital », rouge urgence pour le logo, police Inter (variable : graisses 400 à 800).
## Fabrique de libellés, boutons (principal / secondaire / discret), panneaux, pastilles et icônes.
## Toutes les tailles sont données pour une fenêtre de référence 1920 × 1080 (mise à l'échelle
## automatique en 1600 × 900 et 1280 × 720).

const ACCENT := Color(0.25, 0.86, 0.79)
const ACCENT_DIM := Color(0.25, 0.86, 0.79, 0.35)
const ACCENT_DARK := Color(0.04, 0.2, 0.2)
const RED := Color(0.96, 0.27, 0.31)
const OK := Color(0.38, 0.87, 0.53)
const BAD := Color(1.0, 0.4, 0.4)
const WARN := Color(1.0, 0.75, 0.3)
const INFO := Color(0.45, 0.7, 1.0)
const TEXT := Color(0.95, 0.97, 0.98)
const TEXT_DIM := Color(0.68, 0.74, 0.8)
const TEXT_FAINT := Color(0.46, 0.52, 0.58)
const PANEL := Color(0.05, 0.07, 0.095, 0.86)
const PANEL_SOLID := Color(0.055, 0.07, 0.095, 0.97)
const CARD := Color(1, 1, 1, 0.045)
const LINE := Color(1, 1, 1, 0.09)

static var _font: Font
static var _weights := {}
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Inter.ttf")
	return _font


## Police Inter à la graisse voulue (400 normal, 500 medium, 600 semi-gras, 700 gras, 800 extra-gras).
static func weight(w: int) -> Font:
	if not _weights.has(w):
		var fv := FontVariation.new()
		fv.base_font = font()
		var ts := TextServerManager.get_primary_interface()
		fv.variation_opentype = {ts.name_to_tag("wght"): w}
		_weights[w] = fv
	return _weights[w]


static func bold() -> Font:
	return weight(700)


static func semibold() -> Font:
	return weight(600)


static func box(bg: Color, radius := 12, border := LINE, border_w := 1, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.8
	s.content_margin_bottom = pad * 0.8
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 4)
	s.anti_aliasing = true
	return s


static func flat(bg: Color, radius := 10, pad := 10) -> StyleBoxFlat:
	var s := box(bg, radius, Color(0, 0, 0, 0), 0, pad)
	s.shadow_size = 0
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = weight(450)
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT)
	# Boutons (secondaires par défaut ; le bouton principal a son propre style)
	var normal := box(Color(1, 1, 1, 0.06), 10, Color(1, 1, 1, 0.1), 1, 18)
	var hover := box(Color(0.25, 0.86, 0.79, 0.16), 10, ACCENT, 2, 18)
	var pressed := box(Color(0.25, 0.86, 0.79, 0.28), 10, ACCENT, 2, 18)
	var focus := box(Color(0, 0, 0, 0), 10, Color(0.25, 0.86, 0.79, 0.7), 2, 18)
	var disabled := box(Color(1, 1, 1, 0.025), 10, Color(1, 1, 1, 0.05), 1, 18)
	for st in [normal, hover, pressed, focus, disabled]:
		st.shadow_size = 0
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_FAINT)
	t.set_font("font", "Button", semibold())
	t.set_font_size("font_size", "Button", 20)
	# Curseurs
	var track := flat(Color(1, 1, 1, 0.12), 4, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := flat(ACCENT, 4, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(22, Color.WHITE))
	t.set_icon("grabber_highlight", "HSlider", _dot(24, ACCENT))
	# Interrupteurs
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(s, "CheckButton", StyleBoxEmpty.new())
		t.set_stylebox(s, "CheckBox", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", _switch(true))
	t.set_icon("unchecked", "CheckButton", _switch(false))
	t.set_font_size("font_size", "CheckButton", 19)
	t.set_font_size("font_size", "CheckBox", 19)
	t.set_color("font_color", "CheckBox", TEXT)
	# Listes déroulantes
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_font("font", "OptionButton", weight(500))
	t.set_stylebox("panel", "PopupMenu", box(PANEL_SOLID, 10, ACCENT_DIM, 1, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("hover", "PopupMenu", flat(Color(0.25, 0.86, 0.79, 0.16), 6, 6))
	t.set_font_size("font_size", "PopupMenu", 19)
	t.set_constant("v_separation", "PopupMenu", 10)
	# Listes
	t.set_stylebox("panel", "ItemList", box(Color(0, 0, 0, 0.25), 10, LINE, 1, 8))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", flat(Color(0.25, 0.86, 0.79, 0.22), 8, 6))
	t.set_stylebox("selected_focus", "ItemList", flat(Color(0.25, 0.86, 0.79, 0.3), 8, 6))
	t.set_stylebox("hovered", "ItemList", flat(Color(1, 1, 1, 0.06), 8, 6))
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_constant("v_separation", "ItemList", 12)
	# Défilement
	var sb := flat(Color(1, 1, 1, 0.04), 4, 0)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", flat(Color(1, 1, 1, 0.2), 4, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(ACCENT_DIM, 4, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(ACCENT, 4, 0))
	# Barres de progression
	t.set_stylebox("background", "ProgressBar", flat(Color(1, 1, 1, 0.1), 6, 0))
	t.set_stylebox("fill", "ProgressBar", flat(ACCENT, 6, 0))
	_theme = t
	return t


static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - 1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return ImageTexture.create_from_image(img)


## Interrupteur (case à cocher) dessiné : pilule turquoise allumée, grise éteinte.
static func _switch(on: bool) -> ImageTexture:
	var w := 52
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := ACCENT if on else Color(1, 1, 1, 0.18)
	var knob_x := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, h * 0.5, w - h * 0.5)
			var d := p.distance_to(Vector2(cx, h * 0.5))
			var a := clampf(h * 0.5 - d, 0.0, 1.0)
			var col := Color(bg.r, bg.g, bg.b, bg.a * a)
			var dk := p.distance_to(Vector2(knob_x, h * 0.5))
			var ka := clampf(h * 0.5 - 3.0 - dk, 0.0, 1.0)
			col = col.lerp(Color(1, 1, 1, 1), ka)
			col.a = maxf(col.a, ka)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 19, color := TEXT, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


## Libellé à la graisse choisie.
static func text(t: String, size := 19, color := TEXT, w := 450) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_override("font", weight(w))
	return l


## Paragraphe qui revient à la ligne, de largeur minimale donnée.
static func para(t: String, size := 19, color := TEXT_DIM, width := 600.0, w := 450) -> Label:
	var l := text(t, size, color, w)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


## Petit titre de section en capitales espacées.
static func caption(t: String, color := ACCENT, size := 14) -> Label:
	var l := text(t.to_upper(), size, color, 700)
	l.add_theme_constant_override("outline_size", 0)
	return l


## Pastille (texte court sur fond coloré).
static func chip(t: String, bg: Color, fg := Color(0.03, 0.05, 0.06), size := 14) -> Label:
	var l := text(t, size, fg, 700)
	var sb := flat(bg, 999, 10)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


## Touche du clavier dessinée (« Échap », « T », « Tab »…).
static func key(t: String, size := 15) -> Label:
	var l := text(t, size, TEXT, 700)
	var sb := box(Color(1, 1, 1, 0.1), 6, Color(1, 1, 1, 0.22), 1, 8)
	sb.shadow_size = 0
	sb.border_width_bottom = 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


static func panel(bg := PANEL, radius := 14, pad := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, LINE, 1, pad))
	return p


## Bouton : principal (plein, turquoise) ou secondaire (verre).
static func button(t: String, min_w := 280, primary := false) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(min_w, 54)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		style_primary(b)
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void: Sfx.play("clic", Vector3.INF, -12.0, 1.0))
	return b


static func style_primary(b: Button) -> void:
	var n := box(ACCENT, 10, Color(0, 0, 0, 0), 0, 18)
	n.shadow_color = Color(0.25, 0.86, 0.79, 0.25)
	n.shadow_size = 14
	n.shadow_offset = Vector2.ZERO
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(0.45, 0.95, 0.88)
	h.shadow_size = 22
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = Color(0.2, 0.7, 0.65)
	var f := n.duplicate() as StyleBoxFlat
	f.border_color = Color.WHITE
	f.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0.02, 0.09, 0.09))
	b.add_theme_font_override("font", bold())


## Bouton discret (texte seul, souligné au survol).
static func link(t: String, size := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_font_override("font", weight(500))
	b.add_theme_color_override("font_color", TEXT_DIM)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	b.mouse_entered.connect(func() -> void: Sfx.play("survol", Vector3.INF, -22.0, 1.6))
	b.pressed.connect(func() -> void: Sfx.play("clic", Vector3.INF, -12.0, 1.0))
	return b


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func spacer(h := 10.0, w := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Filet horizontal.
static func rule(alpha := 0.09) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, alpha)
	r.custom_minimum_size.y = 1
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func icon(kind: String, size := 24.0, color := TEXT) -> UIIcon:
	var i := UIIcon.new()
	i.kind = kind
	i.color = color
	i.custom_minimum_size = Vector2(size, size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Rend un arbre de contrôles transparent à la souris (libellés dans un bouton…).
static func pass_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		pass_mouse(c)


## Fondu d'apparition d'un élément.
static func pop_in(c: Control, dur := 0.25) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]


## Couleur d'une note (S, A, B, C, D).
static func grade_color(g: String) -> Color:
	return {"S": Color(1.0, 0.82, 0.3), "A": OK, "B": ACCENT, "C": WARN, "D": BAD}.get(g, TEXT)
