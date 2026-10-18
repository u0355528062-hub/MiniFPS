class_name ERBot
extends Node
## Robot de test : joue le cas choisi comme un bon urgentiste, en passant par les vrais gestes
## (mêmes fonctions que la souris), puis conclut. Vérifie que la prise en charge mène au bon devenir.
##   godot --headless --path . -- --case=acr_fv --autotest

var game: ERGame
var g: Gestures
var inv: Inventory


func _log(t: String) -> void:
	print("ROBOT %6.1f s  %s" % [game.physio.time, t])


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func run() -> void:
	Engine.time_scale = 4.0
	g = game.gestures
	inv = game.inv
	await wait(0.5)
	game._start()
	game._on_interact(_find_interactable("gants"))
	match game.case.id:
		"acr_fv":
			await _acr()
		"sca_st":
			await _sca()
		"overdose":
			await _overdose()
		"hypoglycemie":
			await _hypo()
		"asthme":
			await _asthme()
		"anaphylaxie":
			await _anaphylaxie()
	await wait(0.5)
	if not game._ended:
		_log("conclusion : %s / %s" % [game.case.diag_ok, game.case.orient_ok])
		game.conclude(game.case.diag_ok, game.case.orient_ok)
	await wait(1.0)
	Engine.time_scale = 1.0


## Partie d'une capture : quelques étapes seulement (pour photographier une situation).
func run_steps(n: int) -> void:
	g = game.gestures
	inv = game.inv
	match game.case.id:
		"acr_fv":
			_take("pads")
			g._pad(Vector3(0.05, 1.05, -0.07))
			g._pad(Vector3(-0.04, 1.0, 0.14))
			if n > 1:
				_take("electrodes")
				g._scope_electrode(Vector3(0.09, 1.0, -0.12))
				g._scope_electrode(Vector3(0.09, 1.0, 0.12))
				g._scope_electrode(Vector3(-0.2, 1.0, 0.1))
		_:
			_take("electrodes")
			g._scope_electrode(Vector3(0.09, 1.0, -0.12))
			g._scope_electrode(Vector3(0.09, 1.0, 0.12))
			g._scope_electrode(Vector3(-0.2, 1.0, 0.1))
			_take("spo2")
			g.gear.place_spo2("R")
	await wait(0.2)


## Capture : souris posée sur un point du monde (--aim=x,y,z), pour voir l'aperçu sous la souris.
func shot_extra(args: Dictionary) -> void:
	g = game.gestures
	inv = game.inv
	if args.has("iv"):
		# Voie veineuse sur le bras droit, faite jusqu'à l'étape N (8 : perfusion branchée)
		var n := int(args["iv"])
		game.flags["gants"] = true
		game.zone_view.enter("perf_R")
		await wait(0.5)
		_iv("R", clampi(n - 1, 0, 6))
		var pr: IVProcedure = g.iv_proc
		if n >= 8:
			_take("perfuseur")
			pr.press({"pos": g.gear.iv["hub"], "normal": Vector3.UP, "collider": null})
		match String(args.get("ivpart", "")):
			"reflux", "avance":
				# Ponction en cours : aiguille dans la veine, sang dans la chambre de reflux
				var h := {"pos": pr.chosen["p"], "normal": Vector3.UP, "collider": null}
				pr.press(h)
				pr._advance(IVProcedure.PUSH_PX * 1.5)
				if args["ivpart"] == "avance":
					pr._advance(IVProcedure.PUSH_PX * 0.6)
			"seringue":
				_take("seringue", {"drug": "morphine", "dose": 3.0, "route": "IV", "name": "Morphine 3 mg IV"})
				g._syringe_press(g.gear.iv["port"], "bras_R")
				g._hold = {}
				g.iv_proc.syringe_progress(0.4)
		await wait(float(args.get("wait", "2.5")))
		if args.has("at"):
			# Vue à la première personne vers un point (ex. la poche sur la potence)
			game.zone_view.exit()
			await wait(0.8)
			var t: PackedFloat64Array = String(args["at"]).split_floats(",")
			game.player.look_towards(Vector3(t[0], t[1], t[2]))
	if args.has("aim"):
		var a: PackedFloat64Array = String(args["aim"]).split_floats(",")
		_aim_at(Vector3(a[0], a[1], a[2]))


