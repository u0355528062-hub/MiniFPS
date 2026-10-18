class_name ERGame
extends Node3D
## URGENCES — simulateur de médecine d'urgence. Point d'entrée : construit la salle de déchocage,
## le patient du cas choisi, sa physiologie, les appareils, le joueur, la vue rapprochée, les gestes,
## l'interface et les menus.
## Déroulé : menu principal → histoire « Première garde » (intro, puis 3 patients : carton, transmission
## dialoguée, prise en charge guidée, bilan avec l'avis du chef, transition, fin) ou entraînement
## libre (choix du cas → transmission → prise en charge → conclusion → bilan).
##
## Arguments (après « -- ») :
##   --case=id                 cas à jouer (acr_fv, sca_st, overdose, hypoglycemie, asthme, anaphylaxie)
##   --play                    sauter le menu principal
##   --story [--chapter=N]     mode histoire (avec --autotest : les 3 patients enchaînés par le robot)
##   --autotest                un robot joue le cas idéalement (vérification)
##   --shot=f.png --view=menu|training|story_intro|card|dialogue|tutorial|cart|constantes|briefing|
##          player|pause|options|end|bilan|story_end|zone:thorax|... --frames=N   capture d'écran

static var skip_menu := false
static var selected_case := "acr_fv"
static var pending := ""  ## après rechargement : "story_brief" (carton + transmission), "training"

