class_name VRHand
extends SurgeonHand
## Main VR : la vraie main (suivi des mains du Quest 3) OU la manette.
## Main nue : PINCER (pouce + index) près d'un instrument = le prendre ; il se tient entre le pouce et
##   l'index comme un crayon. Serrer / desserrer le pouce contre l'index ferme / ouvre les mâchoires
##   (ciseaux, pinces), pousse le piston de la seringue. OUVRIR GRAND LA MAIN = le lâcher (il retourne
##   sur la table). Le bistouri, la pince à badigeon, les écarteurs agissent simplement au contact.
## Manette : GRIP = prendre / reposer, GÂCHETTE = serrer.
## Un rayon discret permet aussi de prendre un instrument à distance (pincer en le visant).

signal pinched(hand: VRHand)  ## pincement main vide : sert à valider dans les menus

const HOLD_TILT := deg_to_rad(38.0)
const PINCH_ON := 0.018
const PINCH_OFF := 0.032
const GRAB_NEAR := 0.035  ## distance pincement ↔ instrument pour le prendre
const RELEASE_HOLD := 0.3  ## main grande ouverte pendant 0,3 s = lâcher

enum Source { CONTROLLER, HAND, NONE }

const CHAINS := [[1, 2, 3, 4, 5], [1, 6, 7, 8, 9, 10], [1, 11, 12, 13, 14, 15], [1, 16, 17, 18, 19, 20], [1, 21, 22, 23, 24, 25]]

var controller: XRController3D
var is_left := false
var hand_model: Node3D
var ray: MeshInstance3D
var source := Source.CONTROLLER
var tracker_name := ""
var patient: Patient
var camera: Node3D
## Simulation (test robot sans casque) : valeurs d'entrée imposées pour la manette
var sim := false
var sim_trigger := 0.0
var sim_grip := 0.0

var _grip_was := false
var _ray_mat := StandardMaterial3D.new()
var _filters: Array[OneEuro] = []
var _j := PackedVector3Array()  ## articulations filtrées (monde)
var _have_joints := false
var _pinch := false
var _pinch_d := 0.1
var _fist := false
var _open_t := 0.0
var _sq := 0.0  ## serrage lissé
var _raw_tip := Vector3.ZERO
var _last_xf := Transform3D.IDENTITY  ## repère de la main (manette ou main), pour les menus
var _grab_from := Transform3D.IDENTITY
var _grab_blend := 1.0
var _rot := Quaternion.IDENTITY
var _hold_local := Vector3.ZERO  ## point de prise dans le repère de la paume
var _offset := Vector3.ZERO  ## la main est repoussée avec l'instrument (elle ne traverse pas)
var _visual: Node3D
var _skel: Skeleton3D
var _bone_of: Array[int] = []
var _rest_frame := Basis.IDENTITY


func setup(c: XRController3D, left: bool) -> void:
	controller = c
	is_left = left
	slot = 0 if left else 1
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
	cm.top_radius = 0.001
	cm.bottom_radius = 0.001
	cm.height = 1.0
	cm.radial_segments = 6
	ray.mesh = cm
	_ray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ray_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.35)
	_ray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ray.material_override = _ray_mat
	ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ray.top_level = true
	add_child(ray)
	for i in XRHandTracker.HAND_JOINT_MAX:
		_filters.append(OneEuro.new())
	_j.resize(XRHandTracker.HAND_JOINT_MAX)
	_build_hand_visual()


## Gant de nitrile mat, bleu clair.
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


## Main nue : le gant 3D (squelette de 26 os) déformé par les articulations suivies.
func _build_hand_visual() -> void:
	var path := "res://addons/godot-xr-tools/hands/model/hand_%s.gltf" % ("l" if is_left else "r")
	var scene: PackedScene = load(path)
	_visual = scene.instantiate() if scene else Node3D.new()
	_visual.name = "MainSuivie"
	_visual.visible = false
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


# ---------------------------------------------------------------- Entrées

