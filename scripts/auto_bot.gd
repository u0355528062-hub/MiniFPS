class_name AutoBot
extends SurgeonHand
## Robot de test : réalise toute l'appendicectomie avec les mêmes règles qu'un joueur
## (prendre l'instrument, amener la pointe, gâchette). Sert à vérifier que chaque étape aboutit.

var bot_tip := Vector3(0.4, 1.3, 0.4)
var bot_trigger := false


func trigger_value() -> float:
	return 1.0 if bot_trigger else 0.0


func tip() -> Vector3:
	return bot_tip if held else global_position


func _process(_delta: float) -> void:
	_update_edges()
	if held:
		held.pose_tip(bot_tip, Vector3(0.2, -0.85, 0.45).normalized(), Vector3.UP)


func _frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _move(to: Vector3, frames := 20) -> void:
	var from := bot_tip
	for i in frames:
		bot_tip = from.lerp(to, float(i + 1) / frames)
		await get_tree().process_frame


func _click() -> void:
	bot_trigger = true
	await _frames(3)
	bot_trigger = false
	await _frames(2)


func run(proc: Procedure, patient: Patient, tray: InstrumentTray) -> void:
	await _frames(5)
	proc.on_continue()
	var t0 := Time.get_ticks_msec()
	var ok := true
	while proc.step < Procedure.STEPS.size():
		var s := proc.step
		var id: String = Procedure.STEPS[s]["id"]
		take_requested.emit(self, tray.instruments[Procedure.STEPS[s]["inst"]])
		await _frames(2)
		match id:
			"badigeon":
				bot_trigger = true
				var c := patient.center
				for row in 13:
					var z := c.z - 0.09 + row * 0.015
					for k in 16:
						var x := c.x - 0.08 + (k if row % 2 == 0 else 15 - k) * 0.0107
						bot_tip = Vector3(x, Patient.body_height(x, z) + 0.005, z)
						await _frames(1)
						if proc.step != s:
							break
					if proc.step != s:
						break
				bot_trigger = false
			"incision":
				await _move(patient.incision_point(0.0) + Vector3.UP * 0.004)
				bot_trigger = true
				for i in 61:
					bot_tip = patient.incision_point(i / 60.0) + Vector3.UP * 0.003
					await _frames(1)
				bot_trigger = false
			"ecarteur1", "ecarteur2":
				await _move(patient.retractor_slot(-1.0 if id == "ecarteur1" else 1.0))
				await _click()
			"saisie":
				await _move(patient.appendix_tip)
				bot_trigger = true
				await _frames(2)
				for i in 60:
					bot_tip += Vector3.UP * 0.0015
					await _frames(1)
					if proc.step != s:
						break
				bot_trigger = false
			"ligature":
				await _move(patient.appendix_point(0.18))
				await _click()
			"section":
				await _move(patient.appendix_point(0.32))
				await _click()
			"retrait":
				await _frames(2)
				await _move(proc._piece.global_position)
				bot_trigger = true
				await _frames(3)
				await _move(tray.dish_center + Vector3.UP * 0.06, 40)
				bot_trigger = false
				await _frames(5)
			"suture":
				for t in Procedure.STITCH_T:
					await _move(patient.incision_point(t) + Vector3.UP * 0.002, 10)
					await _click()
		await _frames(3)
		if proc.step == s:
			print("AUTOTEST ÉCHEC à l'étape ", id)
			ok = false
			break
		print("AUTOTEST étape réussie : ", id)
	put_back_requested.emit(self)
	print("AUTOTEST ", "OK" if ok else "ÉCHEC", " — erreurs : ", proc.errors, " — durée simulée : ", (Time.get_ticks_msec() - t0) / 1000.0, " s")
