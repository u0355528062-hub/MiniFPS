class_name VRRig
extends XROrigin3D
## Joueur VR (Quest 3 via Air Link / Quest Link) : casque + deux mains gantées.
## Stick gauche : se déplacer doucement. Stick droit : tourner par crans. B / Y : recentrer.

var camera: XRCamera3D
var hands: Array[SurgeonHand] = []
var left: XRController3D
var right: XRController3D
var _snap_ready := true
var _recenter_was := false


func build() -> void:
	camera = XRCamera3D.new()
	camera.near = 0.02
	camera.far = 60.0
	add_child(camera)
	left = _controller("left_hand", true)
	right = _controller("right_hand", false)


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
	hands.append(h)
	return c


func _process(delta: float) -> void:
	# Déplacement fin (pour se placer face au champ)
	var mv := left.get_vector2("primary")
	if mv.length() > 0.2:
		var fwd := -camera.global_basis.z
		fwd.y = 0
		fwd = fwd.normalized()
		var rgt := Vector3(-fwd.z, 0, fwd.x)
		global_position += (rgt * mv.x + fwd * mv.y) * 0.6 * delta
	# Rotation par crans de 30°
	var turn := right.get_vector2("primary").x
	if absf(turn) > 0.7 and _snap_ready:
		_snap_ready = false
		var pivot := camera.global_position
		var t := Transform3D(Basis(Vector3.UP, deg_to_rad(-30.0 * signf(turn))), Vector3.ZERO)
		global_transform = Transform3D.IDENTITY.translated(pivot) * t * Transform3D.IDENTITY.translated(-pivot) * global_transform
	elif absf(turn) < 0.3:
		_snap_ready = true
	# Recentrer : remet la tête au poste du chirurgien
	var rc := left.is_button_pressed("by_button") or right.is_button_pressed("by_button")
	if rc and not _recenter_was:
		recenter()
	_recenter_was = rc


## Place la tête du joueur à la position du chirurgien, face à la table.
func recenter(target := Vector3(0.12, 0.0, 0.62)) -> void:
	var head := camera.position
	var yaw := atan2(-camera.transform.basis.z.x, -camera.transform.basis.z.z)
	rotation = Vector3(0, -yaw, 0)
	var head_world := global_transform.basis * Vector3(head.x, 0, head.z)
	global_position = Vector3(target.x, 0, target.z) - head_world
