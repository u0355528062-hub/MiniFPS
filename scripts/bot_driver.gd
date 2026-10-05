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


## Main vide : regarder / poser la main sur `p` (manivelle, massage).
func aim_hand(_p: Vector3) -> void:
	pass


func _above(p: Vector3, h := 0.012) -> Vector3:
	return p + Vector3.UP * h


# ---------------------------------------------------------------- Étapes génériques

func start() -> void:
	if proc.step < 0:
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
	print(prefix, " ", "OK" if ok and done else "ÉCHEC", " — ", proc.op.name, " — erreurs : ", proc.errors, " — temps : %d s, note %s" % [int(proc.elapsed), proc.grade()])
	for e in proc.error_log:
		print(prefix, "   erreur : ", e)


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
	if s["inst"] != "" and s["kind"] not in ["pick", "pump"]:
		await take(s["inst"])
		if held_id() != s["inst"]:
			fail("impossible de prendre %s" % s["inst"])
	await lift_clear()
	match s["kind"]:
		"mark":
			var p: Vector3 = s["ideal"].call()
			await tip_to(_above(p, 0.01), 14)
			squeeze(1.0)
			# Appui franc : la peau monte et descend avec la respiration
			await tip_to(p - Vector3.UP * 0.009, 12)
			await _frames(6)
			squeeze(0.0)
			if OS.get_cmdline_user_args().has("--debug"):
				print("DEBUG mark ideal=", p, " ", debug_state())
			await tip_to(_above(p, 0.02), 6)
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			var rx := patient.paint_r.x + 0.005
			var rz := patient.paint_r.y + 0.005
			await tip_to(_above(Vector3(c.x - rx, Patient.body_height(c.x - rx, c.z - rz), c.z - rz)), 14)
			var rows := int(ceil(rz * 2.0 / 0.011)) + 1
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
			while proc.anesthesia_ready_at > 0 and Time.get_ticks_msec() < proc.anesthesia_ready_at + 200:
				await _frames(5)
			var n := int(clampf(patient.INC_A.distance_to(patient.INC_B) / 0.0015, 40, 220))
			var spans := [[0.0, 1.0]]
			if patient.has_cut():
				spans = [[patient.cut0, 0.0], [patient.cut1, 1.0]]
			for span in spans:
				var a: float = span[0]
				var b: float = span[1]
				if absf(b - a) < 0.005 or proc.step != si:
					continue
				await tip_to(_above(patient.incision_point(a), 0.006), 16)
				await tip_to(patient.incision_point(a) - Vector3.UP * 0.004, 10)
				var k := maxi(8, int(n * absf(b - a)))
				for i in k + 1:
					await tip_to(patient.incision_point(lerpf(a, b, float(i) / k)) - Vector3.UP * 0.004, 2)
					if proc.step != si:
						break
				if proc.step == si:
					await tip_to(patient.incision_point(b) - Vector3.UP * 0.004, 12)
				await tip_to(_above(patient.incision_point(b), 0.02), 6)
		"inject":
			var p: Vector3 = s["target"].call()
			want_axis = (-skin_normal(p) * 0.7 + Vector3.DOWN * 0.3).normalized()
			squeeze(0.0)
			await tip_to(_above(p, 0.01), 16)
			await tip_to(p - Vector3.UP * 0.006, 12)
			squeeze(1.0)
			for i in int((1.0 / 0.24 + 4.0) * 90):
				await tip_to(p - Vector3.UP * 0.006, 1)
				if proc.st.get("inj", 0.0) >= 0.99 or (held_inst() != null and held_inst().volume <= 0.01):
					break
			squeeze(0.0)
			await _frames(4)
			for i in 30:
				await tip_to(_above(p, 0.03), 1)
				if proc.step != si:
					break
		"spread":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			squeeze(1.0)
			await tip_to(entry - axis * 0.01, 14)
			for k in 30:
				var d: float = proc.st.get("dissect", 0.008)
				await tip_to(entry + axis * (d + 0.004), 10)
				if OS.get_cmdline_user_args().has("--debug"):
					var hh: SurgeonHand = proc.hands[0]
					print("DEBUG spread k=%d dissect=%.4f along=%.4f %s" % [k, d, (hh.tip() - entry).dot(axis), debug_state()])
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
		"needle":
			while proc.anesthesia_ready_at > 0 and Time.get_ticks_msec() < proc.anesthesia_ready_at + 200:
				await _frames(5)
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			var fd: float = s["flash_depth"]
			want_axis = axis
			squeeze(0.0)
			await tip_to(entry - axis * 0.01, 14)
			squeeze(1.0)
			for i in 200:
				await tip_to(entry + axis * minf(fd + 0.003, (i + 1) * 0.0005), 1)
				if proc.step != si:
					break
			squeeze(0.0)
		"probe":
			var spot: Vector3 = s["target"].call()
			want_axis = s["axis"]
			squeeze(0.0)
			await tip_to(spot + Vector3.UP * 0.01, 14)
			squeeze(1.0)
			for i in 240:
				await tip_to(spot - (s["axis"] as Vector3) * 0.004, 1)
				if proc.step != si:
					break
			squeeze(0.0)
		"thread":
			var tgt: Vector3 = s["target"].call()
			var ok: Vector2 = s["ok"]
			want_axis = s["axis"]
			squeeze(0.0)
			await tip_to(tgt, 14)
			squeeze(1.0)
			for i in 900:
				await tip_to(tgt, 1)
				if proc.step != si or float(proc.st.get("len", 0.0)) >= (ok.x + ok.y) * 0.5:
					break
			squeeze(0.0)
			for i in 30:
				await _frames(1)
				if proc.step != si:
					break
		"aspirate":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			want_axis = axis
			squeeze(1.0)
			for i in 600:
				await tip_to(entry + axis * float(s.get("hold_depth", 0.0)), 1)
				if proc.step != si:
					break
			squeeze(0.0)
		"withdraw":
			var entry: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			want_axis = axis
			for i in 80:
				await tip_to(entry + axis * (0.03 - i * 0.001), 1)
				if proc.step != si:
					break
		"cutline":
			# Ciseaux au fond de la plaie, clic maintenu, d'un bout à l'autre de la ligne ; une coupe
			# déjà commencée (au hasard) se prolonge depuis ses bords : vers la fin, puis vers le début
			var path := proc.cut_path(s)
			var legs := [[0.0, 1.0]]
			if proc.st.get("t0", -1.0) >= 0.0:
				legs = [[float(proc.st["t1"]), 1.0], [float(proc.st["t0"]), 0.0]]
			for leg in legs:
				var a: float = leg[0]
				var b: float = leg[1]
				var start := Procedure.path_point(path, a)
				squeeze(0.0)
				await tip_to(_above(start, 0.04), 14)
				await tip_to(start, 14)
				squeeze(1.0)
				var span := maxf(180.0 * absf(b - a), 10.0)
				for i in int(span) + 80:
					var t := lerpf(a, b, minf(1.0, float(i) / span))
					var target := Procedure.path_point(proc.cut_path(s), t)
					await tip_to(target, 2)
					if OS.get_cmdline_user_args().has("--debug") and i % 20 == 0:
						print("DEBUG coupe t=%.2f cible=%s %s" % [t, target, debug_state()])
					if proc.step != si:
						break
				squeeze(0.0)
				await tip_to(_above(Procedure.path_point(path, b), 0.05), 8)
				if proc.step != si:
					break
		"crank":
			# Présenter l'écarteur dans l'incision, serrer : il se pose ; puis tourner la manivelle
			var tgt: Vector3 = s["target"].call()
			squeeze(0.0)
			await tip_to(_above(tgt, 0.05), 16)
			await tip_to(tgt, 14)
			squeeze(1.0)
			for i in 1400:
				await _frames(1)
				if held_inst() == null:
					await aim_hand(tgt)
				if proc.step != si:
					break
			squeeze(0.0)
		"pump":
			# Mains nues : compressions rythmées sur le cœur (≈ 100 par minute)
			var tgt: Vector3 = s["target"].call()
			await aim_hand(tgt)
			for i in 90:
				squeeze(1.0)
				await _wait(0.28)
				squeeze(0.0)
				await _wait(0.3)
				if proc.step != si:
					break
		"pick":
			# Main vide : viser l'instrument posé, cliquer
			var tgt: Vector3 = proc._pick_target(s)
			await aim_hand(tgt)
			for i in 40:
				squeeze(1.0)
				await _frames(3)
				squeeze(0.0)
				await _frames(3)
				if proc.step != si:
					break
				await aim_hand(proc._pick_target(s))
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
	await _frames(6)
	if proc.step == si:
		fail("étape %s non terminée depuis l'état courant — %s" % [s["id"], debug_state()])