var room: ERRoom
var patient: Patient
var physio: Physio
var monitor: VitalMonitor
var defib: Defibrillator
var player: Player
var zone_view: ZoneView
var gestures: Gestures
var inv: Inventory
var journal := Journal.new()
var case: Case
var hud: ERHud
var menus: Menus
var dialogue: DialogueBox
var guide: Guide
var env: WorldEnvironment
var flags := {"gants": false}
var state := "menu"  ## menu, briefing, play, pause, end
var args := {}
var lab_pending: Array = []  ## [exam, résultat, heure d'arrivée]
var results: Array = []  ## [exam, texte, heure]
var radio_tex: Texture2D
var _leaving := false
var _menu_cam: Camera3D
var _menu_t := 0.0
var _ended := false
var _testing := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_testing = args.has("autotest")
	if args.has("story") and not Story.active:
		Story.begin(true, _testing or args.has("shot"))
		Story.chapter = clampi(int(args.get("chapter", "0")), 0, Story.CHAPTERS.size() - 1)
		pending = "story_brief"
	if Story.active:
		selected_case = Story.current()["case"]
	elif args.has("case"):
		selected_case = args["case"]
	var sfx := Sfx.new()
	sfx.name = "Sons"
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	_build_environment()
	case = Case.create(selected_case)
	case.game = self
	room = ERRoom.new()
	room.name = "Salle"
	add_child(room)
	room.build()
	physio = Physio.new()
	physio.name = "Physiologie"
	add_child(physio)
	case.physio = physio
	patient = Patient.new()
	patient.name = "Patient"
	add_child(patient)
	patient.build(case.profile)
	# Scope sur le bras plafonnier
	monitor = VitalMonitor.new()
	monitor.name = "Scope"
	add_child(monitor)
	monitor.global_transform = room.monitor_anchor
	monitor.physio = physio
	monitor.gear = patient.gear
	var scope_scene: PackedScene = load("res://assets/models/scope.glb")
	monitor.build(scope_scene.instantiate())
	Interactable.make(monitor, "scope:pni", "Mesure de la pression (PNI)", "Appuyer", Vector3(0.05, 0.04, 0.03), monitor.global_transform * Vector3(0.16, -0.12, 0.01), Patient.LAYER_DEVICE)
	defib = Defibrillator.new()
	defib.name = "Defibrillateur"
	add_child(defib)
	defib.setup(room.defib_root, physio, patient.gear)
	defib.set_meta("monitor", monitor)
	defib.shocked.connect(_on_shock)
	defib.analysed.connect(func(adv: bool) -> void: event("analyse", "Analyse du rythme : choc %s" % ("recommandé" if adv else "non recommandé")))
	# Électrocardiographe : électrodes à prendre, bouton d'enregistrement
	var ecg_xf := room.ecg_root.global_transform
	Interactable.make(room.ecg_root, "ecg:electrodes", "Prendre les électrodes de l'ECG", "Prendre", Vector3(0.1, 0.12, 0.1), ecg_xf * Vector3(0.22, 0.85, 0.08), Patient.LAYER_DEVICE)
	Interactable.make(room.ecg_root, "ecg:enregistrer", "Enregistrer l'ECG", "Appuyer", Vector3(0.3, 0.02, 0.1), ecg_xf * Vector3(0.0, 0.935, 0.06), Patient.LAYER_DEVICE)
	# Débitmètre d'oxygène : + et -
	Interactable.make(room, "rampe:plus", "Oxygène : augmenter le débit", "Tourner", Vector3(0.04, 0.04, 0.05), Vector3(1.47, 1.66, -0.35), Patient.LAYER_DEVICE)
	Interactable.make(room, "rampe:moins", "Oxygène : diminuer le débit", "Tourner", Vector3(0.04, 0.04, 0.05), Vector3(1.47, 1.4, -0.35), Patient.LAYER_DEVICE)
	room.add_interactables(room)
	inv = Inventory.new()
	player = Player.new()
	player.name = "Joueur"
	add_child(player)
	player.build(Vector3(-0.1, 0.0, 0.85), Vector3(-0.05, 1.0, 0.0))
	player.interact_requested.connect(_on_interact)
	player.pause_requested.connect(_on_pause_key)
	player.key_action.connect(_on_key_action)
	zone_view = ZoneView.new()
	zone_view.name = "VueRapprochee"
	zone_view.player = player
	add_child(zone_view)
	_define_zones()
	gestures = Gestures.new()
	gestures.name = "Gestes"
	add_child(gestures)
	zone_view.gestures = gestures
	gestures.setup(self)
	defib.set_meta("gestures", gestures)
	hud = ERHud.new()
	hud.name = "HUD"
	hud.game = self
	add_child(hud)
	hud.build()
	zone_view.entered.connect(func(_z: String) -> void: hud.zone_mode(true))
	zone_view.exited.connect(func() -> void: hud.zone_mode(false))
	inv.changed.connect(hud.refresh_hotbar)
	_vignette()
	menus = Menus.new()
	menus.name = "Menus"
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	menus.game = self
	add_child(menus)
	menus.build()
	menus.case_chosen.connect(_choose_case)
	menus.story_pressed.connect(_start_story)
	menus.start_pressed.connect(_start)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(_restart)
	menus.next_pressed.connect(_story_next)
	menus.main_menu_pressed.connect(_to_main_menu)
	menus.training_pressed.connect(_to_training)
	menus.quit_pressed.connect(func() -> void: _quit())
	dialogue = DialogueBox.new()
	dialogue.name = "Dialogues"
	dialogue.auto = _testing
	dialogue.patient_profile = case.profile
	add_child(dialogue)
	if args.has("quality"):
		Settings.quality = int(args["quality"])
	Settings.apply_graphics(env.environment, get_viewport())
	case.setup()
	physio.died.connect(_on_died)
	_sync_patient(0.0)
	if Story.active:
		guide = Guide.new()
		guide.name = "Guide"
		add_child(guide)
		guide.setup(self)
	if _testing or args.has("shot"):
		await _run_cli()
		return
	if Story.active and pending == "story_brief":
		pending = ""
		_story_briefing()
	elif skip_menu or args.has("play"):
		skip_menu = false
		_go_briefing(true)
	else:
		_show_main_menu()
		if pending == "training":
			pending = ""
			menus.show_training()


