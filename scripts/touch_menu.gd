class_name TouchMenu
extends Node3D
## Boutons 3D à toucher du bout de l'index (mains nues) ou du bout de la manette : choix de
## l'opération, commencer, recommencer, se recentrer. Un clic sonore et le bouton s'enfonce.

signal pressed(action: String)

const W := 0.27
const H := 0.062

var hands: Array[SurgeonHand] = []
var _buttons: Array[Dictionary] = []
var _cool := 0.0
var _font: Font
var _panel: Node3D
var _corner: Node3D


func build(spot: Vector3) -> void:
	_font = load("res://assets/fonts/Inter.ttf")
	_panel = Node3D.new()
	_panel.name = "Boutons"
	add_child(_panel)
	# Devant le chirurgien, au-dessus du bord de la table, incliné vers lui
	_panel.position = spot + Vector3(-0.16, 1.24, -0.34)
	_panel.rotation = Vector3(deg_to_rad(-38.0), 0, 0)
	# Bouton « Recentrer » toujours disponible, en haut à gauche (hors de la zone de travail)
	_corner = Node3D.new()
	_corner.name = "Recentrer"
	add_child(_corner)
	_corner.position = spot + Vector3(-0.5, 1.48, -0.18)
	_corner.rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(35.0), 0)
	_add_button(_corner, "Recentrer", "recenter", Vector3.ZERO, 0.16)


func _add_button(parent: Node3D, text: String, action: String, pos: Vector3, width := W, selected := false) -> void:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var cap := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, H, 0.014)
	cap.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.16, 0.19) if not selected else Color(0.07, 0.36, 0.36)
	mat.roughness = 0.4
	mat.emission_enabled = true
	mat.emission = GuideUI.ACCENT
	mat.emission_energy_multiplier = 0.15 if selected else 0.03
	cap.material_override = mat
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cap)
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font = _font
	lbl.font_size = 44
	lbl.pixel_size = 0.0007
	lbl.outline_size = 0
	lbl.modulate = Color(0.92, 1.0, 0.98)
	lbl.position = Vector3(0, 0, 0.0085)
	lbl.width = width / 0.0007
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl)
	_buttons.append({"root": root, "cap": cap, "mat": mat, "action": action, "w": width, "armed": true, "push": 0.0})


func _clear_panel() -> void:
	for b in _buttons.duplicate():
		if (b["root"] as Node3D).get_parent() == _panel:
			(b["root"] as Node3D).queue_free()
			_buttons.erase(b)


## Menu : un bouton par opération (le toucher la lance).
func show_menu(labels: Array, selected: int) -> void:
	_clear_panel()
	for i in labels.size():
		_add_button(_panel, labels[i], "op:%d" % i, Vector3(0, -i * (H + 0.016), 0), W, i == selected)


func show_buttons(list: Array) -> void:
	_clear_panel()
	for i in list.size():
		_add_button(_panel, list[i][0], list[i][1], Vector3(0, -i * (H + 0.016), 0))


func _process(delta: float) -> void:
	_cool -= delta
	var tips: Array[Vector3] = []
	for h in hands:
		var t := h.fingertip()
		if t != Vector3.INF:
			tips.append(t)
	for b in _buttons:
		var root: Node3D = b["root"]
		if not is_instance_valid(root) or not root.is_inside_tree():
			continue
		var inv := root.global_transform.affine_inverse()
		var touching := false
		var hover := false
		for t in tips:
			var q := inv * t
			if absf(q.x) < b["w"] * 0.5 + 0.008 and absf(q.y) < H * 0.5 + 0.008:
				if q.z < 0.012 and q.z > -0.03:
					touching = true
				elif q.z < 0.06 and q.z >= 0.012:
					hover = true
		var mat: StandardMaterial3D = b["mat"]
		mat.emission_energy_multiplier = 0.5 if touching else (0.22 if hover else (0.15 if mat.albedo_color.g > 0.3 else 0.03))
		b["push"] = move_toward(b["push"], 1.0 if touching else 0.0, delta * 12.0)
		(b["cap"] as MeshInstance3D).position.z = -0.006 * b["push"]
		if touching and b["armed"] and _cool <= 0.0:
			b["armed"] = false
			_cool = 0.6
			Sfx.play("pose", root.global_position, -6.0, 1.5)
			for h in hands:
				h.pulse(0.5, 0.05)
			pressed.emit(b["action"])
			return
		if not touching:
			b["armed"] = true