func squeeze_value() -> float:
	return _sq


func _raw_squeeze() -> float:
	match source:
		Source.HAND:
			return 1.0 - clampf((_pinch_d - 0.016) / (0.058 - 0.016), 0.0, 1.0)
		Source.NONE:
			return _sq
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


func raw_tip() -> Vector3:
	return _raw_tip if held else tip()


func fingertip() -> Vector3:
	if source == Source.HAND and _have_joints:
		return _j[XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP]
	if source == Source.CONTROLLER:
		var b := _last_xf.basis.orthonormalized()
		return _last_xf.origin - b.z * 0.07 - b.y * 0.01
	return Vector3.INF


## Point de pincement (entre le bout du pouce et le bout de l'index), ou point de prise manette.
func pinch_point() -> Vector3:
	if source == Source.HAND and _have_joints:
		return (_j[XRHandTracker.HAND_JOINT_THUMB_TIP] + _j[XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP]) * 0.5
	var b := _last_xf.basis.orthonormalized()
	return _last_xf.origin + _ctrl_axis() * 0.035 - b.y * 0.01


func pulse(amplitude := 0.5, duration := 0.05) -> void:
	if controller and not sim and source == Source.CONTROLLER:
		controller.trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)


func _ctrl_axis() -> Vector3:
	var b := _last_xf.basis.orthonormalized()
	return (-b.z).rotated(b.x.normalized(), -HOLD_TILT).normalized()


func _hand_tracker() -> XRHandTracker:
	var t := XRServer.get_tracker(tracker_name)
	if t is XRHandTracker and (t as XRHandTracker).has_tracking_data:
		return t
	return null


## Lit les articulations de la vraie main (filtrées), le pincement, le poing, la main ouverte.
func _update_hand(tr: XRHandTracker, delta: float) -> void:
	var origin := (get_parent() as Node3D).global_transform
	if not _have_joints:
		for f in _filters:
			f.reset()
	for j in XRHandTracker.HAND_JOINT_MAX:
		_j[j] = _filters[j].filter(origin * tr.get_hand_joint_transform(j).origin, delta)
	_have_joints = true
	_pinch_d = _j[XRHandTracker.HAND_JOINT_THUMB_TIP].distance_to(_j[XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP])
	_pinch = _pinch_d < (PINCH_OFF if _pinch else PINCH_ON)
	var wrist := _j[XRHandTracker.HAND_JOINT_WRIST]
	var palm := _j[XRHandTracker.HAND_JOINT_PALM]
	var fold := 0.0
	for k in [15, 20, 25]:
		fold += _j[k].distance_to(palm) / 3.0
	_fist = fold < (0.08 if _fist else 0.06)
	# Main grande ouverte : majeur et annulaire tendus, pouce écarté de l'index
	var ext := 0
	for f in [[12, 15], [17, 20]]:
		if _j[f[1]].distance_to(wrist) > 1.7 * _j[f[0]].distance_to(wrist):
			ext += 1
	var flat := ext == 2 and _pinch_d > 0.05
	_open_t = _open_t + delta if flat else 0.0
	var b := _hand_basis()
	_last_xf = Transform3D(b, palm)


## Repère de la main : x en travers, y = dos de la main, -z vers les doigts.
func _hand_basis() -> Basis:
	var fwd := (_j[XRHandTracker.HAND_JOINT_MIDDLE_FINGER_PHALANX_PROXIMAL] - _j[XRHandTracker.HAND_JOINT_WRIST]).normalized()
	var across := (_j[XRHandTracker.HAND_JOINT_INDEX_FINGER_PHALANX_PROXIMAL] - _j[XRHandTracker.HAND_JOINT_PINKY_FINGER_PHALANX_PROXIMAL]).normalized()
	var dorsal := fwd.cross(across).normalized() * (-1.0 if is_left else 1.0)
	var x := dorsal.cross(-fwd).normalized()
	return Basis(x, dorsal, -fwd).orthonormalized()