func _define_zones() -> void:
	var zv := zone_view
	var ideal := Vector3(-0.03, 1.06, 0.0)
	zv.define("thorax", "Thorax", ideal + Vector3(0.08, -0.02, 0.0), 0.0, 58.0, 0.72, 0.25, 1.2)
	var nose := Patient.lm("nose_tip")
	var neck_x := float(Patient.landmarks.get("neck", {"x": 0.18})["x"])
	zv.define("tete", "Tête et visage", Vector3(nose.x + 0.01, nose.y - 0.03, 0.0), 0.55, 52.0, 0.42, 0.15, 0.9)
	zv.define("cou", "Cou", Vector3(neck_x, 0.98, 0.02), 0.25, 55.0, 0.36, 0.15, 0.8)
	zv.define("abdomen", "Abdomen", Vector3(-0.27, 1.0, 0.0), 0.0, 58.0, 0.55, 0.2, 1.0)
	for side in ["L", "R"]:
		var mid := Patient.arm_point(side, 0.55)
		var hand := Patient.arm_point(side, 0.9)
		var yaw := 0.0 if side == "L" else PI
		var nm := "gauche" if side == "L" else "droit"
		zv.define("bras_" + side, "Bras " + nm, mid + Vector3(0, 0.05, 0), yaw, 60.0, 0.55, 0.15, 1.0)
		zv.define("main_" + side, "Main " + ("gauche" if side == "L" else "droite"), hand + Vector3(0, 0.03, 0), yaw, 58.0, 0.32, 0.12, 0.8)
	zv.define("jambes", "Jambes (cuisse)", Vector3(-0.68, 0.95, 0.05), 0.0, 55.0, 0.7, 0.25, 1.2)
	var d := room.defib_root
	zv.define("defib", "Défibrillateur", d.global_transform * Vector3(0.02, 0.14, 0.0), d.rotation.y, 18.0, 0.5, 0.25, 1.0)
	var m := room.monitor_anchor
	zv.define("scope", "Scope", m.origin, atan2(m.basis.z.x, m.basis.z.z), 5.0, 0.55, 0.25, 1.0)
	var e := room.ecg_root
	zv.define("ecg", "Électrocardiographe", e.global_transform * Vector3(0.0, 0.92, 0.0), e.rotation.y, 40.0, 0.7, 0.3, 1.2)
	zv.define("rampe", "Débitmètre d'oxygène", Vector3(1.44, 1.52, -0.35), -PI * 0.5, 8.0, 0.45, 0.2, 0.9)


func _vignette() -> void:
	var vig_layer := CanvasLayer.new()
	vig_layer.name = "Vignettage"
	vig_layer.layer = 1
	add_child(vig_layer)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/vignette.gdshader")
	vig.material = vm
	vig_layer.add_child(vig)


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if state in ["menu", "story_intro"] and _menu_cam:
		_menu_t += delta * 0.06
		var a := 0.9 + sin(_menu_t) * 0.6
		var c := Vector3(-0.3, 1.0, 0.0)
		_menu_cam.global_position = c + Vector3(cos(a) * 2.2, 0.85 + 0.12 * sin(_menu_t * 1.7), sin(a) * 2.2)
		_menu_cam.look_at(c + Vector3(0.2, 0.0, 0.0))
	if state != "play":
		return
	case.tick(delta)
	case.chatter(delta)
	_sync_patient(delta)
	# Résultats d'examens qui arrivent
	for i in range(lab_pending.size() - 1, -1, -1):
		var lp: Array = lab_pending[i]
		if physio.time >= float(lp[2]):
			results.append([lp[0], lp[1], physio.time])
			lab_pending.remove_at(i)
			if lp[0] == "radio":
				if radio_tex:
					room.show_imaging(radio_tex)
				say("La radio est sur l'écran d'imagerie.", "ide")
			else:
				hud.toast("Résultat arrivé : %s" % Labs.NAMES.get(lp[0], lp[0]), true)
	if physio.dead and not _ended:
		_finish(false)


