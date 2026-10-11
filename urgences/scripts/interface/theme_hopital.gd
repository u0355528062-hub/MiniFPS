class_name ThemeHopital
extends RefCounted
## Thème d'interface « hôpital moderne » : panneaux blancs translucides, coins arrondis,
## accent bleu-vert (couleur des urgences), typographie Inter.

const ACCENT := Color("0e8c8c")
const ACCENT_CLAIR := Color("12a5a5")
const TEXTE := Color("1d2b36")
const TEXTE_DOUX := Color("5a6b78")
const FOND := Color(0.97, 0.98, 0.98, 0.94)
const ROUGE := Color("d63031")
const ORANGE := Color("e17b22")
const JAUNE := Color("e8b923")
const VERT := Color("2e9e5b")
const BLEU := Color("2f6fb5")
## Couleurs des niveaux de tri (1 = urgence vitale … 5 = non urgent).
const TRI := {1: Color("c0392b"), 2: Color("e67e22"), 3: Color("f1c40f"), 4: Color("27ae60"), 5: Color("2f80c8")}

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/Inter.ttf")
	t.default_font_size = 18
	t.set_stylebox("panel", "PanelContainer", _boite(FOND, 14, 18))
	t.set_stylebox("panel", "Panel", _boite(FOND, 14, 0))
	for etat in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := ACCENT
		match etat:
			"hover": c = ACCENT_CLAIR
			"pressed": c = ACCENT.darkened(0.2)
			"disabled": c = Color(0.7, 0.74, 0.76)
		var b := _boite(c, 9, 0)
		b.content_margin_left = 16
		b.content_margin_right = 16
		b.content_margin_top = 9
		b.content_margin_bottom = 9
		if etat == "focus":
			b = StyleBoxFlat.new()
			b.draw_center = false
			b.border_color = Color(1, 1, 1, 0.8)
			b.set_border_width_all(2)
			b.set_corner_radius_all(9)
		t.set_stylebox(etat, "Button", b)
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.7))
	t.set_color("font_color", "Label", TEXTE)
	t.set_color("font_color", "CheckBox", TEXTE)
	t.set_color("font_hover_color", "CheckBox", ACCENT)
	t.set_color("font_color", "OptionButton", Color.WHITE)
	t.set_color("default_color", "RichTextLabel", TEXTE)
	t.set_font_size("font_size", "Label", 18)
	var barre := StyleBoxFlat.new()
	barre.bg_color = Color(0.82, 0.86, 0.88)
	barre.set_corner_radius_all(4)
	barre.content_margin_top = 4
	barre.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", barre)
	var rempli := StyleBoxFlat.new()
	rempli.bg_color = ACCENT
	rempli.set_corner_radius_all(4)
	rempli.content_margin_top = 4
	rempli.content_margin_bottom = 4
	t.set_stylebox("grabber_area", "HSlider", rempli)
	t.set_stylebox("grabber_area_highlight", "HSlider", rempli)
	var fond_barre := StyleBoxFlat.new()
	fond_barre.bg_color = Color(0.85, 0.88, 0.9)
	fond_barre.set_corner_radius_all(6)
	t.set_stylebox("background", "ProgressBar", fond_barre)
	var plein := StyleBoxFlat.new()
	plein.bg_color = ACCENT
	plein.set_corner_radius_all(6)
	t.set_stylebox("fill", "ProgressBar", plein)
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	var sep := StyleBoxLine.new()
	sep.color = Color(0.8, 0.84, 0.86)
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	_theme = t
	return t


## Place `c` (à sa taille minimale) avec son coin haut-gauche à `haut_gauche` pixels du point
## d'ancrage `ancre` (0..1 dans le parent). Passe par les offsets : `position` serait absolue.
static func placer(c: Control, ancre: Vector2, haut_gauche: Vector2) -> void:
	c.reset_size()
	var t := c.size
	c.anchor_left = ancre.x
	c.anchor_right = ancre.x
	c.anchor_top = ancre.y
	c.anchor_bottom = ancre.y
	c.offset_left = haut_gauche.x
	c.offset_top = haut_gauche.y
	c.offset_right = haut_gauche.x + t.x
	c.offset_bottom = haut_gauche.y + t.y


## Centre `c` dans son parent.
static func centrer(c: Control) -> void:
	c.reset_size()
	placer(c, Vector2(0.5, 0.5), -c.size * 0.5)


static func _boite(c: Color, rayon: int, marge: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(rayon)
	b.content_margin_left = marge
	b.content_margin_right = marge
	b.content_margin_top = marge
	b.content_margin_bottom = marge
	if marge > 0:
		b.shadow_color = Color(0, 0, 0, 0.18)
		b.shadow_size = 12
		b.shadow_offset = Vector2(0, 4)
	return b


static func titre(texte: String, taille := 26) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", TEXTE)
	return l


static func texte_doux(texte: String, taille := 16) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", TEXTE_DOUX)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
