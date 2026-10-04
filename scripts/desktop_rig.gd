class_name DesktopRig
extends Node3D
## Mode écran (sans casque) : souris + clavier.
## Clic gauche : prendre l'instrument visé / agir (maintenu). Molette : lever / baisser.
## R ou clic droit bref : reposer. Clic droit glissé : regarder. ZQSD : se déplacer.
## 1 à 8 : prendre un instrument. Espace / Entrée : continuer.

signal continue_pressed
signal menu_moved(delta: int)
signal menu_number(index: int)

var camera: Camera3D
var hand: DesktopHand
var hands: Array[SurgeonHand] = []
var yaw := 0.0
var pitch := deg_to_rad(-42.0)
var _right_down := false
var _right_moved := 0.0


func build(start := Vector3(0.12, 1.6, 0.6)) -> void:
	camera = Camera3D.new()
	camera.fov = 62
	camera.near = 0.02
	add_child(camera)
	position = start
	hand = DesktopHand.new()
	hand.name = "MainSouris"
	hand.camera = camera
	add_child(hand)
	hands.append(hand)
	_apply_look()


func _apply_look() -> void:
	camera.rotation = Vector3(pitch, yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_right_down = true
					_right_moved = 0.0
				else:
					_right_down = false
					if _right_moved < 6.0:
						hand.put_back_requested.emit(hand)
			MOUSE_BUTTON_LEFT:
				hand.mouse_left = mb.pressed
				if mb.pressed and hand.held == null and hand.hovered:
					hand.take_requested.emit(hand, hand.hovered)
					hand.swallow_click = true
				if not mb.pressed:
					hand.swallow_click = false
			MOUSE_BUTTON_WHEEL_UP:
				hand.lift = clampf(hand.lift + 0.006, -0.06, 0.25)
			MOUSE_BUTTON_WHEEL_DOWN:
				hand.lift = clampf(hand.lift - 0.006, -0.06, 0.25)
	elif event is InputEventMouseMotion and _right_down:
		var mm := event as InputEventMouseMotion
		_right_moved += mm.relative.length()
		yaw -= mm.relative.x * 0.004
		pitch = clampf(pitch - mm.relative.y * 0.004, deg_to_rad(-85), deg_to_rad(30))
		_apply_look()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		match k.physical_keycode:
			KEY_R, KEY_BACKSPACE:
				hand.put_back_requested.emit(hand)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				continue_pressed.emit()
			KEY_UP:
				menu_moved.emit(-1)
			KEY_DOWN:
				menu_moved.emit(1)
			_:
				var n := k.physical_keycode - KEY_1
				if n >= 0 and n < 9:
					menu_number.emit(n)
				if n >= 0 and n < hand.instruments.size():
					hand.take_requested.emit(hand, hand.instruments[n])


func _process(delta: float) -> void:
	var mv := Vector2.ZERO
	# Touches physiques : ZQSD sur AZERTY = WASD sur QWERTY
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y += 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y -= 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1
	if mv != Vector2.ZERO:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var rgt := Vector3(cos(yaw), 0, -sin(yaw))
		position += (fwd * mv.y + rgt * mv.x).normalized() * 0.8 * delta
	if Input.is_physical_key_pressed(KEY_E):
		position.y = minf(position.y + 0.5 * delta, 2.0)
	if Input.is_physical_key_pressed(KEY_C):
		position.y = maxf(position.y - 0.5 * delta, 1.2)
