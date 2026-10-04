class_name BotDriver
extends Node
## Base commune des robots de test. Chaque robot (classique, VR, souris) fournit les gestes
## élémentaires ; `do_step` sait terminer n'importe quel type d'étape depuis l'état courant.

var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var ok := true
var prefix := "BOT"


func fail(msg: String) -> void:
	print(prefix, " ÉCHEC : ", msg)
	ok = false


func _frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


# ---------------------------------------------------------------- Gestes élémentaires (à redéfinir)

func take(_inst_id: String) -> void:
	pass


func put_back_all() -> void:
	pass


## Amène la pointe de l'instrument tenu sur `p`.
func tip_to(_p: Vector3, _frames_n := 12) -> void:
	pass


func trigger(_down: bool) -> void:
	pass


func held_id() -> String:
	return ""


func debug_state() -> String:
	return ""


func click() -> void:
	trigger(true)
	await _frames(3)
	trigger(false)
	await _frames(3)


func cleanup() -> void:
	trigger(false)
	await _frames(3)
	await put_back_all()
	await _wait(0.8)  # laisse finir les animations (retour d'instrument, objet qui retombe)


# ---------------------------------------------------------------- Étapes génériques

func start() -> void:
	var guard := 0
	while proc.step < 0 and guard < 5:
		guard += 1
		proc.on_continue()
		await _frames(2)


func run_all() -> void:
	await start()
	while proc.step >= 0 and proc.step < proc.steps.size():
		var s := proc.step
		await do_step()
		if proc.step == s:
			break
		print(prefix, " étape réussie : ", proc.steps[s]["id"])
	await cleanup()
	for inst in tray.ordered:
		if not inst.parked and inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			fail("%s n'est pas revenu sur la table" % inst.id)
	var done := proc.step >= proc.steps.size()
	if not done:
		fail("opération inachevée")
	print(prefix, " ", "OK" if ok and done else "ÉCHEC", " — ", proc.op.name, " — erreurs : ", proc.errors)


func do_step() -> void:
	var si := proc.step
	if si < 0 or si >= proc.steps.size():
		return
	await cleanup()
	var s: Dictionary = proc.steps[si]
	await take(s["inst"])
	if held_id() != s["inst"]:
		fail("impossible de prendre %s" % s["inst"])
	match s["kind"]:
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			var rx := patient.paint_r.x + 0.005
			var rz := patient.paint_r.y + 0.005
			await tip_to(Vector3(c.x - rx, Patient.body_height(c.x - rx, c.z - rz) + 0.004, c.z - rz), 14)
			trigger(true)
			var rows := int(ceil(rz * 2.0 / 0.014)) + 1
			var cols := int(ceil(rx * 2.0 / 0.011)) + 1
			for row in rows:
				for k in cols:
					var x := c.x - rx + (k if row % 2 == 0 else cols - 1 - k) * (rx * 2.0 / (cols - 1))
					var z := c.z - rz + row * (rz * 2.0 / (rows - 1))
					await tip_to(Vector3(x, Patient.body_height(x, z) + 0.004, z), 2)
					if proc.step != si:
						break
				if proc.step != si:
					break
			trigger(false)
		"trace":
			var t0 := maxf(proc._trace, 0.0)
			await tip_to(patient.incision_point(t0) + Vector3.UP * 0.003, 16)
			trigger(true)
			var n := int(clampf(patient.INC_A.distance_to(patient.INC_B) / 0.0015, 40, 220))
			for i in n + 1:
				await tip_to(patient.incision_point(lerpf(t0, 1.0, float(i) / n)) + Vector3.UP * 0.002, 2)
				if proc.step != si:
					break
			if proc.step == si:
				await tip_to(patient.incision_point(1.0) + Vector3.UP * 0.002, 16)
			trigger(false)
		"place":
			await tip_to(s["target"].call(), 16)
			await click()
		"hold":
			await tip_to(s["target"].call(), 16)
			trigger(true)
			for i in int((s.get("duration", 1.5) + 2.0) * 90):
				await tip_to(s["target"].call(), 1)
				if proc.step != si:
					break
			trigger(false)
		"push":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			var depth: float = s["depth"]
			await tip_to(entry, 16)
			trigger(true)
			for i in 120:
				await tip_to(entry + axis * depth * minf(1.15, (i + 1) / 90.0), 1)
				if proc.step != si:
					break
			trigger(false)
		"lift":
			await tip_to(s["target"].call(), 16)
			trigger(true)
			await _frames(2)
			var start_p: Vector3 = s["target"].call()
			for i in 140:
				await tip_to(start_p + Vector3.UP * minf(0.12, i * 0.0015), 1)
				if proc.step != si:
					break
			trigger(false)
		"carry":
			await _wait(0.6)
			var obj: Node3D = s["object"].call()
			await tip_to(obj.global_position, 16)
			trigger(true)
			await _frames(4)
			var from := obj.global_position
			var dest: Vector3 = s["dest"].call() + Vector3.UP * 0.06
			for i in 40:
				await tip_to(from.lerp(dest, (i + 1) / 40.0), 1)
			await tip_to(dest, 10)
			trigger(false)
		"points":
			var pts: Array = s["points"].call()
			for k in range(proc._point_i, pts.size()):
				await tip_to(pts[k], 14)
				await click()
	await _frames(6)
	if proc.step == si:
		fail("étape %s non terminée depuis l'état courant — %s" % [s["id"], debug_state()])
