class_name VRBot
extends Node
## Test robot de la VR sans casque : pilote les vraies mains VR (VRHand) en déplaçant les
## manettes et en simulant grip / gâchette. Utilise les deux mains et la prise au rayon.

var rig: VRRig
var R: VRHand
var L: VRHand
var ok := true


func _frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


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


func _grab(h: VRHand, inst: Instrument, by_ray := false) -> void:
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
	h.sim_grip = 1.0
	await _frames(2)
	h.sim_grip = 0.0
	await _frames(3)
	if h.held != inst:
		print("VRTEST ÉCHEC : impossible de prendre ", inst.id, " (", "rayon" if by_ray else "main", ")")
		ok = false


func _put_back(h: VRHand) -> void:
	h.sim_grip = 1.0
	await _frames(2)
	h.sim_grip = 0.0
	await _frames(3)


func _click(h: VRHand) -> void:
	h.sim_trigger = 1.0
	await _frames(3)
	h.sim_trigger = 0.0
	await _frames(3)


func run(proc: Procedure, patient: Patient, tray: InstrumentTray) -> void:
	R = rig.hands[1]
	L = rig.hands[0]
	for h in [R, L]:
		h.sim = true
		h.controller.show_when_tracked = false
	# Recentrage : tête n'importe où, tournée de 40°, yeux à 1,20 m (joueur assis)
	rig.camera.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)), Vector3(0.3, 1.2, 0.1))
	rig.recenter()
	await _frames(1)
	var cam := rig.camera.global_transform
	if cam.origin.distance_to(Vector3(0.12, 1.62, 0.6)) > 0.01 or (-cam.basis.z).dot(Vector3.FORWARD) < 0.99:
		print("VRTEST ÉCHEC : recentrage ", cam.origin, " ", -cam.basis.z)
		ok = false
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
				# Maladresse : mauvais instrument d'abord (1 erreur attendue)
				await _grab(R, I["bistouri"])
				await _put_back(R)
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
				await _put_back(R)
			"incision":
				await _grab(R, I["bistouri"], true)  # prise au rayon
				await _tip_to(R, patient.incision_point(0.0) + Vector3.UP * 0.003)
				R.sim_trigger = 1.0
				for i in 41:
					await _tip_to(R, patient.incision_point(i / 40.0) + Vector3.UP * 0.002, 2)
				R.sim_trigger = 0.0
				await _put_back(R)
			"ecarteur1", "ecarteur2":
				await _grab(R, I["langenbeck" if id == "ecarteur1" else "roux"])
				await _tip_to(R, patient.retractor_slot(-1.0 if id == "ecarteur1" else 1.0))
				await _click(R)
				if R.held != null:
					print("VRTEST ÉCHEC : l'écarteur n'a pas quitté la main")
					ok = false
			"saisie":
				await _grab(R, I["debakey"])
				# Maladresse : on lâche en cours de route, l'appendice retombe
				await _tip_to(R, patient.appendix_tip)
				R.sim_trigger = 1.0
				for i in 8:
					R.controller.global_position += Vector3.UP * 0.002
					await _frames(1)
				R.sim_trigger = 0.0
				await get_tree().create_timer(0.9).timeout
				await _tip_to(R, patient.appendix_tip)
				R.sim_trigger = 1.0
				await _frames(2)
				for i in 50:
					R.controller.global_position += Vector3.UP * 0.002
					await _frames(1)
					if proc.step != s:
						break
				R.sim_trigger = 0.0
				await _frames(3)
			"ligature":
				# Main gauche pendant que la droite garde la pince
				await _grab(L, I["overholt"])
				await _tip_to(L, patient.appendix_point(0.18))
				await _click(L)
				await _put_back(L)
			"section":
				await _grab(L, I["ciseaux"])
				await _tip_to(L, patient.appendix_point(0.32))
				await _click(L)
				await _put_back(L)
			"retrait":
				if R.held == null or R.held.id != "debakey":
					await _grab(R, I["debakey"])
				# Maladresse : lâché loin du haricot, il revient à sa place
				await _tip_to(R, proc._piece.global_position)
				R.sim_trigger = 1.0
				await _frames(3)
				await _tip_to(R, Vector3(0.3, 1.25, -0.2), 12)
				R.sim_trigger = 0.0
				await get_tree().create_timer(0.7).timeout
				if proc.step != s:
					print("VRTEST ÉCHEC : lâché hors du haricot mais étape validée")
					ok = false
				await _tip_to(R, proc._piece.global_position)
				R.sim_trigger = 1.0
				await _frames(3)
				await _tip_to(R, tray.dish_center + Vector3.UP * 0.06, 20)
				R.sim_trigger = 0.0
				await _frames(5)
				await _put_back(R)
			"suture":
				await _grab(R, I["porte_aiguille"])
				# Passage de main à main
				L.controller.global_position += R.held.grip_global() - L.grip_point()
				await _frames(2)
				L.sim_grip = 1.0
				await _frames(2)
				L.sim_grip = 0.0
				await _frames(3)
				if L.held == null or L.held.id != "porte_aiguille" or R.held != null:
					print("VRTEST ÉCHEC : passage de main à main")
					ok = false
				_aim(L, L.controller.global_position)
				for t in Procedure.STITCH_T:
					await _tip_to(L, patient.incision_point(t) + Vector3.UP * 0.002, 10)
					await _click(L)
				await _put_back(L)
		await _frames(3)
		if proc.step == s:
			print("VRTEST ÉCHEC à l'étape ", id)
			ok = false
			break
		print("VRTEST étape réussie : ", id)
	# Tous les instruments doivent être revenus sur la table
	await _frames(40)
	for inst in tray.ordered:
		if inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			print("VRTEST ÉCHEC : ", inst.id, " n'est pas revenu sur la table")
			ok = false
	if proc.errors != 1:
		print("VRTEST ÉCHEC : 1 erreur attendue, ", proc.errors, " comptées")
		ok = false
	print("VRTEST ", "OK" if ok else "ÉCHEC", " — erreurs : ", proc.errors)
