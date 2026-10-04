class_name BotDriver
extends Node
## Base commune des robots de test. Chaque robot (classique, VR, souris) fournit les gestes
## élémentaires (prendre, amener la pointe quelque part — même sous la peau —, serrer les doigts) ;
## `do_step` sait terminer n'importe quel type d'étape depuis l'état courant, avec de vrais gestes.

var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var ok := true
var prefix := "BOT"
## Orientation voulue de l'instrument pour le geste en cours (zéro = tenue normale)
var want_axis := Vector3.ZERO


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


## Amène la pointe de l'instrument tenu sur `p` (les contacts peuvent l'arrêter avant).
func tip_to(_p: Vector3, _frames_n := 12) -> void:
	pass


## Serrage des doigts : 0 = ouvert, 1 = serré.
func squeeze(_v: float) -> void:
	pass


func trigger(down: bool) -> void:
	squeeze(1.0 if down else 0.0)


func held_id() -> String:
	return ""


func held_inst() -> Instrument:
	return null


func debug_state() -> String:
	return ""


func cleanup() -> void:
	squeeze(0.0)
	await _frames(3)
	await put_back_all()
	await _wait(0.8)  # laisse finir les animations (retour d'instrument, objet qui retombe)


static func skin_normal(p: Vector3) -> Vector3:
	var e := 0.004
	var hx := (Patient.body_height(p.x + e, p.z) - Patient.body_height(p.x - e, p.z)) / (2.0 * e)
	var hz := (Patient.body_height(p.x, p.z + e) - Patient.body_height(p.x, p.z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


## Monte l'instrument bien au-dessus du patient avant d'aller ailleurs (une lame qui traîne coupe).
func lift_clear() -> void:
	pass


func _above(p: Vector3, h := 0.012) -> Vector3:
	return p + Vector3.UP * h


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
	check_tray()
	var done := proc.step >= proc.steps.size()
	if not done:
		fail("opération inachevée")
	print(prefix, " ", "OK" if ok and done else "ÉCHEC", " — ", proc.op.name, " — erreurs : ", proc.errors)


func check_tray() -> void:
	for inst in tray.ordered:
		if not inst.parked and inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			fail("%s n'est pas revenu sur la table" % inst.id)


func do_step() -> void:
	var si := proc.step
	if si < 0 or si >= proc.steps.size():
		return
	await cleanup()
	var s: Dictionary = proc.steps[si]
	want_axis = Vector3.ZERO
	await take(s["inst"])
	if held_id() != s["inst"]:
		fail("impossible de prendre %s" % s["inst"])
	await lift_clear()
	match s["kind"]:
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			var rx := patient.paint_r.x + 0.005
			var rz := patient.paint_r.y + 0.005
			await tip_to(_above(Vector3(c.x - rx, Patient.body_height(c.x - rx, c.z - rz), c.z - rz)), 14)
			var rows := int(ceil(rz * 2.0 / 0.012)) + 1
			var cols := int(ceil(rx * 2.0 / 0.01)) + 1
			for row in rows:
				for k in cols:
					var x := c.x - rx + (k if row % 2 == 0 else cols - 1 - k) * (rx * 2.0 / (cols - 1))
					var z := c.z - rz + row * (rz * 2.0 / (rows - 1))
					await tip_to(Vector3(x, Patient.body_height(x, z) - 0.002, z), 2)
					if proc.step != si:
						break
				if proc.step != si:
					break
		"incise":
			# Anesthésie locale : on attend qu'elle agisse avant de couper
			while proc.anesthesia_ready_at > 0 and Time.get_ticks_msec() < proc.anesthesia_ready_at + 200:
				await _frames(5)
			var t0 := patient.cut1 if patient.has_cut() else 0.0
			await tip_to(_above(patient.incision_point(t0), 0.006), 16)
			await tip_to(patient.incision_point(t0) - Vector3.UP * 0.004, 10)
			var n := int(clampf(patient.INC_A.distance_to(patient.INC_B) / 0.0015, 40, 220))
			for i in n + 1:
				await tip_to(patient.incision_point(lerpf(t0, 1.0, float(i) / n)) - Vector3.UP * 0.004, 2)
				if i == n / 2 and OS.get_cmdline_user_args().has("--debug"):
					print("DEBUG incision ", debug_state())
				if proc.step != si:
					break
			if proc.step == si:
				await tip_to(patient.incision_point(1.0) - Vector3.UP * 0.004, 16)
			await tip_to(_above(patient.incision_point(1.0), 0.02), 6)
		"inject":
			var p: Vector3 = s["target"].call()
			want_axis = (-skin_normal(p) * 0.7 + Vector3.DOWN * 0.3).normalized()
			squeeze(0.0)
			await tip_to(_above(p, 0.01), 16)
			await tip_to(p - Vector3.UP * 0.006, 12)
			squeeze(1.0)
			for i in int((1.0 / 0.24 + 1.0) * 90):
				await tip_to(p - Vector3.UP * 0.006, 1)
				if i % 60 == 0 and OS.get_cmdline_user_args().has("--debug"):
					print("DEBUG inject ", debug_state(), " inj=", proc.st.get("inj", 0.0), " in=", proc.st.get("in", false))
				if proc.st.get("inj", 0.0) >= 0.99:
					break
			squeeze(0.0)
			await _frames(4)
			for i in 30:
				await tip_to(_above(p, 0.03), 1)
				if proc.step != si:
					break
		"retract":
			var side := proc._free_side(s)
			var perp := patient.perp3 * side
			var start_p := patient.center + perp * 0.003
			start_p.y = Patient.body_height(start_p.x, start_p.z)
			await tip_to(_above(start_p, 0.01), 16)
			await tip_to(start_p - Vector3.UP * 0.009, 12)
			for i in 150:
				var k := minf(1.0, (i + 1) / 60.0)
				var q := patient.center + perp * (0.003 + 0.024 * k)
				q.y = Patient.body_height(q.x, q.z) - 0.009
				await tip_to(q, 1)
				if proc.step != si:
					break
		"spread":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			squeeze(1.0)
			await tip_to(entry - axis * 0.01, 14)
			for k in 20:
				var d: float = proc.st.get("dissect", 0.008)
				await tip_to(entry + axis * (d + 0.004), 10)
				if OS.get_cmdline_user_args().has("--debug"):
					var hh: SurgeonHand = proc.hands[1] if proc.hands.size() > 1 else proc.hands[0]
					print("DEBUG spread k=%d dissect=%.4f along=%.4f lat=%.4f axis=%s %s" % [k, d, (hh.tip() - entry).dot(axis), ((hh.tip() - entry) - axis * (hh.tip() - entry).dot(axis)).length(), axis, debug_state()])
				if proc.step != si:
					break
				squeeze(0.0)
				await _frames(8)
				squeeze(1.0)
				await _frames(8)
			squeeze(0.0)
		"insert":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			var depth: float = s["depth"]
			await tip_to(entry - axis * 0.01, 14)
			for i in 140:
				await tip_to(entry + axis * depth * minf(1.15, (i + 1) / 100.0), 1)
				if proc.step != si:
					break
		"lift":
			squeeze(0.0)
			await _frames(10)
			await tip_to(s["target"].call(), 16)
			if OS.get_cmdline_user_args().has("--debug"):
				print("DEBUG lift cible=", s["target"].call(), " ", debug_state())
			squeeze(1.0)
			for f in 6:
				await _frames(1)
				if OS.get_cmdline_user_args().has("--debug"):
					var hh: SurgeonHand = proc.hands[1] if proc.hands.size() > 1 else proc.hands[0]
					print("DEBUG serrage %.2f dist %.4f st %s" % [hh.squeeze_value(), hh.tip().distance_to(s["target"].call()), proc.st.keys()])
			var start_p: Vector3 = s["target"].call()
			for i in 160:
				await tip_to(start_p + Vector3.UP * minf(0.12, i * 0.0015), 1)
				if proc.step != si:
					break
		"ligate":
			squeeze(0.0)
			await _frames(10)
			var base: Vector3 = s["target"].call()
			await tip_to(base, 16)
			if OS.get_cmdline_user_args().has("--debug"):
				print("DEBUG ligate base=", base, " ", debug_state())
			squeeze(1.0)
			await _frames(6)
			var away := (Vector3.UP + Vector3(0, 0, 0.5)).normalized()
			for i in 90:
				await tip_to(base + away * minf(0.07, (i + 1) * 0.001), 1)
				if proc.step != si:
					break
		"cut":
			squeeze(0.0)
			await _frames(12)
			await tip_to(s["target"].call(), 16)
			await _frames(4)
			squeeze(1.0)
			await _frames(8)
		"carry":
			squeeze(0.0)
			await _frames(10)
			await _wait(0.4)
			var obj: Node3D = s["object"].call()
			await tip_to(obj.global_position, 16)
			if OS.get_cmdline_user_args().has("--debug"):
				print("DEBUG carry objet=", obj.global_position, " ", debug_state())
			squeeze(1.0)
			for f in 6:
				await _frames(1)
				if OS.get_cmdline_user_args().has("--debug"):
					var hh: SurgeonHand = proc.hands[1] if proc.hands.size() > 1 else proc.hands[0]
					print("DEBUG carry serrage %.2f dist %.4f st %s" % [hh.squeeze_value(), hh.tip().distance_to(obj.global_position), proc.st.keys()])
			var from := obj.global_position
			var dest: Vector3 = s["dest"].call() + Vector3.UP * 0.08
			for i in 50:
				await tip_to(from.lerp(dest, (i + 1) / 50.0) + Vector3.UP * 0.06 * sin(PI * (i + 1) / 50.0), 1)
			await tip_to(dest, 10)
			squeeze(0.0)
			await _wait(1.2)
		"suture":
			var pairs: Array = s["pairs"].call()
			for k in range(proc.st.get("k", 0), pairs.size()):
				var pair: Array = s["pairs"].call()[k]
				await tip_to(_above(pair[0], 0.008), 14)
				await tip_to(pair[0] - Vector3.UP * 0.004, 10)
				await tip_to(pair[1] - Vector3.UP * 0.003, 14)
				await tip_to(_above(pair[1], 0.012), 6)
				if proc.step != si:
					break
		"hold":
			await tip_to(s["target"].call(), 16)
			for i in int((s.get("duration", 1.5) + 2.0) * 90):
				await tip_to(s["target"].call(), 1)
				if proc.step != si:
					break
		"place":
			squeeze(0.0)
			await _frames(8)
			await tip_to(s["target"].call(), 16)
			squeeze(1.0)
			await _frames(6)
	await _frames(6)
	if proc.step == si:
		fail("étape %s non terminée depuis l'état courant — %s" % [s["id"], debug_state()])