## Ce qu'on voit du patient suit sa physiologie.
func _sync_patient(_delta: float) -> void:
	patient.set_signs(physio.signs)
	if physio.in_arrest():
		patient.set_eyes_open(0.15)


# ---------------------------------------------------------------- Événements

func now() -> float:
	return physio.time


func event(kind: String, text := "", data := {}) -> void:
	journal.add(physio.time, kind, text, data)
	case.on_event(kind, data)


func toast(text: String, ok := true) -> void:
	if hud:
		hud.toast(text, ok)


func say(text: String, who := "patient") -> void:
	if hud:
		hud.say(text, who)


func set_progress(v: float, label: String) -> void:
	if hud:
		hud.set_progress(v, label)


func case_fault(text: String, pts: float) -> void:
	case.fault(text, pts)


## Un médicament est administré (seringue, perfusion, nébulisation).
func drug_given(drug: String, dose: float, route: String) -> void:
	case.on_drug(drug, dose, route)
	var txt := "%s %s %s" % [Drugs.name_of(drug), Drugs.dose_text(drug, dose), route]
	event("drug:" + drug, txt, {"dose": dose, "route": route})
	event("traitement", "")
	var simple := "%s %s — %s" % [Drugs.name_of(drug), Drugs.dose_text(drug, dose), Lexique.route(route).to_lower()]
	toast("Injecté : " + simple if route in ["IV", "IM"] else simple)
	Sfx.play("succes", Vector3.INF, -14.0)


func on_compression(_depth: float, _rate: float) -> void:
	pass


func on_insufflation(_effective: bool) -> void:
	pass


func _on_shock(energy: int) -> void:
	event("choc", "Choc électrique externe %d J" % energy)
	if gestures.cpr:
		case_fault("Choc délivré pendant que vous touchiez le patient !", 10.0)
	patient.set_compression(0.0)
	# Le corps sursaute
	var tw := create_tween()
	tw.tween_property(patient, "position:y", 0.02, 0.06)
	tw.tween_property(patient, "position:y", 0.0, 0.18)
	case.on_shock(energy)


func record_ecg12() -> void:
	if patient.gear.ecg12.size() < 10:
		toast("Pose d'abord les 10 électrodes de l'ECG", false)
		return
	var e := case.ecg12()
	var bad: Array = flags.get("ecg12_bad", [])
	event("ecg12", "ECG 12 dérivations : " + String(e["text"]), e)
	hud.show_ecg(e, bad)
	Sfx.play("clic", Vector3.INF, -8.0)


## Prescription d'un examen (ordinateur) : il faut un prélèvement pour la biologie.
func order_exam(exam: String) -> String:
	if exam == "radio":
		if journal.has("exam:radio"):
			return "Radio déjà demandée"
		var x := case.xray()
		var path: String = x.get("tex", "")
		radio_tex = load(path) if path != "" and ResourceLoader.exists(path) else load("res://assets/textures/radio_normale.png") if ResourceLoader.exists("res://assets/textures/radio_normale.png") else null
		lab_pending.append(["radio", x["text"], physio.time + 50.0])
		event("exam:radio", "Radio du thorax au lit demandée")
		say("Le manipulateur radio arrive.", "ide")
		return "Radio demandée : le manipulateur arrive"
	if not journal.has("prelevement"):
		return "Il faut d'abord prélever des tubes (sur le cathéter)"
	if journal.has("exam:" + exam):
		return "Déjà demandé"
	var delay := 25.0 if exam == "gds" else 45.0
	lab_pending.append([exam, case.lab(exam), physio.time + delay])
	event("exam:" + exam, "Demandé : %s" % Labs.NAMES.get(exam, exam))
	return "Demandé : résultat dans quelques minutes"


## Interrogatoire : une question posée au patient.
func ask(i: int) -> void:
	if i < 0 or i >= case.questions.size():
		return
	var q: Array = case.questions[i]
	if not physio.speaks:
		say("…", "patient")
		toast("Il ne peut pas répondre", false)
		return
	event("question", "« %s » — %s" % [q[0], q[1]])
	say(q[1], "patient")


