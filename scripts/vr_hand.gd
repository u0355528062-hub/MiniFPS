class_name VRHand
extends SurgeonHand
## Main VR : gant de latex (XR Tools) sur la manette Quest.
## Grip = prendre / reposer (bascule), gâchette = agir. On peut aussi viser un instrument
## avec le rayon et appuyer sur grip pour l'attirer dans la main.

const HOLD_TILT := deg_to_rad(38.0)

var controller: XRController3D
var hand_model: Node3D
var ray: MeshInstance3D
var _grip_was := false
var _ray_mat := StandardMaterial3D.new()


func setup(c: XRController3D, left: bool) -> void:
	controller = c
	var path := "res://addons/godot-xr-tools/hands/scenes/highpoly/%s_fullglove_hand.tscn" % ("left" if left else "right")
	var scene: PackedScene = load(path)
	if scene:
		hand_model = scene.instantiate()
		var glove: Material = load("res://addons/godot-xr-tools/hands/materials/labglove.tres")
		if glove and "hand_material_override" in hand_model:
			hand_model.set("hand_material_override", glove)
		controller.add_child(hand_model)
	# Rayon de visée (fin, discret) pour attraper à distance
	ray = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0012
	cm.bottom_radius = 0.0012
	cm.height = 1.0
	ray.mesh = cm
	_ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ray_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.35)
	_ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.material_override = _ray_mat
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ray)


func trigger_value() -> float:
	return controller.get_float("trigger") if controller else 0.0


func _grip() -> bool:
	return controller.get_float("grip") > 0.6 if controller else false


func pulse(amplitude := 0.5, duration := 0.05) -> void:
	if controller:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)


## Direction de l'instrument tenu « en crayon » : vers l'avant du poing, inclinée vers le bas.
func _hold_axis() -> Vector3:
	var b := controller.global_basis
	return (-b.z).rotated(b.x.normalized(), -HOLD_TILT).normalized()


func _process(_delta: float) -> void:
	if controller == null:
		return
	global_transform = controller.global_transform
	_update_edges()
	var axis := _hold_axis()
	var grip_point := controller.global_position + axis * 0.035 - controller.global_basis.y * 0.01

	# Survol : instrument le plus proche de la main, sinon celui visé par le rayon
	var best: Instrument = null
	if held == null:
		var best_d := 0.13
		for inst in instruments:
			if inst.parked:
				continue
			var d := inst.grip_global().distance_to(grip_point)
			if d < best_d:
				best_d = d
				best = inst
		if best == null:
			var best_ray := 0.045
			for inst in instruments:
				if inst.parked:
					continue
				var to := inst.global_position - grip_point
				var along := to.dot(axis)
				if along < 0.05 or along > 2.0:
					continue
				var off := (to - axis * along).length()
				if off < best_ray + along * 0.02:
					best_ray = off
					best = inst
	set_hover(best)

	var grip := _grip()
	if grip and not _grip_was:
		if held:
			put_back_requested.emit(self)
		elif best:
			take_requested.emit(self, best)
	_grip_was = grip

	if held:
		held.pose_grip(grip_point, axis, controller.global_basis.y)
		if hand_model and hand_model.has_method("force_grip_trigger"):
			hand_model.force_grip_trigger(0.85, trigger_value() * 0.6 + 0.2)
	elif hand_model and hand_model.has_method("force_grip_trigger"):
		hand_model.force_grip_trigger(-1.0, -1.0)

	# Rayon visible seulement main vide
	ray.visible = held == null
	if ray.visible:
		var length := 0.6
		if best:
			length = clampf((best.global_position - grip_point).dot(axis), 0.05, 2.0)
		_ray_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.55 if best else 0.18)
		ray.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), grip_point + axis * length * 0.5)
		ray.scale = Vector3(1, length, 1)
