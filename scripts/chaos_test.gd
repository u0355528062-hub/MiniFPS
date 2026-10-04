class_name ChaosTest
extends Node
## Test « chaos » : à chaque étape, des centaines d'actions au hasard (mains VR ou souris/clavier),
## puis le robot doit pouvoir terminer l'étape depuis l'état laissé. Des invariants sont vérifiés à
## chaque image (instrument tenu par deux mains, valeurs absurdes, étape qui recule...).

var proc: Procedure
var patient: Patient
var tray: InstrumentTray
var rng := RandomNumberGenerator.new()
var violations := 0
var _last_step := -10
var _checking := false
var bot: BotDriver


func _violation(msg: String) -> void:
	violations += 1
	if violations <= 20:
		print("CHAOS INVARIANT VIOLÉ : ", msg)


func _finite(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


func _physics_process(_delta: float) -> void:
	if not _checking:
		return
	# 1. Un instrument n'est jamais dans deux mains
	var seen := {}
	for h in proc.hands:
		if h.held:
			if seen.has(h.held):
				_violation("%s tenu par deux mains" % h.held.id)
			seen[h.held] = true
			if not h.held.held:
				_violation("%s dans une main mais pas marqué tenu" % h.held.id)
	# 2. Les instruments restent dans la salle, positions valides
	for inst in tray.ordered:
		var p := inst.global_position
		if not _finite(p) or absf(p.x) > 4.0 or absf(p.z) > 4.0 or p.y < -0.5 or p.y > 3.5:
			_violation("%s hors de la salle : %s" % [inst.id, p])
	# 3. L'étape ne recule jamais
	if proc.step < _last_step:
		_violation("étape revenue de %d à %d" % [_last_step, proc.step])
	_last_step = proc.step
	# 4. Patient cohérent
	if not is_finite(patient.opening) or patient.opening < -0.01 or patient.opening > 1.1:
		_violation("ouverture de plaie absurde %f" % patient.opening)
	if proc.op.id == "appendicectomie":
		if not _finite(patient.appendix_tip) or patient.appendix_tip.distance_to(patient.appendix_base) > 0.1:
			_violation("pointe d'appendice absurde %s" % patient.appendix_tip)
	var cur := proc.current()
	if not cur.is_empty() and cur["kind"] == "carry":
		var obj: Node3D = cur["object"].call()
		if obj and not _finite(obj.global_position):
			_violation("objet transporté : position invalide")
	if not cur.is_empty() and cur["kind"] == "lift":
		var t: Vector3 = cur["target"].call()
		if not _finite(t) or t.distance_to(patient.center) > 0.4:
			_violation("objet soulevé hors de portée %s" % t)
	if proc.errors < 0 or proc.elapsed < 0.0:
		_violation("compteurs invalides")


func _random_point() -> Vector3:
	match rng.randi_range(0, 4):
		0, 1:  # champ opératoire / plaie
			var c := patient.center
			return c + Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.06, 0.15), rng.randf_range(-0.12, 0.12))
		2:  # plateau d'instruments
			return InstrumentTray.MAYO_POS + Vector3(rng.randf_range(-0.3, 0.3), InstrumentTray.TRAY_Y + rng.randf_range(0.0, 0.25), rng.randf_range(-0.25, 0.25))
		3:  # haricot (ou autour du chirurgien)
			var base := tray.dish_center if proc.op.with_dish else proc.op.surgeon_spot + Vector3(0, 1.1, -0.2)
			return base + Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(0.0, 0.2), rng.randf_range(-0.15, 0.15))
		_:  # n'importe où
			return Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.5, 2.0), rng.randf_range(-1.5, 1.5))


## Rafale d'actions au hasard avec les mains VR.
func chaos_vr(frames: int) -> void:
	for f in frames:
		var vb := bot as VRBot
		for h in [vb.R, vb.L]:
			if rng.randf() < 0.12:
				var basis := Basis.from_euler(Vector3(rng.randf_range(-1.2, 0.3), rng.randf_range(-PI, PI), rng.randf_range(-0.8, 0.8)))
				h.controller.global_transform = Transform3D(basis, _random_point())
			if rng.randf() < 0.05 and h.held:
				# Vise une cible de l'étape (fait parfois avancer l'opération par hasard)
				var t := proc._target()
				if t != Vector3.INF:
					h.controller.global_position += t - h.held.tip_global()
			if rng.randf() < 0.04:
				h.sim_grip = 1.0 - h.sim_grip
			if rng.randf() < 0.1:
				h.sim_trigger = 1.0 if rng.randf() < 0.5 else 0.0
		if rng.randf() < 0.01 and proc.step == Procedure.INTRO:
			proc.on_continue()
		await get_tree().process_frame


## Rafale d'actions au hasard à la souris et au clavier.
func chaos_desk(frames: int) -> void:
	var b := bot as DesktopBot
	for f in frames:
		if rng.randf() < 0.2:
			b.hand.sim_mouse = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720))
		if rng.randf() < 0.05:
			b.aim(_random_point())
		var r := rng.randf()
		if r < 0.06:
			b.mouse_button(MOUSE_BUTTON_LEFT, rng.randf() < 0.5)
		elif r < 0.08:
			b.mouse_button(MOUSE_BUTTON_RIGHT, true)
			b.mouse_motion(Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)))
			b.mouse_button(MOUSE_BUTTON_RIGHT, false)
		elif r < 0.10:
			b.key([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_R, KEY_9, KEY_0][rng.randi_range(0, 10)])
		elif r < 0.12:
			b.mouse_button([MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN][rng.randi_range(0, 1)], true)
		await get_tree().process_frame


func run(mode: String, seed_value: int) -> void:
	rng.seed = seed_value
	_checking = true
	await get_tree().process_frame
	await bot.start()
	var guard := 0
	while proc.step >= 0 and proc.step < proc.steps.size() and guard < 40:
		guard += 1
		var s := proc.step
		if mode == "vr":
			await chaos_vr(rng.randi_range(120, 360))
		else:
			await chaos_desk(rng.randi_range(120, 360))
		await bot.do_step()
		if proc.step == s:
			print("CHAOS BLOQUÉ à l'étape ", proc.steps[s]["id"])
			break
	var ok := proc.step >= proc.steps.size() and violations == 0 and bot.ok
	await bot.cleanup()
	await get_tree().create_timer(0.8).timeout
	for inst in tray.ordered:
		if not inst.parked and inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			print("CHAOS : ", inst.id, " pas revenu sur la table")
			ok = false
	print("CHAOS %s %s graine %d : %s (étapes %d/%d, erreurs joueur %d, invariants violés %d)" % [mode, proc.op.id, seed_value, "OK" if ok else "ÉCHEC", proc.step, proc.steps.size(), proc.errors, violations])
