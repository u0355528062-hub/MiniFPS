class_name VRBot
extends Node
## Test robot de la VR sans casque : pilote les vraies mains VR (VRHand) en déplaçant les
## manettes et en simulant grip / gâchette. `run` joue un scénario complet avec maladresses ;
## `do_step` sait terminer l'étape en cours depuis n'importe quel état (utilisé par le test chaos).

var rig: VRRig
var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var R: VRHand
var L: VRHand
var ok := true


func setup(p_rig: VRRig, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	rig = p_rig
	proc = p_proc
	patient = p_patient
	tray = p_tray
	R = rig.hands[1]
	L = rig.hands[0]
	for h in [R, L]:
		h.sim = true
		h.controller.show_when_tracked = false


func fail(msg: String) -> void:
	print("VRTEST ÉCHEC : ", msg)
	ok = false


func _frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _aim(h: VRHand, pos: Vector3) -> void:
	# Manette tenue vers l'avant et le bas, comme au-dessus du champ
	h.controller.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.45, -0.9).normalized(), Vector3.UP), pos)


## Amène la pointe de l'instrument tenu sur `target` (en déplaçant la manette).
func _tip_to(h: VRHand, target: Vector3, frames := 12) -> void:
	for i in frames:
		if h.held:
			var err := target - h.held.tip_global()
			h.controller.global_position += err * (0.5 if i < frames - 3 else 1.0)
		await _frames(1)


func _grip_press(h: VRHand) -> void:
	h.sim_grip = 1.0
	await _frames(2)
	h.sim_grip = 0.0
	await _frames(3)


func _grab(h: VRHand, inst: Instrument, by_ray := false) -> void:
	if h.held == inst:
		return
	if h.held:
		await _grip_press(h)  # repose d'abord
	if by_ray:
		_aim(h, Vector3(0.25, 1.35, 0.85))
		await _frames(2)
		var axis := h._hold_axis()
		h.controller.global_position += inst.global_position - (h.grip_point() + axis * 0.45)
	else:
		_aim(h, h.controller.global_position)
		await _frames(1)
		h.controller.global_position += inst.grip_global() - h.grip_point()
	await _frames(3)
	await _grip_press(h)
	if h.held != inst:
		fail("impossible de prendre %s (%s)" % [inst.id, "rayon" if by_ray else "main"])


func _put_back(h: VRHand) -> void:
	if h.held:
		await _grip_press(h)


func _click(h: VRHand) -> void:
	h.sim_trigger = 1.0
	await _frames(3)
	h.sim_trigger = 0.0
	await _frames(3)


## Remet les deux mains dans un état neutre (gâchettes relâchées, instruments reposés).
func cleanup() -> void:
	for h in [R, L]:
		h.sim_trigger = 0.0
		h.sim_grip = 0.0
	await _frames(3)
	for h in [R, L]:
		await _put_back(h)
	_aim(R, Vector3(0.3, 1.3, 0.45))
	_aim(L, Vector3(-0.1, 1.3, 0.45))
	await _wait(0.8)  # laisse finir les animations (retour d'instrument, appendice qui retombe)


