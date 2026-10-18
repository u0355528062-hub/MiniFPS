class_name Player
extends CharacterBody3D
## Urgentiste à la première personne : ZQSD (ou WASD, flèches) pour marcher, souris pour regarder,
## Maj pour aller plus vite, Ctrl pour se pencher. Le viseur désigne ce qu'on peut utiliser (zone
## du patient, appareil, chariot...) : clic gauche (ou E) pour l'utiliser. En baissant la tête, on voit
## son corps (tunique et pantalon de bloc, sabots, mains nues ou gantées), qui se penche avec lui.

signal pause_requested
signal interact_requested(it: Interactable)
signal key_action(action: String)

const EYE := 1.66
const LEAN_DOWN := 0.12
const LEAN_FWD := 0.28
const WALK := 1.4
const RUN := 2.6
const REACH := 1.9
const BODY_GLB := "res://assets/models/medecin.glb"
## Inclinaison du buste quand on se penche (degrés)
const BODY_LEAN := 24.0

var camera: Camera3D
var head: Node3D
var enabled := true  ## faux pendant les menus et les vues rapprochées
var crouch := 0.0
var aimed: Interactable
var sim_look := Vector2.INF
var sim_lean := -1.0

var body: Node3D  ## corps de l'urgentiste (sans tête : la caméra est à la place des yeux)
var _buste: Node3D
var _hands_mi: Array = []  ## [MeshInstance3D, surface] des mains (gants)
var _gloved := false
var _yaw := 0.0
var _pitch := -0.35
var _bob_t := 0.0
var _bob := Vector3.ZERO


func build(at: Vector3, look_at_point: Vector3) -> void:
	collision_layer = 1
	collision_mask = 1
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
	camera.near = 0.03
	camera.far = 40.0
	camera.fov = Settings.fov
	head.add_child(camera)
	camera.current = true
	position = at
	floor_max_angle = deg_to_rad(50)
	look_towards(look_at_point)
	_build_body()


## Corps vu à la première personne (tools/blender/build_mains.py) : pieds à l'origine, yeux à la
## verticale de l'origine, regard vers -Z.
func _build_body() -> void:
	var sc: PackedScene = load(BODY_GLB)
	body = sc.instantiate()
	body.name = "Corps"
	add_child(body)
	Hands.dress(body)
	_buste = body.find_child("Buste", true, false) as Node3D
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			if src and src.resource_name.to_lower().begins_with("main"):
				_hands_mi.append([m3, i])
	_set_gloves(false)


## Mains nues ou gantées (gants nitrile).
func _set_gloves(on: bool) -> void:
	_gloved = on
	for e in _hands_mi:
		(e[0] as MeshInstance3D).set_surface_override_material(e[1], Hands.glove_mat() if on else Hands.skin_mat())


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var k := 0.0022 * Settings.sensitivity
		_yaw -= m.relative.x * k
		_pitch -= m.relative.y * k * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch, deg_to_rad(-86), deg_to_rad(80))
		_apply_look()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and aimed:
			interact_requested.emit(aimed)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_E:
				if aimed:
					interact_requested.emit(aimed)
			KEY_T:
				key_action.emit("parler")
			KEY_TAB:
				key_action.emit("dossier")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		pause_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_look() -> void:
	rotation.y = _yaw
	head.rotation.x = _pitch


func look_towards(p: Vector3) -> void:
	var dh := p - global_position
	_yaw = atan2(-dh.x, -dh.z)
	_apply_look()
	var d := p - (global_position + Vector3.UP * EYE)
	_pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-86), deg_to_rad(80))
	_apply_look()


func eye_transform() -> Transform3D:
	return camera.global_transform


## Ce que vise le viseur (objet utilisable à portée).
func _update_aim() -> void:
	aimed = null
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, Patient.LAYER_INTERACT | 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Interactable and (hit["collider"] as Interactable).enabled:
		aimed = hit["collider"]


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	var active := enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if active:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			input.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			input.y += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			input.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			input.x += 1.0
	input = input.limit_length(1.0)
	var run := active and Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := (RUN if run else WALK) * lerpf(1.0, 0.6, crouch)
	var wish := (transform.basis * Vector3(input.x, 0, input.y)) * speed
	var accel := 10.0 if input != Vector2.ZERO else 14.0
	velocity.x = move_toward(velocity.x, wish.x, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z, accel * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	var want_crouch := 1.0 if active and Input.is_physical_key_pressed(KEY_CTRL) else 0.0
	if sim_lean >= 0.0:
		want_crouch = sim_lean
	crouch = move_toward(crouch, want_crouch, delta * 3.5)
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if Settings.head_bob and is_on_floor() and hspeed > 0.2:
		_bob_t += delta * hspeed * 5.2
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 4.0)
	var amp := 0.012 * clampf(hspeed / WALK, 0.0, 1.5)
	_bob = Vector3(cos(_bob_t * 0.5) * amp * 0.6, -absf(sin(_bob_t)) * amp, 0.0)
	var lean := smoothstep(0.0, 1.0, crouch)
	head.position = Vector3(0, EYE - LEAN_DOWN * lean, -LEAN_FWD * lean) + _bob
	if body:
		# Le corps n'est visible qu'à la première personne (la caméra de la vue rapprochée tourne autour
		# du patient et pourrait passer dedans)
		body.visible = enabled
		if _buste:
			_buste.rotation.x = -deg_to_rad(BODY_LEAN) * lean
		var flags: Variant = get_parent().get("flags")
		var gloves: bool = flags is Dictionary and bool((flags as Dictionary).get("gants", false))
		if gloves != _gloved:
			_set_gloves(gloves)
	camera.fov = Settings.fov
	if enabled:
		_update_aim()
	else:
		aimed = null
