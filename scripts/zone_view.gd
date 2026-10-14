class_name ZoneView
extends Node3D
## Vue rapprochée libre sur la zone du geste (thorax, bras, tête, défibrillateur...) : la caméra
## quitte les yeux du joueur et tourne autour de la zone. Clic droit maintenu : tourner autour ;
## molette : rapprocher / éloigner ; ZQSD : décaler ; clic gauche : utiliser l'objet en main là où
## pointe la souris (la souris est libre). Échap, Espace ou Retour arrière : revenir à la vue normale.

signal exited
signal entered(zone: String)

const TRANSITION := 0.45

var camera: Camera3D
var player: Player
var gestures: Node  ## Gestures
var active := false
var zone := ""
var title := ""
var hit := {}  ## ce que vise la souris : position, normale, objet
var mouse_left := false
var locked := false  ## un geste garde la main (massage) : la caméra ne bouge pas

var _pivot0 := Vector3.ZERO
var _pivot := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.9
var _dist := 0.5
var _dmin := 0.15
var _dmax := 1.2
var _orbit := false
var _t := 1.0
var _from := Transform3D.IDENTITY
var _leaving := false
var _presets := {}


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "CameraZone"
	camera.near = 0.01
	camera.far = 30.0
	camera.fov = 50.0
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_transition = 0.8
	attrs.dof_blur_amount = 0.04
	camera.attributes = attrs
	add_child(camera)


## Réglage d'une vue : point regardé, angle autour (0 = depuis le côté gauche du patient, +Z),
## inclinaison (degrés), distance et limites.
func define(id: String, label: String, pivot: Vector3, yaw: float, pitch_deg: float, dist: float, dmin := 0.12, dmax := 1.2) -> void:
	_presets[id] = {"label": label, "p": pivot, "yaw": yaw, "pitch": deg_to_rad(pitch_deg), "d": dist, "min": dmin, "max": dmax}


func has_preset(id: String) -> bool:
	return _presets.has(id)


func enter(id: String) -> void:
	var pr: Dictionary = _presets[id]
	zone = id
	title = pr["label"]
	_pivot0 = pr["p"]
	_pivot = _pivot0
	_yaw = pr["yaw"]
	_pitch = pr["pitch"]
	_dist = pr["d"]
	_dmin = pr["min"]
	_dmax = pr["max"]
	_from = player.camera.global_transform
	_t = 0.0
	_leaving = false
	active = true
	locked = false
	mouse_left = false
	player.enabled = false
	camera.global_transform = _from
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	entered.emit(id)


func exit() -> void:
	if not active or _leaving:
		return
	_leaving = true
	_t = 0.0
	_from = camera.global_transform
	mouse_left = false
	locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _want_xf() -> Transform3D:
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	var eye := _pivot + off
	return Transform3D(Basis.IDENTITY, eye).looking_at(_pivot, Vector3.UP if absf(_pitch) < 1.5 else Vector3(-sin(_yaw), 0, -cos(_yaw)))


func _process(delta: float) -> void:
	if not active:
		return
	_t = minf(1.0, _t + delta / TRANSITION)
	var k := smoothstep(0.0, 1.0, _t)
	if _leaving:
		var to := player.camera.global_transform
		camera.global_transform = Transform3D(Basis(Quaternion(_from.basis.orthonormalized()).slerp(Quaternion(to.basis.orthonormalized()), k)), _from.origin.lerp(to.origin, k))
		if _t >= 1.0:
			active = false
			_leaving = false
			player.camera.current = true
			player.enabled = true
			zone = ""
			exited.emit()
		return
	# Décalage au clavier (dans le plan de l'écran)
	if not locked:
		var mv := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			mv.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			mv.y -= 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			mv.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			mv.x += 1.0
		if mv != Vector2.ZERO:
			var right := camera.global_basis.x
			var fwd := -camera.global_basis.z
			fwd.y = 0.0
			fwd = fwd.normalized()
			_pivot += (right * mv.x + fwd * mv.y) * delta * 0.35 * clampf(_dist, 0.2, 1.0)
			var d := _pivot - _pivot0
			if d.length() > 0.35:
				_pivot = _pivot0 + d.normalized() * 0.35
	var want := _want_xf()
	if _t < 1.0:
		camera.global_transform = Transform3D(Basis(Quaternion(_from.basis.orthonormalized()).slerp(Quaternion(want.basis.orthonormalized()), k)), _from.origin.lerp(want.origin, k))
	else:
		camera.global_transform = want
	var attrs := camera.attributes as CameraAttributesPractical
	attrs.dof_blur_far_distance = _dist + 0.35
	_update_hit()


func _update_hit() -> void:
	hit = {}
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 3.0, Patient.LAYER_BODY | Patient.LAYER_DEVICE)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		hit = {"pos": r["position"], "normal": r["normal"], "collider": r["collider"], "device": r["collider"] is Interactable}


## Point de l'écran -> rayon (pour les gestes qui suivent la souris hors du corps).
func mouse_ray() -> Array:
	var mp := get_viewport().get_mouse_position()
	return [camera.project_ray_origin(mp), camera.project_ray_normal(mp)]


func _unhandled_input(event: InputEvent) -> void:
	if not active or _leaving:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var kc := (event as InputEventKey).physical_keycode
		if kc in [KEY_ESCAPE, KEY_SPACE, KEY_BACKSPACE]:
			get_viewport().set_input_as_handled()
			if gestures and gestures.call("cancel_current"):
				return
			exit()
			return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				_orbit = mb.pressed and not locked
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed and not locked:
					_dist = maxf(_dmin, _dist * 0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed and not locked:
					_dist = minf(_dmax, _dist / 0.9)
			MOUSE_BUTTON_LEFT:
				mouse_left = mb.pressed
				if gestures:
					if mb.pressed:
						gestures.call("press", hit)
					else:
						gestures.call("release", hit)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbit:
			_yaw -= mm.relative.x * 0.006
			_pitch = clampf(_pitch + mm.relative.y * 0.006, deg_to_rad(-10), deg_to_rad(88))
		elif mouse_left and gestures:
			gestures.call("drag", hit, mm.relative)