## Conclusion : diagnostic et orientation → fin du cas.
func conclude(diag: String, orient: String) -> void:
	event("diagnostic", "Diagnostic retenu : " + diag)
	event("orientation", "Orientation : " + orient)
	if diag == case.diag_ok:
		event("diag_ok", "")
	var ok_orient := orient == case.orient_ok
	if case is CaseAsthme and orient == "Réanimation" and (case as CaseAsthme).severity > 0.5:
		ok_orient = true
	if ok_orient:
		event("orient_ok", "")
	_finish(not physio.in_arrest() and not physio.dead)


func _on_died() -> void:
	if not _ended:
		_finish(false)


## Évaluation : objectifs atteints, erreurs, devenir du patient → note.
func evaluate(alive: bool) -> Dictionary:
	var objs := case.objectives()
	var total := 0.0
	var got := 0.0
	var lines := []
	for o in objs:
		total += float(o[1])
		if o[2]:
			got += float(o[1])
		lines.append([o[0], o[1], o[2], o[3] if o.size() > 3 else "", o.size() > 4 and o[4]])
	var pen := 0.0
	for e in case.errors:
		pen += float(e[1])
	var score := clampf(got / maxf(total, 1.0) * 100.0 - pen, 0.0, 100.0)
	if not alive:
		score = minf(score, 45.0)
	var grade := "D"
	if score >= 92.0 and case.errors.is_empty() and alive:
		grade = "S"
	elif score >= 80.0:
		grade = "A"
	elif score >= 65.0:
		grade = "B"
	elif score >= 45.0:
		grade = "C"
	return {"score": score, "grade": grade, "objectives": lines, "errors": case.errors.duplicate(), "alive": alive,
		"time": physio.time, "summary": case.summary_good if alive else case.summary_bad}


func _finish(alive: bool) -> void:
	if _ended:
		return
	_ended = true
	var res := evaluate(alive)
	if not _testing and not args.has("shot"):
		res["record"] = Records.submit(case.id, res["grade"], res["score"], physio.time)
	if Story.active:
		res["chief"] = Story.debrief(Story.chapter, res)
		Story.record(res)
	else:
		res["chief"] = _chief_comment(res)
	if _testing:
		print("FIN DU CAS %s — %s — note %s (%d/100) — vivant : %s — erreurs : %s" % [case.id, case.name, res["grade"], int(res["score"]), alive, str(case.errors)])
		for l in res["objectives"]:
			print("   %s %s" % ["[x]" if l[2] else "[ ]", l[0]])
	await get_tree().create_timer(0.1 if _testing else 1.6).timeout
	state = "end"
	if zone_view.active:
		zone_view.exit()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.enabled = false
	hud.visible = false
	dialogue.hide_bark()
	menus.show_end(res)


# ---------------------------------------------------------------- Interactions

func _on_interact(it: Interactable) -> void:
	if state != "play":
		return
	if it.zone != "":
		zone_view.enter(it.zone)
		return
	match it.id:
		"chariot", "armoire":
			hud.open_cart(it.id)
		"defib":
			zone_view.enter("defib")
		"scope":
			zone_view.enter("scope")
		"ecg":
			zone_view.enter("ecg")
		"rampe":
			zone_view.enter("rampe")
		"poste":
			hud.open_computer()
		"imagerie":
			if radio_tex and journal.has("exam:radio") and lab_pending.filter(func(l: Array) -> bool: return l[0] == "radio").is_empty():
				hud.show_image(radio_tex, _result_text("radio"))
			else:
				toast("Aucune image pour l'instant", false)
		"gants":
			if not flags["gants"]:
				flags["gants"] = true
				event("gants", "Gants mis")
				toast("Gants enfilés")
				Sfx.play("drap", Vector3.INF, -12.0, 1.4)
		"sha", "lavabo":
			event("hygiene", "Hygiène des mains")
			toast("Friction hydro-alcoolique des mains")
			Sfx.play("souffle", Vector3.INF, -18.0, 1.6)


