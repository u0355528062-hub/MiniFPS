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
var _skel: Skeleton3D
var _bone_of: Array[int] = []
var _rest_frame := Basis.IDENTITY


func setup(c: XRController3D, left: bool) -> void:
	controller = c
	is_left = left
	tracker_name = "/user/hand_tracker/%s" % ("left" if left else "right")
	var path := "res://addons/godot-xr-tools/hands/scenes/highpoly/%s_fullglove_hand.tscn" % ("left" if left else "right")
	var scene: PackedScene = load(path)
	if scene:
		hand_model = scene.instantiate()
		if "hand_material_override" in hand_model:
			hand_model.set("hand_material_override", glove_material())
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


## Gant de nitrile mat, bleu clair (le gant d'origine de XR Tools est verni et brille sous le scialytique).
static var _glove_mat: StandardMaterial3D

static func glove_material() -> Material:
	if _glove_mat == null:
		_glove_mat = StandardMaterial3D.new()
		_glove_mat.albedo_color = Color(0.45, 0.58, 0.8)
		_glove_mat.roughness = 0.75
		_glove_mat.metallic_specular = 0.2
		_glove_mat.normal_enabled = true
		_glove_mat.normal_scale = 0.15
		_glove_mat.normal_texture = load("res://addons/godot-xr-tools/hands/textures/glove_normal.png")
	return _glove_mat


## Main nue : le vrai gant 3D (squelette de 26 os) déformé par les articulations suivies.
func _build_hand_visual() -> void:
	var path := "res://addons/godot-xr-tools/hands/model/hand_%s.gltf" % ("l" if is_left else "r")
	var scene: PackedScene = load(path)
	_visual = scene.instantiate() if scene else Node3D.new()
	_visual.name = "MainSuivie"
	_visual.visible = false
	# Attaché à l'origine XR : les articulations sont données dans ce repère
	_visual.top_level = true
	add_child(_visual)
	var skels := _visual.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return
	_skel = skels[0]
	for mi in _visual.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = glove_material()
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var side := "L" if is_left else "R"
	var names := ["Palm", "Wrist", "Thumb_Metacarpal", "Thumb_Proximal", "Thumb_Distal", "Thumb_Tip"]
	for f in ["Index", "Middle", "Ring", "Little"]:
		for part in ["Metacarpal", "Proximal", "Intermediate", "Distal", "Tip"]:
			names.append("%s_%s" % [f, part])
	_bone_of.resize(XRHandTracker.HAND_JOINT_MAX)
	for j in XRHandTracker.HAND_JOINT_MAX:
		_bone_of[j] = _skel.find_bone("%s_%s" % [names[j], side])
	# Repère de la main au repos (positions des os) pour transférer l'orientation globale
	var rest := []
	for j in XRHandTracker.HAND_JOINT_MAX:
		rest.append(_skel.get_bone_global_rest(_bone_of[j]).origin if _bone_of[j] >= 0 else Vector3.ZERO)
	_rest_frame = _hand_frame(rest)


## Repère de main construit avec des positions seulement (même chiralité au repos et en suivi).
static func _hand_frame(p: Array) -> Basis:
	var fwd: Vector3 = (p[XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL] - p[XRHandTracker.HAND_JOINT_WRIST]).normalized()
	var across: Vector3 = (p[XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL] - p[XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL]).normalized()
	var up := fwd.cross(across).normalized()
	across = up.cross(fwd).normalized()
	return Basis(across, fwd, up)


## Pose le squelette du gant sur les articulations (origine = articulation, os orienté vers l'enfant).
func _pose_glove(pts: Array) -> void:
	if _skel == null:
		return
	var to_skel := _skel.global_transform.affine_inverse()
	var local := []
	for p in pts:
		local.append(to_skel * (p as Vector3))
	var q := _hand_frame(local) * _rest_frame.inverse()
	for j in [XRHandTracker.HAND_JOINT_WRIST, XRHandTracker.HAND_JOINT_PALM]:
		var bj: int = _bone_of[j]
		if bj >= 0:
			_skel.set_bone_global_pose(bj, Transform3D(q * _skel.get_bone_global_rest(bj).basis, local[j]))
	for chain in CHAINS:
		for k in range(1, chain.size()):
			var j: int = chain[k]
			var bj: int = _bone_of[j]
			if bj < 0:
				continue
			var rest_b := q * _skel.get_bone_global_rest(bj).basis
			var b := rest_b
			if k < chain.size() - 1:
				var d: Vector3 = (local[chain[k + 1]] - local[j])
				if d.length() > 0.001:
					b = Basis(Quaternion(rest_b.y.normalized(), d.normalized())) * rest_b
			_skel.set_bone_global_pose(bj, Transform3D(b.orthonormalized(), local[j]))


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
	# Dessin : le gant suit les articulations
	_visual.global_transform = Transform3D.IDENTITY
	_pose_glove(pts)


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
