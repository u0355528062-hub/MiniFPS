class_name VRBot
extends BotDriver
## Robot de test VR sans casque : pilote les vraies mains VR (VRHand) en déplaçant les manettes et
## en simulant grip / gâchette. `run` ajoute des maladresses volontaires à la partie complète.

var rig: VRRig
var R: VRHand
var L: VRHand
var active: VRHand  ## main qui opère


func setup(p_rig: VRRig, p_proc: Procedure, p_patient: Patient, p_tray: InstrumentTray) -> void:
	rig = p_rig
	proc = p_proc
	patient = p_patient
	tray = p_tray
	prefix = "VRTEST"
	R = rig.hands[1]
	L = rig.hands[0]
	active = R
	for h in [R, L]:
		h.sim = true
		h.controller.show_when_tracked = false


func _home(h: VRHand) -> Vector3:
	return rig.surgeon_spot + (Vector3(0.18, 1.3, -0.15) if h == R else Vector3(-0.22, 1.3, -0.15))


func _aim(h: VRHand, pos: Vector3) -> void:
	# Manette tenue vers l'avant et le bas, comme au-dessus du champ
	h.controller.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.45, -0.9).normalized(), Vector3.UP), pos)


func _grip_press(h: VRHand) -> void:
	h.sim_grip = 1.0
	await _frames(2)
	h.sim_grip = 0.0
	await _frames(3)


func grab_with(h: VRHand, inst: Instrument, by_ray := false) -> void:
	if h.held == inst:
		return
	if h.held:
		await _grip_press(h)
	if by_ray:
		_aim(h, rig.surgeon_spot + Vector3(0.13, 1.35, 0.25))
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


func take(inst_id: String) -> void:
	await grab_with(active, tray.instruments[inst_id])


func put_back_all() -> void:
	for h in [R, L]:
		h.sim_trigger = 0.0
		h.sim_grip = 0.0
	await _frames(2)
	for h in [R, L]:
		if h.held:
			await _grip_press(h)
	_aim(R, _home(R))
	_aim(L, _home(L))


func tip_to(p: Vector3, frames_n := 12) -> void:
	for i in frames_n:
		if active.held:
			var err := p - active.held.tip_global()
			active.controller.global_position += err * (0.5 if i < frames_n - 3 else 1.0)
		await _frames(1)


func trigger(down: bool) -> void:
	active.sim_trigger = 1.0 if down else 0.0


func held_id() -> String:
	return active.held.id if active.held else ""


func cleanup() -> void:
	await super.cleanup()
	active = R


## Partie complète + maladresses volontaires (mauvais instrument, prise au rayon, lâcher,
## objet lâché loin de la cible, passage de main à main), puis recentrage assis.
func run() -> void:
	rig.camera.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)), Vector3(0.3, 1.2, 0.1))
	rig.recenter()
	await _frames(1)
	var cam := rig.camera.global_transform
	var want := rig.surgeon_spot + Vector3(0, 1.62, 0)
	if cam.origin.distance_to(want) > 0.01 or (-cam.basis.z).dot(Vector3.FORWARD) < 0.99:
		fail("recentrage %s %s" % [cam.origin, -cam.basis.z])
	else:
		print("VRTEST recentrage OK (assis, tourné)")
	rig.camera.transform = Transform3D.IDENTITY
	rig.global_transform = Transform3D(Basis.IDENTITY, rig.surgeon_spot)
	_aim(R, _home(R))
	_aim(L, _home(L))
	await _frames(5)
	await start()
	var expected_errors := 0
	for si in proc.steps.size():
		var s: Dictionary = proc.steps[si]
		var others := tray.ordered.filter(func(i: Instrument) -> bool: return i.id != s["inst"] and not i.parked)
		match s["kind"]:
			"paint":
				if si == 0 and not others.is_empty():
					# Mauvais instrument d'abord (1 erreur attendue)
					await grab_with(R, others[0])
					await _grip_press(R)
					expected_errors += 1
			"trace":
				# Prise au rayon
				await grab_with(R, tray.instruments[s["inst"]], true)
				await _grip_press(R)
			"lift":
				# On lâche en cours de route : ça retombe
				await grab_with(R, tray.instruments[s["inst"]])
				await tip_to(s["target"].call())
				R.sim_trigger = 1.0
				for i in 8:
					R.controller.global_position += Vector3.UP * 0.002
					await _frames(1)
				R.sim_trigger = 0.0
				await _wait(0.9)
			"carry":
				# Lâché loin de la cible : il revient à sa place
				await _wait(0.6)
				await grab_with(R, tray.instruments[s["inst"]])
				await tip_to(s["object"].call().global_position)
				R.sim_trigger = 1.0
				await _frames(3)
				await tip_to(rig.surgeon_spot + Vector3(0.2, 1.25, -0.8), 12)
				R.sim_trigger = 0.0
				await _wait(0.7)
				if proc.step != si:
					fail("lâché loin de la cible mais étape validée")
			"points":
				# Passage de main à main puis la main gauche termine
				await grab_with(R, tray.instruments[s["inst"]])
				L.controller.global_position += R.held.grip_global() - L.grip_point()
				await _frames(2)
				await _grip_press(L)
				if L.held == null or L.held.id != s["inst"] or R.held != null:
					fail("passage de main à main")
		await do_step()
		print("VRTEST étape réussie : ", s["id"])
	await cleanup()
	for inst in tray.ordered:
		if not inst.parked and inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			fail("%s n'est pas revenu sur la table" % inst.id)
	if proc.errors != expected_errors:
		fail("%d erreur(s) attendue(s), %d comptée(s)" % [expected_errors, proc.errors])
	print("VRTEST ", "OK" if ok and proc.step >= proc.steps.size() else "ÉCHEC", " — ", proc.op.name, " — erreurs : ", proc.errors)
