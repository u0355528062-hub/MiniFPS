class_name DesktopHUD
extends CanvasLayer
## Surimpression du mode écran : consigne (copie du panneau), barre d'instruments 1-8, aide.

var ui: GuideUI
var _slots: Array[PanelContainer] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _hand: DesktopHand
var _ids: Array[String] = []

const SHORT := {
	"mikulicz": "Badigeon", "bistouri": "Bistouri", "langenbeck": "Langenbeck", "roux": "Roux",
	"debakey": "De Bakey", "overholt": "Overholt", "ciseaux": "Ciseaux", "porte_aiguille": "Porte-aiguille",
	"seringue": "Seringue", "kelly": "Kelly", "drain": "Drain", "gosset": "Gosset", "aspirateur": "Aspiration",
	"meche": "Mèche",
}


func build(hand: DesktopHand, instruments: Array[Instrument]) -> void:
	_hand = hand
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	ui = GuideUI.new()
	ui.scale = Vector2(0.42, 0.42)
	ui.position = Vector2(16, 16)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(ui)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-470, -92)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(bar)
	for i in instruments.size():
		var inst := instruments[i]
		_ids.append(inst.id)
		var p := PanelContainer.new()
		var s := GuideUI._box(Color(0.03, 0.06, 0.08, 0.85), 12, Color(1, 1, 1, 0.15), 2)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		p.add_theme_stylebox_override("panel", s)
		p.custom_minimum_size = Vector2(110, 64)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := Label.new()
		l.text = "%d\n%s" % [i + 1, SHORT.get(inst.id, inst.label)]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 14)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(l)
		bar.add_child(p)
		_slots.append(p)
		_slot_styles.append(s)

	var help := Label.new()
	help.text = "Clic : prendre · Clic maintenu : agir · Molette : lever/baisser · R / clic droit : reposer · Clic droit glissé : regarder · ZQSD : bouger · Espace : continuer"
	help.add_theme_font_size_override("font_size", 14)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help.modulate = Color(1, 1, 1, 0.75)
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.position = Vector2(-520, -22)
	holder.add_child(help)


func mark_required(id: String) -> void:
	for i in _ids.size():
		var req := _ids[i] == id
		_slot_styles[i].border_color = GuideUI.ACCENT if req else Color(1, 1, 1, 0.15)
		_slot_styles[i].bg_color = Color(GuideUI.ACCENT, 0.25) if req else Color(0.03, 0.06, 0.08, 0.85)


func _process(_delta: float) -> void:
	if _hand == null:
		return
	for i in _ids.size():
		var held := _hand.held != null and _hand.held.id == _ids[i]
		_slots[i].modulate = Color(1.3, 1.3, 1.3) if held else Color.WHITE
