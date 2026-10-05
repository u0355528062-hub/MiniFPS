class_name ChaosTest
extends Node
## Test « chaos » : à chaque étape, des centaines d'actions au hasard (souris, clavier, regard),
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
var _deep := {}


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
	if not is_finite(patient.opening) or patient.opening < -0.01 or patient.opening > 1.4:
		_violation("ouverture de plaie absurde %f" % patient.opening)
	if not is_finite(patient.lung_collapse) or patient.tract_depth < 0.0 or patient.tract_depth > 0.06:
		_violation("état anatomique absurde (poumon %.2f, trajet %.3f)" % [patient.lung_collapse, patient.tract_depth])
	# 5. Aucun instrument tenu ne traverse la peau hors des zones permises
	for h in proc.hands:
		if h.held and not h.held.samples.is_empty():
			var tp := h.held.tip_global()
			var allowed := Contact.allowance(tp, h.held.samples[0][1])
			# Une image de décalage est normale (la plaie se referme entre deux poses) : il faut que ça dure
			var key := "deep_%s" % h.held.id
			if h.held.tip_depth > allowed + 0.004:
				_deep[key] = _deep.get(key, 0) + 1
				if _deep[key] == 4:
					_violation("%s enfoncé de %.0f mm (permis %.0f)" % [h.held.id, h.held.tip_depth * 1000.0, allowed * 1000.0])
			else:
				_deep[key] = 0
	if patient.open_l > 1.4 or patient.open_r > 1.4 or not is_finite(patient.open_l + patient.open_r):
		_violation("plaie déchirée %.2f / %.2f" % [patient.open_l, patient.open_r])
	if proc.errors < 0 or proc.elapsed < 0.0:
		_violation("compteurs invalides")


func _random_point() -> Vector3:
	match rng.randi_range(0, 4):
		0, 1, 2:  # champ opératoire / plaie
			var c := patient.center
			return c + Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.06, 0.15), rng.randf_range(-0.12, 0.12))
		3:  # plateau d'instruments
			return InstrumentTray.MAYO_POS + Vector3(rng.randf_range(-0.3, 0.3), InstrumentTray.TRAY_Y + rng.randf_range(0.0, 0.25), rng.randf_range(-0.25, 0.25))
		_:  # n'importe où
			return Vector3(rng.randf_range(-1.5, 1.5), rng.randf_range(0.5, 2.0), rng.randf_range(-1.5, 1.5))


## Rafale d'actions au hasard : regard, clic, molette, touches (instruments, reposer, vue anatomique).
func chaos_burst(frames: int) -> void:
	var b := bot as PlayerBot
	for f in frames:
		if rng.randf() < 0.08:
			b.aim(_random_point())
		if rng.randf() < 0.03 and proc.marker.visible:
			b.aim(proc.marker.global_position)
		var r := rng.randf()
		if r < 0.06:
			b.hand.sim_click = rng.randi_range(0, 1)
		elif r < 0.08:
			b.key([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_R, KEY_9, KEY_0, KEY_E][rng.randi_range(0, 11)])
		elif r < 0.10:
			b.hand.lift = clampf(b.hand.lift + rng.randf_range(-0.01, 0.01), 0.0, 0.12)
		elif r < 0.105:
			b.player.view_mode_requested.emit()
		elif r < 0.11:
			b.player.position = b.home + Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(0.0, 0.4))
		await get_tree().process_frame


func run(seed_value: int) -> void:
	rng.seed = seed_value
	_checking = true
	await get_tree().process_frame
	await bot.start()
	var guard := 0
	while proc.step >= 0 and proc.step < proc.steps.size() and guard < 40:
		guard += 1
		var s := proc.step
		await chaos_burst(rng.randi_range(120, 360))
		(bot as PlayerBot).player.position = (bot as PlayerBot).home
		if patient.view_mode != 0:
			patient.set_view_mode(0)
		await bot.do_step()
		if proc.step == s:
			print("CHAOS BLOQUÉ à l'étape ", proc.steps[s]["id"])
			break
	var ok := proc.step >= proc.steps.size() and violations == 0 and bot.ok
	await bot.cleanup()
	await get_tree().create_timer(0.8).timeout
	for inst in tray.ordered:
		if not inst.parked and inst.global_position.distance_to(inst.tray_transform.origin) > 0.01:
			print("CHAOS : ", inst.id, " pas revenu sur la table (", inst.global_position, " au lieu de ", inst.tray_transform.origin, ", tenu : ", inst.held, ", parqué : ", inst.parked, ")")
			ok = false
	print("CHAOS %s graine %d : %s (étapes %d/%d, erreurs joueur %d, invariants violés %d)" % [proc.op.id, seed_value, "OK" if ok else "ÉCHEC", proc.step, proc.steps.size(), proc.errors, violations])
	for e in proc.error_log:
		print("CHAOS   erreur : ", e)
