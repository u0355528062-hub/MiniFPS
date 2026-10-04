class_name VRHand
extends SurgeonHand
## Main VR, avec manette Quest OU avec la vraie main (suivi des mains du Quest 3).
## Manette : GRIP = prendre / reposer (bascule), GÂCHETTE = agir.
## Main nue : POING (majeur, annulaire, auriculaire repliés) = prendre / reposer,
##            PINCER pouce + index = agir.
## Dans les deux cas un rayon part de la main pour attraper un instrument à distance.

signal pinched(hand: VRHand)  ## pincement (main nue) : sert aussi à valider dans les menus

const HOLD_TILT := deg_to_rad(38.0)
# Seuils des gestes (mètres), avec hystérésis pour éviter les clignotements
const PINCH_ON := 0.02
const PINCH_OFF := 0.035
const FIST_ON := 0.06
const FIST_OFF := 0.08
const FIST_HOLD := 0.12  ## le poing doit tenir 0,12 s pour compter

enum Source { CONTROLLER, HAND, NONE }

const CHAINS := [[1, 2, 3, 4, 5], [1, 6, 7, 8, 9, 10], [1, 11, 12, 13, 14, 15], [1, 16, 17, 18, 19, 20], [1, 21, 22, 23, 24, 25]]

var controller: XRController3D
var is_left := false
var hand_model: Node3D
var ray: MeshInstance3D
var source := Source.CONTROLLER
var tracker_name := ""
var _grip_was := false
var _ray_mat := StandardMaterial3D.new()
## Simulation (test robot sans casque) : valeurs d'entrée imposées pour la manette
var sim := false
var sim_trigger := 0.0
var sim_grip := 0.0
# Main nue
var _pinch := false
var _fist := false
var _fist_t := 0.0
var _hand_xf := Transform3D.IDENTITY  ## repère de la paume (lissé), en global
var _last_xf := Transform3D.IDENTITY  ## dernière pose valide (main ou manette)
var _have_hand_xf := false
var _visual: Node3D
var _joint_balls: Array[MeshInstance3D] = []
var _bones: Array[MeshInstance3D] = []


func setup(c: XRController3D, left: bool) -> void:
	controller = c
	is_left = left
	tracker_name = "/user/hand_tracker/%s" % ("left" if left else "right")
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
	_build_hand_visual()


## Main nue dessinée en gant de nitrile : une bille par articulation + des segments.
func _build_hand_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "MainSuivie"
	_visual.visible = false
	add_child(_visual)
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color(0.16, 0.32, 0.78)
	glove.roughness = 0.32
	glove.metallic_specular = 0.6
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cm.radial_segments = 10
	for j in XRHandTracker.HAND_JOINT_MAX:
		var b := MeshInstance3D.new()
		b.mesh = sm
		b.material_override = glove
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(b)
		_joint_balls.append(b)
	for chain in CHAINS:
		for k in chain.size() - 1:
			var bone := MeshInstance3D.new()
			bone.mesh = cm
			bone.material_override = glove
			bone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visual.add_child(bone)
			_bones.append(bone)


func trigger_value() -> float:
	match source:
		Source.HAND:
			return 1.0 if _pinch else 0.0
		Source.NONE:
			return 0.0
	if sim:
		return sim_trigger
	return controller.get_float("trigger") if controller else 0.0


func _grip() -> bool:
	match source:
		Source.HAND:
			return _fist
		Source.NONE:
			return _grip_was
	if sim:
		return sim_grip > 0.6
	return controller.get_float("grip") > 0.6 if controller else false


func _basis() -> Basis:
	return _last_xf.basis.orthonormalized()


## Point tenu dans la main (là où se place le point de prise de l'instrument).
func grip_point() -> Vector3:
	var b := _basis()
	if source == Source.HAND:
		# Main nue : l'instrument se tient entre le pouce et l'index, un peu devant la paume
		return _last_xf.origin + _hold_axis() * 0.045 - b.y * 0.02
	return _last_xf.origin + _hold_axis() * 0.035 - b.y * 0.01


func pulse(amplitude := 0.5, duration := 0.05) -> void:
	if controller and not sim and source == Source.CONTROLLER:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)


## Direction de l'instrument tenu « en crayon » : vers l'avant de la main, inclinée vers le bas.
func _hold_axis() -> Vector3:
	var b := _basis()
	return (-b.z).rotated(b.x.normalized(), -HOLD_TILT).normalized()


func _hand_tracker() -> XRHandTracker:
	var t := XRServer.get_tracker(tracker_name)
	if t is XRHandTracker and (t as XRHandTracker).has_tracking_data:
		return t
	return null


