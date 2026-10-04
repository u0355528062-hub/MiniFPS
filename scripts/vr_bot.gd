class_name VRBot
extends BotDriver
## Robot de test VR sans casque : pilote les vraies mains VR (VRHand) en déplaçant les manettes
## et en simulant grip / gâchette, ou — en mode mains nues — en fabriquant un faux suivi des mains
## (26 articulations par main : pincement continu, main ouverte, poing). `run` ajoute des
## maladresses volontaires à la partie complète.

var rig: VRRig
var R: VRHand
var L: VRHand
var active: VRHand  ## main qui opère
var hand_mode := false
var _trackers := {}
var _open := {}  ## main grande ouverte (pour lâcher)


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
		h.patient = patient
		h.camera = rig.camera
		h.controller.show_when_tracked = false


func _home(h: VRHand) -> Vector3:
	return rig.surgeon_spot + (Vector3(0.18, 1.3, -0.15) if h == R else Vector3(-0.22, 1.3, -0.15))


func _aim(h: VRHand, pos: Vector3) -> void:
	# Main tenue vers l'avant et le bas, comme au-dessus du champ
	h.controller.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, -0.45, -0.9).normalized(), Vector3.UP), pos)


## Prendre / lâcher : grip à la manette, pincement / main ouverte aux mains nues.
func _grip_press(h: VRHand) -> void:
	if hand_mode:
		if h.held:
			_open[h] = true
			await _wait(0.45)
			_open[h] = false
			await _frames(3)
		else:
			h.sim_trigger = 0.0
			await _frames(4)
			h.sim_trigger = 1.0
			await _frames(6)
		return
	h.sim_grip = 1.0
	await _frames(2)
	h.sim_grip = 0.0
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
		_open[h] = false


## Articulations dans le repère de la main (x vers l'auriculaire pour la main droite, y = dos,
## -z = doigts). pinch : 0 pouce et index écartés, 1 bouts qui se touchent.
static func joint_local(j: int, pinch: float, holding: bool, open: bool, fist: bool) -> Vector3:
	var P := Vector3(-0.028, -0.03, -0.072)
	var u := Vector3(0.25, 0.7, -0.65).normalized()
	var d := lerpf(0.065, 0.006, clampf(pinch, 0.0, 1.0))
	if open:
		d = 0.085
	var itip := P + u * d * 0.5
	var ttip := P - u * d * 0.5
	if open:
		itip = Vector3(-0.022, 0.0, -0.11)
		ttip = Vector3(-0.07, -0.02, -0.03)
	match j:
		XRHandTracker.HAND_JOINT_PALM:
			return Vector3.ZERO
		XRHandTracker.HAND_JOINT_WRIST:
			return Vector3(0, 0, 0.065)
		2:
			return Vector3(-0.025, -0.01, 0.045)
		3:
			return Vector3(-0.042, -0.018, 0.012)
		4:
			return Vector3(-0.042, -0.018, 0.012).lerp(ttip, 0.55) + Vector3(-0.004, 0, 0)
		5:
			return ttip
		6:
			return Vector3(-0.012, 0, 0.055)
		7:
			return Vector3(-0.02, 0, -0.025)
		8:
			return Vector3(-0.02, 0, -0.025).lerp(itip, 0.45) + Vector3(0, 0.006 if not open else 0.0, 0)
		9:
			return Vector3(-0.02, 0, -0.025).lerp(itip, 0.75) + Vector3(0, 0.005 if not open else 0.0, 0)
		10:
			return itip
	# Majeur, annulaire, auriculaire : tendus (main ouverte ou vide), repliés (poing ou en tenant)
	var f := int((j - 11) / 5)
	var k := (j - 11) % 5
	var xs := [-0.002, 0.015, 0.03]
	var base := Vector3(xs[f], 0, -0.03 + f * 0.004)
	var ext := Vector3(xs[f] + f * 0.002, 0, -0.12 + f * 0.012)
	var tip := ext
	if fist:
		tip = Vector3(xs[f], -0.03, -0.012)
	elif holding and not open:
		tip = Vector3(xs[f], -0.036, -0.05)
	if k == 0:
		return Vector3(xs[f] * 0.6, 0, 0.055)
	return base.lerp(tip, (k - 1) / 3.0) + Vector3(0, -0.004 * sin(PI * (k - 1) / 3.0) if tip != ext else 0.0, 0)


