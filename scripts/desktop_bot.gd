class_name DesktopBot
extends BotDriver
## Robot de test du mode écran : simule de vrais événements souris / clavier
## (Input.parse_input_event) et une position de souris.

var rig: DesktopRig
var hand: DesktopHand
var home := Vector3(0.12, 1.6, 0.6)


func setup(p_rig: DesktopRig, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	rig = p_rig
	hand = rig.hand
	proc = p_proc
	patient = p_patient
	tray = p_tray
	prefix = "DESKTEST"
	home = rig.position
	hand.sim_mouse = Vector2(640, 360)


func mouse_button(button: MouseButton, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = hand.sim_mouse
	ev.global_position = hand.sim_mouse
	Input.parse_input_event(ev)


func mouse_motion(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = hand.sim_mouse
	Input.parse_input_event(ev)


func key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Oriente la vue vers `p` puis place la souris dessus (sur la surface visée par le rayon).
func aim(p: Vector3) -> void:
	var d := (p - rig.camera.global_position).normalized()
	rig.yaw = atan2(-d.x, -d.z)
	rig.pitch = clampf(asin(d.y), deg_to_rad(-85), deg_to_rad(30))
	rig._apply_look()
	var on_patient := p.x > -0.64 and p.x < 1.1 and absf(p.z) < 0.3
	var surf := Vector3(p.x, Patient.body_height(p.x, p.z), p.z) if on_patient else p
	hand.sim_mouse = rig.camera.unproject_position(surf)


## Attend que la pointe de l'instrument soit arrivée sous la souris.
func _settle() -> void:
	var last := hand.tip()
	for i in 90:
		await _frames(1)
		var now := hand.tip()
		if now.distance_to(last) < 0.0005 and i > 3:
			break
		last = now


func take(inst_id: String) -> void:
	if hand.held and hand.held.id == inst_id:
		return
	var idx := tray.ordered.find(tray.instruments[inst_id])
	key(KEY_1 + idx)
	await _frames(3)


func put_back_all() -> void:
	mouse_button(MOUSE_BUTTON_LEFT, false)
	mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	if hand.held:
		key(KEY_R)
	hand.lift = 0.0
	rig.position = home


func tip_to(p: Vector3, frames_n := 12) -> void:
	aim(p)
	if frames_n > 4:
		await _settle()
	else:
		await _frames(frames_n)


func trigger(down: bool) -> void:
	mouse_button(MOUSE_BUTTON_LEFT, down)


func held_id() -> String:
	return hand.held.id if hand.held else ""


func debug_state() -> String:
	var tip := hand.tip()
	return "tenu=%s tip=%s peau=%.3f lift=%.3f auto=%.3f trace=%.2f proj=%s souris=%s" % [held_id(), tip, Patient.body_height(tip.x, tip.z), hand.lift, hand.auto_lift, proc._trace, patient.incision_project(tip), hand.sim_mouse]