## Garde la souris sur un point du monde (vue rapprochée) pendant toute la capture.
func _aim_at(p: Vector3) -> void:
	var cb := func() -> void:
		if game.zone_view.active:
			get_viewport().warp_mouse(game.zone_view.camera.unproject_position(p))
	get_tree().process_frame.connect(cb)


func _take(id: String, data := {}) -> void:
	if not inv.has(id) or id == "seringue":
		inv.add(id, data)
	inv.select_id(id)
	if id == "seringue":
		inv.select(inv.items.size() - 1)


func _skin(x: float, z: float) -> Vector3:
	return Vector3(x, Patient.body_height(x, z), z)


# ---------------------------------------------------------------- Gestes de base

func _assess() -> void:
	g._stimulate()
	g.airway_open = true
	g._airway_result()
	g._pulse_result("carotidien")
	_log("évaluation : %s" % game.journal.last("pouls").get("text", ""))


func _monitor() -> void:
	_take("electrodes")
	g._scope_electrode(_skin(0.09, -0.12))
	g._scope_electrode(_skin(0.09, 0.12))
	g._scope_electrode(_skin(-0.22, 0.1))
	_take("spo2")
	g._process(0.0)
	g.gear.place_spo2("R")
	inv.use_current()
	game.event("spo2", "Capteur de SpO2 posé")
	_take("brassard")
	g.gear.place_cuff("L")
	inv.use_current()
	game.monitor.measure_nibp()
	game.event("brassard", "Brassard posé")
	_log("scope branché")


## Voie veineuse complète, étape par étape, avec les mêmes gestes que la souris (clic, glisser).
func _iv(side := "R", stop_after := 7) -> void:
	if not game.flags["gants"]:
		game._on_interact(_find_interactable("gants"))
	for id in ["garrot", "antiseptique", "catheter18"]:
		if not inv.has(id):
			inv.add(id)
	var pr: IVProcedure = g.iv_proc
	pr.start(side, false)
	var arm := func(t: float) -> Dictionary:
		var q := Patient.arm_top(side, t)
		return {"pos": q, "normal": Vector3.UP, "collider": null}
	var steps := [
		func() -> void:  # 1. garrot au-dessus du coude, on tire pour serrer
			var h: Dictionary = arm.call(0.34)
			pr.press(h)
			pr.drag(h, Vector2(IVProcedure.PULL_PX, 0.0))
			pr.release(h),
		func() -> void:  # 2. désinfection en frottant
			var h: Dictionary = arm.call(0.5)
			pr.press(h)
			for k in 10:
				pr.drag(h, Vector2(IVProcedure.RUB_PX / 10.0, 0.0))
			pr.release(h),
		func() -> void:  # 3. palpation de la veine du pli du coude
			var q: Vector3 = (pr.vein_by("pli", side)["pts"] as PackedVector3Array)[1]
			pr.press({"pos": q, "normal": Vector3.UP, "collider": null})
			pr._palpate(pr.vein_near(q, side)),
		func() -> void:  # 4. ponction : l'aiguille entre, reflux, on avance le cathéter, on retire l'aiguille
			var h: Dictionary = {"pos": pr.chosen["p"], "normal": Vector3.UP, "collider": null}
			pr.press(h)
			for k in 6:
				pr.drag(h, pr._screen_dir() * IVProcedure.PUSH_PX * 0.5)
			for k in 6:
				pr.drag(h, -pr._screen_dir() * IVProcedure.PUSH_PX * 0.5)
			pr.release(h),
		func() -> void:  # 5. garrot desserré
			pr.press(arm.call(0.36)),
		func() -> void:  # 6. pansement transparent
			var h := {"pos": g.gear.iv["hub"], "normal": Vector3.UP, "collider": null}
			pr.press(h)
			pr.drag(h, Vector2(IVProcedure.DRESS_PX, 0.0))
			pr.release(h),
	]
	for i in mini(stop_after, steps.size()):
		if not pr.active or pr.step != i:
			_log("ÉCHEC : voie veineuse bloquée à l'étape %d (%s)" % [pr.step + 1, IVProcedure.STEPS[pr.step]])
			return
		(steps[i] as Callable).call()
		if i == 3 and stop_after > 4 and g.gear.has_iv():
			# Prélèvement sur le cathéter (avant de desserrer le garrot)
			_take("tubes")
			inv.select_id("tubes")
			if g._near_port(g.gear.iv["port"]):
				inv.use_current()
				game.event("prelevement", "Tubes prélevés")
	_log("voie veineuse : %s (étape %d/7)" % [game.journal.has("vvp"), pr.step + 1])