## Termine l'étape en cours, quel que soit l'état laissé par le joueur.
func do_step() -> void:
	var s := proc.step
	if s < 0 or s >= Procedure.STEPS.size():
		return
	await cleanup()
	var id: String = Procedure.STEPS[s]["id"]
	var I := tray.instruments
	match id:
		"badigeon":
			await _grab(R, I["mikulicz"])
			_aim(R, R.controller.global_position)
			R.sim_trigger = 1.0
			var c := patient.center
			for row in 13:
				for k in 16:
					var x := c.x - 0.08 + (k if row % 2 == 0 else 15 - k) * 0.0107
					var z := c.z - 0.09 + row * 0.015
					await _tip_to(R, Vector3(x, Patient.body_height(x, z) + 0.004, z), 2)
					if proc.step != s:
						break
				if proc.step != s:
					break
			R.sim_trigger = 0.0
		"incision":
			await _grab(R, I["bistouri"])
			# Reprend à l'endroit où l'incision s'est arrêtée
			var t0 := maxf(proc._incision, 0.0)
			await _tip_to(R, patient.incision_point(t0) + Vector3.UP * 0.003)
			R.sim_trigger = 1.0
			for i in 41:
				await _tip_to(R, patient.incision_point(lerpf(t0, 1.0, i / 40.0)) + Vector3.UP * 0.002, 2)
				if proc.step != s:
					break
			R.sim_trigger = 0.0
		"ecarteur1", "ecarteur2":
			await _grab(R, I["langenbeck" if id == "ecarteur1" else "roux"])
			await _tip_to(R, patient.retractor_slot(-1.0 if id == "ecarteur1" else 1.0))
			await _click(R)
		"saisie":
			await _grab(R, I["debakey"])
			await _tip_to(R, patient.appendix_tip)
			R.sim_trigger = 1.0
			await _frames(2)
			for i in 60:
				R.controller.global_position += Vector3.UP * 0.002
				await _frames(1)
				if proc.step != s:
					break
			R.sim_trigger = 0.0
		"ligature":
			await _grab(L, I["overholt"])
			await _tip_to(L, patient.appendix_point(0.18))
			await _click(L)
		"section":
			await _grab(L, I["ciseaux"])
			await _tip_to(L, patient.appendix_point(0.32))
			await _click(L)
		"retrait":
			await _grab(R, I["debakey"])
			await _wait(0.6)
			await _tip_to(R, proc._piece.global_position)
			R.sim_trigger = 1.0
			await _frames(3)
			await _tip_to(R, tray.dish_center + Vector3.UP * 0.06, 20)
			R.sim_trigger = 0.0
		"suture":
			await _grab(R, I["porte_aiguille"])
			for k in range(proc._stitch_i, Procedure.STITCH_T.size()):
				await _tip_to(R, patient.incision_point(Procedure.STITCH_T[k]) + Vector3.UP * 0.002, 10)
				await _click(R)
	await _frames(5)
	if proc.step == s:
		fail("étape %s non terminée depuis l'état courant" % id)


## Scénario complet avec maladresses volontaires.
func run() -> void:
	# Recentrage : tête n'importe où, tournée de 40°, yeux à 1,20 m (joueur assis)
	rig.camera.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)), Vector3(0.3, 1.2, 0.1))
	rig.recenter()
	await _frames(1)
	var cam := rig.camera.global_transform
	if cam.origin.distance_to(Vector3(0.12, 1.62, 0.6)) > 0.01 or (-cam.basis.z).dot(Vector3.FORWARD) < 0.99:
		fail("recentrage %s %s" % [cam.origin, -cam.basis.z])
	else:
		print("VRTEST recentrage OK (assis, tourné)")
	rig.camera.transform = Transform3D.IDENTITY
	rig.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.12, 0.0, 0.6))
	_aim(R, Vector3(0.3, 1.3, 0.45))
	_aim(L, Vector3(-0.1, 1.3, 0.45))
	await _frames(5)
	proc.on_continue()
	var I := tray.instruments
	for s in Procedure.STEPS.size():
		var id: String = Procedure.STEPS[s]["id"]
		match id:
			"badigeon":
				# Mauvais instrument d'abord (1 erreur attendue)
				await _grab(R, I["bistouri"])
				await _put_back(R)
			"incision":
				# Prise au rayon
				await _grab(R, I["bistouri"], true)
				await _put_back(R)
			"saisie":
				# On lâche en cours de route, l'appendice retombe
				await _grab(R, I["debakey"])
				await _tip_to(R, patient.appendix_tip)
				R.sim_trigger = 1.0
				for i in 8:
					R.controller.global_position += Vector3.UP * 0.002
					await _frames(1)
				R.sim_trigger = 0.0
				await _wait(0.9)
			"retrait":
				# Lâché loin du haricot : il revient à sa place
				await _grab(R, I["debakey"])
				await _tip_to(R, proc._piece.global_position)
				R.sim_trigger = 1.0
				await _frames(3)
				await _tip_to(R, Vector3(0.3, 1.25, -0.2), 12)
				R.sim_trigger = 0.0
				await _wait(0.7)
				if proc.step != s:
					fail("lâché hors du haricot mais étape validée")
			"suture":
				# Passage de main à main
				await _grab(R, I["porte_aiguille"])
				L.controller.global_position += R.held.grip_global() - L.grip_point()
				await _frames(2)
				await _grip_press(L)
				if L.held == null or L.held.id != "porte_aiguille" or R.held != null:
					fail("passage de main à main")
		await do_step()
		print("VRTEST étape réussie : ", id)
	await cleanup()
	for inst in tray.ordered:
		if inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			fail("%s n'est pas revenu sur la table" % inst.id)
	if proc.errors != 1:
		fail("1 erreur attendue, %d comptées" % proc.errors)
	print("VRTEST ", "OK" if ok else "ÉCHEC", " — erreurs : ", proc.errors)
