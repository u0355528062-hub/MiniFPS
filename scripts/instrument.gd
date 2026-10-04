class_name Instrument
extends Node3D
## Instrument chirurgical saisissable. Le modèle est centré, pointe vers +Z local.

signal grabbed(inst: Instrument)

var id := ""
var label := ""
var length := 0.2
var tip_local := Vector3.ZERO
var grip_local := Vector3.ZERO  ## point tenu dans la main (côté anneaux / manche)
var tray_transform := Transform3D.IDENTITY
var held := false
var parked := false  ## posé dans la plaie (écarteurs)
var model: Node3D

var _overlay := ShaderMaterial.new()
var _meshes: Array[MeshInstance3D] = []
var _tween: Tween
var _mode := 0  # 0 = rien, 1 = à utiliser, 2 = survolé


static func create(p_id: String, p_label: String, file: String, roll_deg := 0.0, scale_to := 0.0, rot := Vector3.ZERO) -> Instrument:
	var scene: PackedScene = load("res://assets/models/" + file + ".glb")
	return create_from_node(p_id, p_label, scene.instantiate(), roll_deg, scale_to, rot)


## Instrument à partir d'un modèle déjà construit (procédural). Pointe vers +Z.
static func create_from_node(p_id: String, p_label: String, node: Node3D, roll_deg := 0.0, scale_to := 0.0, rot := Vector3.ZERO) -> Instrument:
	var inst := Instrument.new()
	inst.id = p_id
	inst.label = p_label
	inst.name = p_id
	inst.model = node
	inst.model.rotation_degrees = rot + Vector3(0, 0, roll_deg)
	inst.add_child(inst.model)
	inst._setup(scale_to)
	return inst


func _setup(scale_to: float) -> void:
	_collect(model)
	var box := _local_aabb()
	if scale_to > 0.0 and box.size.z > 0.0:
		model.scale = Vector3.ONE * (scale_to / box.size.z)
		box = _local_aabb()
	length = box.size.z
	var c := box.get_center()
	tip_local = Vector3(c.x, c.y, box.end.z)
	grip_local = Vector3(c.x, c.y, box.position.z + length * 0.18)
	_overlay.shader = preload("res://shaders/highlight.gdshader")
	_overlay.set_shader_parameter("strength", 0.0)


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	for ch in n.get_children():
		_collect(ch)


func _local_aabb() -> AABB:
	var box := AABB()
	var first := true
	for m in _meshes:
		var xf := _transform_to_self(m)
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _transform_to_self(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != self and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Ajoute une pièce procédurale (lame, compresse, aiguille...) attachée à la pointe.
func attach_tip_part(part: Node3D) -> void:
	add_child(part)
	part.position = tip_local
	_collect(part)


func tip_global() -> Vector3:
	return global_transform * tip_local


func grip_global() -> Vector3:
	return global_transform * grip_local


## 0 = normal, 1 = instrument demandé (pulsation cyan), 2 = survolé (blanc)
func set_highlight(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	for m in _meshes:
		m.material_overlay = _overlay if mode > 0 else null
	_overlay.set_shader_parameter("strength", 1.0 if mode == 1 else 0.8)
	_overlay.set_shader_parameter("glow", Color(0.2, 0.95, 0.85) if mode == 1 else Color(0.9, 0.95, 1.0))


func take() -> void:
	held = true
	parked = false
	if _tween:
		_tween.kill()
	grabbed.emit(self)


func return_to_tray() -> void:
	held = false
	parked = false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_transform", tray_transform, 0.45)


func park(xf: Transform3D) -> void:
	held = false
	parked = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_transform", xf, 0.3)


## Transformation qui met la pointe en `tip`, l'axis de l'instrument suivant `axis` (vers la pointe).
func tip_transform(tip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> Transform3D:
	var z := axis.normalized()
	var x := up_hint.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var b := Basis(x, z.cross(x), z)
	return Transform3D(b, tip - b * tip_local)


func pose_tip(tip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> void:
	global_transform = tip_transform(tip, axis, up_hint)


## Place l'instrument pour que son point de prise soit en `grip` (main VR).
func pose_grip(grip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> void:
	var z := axis.normalized()
	var x := up_hint.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var b := Basis(x, z.cross(x), z)
	global_transform = Transform3D(b, grip - b * grip_local)
