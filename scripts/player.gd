class_name Player
extends CharacterBody3D
## Joueur à la première personne : ZQSD (ou WASD, flèches) pour marcher, souris pour regarder,
## Maj pour aller plus vite, Ctrl pour se pencher (regard plus près du patient).
## Clic droit maintenu : précision (zoom, souris ralentie, profondeur de champ) pour les gestes fins.

signal pause_requested
signal view_mode_requested
signal continue_requested

const EYE := 1.66
const CROUCH := 0.32
const WALK := 1.35
const RUN := 2.6

var camera: Camera3D
var head: Node3D
var hand: PlayerHand
var enabled := true  ## faux pendant les menus
var precision := 0.0  ## 0..1 (zoom de précision)
var crouch := 0.0
var sim_look := Vector2.INF  ## tests : orientation imposée (lacet, tangage en radians)

var _yaw := 0.0
var _pitch := -0.35
var _bob_t := 0.0
var _bob := Vector3.ZERO
var _attrs: CameraAttributesPractical


func build(at: Vector3, look_at_point: Vector3) -> void:
	var cap := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.22
	shape.height = 1.7
	cap.shape = shape
	cap.position.y = 0.85
	add_child(cap)
	head = Node3D.new()
	head.name = "Tete"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.02
	camera.far = 40.0
	camera.fov = Settings.fov
	head.add_child(camera)
	_attrs = CameraAttributesPractical.new()
	_attrs.dof_blur_far_enabled = false
	_attrs.dof_blur_amount = 0.06
	camera.attributes = _attrs
	camera.current = true
	position = at
	var d := look_at_point - (at + Vector3.UP * EYE)
	_yaw = atan2(-d.x, -d.z)
	_pitch = atan2(d.y, Vector2(d.x, d.z).length())
	hand = PlayerHand.new()
	hand.name = "Main"
	hand.camera = camera
	hand.player = self
	add_child(hand)
	floor_max_angle = deg_to_rad(50)
	_apply_look()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var k := 0.0022 * Settings.sensitivity * (camera.fov / Settings.fov)
		_yaw -= m.relative.x * k
		_pitch -= m.relative.y * k * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch, deg_to_rad(-86), deg_to_rad(80))
		_apply_look()
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_V:
				view_mode_requested.emit()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		pause_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_look() -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch


## Orientation imposée (robots de test, cinématique).
func look_towards(p: Vector3) -> void:
	var d := p - camera.global_position
	_yaw = atan2(-d.x, -d.z)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-86), deg_to_rad(80))
	_apply_look()


func _key(phys: Key) -> bool:
	return Input.is_physical_key_pressed(phys)


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var active := enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if active:
		if _key(KEY_W) or _key(KEY_UP):
			input.y -= 1.0
		if _key(KEY_S) or _key(KEY_DOWN):
			input.y += 1.0
		if _key(KEY_A) or _key(KEY_LEFT):
			input.x -= 1.0
		if _key(KEY_D) or _key(KEY_RIGHT):
			input.x += 1.0
	input = input.limit_length(1.0)
	var run := active and _key(KEY_SHIFT)
	var speed := (RUN if run else WALK) * lerpf(1.0, 0.35, precision) * lerpf(1.0, 0.6, crouch)
	var wish := (transform.basis * Vector3(input.x, 0, input.y)) * speed
	var accel := 10.0 if input != Vector2.ZERO else 14.0
	velocity.x = move_toward(velocity.x, wish.x, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z, accel * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	# Se pencher, précision, balancement de la tête
	var want_crouch := 1.0 if active and _key(KEY_CTRL) else 0.0
	crouch = move_toward(crouch, want_crouch, delta * 3.5)
	var want_prec := 1.0 if active and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 0.0
	precision = move_toward(precision, want_prec, delta * 4.0)
	var pe := smoothstep(0.0, 1.0, precision)
	camera.fov = lerpf(Settings.fov, 30.0, pe)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if Settings.head_bob and is_on_floor() and hspeed > 0.2:
		_bob_t += delta * hspeed * 5.2
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 4.0)
	var amp := 0.012 * clampf(hspeed / WALK, 0.0, 1.5) * (1.0 - pe)
	_bob = Vector3(cos(_bob_t * 0.5) * amp * 0.6, -absf(sin(_bob_t)) * amp, 0.0)
	head.position = Vector3(0, EYE - CROUCH * smoothstep(0.0, 1.0, crouch), 0) + _bob
	# Profondeur de champ en précision : l'arrière-plan s'estompe derrière le point visé
	if _attrs:
		var aim := hand.aim_distance()
		_attrs.dof_blur_far_enabled = pe > 0.05 and aim < 3.0
		_attrs.dof_blur_far_distance = aim + 0.25
		_attrs.dof_blur_far_transition = 0.6
		_attrs.dof_blur_amount = 0.05 * pe