func _process(_delta: float) -> void:
	if not hand_mode or rig == null:
		return
	var inv := rig.global_transform.affine_inverse()
	for h in _trackers:
		var t: XRHandTracker = _trackers[h]
		var vh := h as VRHand
		var palm: Transform3D = inv * vh.controller.global_transform
		var mirror := -1.0 if vh.is_left else 1.0
		for j in XRHandTracker.HAND_JOINT_MAX:
			var p := joint_local(j, vh.sim_trigger, vh.held != null, _open.get(h, false), vh.sim_grip > 0.6)
			p.x *= mirror
			t.set_hand_joint_transform(j, Transform3D(palm.basis, palm * p))
			t.set_hand_joint_flags(j, XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID | XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_TRACKED | XRHandTracker.HAND_JOINT_FLAG_POSITION_TRACKED)
			t.set_hand_joint_radius(j, 0.009 if j > 1 else 0.02)
		t.has_tracking_data = true


func pinch(h: VRHand) -> void:
	h.sim_trigger = 1.0
	await _frames(6)
	h.sim_trigger = 0.0
	await _frames(6)


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


## Menu tactile : touche un bouton du bout de l'index.
func poke(action: String) -> bool:
	var tm := proc.touch_menu
	if tm == null:
		return false
	for b in tm._buttons:
		if b["action"] == action and is_instance_valid(b["root"]):
			var root: Node3D = b["root"]
			var target := root.global_transform * Vector3(0, 0, 0.004)
			_aim(R, R.controller.global_position)
			await _frames(2)
			for i in 30:
				var err: Vector3 = target - R.fingertip()
				R.controller.global_position += err * 0.5
				await _frames(1)
			await _frames(4)
			_aim(R, _home(R))
			await _frames(6)
			return true
	return false


func grab_with(h: VRHand, inst: Instrument, by_ray := false) -> void:
	if h.held == inst:
		return
	_open[h] = false
	h.sim_grip = 0.0
	if h.held:
		await _grip_press(h)
	h.sim_trigger = 0.0
	await _frames(3)
	if by_ray:
		_aim(h, rig.surgeon_spot + Vector3(0.13, 1.35, 0.25))
		await _frames(2)
		for i in 14:
			if hand_mode:
				var shoulder := rig.camera.global_position + Vector3.DOWN * 0.22 + rig.camera.global_basis.x * (-0.17 if h.is_left else 0.17)
				var want := inst.global_position - (inst.global_position - shoulder).normalized() * 0.4
				h.controller.global_position += (want - h.pinch_point()) * 0.6
			else:
				h.controller.global_position += inst.global_position - (h.pinch_point() + h._ctrl_axis() * 0.45)
			await _frames(1)
	else:
		_aim(h, h.controller.global_position)
		await _frames(1)
		for i in 12:
			h.controller.global_position += inst.grip_global() - h.pinch_point()
			await _frames(1)
	await _frames(2)
	await _grip_press(h)
	await _frames(4)
	if h.held != inst:
		fail("impossible de prendre %s (%s) — survol %s" % [inst.id, "rayon" if by_ray else "main", h.hovered.id if h.hovered else "aucun"])


func take(inst_id: String) -> void:
	await grab_with(active, tray.instruments[inst_id])


func put_back_all() -> void:
	for h in [R, L]:
		h.sim_grip = 0.0
	await _frames(2)
	for h in [R, L]:
		if h.held:
			await _grip_press(h)
		h.sim_trigger = 0.0
	_aim(R, _home(R))
	_aim(L, _home(L))


func tip_to(p: Vector3, frames_n := 12) -> void:
	# Main nue : les articulations sont filtrées, on corrige plus longtemps
	var gain := 0.4 if hand_mode else 0.6
	var n := frames_n * 2 if hand_mode and frames_n > 4 else frames_n
	for i in n:
		if active.held:
			_orient_for(p)
			var err := p - active.raw_tip()
			active.controller.global_position += err * (gain if i < n - 3 or hand_mode else 1.0)
		await _frames(1)