## Pose de l'instrument tenu : entre le pouce et l'index, couché le long de l'index comme un crayon.
func _held_pose() -> Transform3D:
	var up := Vector3.UP
	var grip: Vector3
	var axis: Vector3
	var dorsal: Vector3
	if source == Source.HAND:
		# Tenue fixe par rapport à la paume (la partie la plus stable du suivi) : serrer le pouce
		# ou plier l'index ne fait pas bouger l'instrument. Le point de prise est celui des doigts au
		# moment où on l'a pris.
		var b := _last_xf.basis
		dorsal = b.y
		grip = _last_xf.origin + b * _hold_local
		axis = (b * _axis_local()).normalized()
	else:
		var b := _last_xf.basis.orthonormalized()
		dorsal = b.y
		axis = _ctrl_axis()
		grip = _last_xf.origin + axis * 0.035 - b.y * 0.01
	match held.up_mode:
		"down":
			up = -dorsal
		"world":
			up = (Vector3.UP * 0.8 + dorsal * 0.2).normalized()
		_:
			up = (dorsal * 0.65 + Vector3.UP * 0.35).normalized()
	return held.grip_transform(grip, axis, up)


func _process(delta: float) -> void:
	if controller == null:
		return
	# Source d'entrée : main nue si le casque la voit, sinon manette, sinon on fige la pose
	var tr := _hand_tracker()
	var was_pinch := _pinch
	if tr:
		source = Source.HAND
		_update_hand(tr, delta)
	elif sim or controller.get_has_tracking_data():
		source = Source.CONTROLLER
		_have_joints = false
		_pinch = false
		_fist = false
		_open_t = 0.0
		_last_xf = controller.global_transform
	else:
		source = Source.NONE
		_have_joints = false
	if hand_model:
		hand_model.visible = source == Source.CONTROLLER
	global_transform = _last_xf
	_sq = lerpf(_sq, _raw_squeeze(), 1.0 - exp(-delta * 30.0))
	_update_edges()

	# Survol : instrument sous les doigts, sinon visé par le rayon
	var best: Instrument = null
	var by_ray := false
	var pp := pinch_point()
	if held == null and source != Source.NONE:
		var best_d := GRAB_NEAR if source == Source.HAND else 0.11
		for inst in instruments:
			if inst.parked:
				continue
			var d := _dist_to_instrument(inst, pp)
			if d < best_d:
				best_d = d
				best = inst
		if best == null:
			var aim := _aim_ray()
			var best_off := 0.05
			for inst in instruments:
				if inst.parked:
					continue
				var to: Vector3 = inst.global_position - aim[0]
				var along: float = to.dot(aim[1])
				if along < 0.15 or along > 2.2:
					continue
				var off: float = (to - aim[1] * along).length()
				if off < best_off + along * 0.02:
					best_off = off
					best = inst
					by_ray = true
	set_hover(best)

	# Prendre / lâcher
	if source == Source.HAND:
		if held == null and best and ((_pinch and not was_pinch) or (_fist and not _grip_was)):
			take_requested.emit(self, best)
		elif held == null and _pinch and not was_pinch:
			pinched.emit(self)
		elif held and _open_t >= RELEASE_HOLD:
			_open_t = 0.0
			put_back_requested.emit(self)
		_grip_was = _fist
	else:
		var grip := _grip()
		if grip and not _grip_was:
			if held:
				put_back_requested.emit(self)
			elif best:
				take_requested.emit(self, best)
		_grip_was = grip

	# Instrument tenu : posé dans les doigts, corrigé pour ne rien traverser
	_offset = _offset.lerp(Vector3.ZERO, 1.0 - exp(-delta * 12.0))
	if held and source != Source.NONE:
		var want := _held_pose()
		var q := Quaternion(want.basis.orthonormalized())
		_rot = q if _grab_blend < 0.01 else _rot.slerp(q, 1.0 - exp(-delta * 40.0))
		want.basis = Basis(_rot)
		if _grab_blend < 1.0:
			_grab_blend = minf(1.0, _grab_blend + delta / 0.14)
			var e := _grab_blend * _grab_blend * (3.0 - 2.0 * _grab_blend)
			want = _grab_from.interpolate_with(want, e)
		_raw_tip = want * held.tip_local
		held.place(want)
		held.set_squeeze(_sq)
		_offset = Vector3.UP * maxf(held.correction, _offset.y)
		_after_place(patient)
		if hand_model and hand_model.has_method("force_grip_trigger"):
			hand_model.force_grip_trigger(0.85, _sq * 0.6 + 0.2)
	elif hand_model and hand_model.has_method("force_grip_trigger"):
		hand_model.force_grip_trigger(-1.0, -1.0)
	if hand_model:
		hand_model.position = controller.global_basis.inverse() * _offset if _offset.length() > 0.0001 else Vector3.ZERO

	# Dessin du gant suivi (repoussé avec l'instrument s'il bute)
	_visual.visible = source == Source.HAND
	if source == Source.HAND:
		_visual.global_transform = Transform3D.IDENTITY
		var pts := []
		for p in _j:
			pts.append(p + _offset)
		_pose_glove(pts)

	# Rayon visible seulement main vide quand il vise un instrument (ou à la manette)
	ray.visible = held == null and source != Source.NONE and (by_ray or source == Source.CONTROLLER)
	if ray.visible:
		var aim := _aim_ray()
		var length := 0.5
		if best:
			length = clampf((best.global_position - aim[0]).dot(aim[1]), 0.05, 2.2)
		_ray_mat.albedo_color = Color(0.3, 1.0, 0.9, 0.5 if best else 0.15)
		ray.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, aim[1])), aim[0] + aim[1] * length * 0.5)
		ray.scale = Vector3(1, length, 1)