func _find_interactable(id: String) -> Interactable:
	for n in game.room.find_children("*", "Interactable", true, false):
		if (n as Interactable).id == id:
			return n
	return null


func _inject(drug: String, dose: float, route: String) -> void:
	_take("seringue", {"drug": drug, "dose": dose, "route": route, "name": Drugs.label(drug, dose, route)})
	if route == "IV":
		g._syringe_press(g.gear.iv["port"], "bras_R")
	else:
		g._syringe_press(_skin(-0.6, 0.08), "jambes")
	if g._hold.is_empty():
		_log("ÉCHEC : injection refusée (%s)" % drug)
		return
	g._hold = {}
	g._inject_done()
	_log("injecté : %s" % Drugs.label(drug, dose, route))


func _compressions(n: int) -> void:
	for i in n:
		g._register_compression(0.055, 110.0, true)
		await wait(60.0 / 110.0)


func _ventilate(n: int) -> void:
	for i in n:
		g._squeeze = 0.0
		g._insufflate()
		await wait(1.2)


func _ecg12() -> void:
	inv.add("ecg12")
	inv.select_id("ecg12")
	var spots := [_skin(0.08, -0.14), _skin(0.08, 0.14), _skin(-0.3, -0.1), _skin(-0.3, 0.1)]
	# Précordiales : sur les vraies côtes
	var v := _find_ics(-4, -0.02)
	var v2 := _find_ics(-4, 0.02)
	var mcl := float(Patient.landmarks.get("mcl_z_L", 0.083))
	var v4 := _find_ics(-5, mcl)
	spots.append_array([v, v2, (v2 + v4) * 0.5, v4, _skin(v4.x, mcl + 0.03), _skin(v4.x, 0.14)])
	for p in spots:
		g._ecg12_electrode(_skin(p.x, p.z))
	game.record_ecg12()
	game.hud.close_panels()
	_log("ECG : %s" % game.journal.last("ecg12").get("text", ""))


## Point de la peau dans l'espace intercostal voulu, à la distance z du milieu.
func _find_ics(code: int, z: float) -> Vector3:
	for k in 120:
		var x := 0.1 - k * 0.002
		if Patient.rib_code(x, z) == code:
			# milieu de l'espace
			var x2 := x
			while Patient.rib_code(x2 - 0.002, z) == code:
				x2 -= 0.002
			return _skin((x + x2) * 0.5, z)
	return _skin(-0.02, z)


func _o2(kind: String, flow: float) -> void:
	var id: String = {"masque": "masque_o2", "lunettes": "lunettes_o2"}[kind]
	_take(id)
	g._o2_device(id)
	g.set_o2_flow(flow)


func _neb(drugs: Array) -> void:
	_take("nebuliseur", {"drugs": drugs, "name": "Nébulisation"})
	inv.select(inv.items.size() - 1)
	g.set_o2_flow(8.0)
	g._o2_device("nebuliseur")


func _ask_all() -> void:
	for i in game.case.questions.size():
		game.ask(i)


# ---------------------------------------------------------------- Cas

func _acr() -> void:
	_assess()
	g.cpr = false
	game.event("rcp", "Massage cardiaque externe débuté")
	await _compressions(30)
	_take("bavu")
	g._bavu_on()
	g.airway_open = true
	await _ventilate(2)
	_take("pads")
	g._pad(_skin(0.05, -0.07))
	g._pad(_skin(-0.04, 0.14))
	_take("electrodes")
	g._scope_electrode(_skin(0.09, -0.12))
	g._scope_electrode(_skin(0.09, 0.12))
	g._scope_electrode(_skin(-0.22, 0.1))
	game.defib.press("Bouton_Marche")
	var shocks := 0
	while game.physio.in_arrest() and shocks < 7 and not game.physio.dead:
		game.defib.press("Bouton_Analyse")
		await wait(5.5)
		if game.physio.shockable():
			await wait(4.5)
			game.defib.press("Bouton_Choc")
			shocks += 1
			_log("choc n°%d → %s" % [shocks, game.physio.rhythm])
		if not game.physio.in_arrest():
			break
		# 2 minutes de massage (30:2), traitements pendant ce temps
		var t0 := game.physio.time
		while game.physio.time - t0 < 120.0:
			await _compressions(30)
			await _ventilate(2)
			if shocks >= 1 and not game.gestures.gear.has_iv():
				_iv("R")
			if shocks >= 3 and not game.journal.has("drug:adrenaline"):
				_inject("adrenaline", 1.0, "IV")
				_inject("amiodarone", 300.0, "IV")
	_log("rythme : %s" % game.physio.rhythm)
	await wait(3.0)
	g._pulse_result("carotidien")
	_ecg12()


