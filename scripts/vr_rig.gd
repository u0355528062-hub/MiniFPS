class_name VRRig
extends XROrigin3D
## Joueur VR (Quest 3 via Air Link / Quest Link) : casque + deux mains gantées.
## Stick gauche : se déplacer doucement. Stick droit : tourner par crans.
## B / Y : se replacer face au patient. A / X : continuer.
## La hauteur des yeux est ramenée à 1,62 m : la table est à bonne hauteur que l'on soit
## grand, petit, debout ou assis.

signal continue_pressed
signal menu_moved(delta: int)
signal hand_pinch(left: bool)  ## pincement main nue (menus sans manettes)

const EYE_HEIGHT := 1.62

var surgeon_spot := Vector3(0.12, 0.0, 0.6)
var _menu_ready := true

var camera: XRCamera3D
var hands: Array[SurgeonHand] = []
var left: XRController3D
var right: XRController3D
var sim := false  ## test robot : pas de casque, entrées imposées
var _snap_ready := true
var _recenter_was := false
var _continue_was := false
var _placed := false


func build() -> void:
	camera = XRCamera3D.new()
	camera.near = 0.02
	camera.far = 60.0
	add_child(camera)
	left = _controller("left_hand", true)
	right = _controller("right_hand", false)
	var xr := XRServer.find_interface("OpenXR")
	if xr and xr.has_signal("pose_recentered"):
		# Appui long sur le bouton Meta : on se replace aussi
		xr.connect("pose_recentered", func() -> void: recenter.call_deferred())


func _controller(tracker: String, is_left: bool) -> XRController3D:
	var c := XRController3D.new()
	c.tracker = tracker
	c.pose = "grip"
	c.name = "Manette_" + ("G" if is_left else "D")
	add_child(c)
	var h := VRHand.new()
	h.name = "Main_" + ("G" if is_left else "D")
	add_child(h)
	h.setup(c, is_left)
	h.pinched.connect(func(_h: VRHand) -> void: hand_pinch.emit(is_left))
	hands.append(h)
	return c


func _vec(c: XRController3D, action: String) -> Vector2:
	return Vector2.ZERO if sim else c.get_vector2(action)


func _btn(c: XRController3D, action: String) -> bool:
	return false if sim else c.is_button_pressed(action)


func _process(delta: float) -> void:
	# Premier placement dès que le casque est suivi (la position vaut 0 avant)
	if not _placed and not sim and camera.position.length() > 0.05:
		_placed = true
		recenter()

	# Déplacement fin (pour se placer face au champ)
	var mv := _vec(left, "primary")
	if mv.length() > 0.2:
		var fwd := -camera.global_basis.z
		fwd.y = 0
		if fwd.length() > 0.01:
			fwd = fwd.normalized()
			var rgt := Vector3(-fwd.z, 0, fwd.x)
			global_position += (rgt * mv.x + fwd * mv.y) * 0.5 * delta
	# Rotation par crans de 30°
	var turn := _vec(right, "primary").x
	if absf(turn) > 0.7 and _snap_ready:
		_snap_ready = false
		var pivot := camera.global_position
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(-30.0 * signf(turn))), Vector3.ZERO)
		global_transform = Transform3D.IDENTITY.translated(pivot) * t * Transform3D.IDENTITY.translated(-pivot) * global_transform
	elif absf(turn) < 0.3:
		_snap_ready = true
	# Stick droit haut / bas : navigation dans le menu
	var vy := _vec(right, "primary").y + _vec(left, "primary").y
	if absf(vy) > 0.7 and _menu_ready:
		_menu_ready = false
		menu_moved.emit(-1 if vy > 0.0 else 1)
	elif absf(vy) < 0.3:
		_menu_ready = true
	# B / Y : se replacer
	var rc := _btn(left, "by_button") or _btn(right, "by_button")
	if rc and not _recenter_was:
		recenter()
	_recenter_was = rc
	# A / X : continuer
	var cont := _btn(left, "ax_button") or _btn(right, "ax_button")
	if cont and not _continue_was:
		continue_pressed.emit()
	_continue_was = cont


## Place la tête du joueur au poste du chirurgien, face à la table, yeux à 1,62 m.
func recenter(target := Vector3.INF) -> void:
	if target == Vector3.INF:
		target = surgeon_spot
	var head := camera.position
	var f := -camera.transform.basis.z
	var yaw := atan2(-f.x, -f.z) if Vector2(f.x, f.z).length() > 0.05 else 0.0
	rotation = Vector3(0, -yaw, 0)
	var head_world := global_transform.basis * Vector3(head.x, 0, head.z)
	var y := clampf(EYE_HEIGHT - head.y, -0.6, 1.2) if head.y > 0.05 else 0.0
	global_position = Vector3(target.x, y, target.z) - head_world