func _result_text(exam: String) -> String:
	for r in results:
		if r[0] == exam:
			return r[1]
	return ""


func _on_key_action(action: String) -> void:
	if state != "play":
		return
	match action:
		"parler":
			if player.global_position.distance_to(Vector3(0.0, 0.0, 0.0)) < 2.2:
				hud.open_dialogue()
		"dossier":
			hud.open_computer()


# ---------------------------------------------------------------- États

func _show_main_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	player.enabled = false
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 55
	add_child(_menu_cam)
	_menu_cam.current = true
	menus.show_main()


func _choose_case(case_id: String) -> void:
	if _leaving or state != "menu":
		return
	Story.stop()
	if case_id == case.id:
		_go_briefing()
		return
	_leaving = true
	selected_case = case_id
	skip_menu = true
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _go_briefing(instant := false) -> void:
	if _menu_cam and not instant:
		menus.hide_all()
		var from := _menu_cam.global_transform
		var to := player.camera.global_transform
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		state = "fly"
		tw.tween_method(func(k: float) -> void:
			_menu_cam.global_transform = Transform3D(Basis(Quaternion(from.basis.orthonormalized()).slerp(Quaternion(to.basis.orthonormalized()), k)), from.origin.lerp(to.origin, k)), 0.0, 1.0, 1.5)
		await tw.finished
	if _menu_cam:
		_menu_cam.queue_free()
		_menu_cam = null
	player.camera.current = true
	state = "briefing"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	player.enabled = false
	menus.show_briefing()


func _start() -> void:
	if state != "briefing":
		return
	state = "play"
	menus.hide_all()
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.enabled = true
	event("debut", "Prise en charge débutée")


func _on_pause_key() -> void:
	if dialogue and dialogue.active:
		return
	match state:
		"play":
			if hud.any_panel_open():
				hud.close_panels()
				return
			if zone_view.active:
				if not gestures.cancel_current():
					zone_view.exit()
				return
			state = "pause"
			get_tree().paused = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			menus.show_pause()
		"pause":
			_resume()


func _resume() -> void:
	state = "play"
	get_tree().paused = false
	menus.hide_all()
	if not zone_view.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	skip_menu = true
	if Story.active:
		pending = "story_brief"
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	skip_menu = false
	Story.stop()
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _to_training() -> void:
	if state == "menu":
		menus.show_training()
		return
	pending = "training"
	_to_main_menu()


## Avis du chef en entraînement libre (selon la note).
func _chief_comment(res: Dictionary) -> String:
	if not res["alive"]:
		return "On l'a perdu. Relis les objectifs manqués : souvent, c'est le premier geste qui a manqué ou qui est venu trop tard."
	match res["grade"]:
		"S":
			return "Parfait, rien à redire. Tu peux viser le même résultat plus vite."
		"A":
			return "Très bonne prise en charge. Il ne manque presque rien."
		"B":
			return "C'est bien. Regarde les objectifs manqués : ce sont eux qui feront la différence."
		"C":
			return "Le patient s'en sort, mais plusieurs choses importantes ont manqué. Recommence en suivant la liste « À faire »."
	return "Il y a beaucoup à revoir. Pas d'inquiétude : recommence, en suivant la liste « À faire » en haut à gauche."


# ---------------------------------------------------------------- Histoire

## Menu → histoire : l'intro (sur le fond animé de la salle) puis le premier patient.
func _start_story(fresh: bool) -> void:
	if _leaving or state != "menu":
		return
	Story.begin(fresh)
	menus.hide_all()
	if Story.chapter == 0:
		state = "story_intro"
		dialogue.patient_profile = {}
		await dialogue.play(Story.intro_lines())
	_leaving = true
	selected_case = Story.current()["case"]
	skip_menu = true
	pending = "story_brief"
	await menus.fade(true, 0.5)
	get_tree().reload_current_scene()


