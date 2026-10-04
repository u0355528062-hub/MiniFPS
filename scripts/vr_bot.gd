class_name VRBot
extends BotDriver
## Robot de test VR sans casque : pilote les vraies mains VR (VRHand) en déplaçant les manettes et
## en simulant grip / gâchette. `run` ajoute des maladresses volontaires à la partie complète.

var rig: VRRig
var R: VRHand
var L: VRHand
var active: VRHand  ## main qui opère
## Mains nues simulées : faux suivi des mains (26 articulations par main), gestes réels
var hand_mode := false
var _trackers := {}


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
	if hand_mode:
		await _wait(0.25)  # le poing doit tenir un instant
	else:
		await _frames(2)
	h.sim_grip = 0.0
	if hand_mode:
		await _wait(0.25)
	else:
		await _frames(3)


# ---------------------------------------------------------------- Mains nues simulées

## Active le faux suivi des mains : deux XRHandTracker enregistrés comme le ferait le casque.
func enable_hands() -> void:
	hand_mode = true
	prefix = "HANDTEST"
	process_priority = -100  # met à jour la fausse main avant que le jeu la lise
	for h in [L, R]:
		var t := XRHandTracker.new()
		t.name = h.tracker_name
		t.hand = XRPositionalTracker.TRACKER_HAND_LEFT if h.is_left else XRPositionalTracker.TRACKER_HAND_RIGHT
		XRServer.add_tracker(t)
		_trackers[h] = t


## Articulations dans le repère de la paume (x vers l'auriculaire, y dos de la main, -z doigts).
func _joint_local(j: int, pinch: bool, fist: bool, mirror: float) -> Vector3:
	var bases := {2: Vector3(-0.025, -0.005, 0.03), 6: Vector3(-0.015, 0, 0.02), 11: Vector3(0, 0, 0.02), 16: Vector3(0.015, 0, 0.02), 21: Vector3(0.03, 0, 0.02)}
	var tips := {
		2: Vector3(-0.01, -0.02, -0.07) if pinch else Vector3(-0.05, -0.01, -0.03),
		6: Vector3(-0.01, -0.02, -0.07) if pinch else Vector3(-0.02, 0, -0.09),
		11: Vector3(0, -0.03, -0.015) if fist else Vector3(0, 0, -0.095),
		16: Vector3(0.015, -0.03, -0.012) if fist else Vector3(0.018, 0, -0.088),
		21: Vector3(0.028, -0.028, -0.01) if fist else Vector3(0.033, 0, -0.075),
	}
	var p := Vector3.ZERO
	if j == XRHandTracker.HAND_JOINT_WRIST:
		p = Vector3(0, 0, 0.05)
	elif j != XRHandTracker.HAND_JOINT_PALM:
		var first := 2 if j < 6 else (6 + int((j - 6) / 5) * 5)
		var count := 4 if first == 2 else 5
		var k := float(j - first) / (count - 1)
		p = bases[first].lerp(tips[first], k)
	return Vector3(p.x * mirror, p.y, p.z)


func _process(_delta: float) -> void:
	if not hand_mode or rig == null:
		return
	var inv := rig.global_transform.affine_inverse()
	for h in _trackers:
		var t: XRHandTracker = _trackers[h]
		var palm: Transform3D = inv * (h as VRHand).controller.global_transform
		var pinch: bool = (h as VRHand).sim_trigger > 0.5
		var fist: bool = (h as VRHand).sim_grip > 0.6
		var mirror := -1.0 if (h as VRHand).is_left else 1.0
		for j in XRHandTracker.HAND_JOINT_MAX:
			t.set_hand_joint_transform(j, Transform3D(palm.basis, palm * _joint_local(j, pinch, fist, mirror)))
			t.set_hand_joint_flags(j, XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_TRACKED | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED)
			t.set_hand_joint_radius(j, 0.009 if j > 1 else 0.02)
		t.has_tracking_data = true


func pinch(h: VRHand) -> void:
	h.sim_trigger = 1.0
	await _frames(4)
	h.sim_trigger = 0.0
	await _frames(4)


## Navigation du menu au pincement : main droite pour changer, main gauche pour valider.
func start_with_pinches() -> void:
	await _frames(5)
	var want := Operation.ALL.find(proc.op.id)
	var guard := 0
	while proc.step == Procedure.MENU and proc.menu_index != want and guard < 6:
		guard += 1
		await pinch(R)
	if proc.menu_index != want:
		fail("le pincement main droite ne change pas l'opération du menu")
	await pinch(L)
	if proc.step != Procedure.INTRO:
		fail("le pincement main gauche ne valide pas le menu (étape %d)" % proc.step)
	await pinch(L)
	if proc.step != 0:
		fail("le pincement ne lance pas l'opération (étape %d)" % proc.step)


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
	# Main nue : la paume est lissée, on corrige plus doucement et plus longtemps
	var gain := 0.35 if hand_mode else 0.5
	var n := frames_n * 2 if hand_mode and frames_n > 4 else frames_n
	for i in n:
		if active.held:
			var err := p - active.held.tip_global()
			active.controller.global_position += err * (gain if i < n - 3 or hand_mode else 1.0)
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


func debug_state() -> String:
	var tip := active.tip()
	return "source=%d tenu=%s tip=%s peau=%.3f trace=%.2f proj=%s gachette=%.1f" % [active.source, held_id(), tip, Patient.body_height(tip.x, tip.z), proc._trace, patient.incision_project(tip), active.trigger_value()]