## Au fond de la plaie, la main tourne pour que l'instrument passe par l'ouverture ; ailleurs elle
## reprend la tenue normale (vers l'avant et le bas). La rotation se fait autour de la pointe.
func _orient_for(p: Vector3) -> void:
	var c := patient.center
	var deep := Vector2(p.x - c.x, p.z - c.z).length() < 0.06 and p.y < c.y - 0.008
	var xf := active.controller.global_transform
	var cur_b := xf.basis.orthonormalized()
	var new_b: Basis
	if want_axis != Vector3.ZERO:
		var cur0 := active.held.axis_global()
		if cur0.angle_to(want_axis) < 0.02:
			return
		new_b = Basis(Quaternion.IDENTITY.slerp(Quaternion(cur0, want_axis), 0.3)) * cur_b
	elif deep:
		var cur := active.held.axis_global()
		var want := (p - (c + Vector3(0.05, 0.3, 0.12))).normalized()
		if cur.angle_to(want) < 0.02:
			return
		new_b = Basis(Quaternion.IDENTITY.slerp(Quaternion(cur, want), 0.3)) * cur_b
	else:
		var b := Basis.looking_at(Vector3(0.0, -0.45, -0.9).normalized(), Vector3.UP)
		if Quaternion(cur_b).angle_to(Quaternion(b)) < 0.02:
			return
		new_b = Basis(Quaternion(cur_b).slerp(Quaternion(b), 0.3))
	var rot := new_b * cur_b.inverse()
	var t := active.raw_tip()
	active.controller.global_transform = Transform3D(new_b, t + rot * (xf.origin - t))


func squeeze(v: float) -> void:
	active.sim_trigger = v


func held_id() -> String:
	return active.held.id if active.held else ""


func cleanup() -> void:
	await super.cleanup()
	active = R


## Partie complète + maladresses volontaires (mauvais instrument, prise au rayon, objet lâché,
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
		print(prefix, " recentrage OK (assis, tourné)")
	rig.camera.transform = Transform3D.IDENTITY
	rig.global_transform = Transform3D(Basis.IDENTITY, rig.surgeon_spot)
	_aim(R, _home(R))
	_aim(L, _home(L))
	await _frames(5)
	# Menu tactile : toucher le bouton de l'opération puis « Commencer »
	if proc.touch_menu:
		var idx := Operation.ALL.find(proc.op.id)
		await poke("op:%d" % idx)
		if proc.step != Procedure.INTRO:
			fail("le bouton tactile de l'opération ne mène pas à l'accueil (étape %d)" % proc.step)
		await poke("start")
		if proc.step != 0:
			fail("le bouton tactile « Commencer » ne lance pas l'opération (étape %d)" % proc.step)
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
			"incise":
				# Prise au rayon
				await grab_with(R, tray.instruments[s["inst"]], true)
				await _grip_press(R)
			"lift":
				# On desserre en cours de route : ça retombe
				await grab_with(R, tray.instruments[s["inst"]])
				R.sim_trigger = 0.0
				await _frames(10)
				await tip_to(s["target"].call())
				R.sim_trigger = 1.0
				await _frames(4)
				for i in 10:
					R.controller.global_position += Vector3.UP * 0.002
					await _frames(1)
				R.sim_trigger = 0.0
				await _wait(1.0)
			"carry":
				# Lâché loin de la cible : il tombe sur les champs, on le reprend
				await _wait(0.6)
				await grab_with(R, tray.instruments[s["inst"]])
				R.sim_trigger = 0.0
				await _frames(10)
				await tip_to(s["object"].call().global_position)
				R.sim_trigger = 1.0
				await _frames(6)
				await tip_to(patient.center + Vector3(0.0, 0.07, 0.12), 12)
				R.sim_trigger = 0.0
				await _wait(1.2)
				if proc.step != si:
					fail("lâché loin de la cible mais étape validée")
			"suture":
				# Passage de main à main puis la main gauche termine
				await grab_with(R, tray.instruments[s["inst"]])
				L.sim_trigger = 0.0
				await _frames(3)
				for i in 12:
					L.controller.global_position += R.held.grip_global() - L.pinch_point()
					await _frames(1)
				await _grip_press(L)
				if L.held == null or L.held.id != s["inst"] or R.held != null:
					fail("passage de main à main (G=%s D=%s)" % [L.held.id if L.held else "-", R.held.id if R.held else "-"])
		await do_step()
		print(prefix, " étape réussie : ", s["id"])
	await cleanup()
	check_tray()
	if proc.errors != expected_errors:
		fail("%d erreur(s) attendue(s), %d comptée(s)" % [expected_errors, proc.errors])
	print(prefix, " ", "OK" if ok and proc.step >= proc.steps.size() else "ÉCHEC", " — ", proc.op.name, " — erreurs : ", proc.errors)


func debug_state() -> String:
	var t := active.tip()
	return "source=%d tenu=%s tip=%s brut=%s prof=%.4f peau=%.3f cut=[%.2f %.2f] serrage=%.2f ouverture=%.2f/%.2f st=%s" % [active.source, held_id(), t, active.raw_tip(), active.held.tip_depth if active.held else 0.0, Patient.body_height(t.x, t.z), patient.cut0, patient.cut1, active.squeeze_value(), patient.open_l, patient.open_r, proc.st.keys()]