## Carton du chapitre, transmission en dialogue, puis on entre dans le box.
func _story_briefing() -> void:
	state = "briefing"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	player.enabled = false
	player.camera.current = true
	var ch: Dictionary = Story.current()
	menus.set_black(true)
	await menus.show_chapter_card("Patient %d / 3%s" % [Story.chapter + 1, "  ·  tutoriel" if ch.get("tutorial", false) else ""], ch["title"], ch["time"], 0.1 if _testing else 2.0)
	await menus.hide_chapter_card(0.1 if _testing else 0.8)
	await dialogue.play(Story.briefing_lines(Story.chapter))
	state = "briefing"
	_start()


## Bilan → patient suivant (ou fin de la garde).
func _story_next() -> void:
	if _leaving:
		return
	if Story.advance():
		_leaving = true
		selected_case = Story.current()["case"]
		skip_menu = true
		pending = "story_brief"
		await menus.fade(true, 0.5)
		get_tree().reload_current_scene()
		return
	menus.hide_all()
	hud.visible = false
	await dialogue.play(Story.ending_lines())
	if _testing:
		print("FIN DE L'HISTOIRE — %s" % str(Story.results))
		return
	menus.show_story_end()


func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.66, 0.7, 0.72)
	e.ambient_light_energy = 0.38
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.3
	e.glow_strength = 0.85
	e.glow_bloom = 0.03
	e.glow_hdr_threshold = 1.3
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.volumetric_fog_density = 0.004
	e.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
	e.volumetric_fog_length = 8.0
	e.volumetric_fog_ambient_inject = 0.1
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.02
	env.environment = e
	add_child(env)


# ---------------------------------------------------------------- Tests et captures

func _run_cli() -> void:
	if args.has("autotest") and Story.active:
		await _story_autotest()
		return
	state = "play"
	hud.visible = true
	player.enabled = true
	if args.has("autotest"):
		var bot := ERBot.new()
		bot.game = self
		add_child(bot)
		await bot.run()
		await _quit()
		return
	if args.has("shot"):
		await _take_shot()


## Test du mode histoire : intro, puis pour chaque patient carton + transmission (dialogues passés
## automatiquement), le robot joue, bilan, patient suivant ; à la fin, le dialogue de fin.
func _story_autotest() -> void:
	if Story.chapter == 0 and not Story.results.has(0):
		print("HISTOIRE : intro (%d répliques)" % Story.intro_lines().size())
		await dialogue.play(Story.intro_lines())
	print("HISTOIRE : patient %d / 3 — %s (%s)" % [Story.chapter + 1, Story.current()["title"], case.id])
	await _story_briefing()
	var bot := ERBot.new()
	bot.game = self
	add_child(bot)
	await bot.run()
	if guide and guide.is_tutorial():
		print("HISTOIRE : tutoriel, étape %d / %d atteinte" % [mini(guide.current + 1, guide.steps.size()), guide.steps.size()])
	await get_tree().create_timer(2.0).timeout
	print("HISTOIRE : avis du chef — %s" % Story.debrief(Story.chapter, Story.results.get(Story.chapter, {})))
	var last := Story.chapter >= Story.CHAPTERS.size() - 1
	await _story_next()
	if last:
		await _quit()


