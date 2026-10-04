class_name UIKit
## Charte graphique de l'interface : panneaux sombres translucides à coins arrondis, accent cyan
## « bloc opératoire », police Inter. Fabrique de libellés, boutons, panneaux et curseurs.

const ACCENT := Color(0.22, 0.92, 0.82)
const ACCENT_DIM := Color(0.22, 0.92, 0.82, 0.35)
const OK := Color(0.35, 0.95, 0.55)
const BAD := Color(1.0, 0.36, 0.33)
const WARN := Color(1.0, 0.78, 0.3)
const TEXT := Color(0.93, 0.97, 0.98)
const TEXT_DIM := Color(0.62, 0.71, 0.74)
const PANEL := Color(0.035, 0.06, 0.075, 0.78)
const PANEL_SOLID := Color(0.03, 0.05, 0.065, 0.94)

static var _font: Font
static var _font_bold: FontVariation
static var _theme: Theme


static func font() -> Font:
	if _font == null:
		_font = load("res://assets/fonts/Inter.ttf")
	return _font


static func bold() -> Font:
	if _font_bold == null:
		_font_bold = FontVariation.new()
		_font_bold.base_font = font()
		_font_bold.variation_embolden = 0.6
	return _font_bold


static func box(bg: Color, radius := 10, border := Color(1, 1, 1, 0.07), border_w := 1, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.8
	s.content_margin_bottom = pad * 0.8
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 10
	s.anti_aliasing = true
	return s


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	# Boutons
	var normal := box(Color(0.08, 0.13, 0.16, 0.85), 8, Color(1, 1, 1, 0.08), 1, 16)
	var hover := box(Color(0.12, 0.24, 0.27, 0.95), 8, ACCENT, 2, 16)
	var pressed := box(Color(0.10, 0.34, 0.33, 0.95), 8, ACCENT, 2, 16)
	var focus := box(Color(0, 0, 0, 0), 8, ACCENT, 2, 16)
	for st in [normal, hover, pressed, focus]:
		st.shadow_size = 0
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", normal)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 20)
	# Curseurs
	var track := box(Color(1, 1, 1, 0.1), 4, Color(0, 0, 0, 0), 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(ACCENT_DIM, 4, Color(0, 0, 0, 0), 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _dot(18, ACCENT)
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", _dot(20, Color.WHITE))
	# Cases à cocher
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_font_size("font_size", "CheckButton", 18)
	# Listes déroulantes
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("focus", "OptionButton", focus)
	t.set_stylebox("panel", "PopupMenu", box(PANEL_SOLID, 8, ACCENT_DIM, 1, 8))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_stylebox("hover", "PopupMenu", box(Color(0.12, 0.24, 0.27, 0.95), 6, Color(0, 0, 0, 0), 0, 6))
	t.set_font_size("font_size", "PopupMenu", 18)
	_theme = t
	return t


static func _dot(size: int, c: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var inner := clampf(r - 3.0 - d, 0.0, 1.0)
			var col := c.lerp(Color(0.05, 0.08, 0.1), inner * 0.0)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)


static func label(text: String, size := 18, color := TEXT, is_bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold())
	return l


static func panel(bg := PANEL, radius := 12, pad := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, radius, Color(1, 1, 1, 0.06), 1, pad))
	return p


static func button(text: String, min_w := 280) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.focus_mode = Control.FOCUS_ALL
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


## Fondu d'apparition (et légère montée) d'un élément.
static func pop_in(c: Control, dur := 0.25) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, dur)


static func fmt_time(sec: float) -> String:
	var s := int(sec)
	return "%02d:%02d" % [s / 60, s % 60]