## Tenue « crayon » dans le repère de la paume : vers l'avant, incliné côté paume, un peu vers le pouce.
func _thumb_sign() -> float:
	return 1.0 if is_left else -1.0


func _canonical_grip() -> Vector3:
	return Vector3(0.022 * _thumb_sign(), -0.033, -0.078)


func _axis_local() -> Vector3:
	return Vector3(0.12 * _thumb_sign(), -0.574, -0.819).normalized()


## Prise de l'instrument : il glisse doucement de sa place jusque dans les doigts.
func take(inst: Instrument) -> void:
	if inst == held:
		return
	_hold_local = _canonical_grip()
	if source == Source.HAND and _have_joints:
		var local := _last_xf.basis.inverse() * (pinch_point() - _last_xf.origin)
		_hold_local = _canonical_grip() + (local - _canonical_grip()).limit_length(0.025)
	_grab_from = inst.global_transform
	_grab_blend = 0.0
	super.take(inst)
	_rot = Quaternion(inst.global_transform.basis.orthonormalized())


## Distance du point de pincement à l'instrument (tout le long du manche).
func _dist_to_instrument(inst: Instrument, p: Vector3) -> float:
	var a := inst.global_transform * inst.back_local
	var b := inst.tip_global()
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return minf((a + ab * k).distance_to(p) + 0.01, inst.grip_global().distance_to(p))


## Rayon de visée : de l'épaule vers la main (main nue), ou dans l'axe de la manette.
func _aim_ray() -> Array:
	if source == Source.HAND and camera:
		var shoulder := camera.global_position + Vector3.DOWN * 0.22 + camera.global_basis.x * (-0.17 if is_left else 0.17)
		var from := pinch_point()
		return [from, (from - shoulder).normalized()]
	return [pinch_point(), _ctrl_axis()]


func _over_tray(p: Vector3) -> bool:
	var m := InstrumentTray.MAYO_POS
	return absf(p.x - m.x) < 0.28 and absf(p.z - m.z) < 0.24 and p.y < InstrumentTray.TRAY_Y + 0.25