## Lit les articulations de la vraie main : repère de paume lissé, pincement, poing, dessin.
func _update_hand(tr: XRHandTracker, delta: float) -> void:
	var origin := (get_parent() as Node3D).global_transform
	var palm := origin * tr.get_hand_joint_transform(XRHandTracker.HAND_JOINT_PALM)
	if not _have_hand_xf:
		_hand_xf = palm
		_have_hand_xf = true
	else:
		# Lissage léger (le suivi optique tremble un peu)
		_hand_xf = Transform3D(Basis(Quaternion(_hand_xf.basis.orthonormalized()).slerp(Quaternion(palm.basis.orthonormalized()), 0.5)), _hand_xf.origin.lerp(palm.origin, 0.6))
	var pts: Array[Vector3] = []
	for j in XRHandTracker.HAND_JOINT_MAX:
		pts.append(origin * tr.get_hand_joint_transform(j).origin)
	var pinch_d := pts[XRHandTracker.HAND_JOINT_THUMB_TIP].distance_to(pts[XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP])
	_pinch = pinch_d < (PINCH_OFF if _pinch else PINCH_ON)
	var fold := 0.0
	for j in [XRHandTracker.HAND_JOINT_MIDDLE_FINGER_TIP, XRHandTracker.HAND_JOINT_RING_FINGER_TIP, XRHandTracker.HAND_JOINT_PINKY_FINGER_TIP]:
		fold += pts[j].distance_to(palm.origin) / 3.0
	var fist_now := fold < (FIST_OFF if _fist else FIST_ON)
	if fist_now != _fist:
		_fist_t += delta
		if _fist_t >= FIST_HOLD:
			_fist = fist_now
			_fist_t = 0.0
	else:
		_fist_t = 0.0
	# Dessin de la main
	for j in pts.size():
		var r := maxf(tr.get_hand_joint_radius(j), 0.006)
		if j == XRHandTracker.HAND_JOINT_PALM:
			_joint_balls[j].global_transform = Transform3D(_hand_xf.basis.orthonormalized().scaled(Vector3(0.035, 0.012, 0.04)), pts[j])
		else:
			_joint_balls[j].global_transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * r), pts[j])
	var bi := 0
	for chain in CHAINS:
		for k in chain.size() - 1:
			var a: Vector3 = pts[chain[k]]
			var b: Vector3 = pts[chain[k + 1]]
			var bone := _bones[bi]
			bi += 1
			var seg := a.distance_to(b)
			if seg < 0.001:
				bone.visible = false
				continue
			bone.visible = true
			var r := maxf(tr.get_hand_joint_radius(chain[k + 1]), 0.006) * 0.95
			bone.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, (b - a) / seg)).scaled(Vector3(r, seg, r)), (a + b) * 0.5)


func _process(delta: float) -> void:
	if controller == null:
		return
	# Source d'entrée : main nue si le casque la voit, sinon manette, sinon on fige la pose
	var tr := _hand_tracker()
	var was_pinch := _pinch
	if tr:
		source = Source.HAND
		_update_hand(tr, delta)
		_last_xf = _hand_xf
	elif sim or controller.get_has_tracking_data():
		source = Source.CONTROLLER
		_have_hand_xf = false
		_pinch = false
		_fist = false
		_last_xf = controller.global_transform
	else:
		source = Source.NONE
		_have_hand_xf = false
	_visual.visible = source == Source.HAND
	if hand_model:
		hand_model.visible = source == Source.CONTROLLER
	global_transform = _last_xf
	_update_edges()
	if source == Source.HAND and _pinch and not was_pinch:
		pinched.emit(self)
	var axis := _hold_axis()
	var grip_point := grip_point()

	# Survol : instrument le plus proche de la main, sinon celui visé par le rayon
	var best: Instrument = null
	if held == null and source != Source.NONE:
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
		held.pose_grip(grip_point, axis, _basis().y)
		if hand_model and hand_model.has_method("force_grip_trigger"):
			hand_model.force_grip_trigger(0.85, trigger_value() * 0.6 + 0.2)
	elif hand_model and hand_model.has_method("force_grip_trigger"):
		hand_model.force_grip_trigger(-1.0, -1.0)

	# Rayon visible seulement main vide
	ray.visible = held == null and source != Source.NONE
	if ray.visible:
		var length := 0.6
		if best:
			length = clampf((best.global_position - grip_point).dot(axis), 0.05, 2.0)
		_ray_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.55 if best else 0.18)
		ray.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), grip_point + axis * length * 0.5)
		ray.scale = Vector3(1, length, 1)
