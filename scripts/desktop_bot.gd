class_name DesktopBot
extends Node
## Test robot du mode écran : simule de vrais événements souris / clavier (Input.parse_input_event)
## et une position de souris, puis termine l'étape en cours depuis n'importe quel état.

var rig: DesktopRig
var hand: DesktopHand
var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var ok := true


func setup(p_rig: DesktopRig, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	rig = p_rig
	hand = rig.hand
	proc = p_proc
	patient = p_patient
	tray = p_tray
	hand.sim_mouse = Vector2(640, 360)


func fail(msg: String) -> void:
	print("DESKTEST ÉCHEC : ", msg)
	ok = false


func _frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


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


func _take(id: String) -> void:
	if hand.held and hand.held.id == id:
		return
	var idx := tray.ordered.find(tray.instruments[id])
	key(KEY_1 + idx)
	await _frames(3)
	if hand.held == null or hand.held.id != id:
		fail("touche %d ne donne pas %s" % [idx + 1, id])


func _click() -> void:
	mouse_button(MOUSE_BUTTON_LEFT, true)
	await _frames(3)
	mouse_button(MOUSE_BUTTON_LEFT, false)
	await _frames(3)


func cleanup() -> void:
	mouse_button(MOUSE_BUTTON_LEFT, false)
	mouse_button(MOUSE_BUTTON_RIGHT, false)
	await _frames(2)
	if hand.held:
		key(KEY_R)
	hand.lift = 0.0
	rig.position = Vector3(0.12, 1.6, 0.6)
	await _wait(0.8)


func do_step() -> void:
	var s := proc.step
	if s < 0 or s >= Procedure.STEPS.size():
		return
	await cleanup()
	var id: String = Procedure.STEPS[s]["id"]
	await _take(Procedure.STEPS[s]["inst"])
	match id:
		"badigeon":
			var c := patient.center
			aim(c)
			await _frames(2)
			mouse_button(MOUSE_BUTTON_LEFT, true)
			for row in 13:
				for k in 16:
					var x := c.x - 0.08 + (k if row % 2 == 0 else 15 - k) * 0.0107
					var z := c.z - 0.09 + row * 0.015
					aim(Vector3(x, 0, z))
					await _frames(2)
					if proc.step != s:
						break
				if proc.step != s:
					break
			mouse_button(MOUSE_BUTTON_LEFT, false)
		"incision":
			var t0 := maxf(proc._incision, 0.0)
			aim(patient.incision_point(t0))
			await _settle()
			mouse_button(MOUSE_BUTTON_LEFT, true)
			for i in 61:
				aim(patient.incision_point(lerpf(t0, 1.0, i / 60.0)))
				await _frames(2)
				if proc.step != s:
					break
			mouse_button(MOUSE_BUTTON_LEFT, false)
		"ecarteur1", "ecarteur2":
			aim(patient.retractor_slot(-1.0 if id == "ecarteur1" else 1.0))
			await _settle()
			await _click()
		"saisie":
			aim(patient.appendix_tip)
			await _settle()
			mouse_button(MOUSE_BUTTON_LEFT, true)
			for i in 120:
				await _frames(1)
				if proc.step != s:
					break
			mouse_button(MOUSE_BUTTON_LEFT, false)
		"ligature":
			aim(patient.appendix_point(0.18))
			await _settle()
			await _click()
		"section":
			aim(patient.appendix_point(0.32))
			await _settle()
			await _click()
		"retrait":
			await _wait(0.6)
			aim(proc._piece.global_position)
			await _settle()
			mouse_button(MOUSE_BUTTON_LEFT, true)
			await _frames(4)
			for i in 30:
				aim(proc._piece.global_position.lerp(tray.dish_center, (i + 1) / 30.0))
				await _frames(1)
			aim(tray.dish_center)
			await _frames(10)
			mouse_button(MOUSE_BUTTON_LEFT, false)
		"suture":
			for k in range(proc._stitch_i, Procedure.STITCH_T.size()):
				aim(patient.incision_point(Procedure.STITCH_T[k]))
				await _settle()
				await _click()
	await _frames(6)
	if proc.step == s:
		var tip := hand.tip()
		var proj := patient.incision_project(tip)
		fail("étape %s non terminée — tenu=%s tip=%s peau=%.3f lift=%.3f auto=%.3f swallow=%s gauche=%s incision=%.2f proj=%s yaw=%.2f pitch=%.2f pos=%s" % [id, hand.held.id if hand.held else "rien", tip, Patient.body_height(tip.x, tip.z), hand.lift, hand.auto_lift, hand.swallow_click, hand.mouse_left, proc._incision, proj, rig.yaw, rig.pitch, rig.position])