func _sca() -> void:
	_assess()
	_monitor()
	_ask_all()
	_ecg12()
	_iv("R")
	_inject("aspirine", 250.0, "IV")
	_inject("heparine", 4000.0, "IV")
	_inject("morphine", 3.0, "IV")
	game.order_exam("trop")
	await wait(3.0)


func _overdose() -> void:
	_assess()
	_take("bavu")
	g._bavu_on()
	g.airway_open = true
	await _ventilate(4)
	_take("spo2")
	g.gear.place_spo2("R")
	game.event("spo2", "")
	_take("glucometre")
	g._hold = {"kind": "glyc", "t": 9.0, "need": 4.0, "p": Vector3.ZERO}
	g._tick_hold(0.1, {})
	_take("lampe")
	g._pupils()
	_iv("R")
	game.order_exam("tox")
	_inject("naloxone", 0.1, "IV")
	await wait(20.0)
	_inject("naloxone", 0.1, "IV")
	await wait(30.0)
	_log("GCS %d, FR %d, SpO2 %d" % [game.physio.gcs, int(game.physio.rr), int(game.physio.spo2)])
	_ask_all()


func _hypo() -> void:
	_assess()
	_take("glucometre")
	g._hold = {"kind": "glyc", "t": 9.0, "need": 4.0, "p": Vector3.ZERO}
	g._tick_hold(0.1, {})
	_monitor()
	_iv("R")
	_inject("glucose30", 9.0, "IV")
	await wait(30.0)
	_take("glucometre")
	g._hold = {"kind": "glyc", "t": 9.0, "need": 4.0, "p": Vector3.ZERO}
	g._tick_hold(0.1, {})
	_log("glycémie %.2f, GCS %d" % [game.physio.glyc, game.physio.gcs])
	_ask_all()


func _asthme() -> void:
	_monitor()
	_take("stetho")
	g._ausc_result(_skin(0.06, 0.09))
	_neb([["salbutamol", 5.0], ["ipratropium", 0.5]])
	_iv("R")
	_inject("methylpred", 80.0, "IV")
	game.order_exam("gds")
	await wait(60.0)
	_neb([["salbutamol", 5.0]])
	await wait(60.0)
	_log("sévérité %.2f, SpO2 %d, FR %d" % [(game.case as CaseAsthme).severity, int(game.physio.spo2), int(game.physio.rr)])


func _anaphylaxie() -> void:
	_inject("adrenaline", 0.5, "IM")
	_o2("masque", 15.0)
	_monitor()
	_iv("R")
	_take("perfuseur")
	g._process(0.0)
	inv.select_id("perfuseur")
	var port: Vector3 = g.gear.iv["port"]
	g.press({"pos": port, "normal": Vector3.UP, "collider": null})
	_inject("methylpred", 80.0, "IV")
	# Comme un urgentiste : tant que le choc persiste, nouvelle dose d'adrénaline IM toutes les 5 min
	var case_a := game.case as CaseAnaphylaxie
	var last_adr := game.physio.time
	await wait(60.0)
	_log("choc %.2f, PA %d/%d" % [case_a.shock, int(game.physio.sys), int(game.physio.dia)])
	while case_a.shock >= 0.3 and game.physio.time < 900.0 and not game.physio.dead:
		if game.physio.time - last_adr >= 300.0:
			_inject("adrenaline", 0.5, "IM")
			last_adr = game.physio.time
		await wait(15.0)
	_log("choc %.2f, PA %d/%d" % [case_a.shock, int(game.physio.sys), int(game.physio.dia)])
	await wait(30.0)