func _take_shot() -> void:
	var view: String = args.get("view", "player")
	if view == "menu":
		_show_main_menu()
		_menu_t = 0.9
	elif view == "training":
		_show_main_menu()
		_menu_t = 0.9
		menus.show_training()
	elif view == "story_intro":
		_show_main_menu()
		_menu_t = 0.9
		menus.hide_all()
		state = "story_intro"
		dialogue.patient_profile = {}
		var lines: Array = Story.intro_lines()
		dialogue.auto = false
		dialogue.play([lines[int(args.get("line", "1"))]])
		await get_tree().create_timer(3.0).timeout
	elif view == "card":
		state = "briefing"
		hud.visible = false
		var ch: Dictionary = Story.current() if Story.active else Story.CHAPTERS[1]
		menus.show_chapter_card("Patient %d / 3" % (Story.chapter + 1), ch["title"], ch["time"], 0.0)
		await get_tree().create_timer(1.5).timeout
	elif view == "dialogue":
		state = "briefing"
		hud.visible = false
		player.enabled = false
		dialogue.auto = false
		var bl: Array = Story.briefing_lines(Story.chapter)
		dialogue.play([bl[clampi(int(args.get("line", "0")), 0, bl.size() - 1)]])
		await get_tree().create_timer(3.5).timeout
	elif view in ["tutorial", "cart", "constantes", "pause", "options", "bilan", "story_end"]:
		state = "play"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if view == "constantes":
			var bot := ERBot.new()
			bot.game = self
			add_child(bot)
			bot.g = gestures
			bot.inv = inv
			bot._monitor()
			inv.add("glucometre")
		if args.has("at"):
			var t2: PackedFloat64Array = args["at"].split_floats(",")
			player.look_towards(Vector3(t2[0], t2[1], t2[2]))
		if view == "cart":
			hud.open_cart("chariot")
			if args.has("tab"):
				var tb: Button = hud.marks.get("cart:tab:" + String(args["tab"]))
				if tb:
					tb.button_pressed = true
					tb.pressed.emit()
		if guide and args.has("step"):
			guide.current = -1
			for i in guide.steps.size():
				guide._latched[i] = i < int(args["step"])
		await get_tree().create_timer(1.0).timeout
		if args.has("bark"):
			var rules: Array = Story.coach_rules(Story.chapter)
			var r: Dictionary = rules[clampi(int(args["bark"]), 0, rules.size() - 1)] if not rules.is_empty() else {"who": "sophie", "text": "Bonjour !"}
			dialogue.bark(r["who"], r["text"])
			await get_tree().create_timer(0.6).timeout
		if view == "pause":
			state = "pause"
			menus.show_pause()
		elif view == "options":
			menus.open_options(func() -> void: pass)
		elif view == "bilan":
			_finish(true)
			await get_tree().create_timer(0.5).timeout
		elif view == "story_end":
			Story.results = {0: {"grade": "A", "score": 88.0, "alive": true}, 1: {"grade": "S", "score": 100.0, "alive": true}, 2: {"grade": "B", "score": 71.0, "alive": true}}
			hud.visible = false
			dialogue.hide_bark()
			menus.show_story_end()
		await get_tree().create_timer(1.0).timeout
	elif view == "briefing":
		state = "briefing"
		hud.visible = false
		menus.show_briefing()
	elif view.begins_with("zone:"):
		zone_view.enter(view.substr(5))
		if args.has("tool"):
			inv.add(args["tool"])
		await get_tree().create_timer(0.8).timeout
	elif view == "end":
		_finish(true)
		await get_tree().create_timer(0.5).timeout
	elif args.has("at"):
		var t: PackedFloat64Array = args["at"].split_floats(",")
		player.look_towards(Vector3(t[0], t[1], t[2]))
	if args.has("steps"):
		var bot := ERBot.new()
		bot.game = self
		add_child(bot)
		await bot.run_steps(int(args["steps"]))
	# Voie veineuse jusqu'à l'étape --iv=N, souris posée sur --aim=x,y,z (voir ERBot.shot_extra)
	if args.has("iv") or args.has("aim"):
		var bot2 := ERBot.new()
		bot2.game = self
		add_child(bot2)
		await bot2.shot_extra(args)
	for i in int(args.get("frames", "30")):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args["shot"])
	print("CAPTURE ", args["shot"])
	await _quit()


func _quit() -> void:
	Sfx.stop_all()
	await get_tree().create_timer(0.15, true, false, true).timeout
	get_tree().quit()
