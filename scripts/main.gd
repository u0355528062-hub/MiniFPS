extends Node3D
## Point d'entrée : construit la salle de déchocage, le patient (anatomie réelle), les instruments,
## le joueur à la première personne, l'interface et les menus.
## Déroulé : menu principal (caméra qui tourne autour de la salle) → briefing → intervention →
## bilan. Échap : pause.
##
## Arguments de ligne de commande (après « -- ») :
##   --play                 sauter le menu principal (directement au briefing)
##   --op=id                opération (drain, exsufflation, pericardiocentese, voie_centrale…)
##   --step=N               sauter à l'étape N
##   --autotest             un robot fait toute l'opération (vérification)
##   --desktest             un robot joue avec la souris et le clavier simulés (vrai joueur)
##   --chaos[=seed]         actions au hasard puis le robot termine (invariants vérifiés)
##   --restarttest          fin de partie → rejouer (rechargement) sans erreur
##   --shot=chemin.png      capture d'écran puis quitter   --view=menu|player|field|overview|xray
##   --cam=x,y,z --at=x,y,z   caméra libre pour la capture  --frames=N  --hold=id  --mode=0|1|2
##   --desktest --shot=f.png --shotstep=N --shotdelay=s   capture pendant le test (étape N)

static var skip_menu := false
## Opération choisie dans le menu (gardée au rechargement de la scène)
static var selected_op := "drain"

var room: OperatingRoom
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var procedure: Procedure
var player: Player
var hud: GameHUD
var menus: Menus
var env: WorldEnvironment
var op: Operation
var args := {}
var state := "menu"  ## menu, briefing, play, pause, end
var _menu_cam: Camera3D
var _menu_t := 0.0
var _testing := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	for t in ["autotest", "desktest", "chaos", "restarttest"]:
		if args.has(t):
			_testing = true
			Engine.max_fps = 90
	if args.has("op"):
		selected_op = args["op"]
	op = Operation.create(selected_op)
	Patient.pose_id = op.pose
	var sfx := Sfx.new()
	sfx.name = "Sons"
	sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sfx)
	_build_environment()
	room = OperatingRoom.new()
	room.name = "Salle"
	room.pose_id = op.pose
	add_child(room)
	room.build()
	patient = Patient.new()
	patient.name = "Patient"
	op.configure_patient(patient)
	add_child(patient)
	patient.build()
	tray = InstrumentTray.new()
	tray.name = "Instruments"
	add_child(tray)
	tray.build(op)
	monitor = VitalMonitor.new()
	monitor.name = "Moniteur"
	add_child(monitor)
	monitor.build()
	monitor.heart_rate = op.vitals["hr"]
	monitor.target_rate = op.vitals["hr"]
	monitor.spo2 = op.vitals["spo2"]
	monitor.sys = op.vitals["sys"]
	monitor.dia = op.vitals["dia"]
	monitor.position = Vector3(0.78, 1.62, -0.52)
	monitor.look_at(Vector3(0.0, 1.62, 0.55), Vector3.UP, true)
	procedure = Procedure.new()
	procedure.name = "Procedure"
	procedure.op = op
	procedure.patient = patient
	procedure.tray = tray
	procedure.monitor = monitor
	add_child(procedure)
	op.proc = procedure
	op.patient = patient
	op.tray = tray
	op.monitor = monitor
	op.root = self
	op.build_extras()
	op.define_steps()
	room.scan_label.text = op.scan_text
	if op.imaging_tex != "":
		(room.scan_film.material_override as StandardMaterial3D).albedo_texture = load(op.imaging_tex)
	else:
		room.scan_film.visible = false
	patient.breath_rate = op.breath_rate
	monitor.resp_rate = op.breath_rate

	if args.has("autotest"):
		var bot := AutoBot.new()
		bot.name = "Robot"
		bot.patient = patient
		add_child(bot)
		procedure.hands.append(bot)
	else:
		player = Player.new()
		player.name = "Joueur"
		add_child(player)
		player.build(op.player_spawn, op.player_look)
		player.hand.patient = patient
		player.hand.tray = tray
		procedure.hands.append(player.hand)
		hud = GameHUD.new()
		hud.name = "HUD"
		hud.monitor = monitor
		hud.hand = player.hand
		hud.player = player
		hud.instruments = tray.ordered
		add_child(hud)
		hud.build()
		hud.marker = procedure.marker
		procedure.uis.append(hud)
		player.pause_requested.connect(_on_pause_key)
		player.view_mode_requested.connect(_cycle_view)
		player.hand.hint_changed.connect(func(t: String) -> void:
			if t != "" and t.begins_with("Approche"):
				hud.toast(t, false))
		procedure.step_changed.connect(func(_i: int) -> void:
			hud.required_id = procedure.required_id()
			hud.step_kind = procedure.current().get("kind", ""))
	# Vignettage léger sur l'image 3D, sous le HUD et les menus
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
	menus = Menus.new()
	menus.name = "Menus"
	menus.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menus)
	menus.build(op)
	menus.play_pressed.connect(_go_briefing)
	menus.op_chosen.connect(_choose_op)
	menus.start_pressed.connect(_start)
	menus.resume_pressed.connect(_resume)
	menus.restart_pressed.connect(_restart)
	menus.main_menu_pressed.connect(_to_main_menu)
	menus.quit_pressed.connect(func() -> void: get_tree().quit())
	procedure.uis.append(menus_proxy())
	procedure.finished.connect(_on_finished)
	if args.has("quality"):
		Settings.quality = int(args["quality"])
	Settings.apply_graphics(env.environment, get_viewport())
	Settings.changed.connect(func() -> void:
		if player:
			player.camera.fov = Settings.fov)
	procedure.setup()
	if args.has("perf"):
		var pp := PerfProbe.new()
		pp.proc = procedure
		add_child(pp)

	if _testing or args.has("shot") or args.has("step"):
		await _run_cli()
		return
	if skip_menu or args.has("play"):
		skip_menu = false
		_go_briefing(true)
	else:
		_show_main_menu()


## Les menus reçoivent aussi l'écran de fin de la procédure.
func menus_proxy() -> Object:
	var p := EndProxy.new()
	p.main = self
	return p


class EndProxy:
	extends RefCounted
	var main: Node

	func show_step(_a: int, _b: int, _c: String, _d: String, _e: String, _f: String) -> void:
		pass

	func set_progress(_v: float, _t: String) -> void:
		pass

	func toast(_t: String, _ok := true) -> void:
		pass

	func set_status(_e: float, _n: int) -> void:
		pass

	func set_steps(_t: Array) -> void:
		pass

	func set_header(_h: String) -> void:
		pass

	func show_end(elapsed: float, errors: int, grade: String, summary: String, log: Array, quality: Dictionary) -> void:
		main.call("_pending_end", [elapsed, errors, grade, summary, log, quality])


var _end_data: Array = []


func _pending_end(data: Array) -> void:
	_end_data = data


# ---------------------------------------------------------------- États

func _show_main_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if hud:
		hud.visible = false
	if player:
		player.enabled = false
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 55
	add_child(_menu_cam)
	_menu_cam.current = true
	menus.show_main()


func _process(delta: float) -> void:
	if state == "menu" and _menu_cam:
		_menu_t += delta * 0.06
		var a := 0.7 + sin(_menu_t) * 0.55
		var c := Vector3(-0.25, 1.15, 0.0)
		_menu_cam.global_position = c + Vector3(cos(a) * 2.6, 0.75 + 0.15 * sin(_menu_t * 1.7), sin(a) * 2.6)
		_menu_cam.look_at(c + Vector3(0.1, 0.05, 0.0))


## Une opération est choisie dans le menu : la même → briefing ; une autre → la scène est
## reconstruite pour elle (patient, salle, instruments), directement au briefing.
func _choose_op(op_id: String) -> void:
	if op_id == op.id:
		_go_briefing()
		return
	selected_op = op_id
	skip_menu = true
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _go_briefing(instant := false) -> void:
	if _menu_cam and not instant:
		# Vol de la caméra jusqu'aux yeux du joueur
		menus.hide_all()
		var from := _menu_cam.global_transform
		var to := player.camera.global_transform
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		state = "fly"
		tw.tween_method(func(k: float) -> void:
			_menu_cam.global_transform = Transform3D(Basis(Quaternion(from.basis.orthonormalized()).slerp(Quaternion(to.basis.orthonormalized()), k)), from.origin.lerp(to.origin, k)), 0.0, 1.0, 1.6)
		await tw.finished
	if _menu_cam:
		_menu_cam.queue_free()
		_menu_cam = null
	player.camera.current = true
	state = "briefing"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	menus.show_briefing()


func _start() -> void:
	if state != "briefing":
		return
	state = "play"
	menus.hide_all()
	hud.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.enabled = true
	procedure.on_continue()


func _on_pause_key() -> void:
	match state:
		"play":
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
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _restart() -> void:
	get_tree().paused = false
	skip_menu = true
	Procedure.restarts += 1
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	get_tree().paused = false
	skip_menu = false
	await menus.fade(true, 0.35)
	get_tree().reload_current_scene()


func _on_finished(_s: float, _e: int) -> void:
	await get_tree().create_timer(1.6).timeout
	state = "end"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.enabled = false
	if hud:
		hud.visible = false
	if not _end_data.is_empty():
		menus.callv("show_end", _end_data)


## Vue anatomique (V) : normale → muscles (peau fantôme) → squelette et organes → normale.
func _cycle_view() -> void:
	if state != "play":
		return
	var m := (patient.view_mode + 1) % 3
	patient.set_view_mode(m)
	Sfx.play("vue", Vector3.INF, -10.0, 1.0 + m * 0.12)
	hud.set_view_tag(["", "VUE ANATOMIQUE  ·  MUSCLES   (V)", "VUE ANATOMIQUE  ·  CÔTES, POUMONS, CŒUR   (V)"][m])


func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.66, 0.68)
	e.ambient_light_energy = 0.42
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.tonemap_white = 4.0
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.2
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.volumetric_fog_density = 0.006
	e.volumetric_fog_albedo = Color(0.9, 0.95, 1.0)
	e.volumetric_fog_length = 8.0
	e.volumetric_fog_ambient_inject = 0.1
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.05
	e.adjustment_saturation = 1.04
	env.environment = e
	add_child(env)


# ---------------------------------------------------------------- Tests et captures

func _run_cli() -> void:
	if hud and player:
		state = "play"
		player.enabled = true
	if args.has("step"):
		procedure.skip_to(int(args["step"]))
	if args.has("autotest"):
		var ad := AutoDriver.new()
		add_child(ad)
		ad.setup(procedure.hands[0], procedure, patient, tray)
		if args.has("shot") and args.has("shotstep"):
			_shot_during_test()
		await ad.run_all()
		get_tree().quit()
		return
	if args.has("desktest"):
		var pb := PlayerBot.new()
		add_child(pb)
		pb.setup(player, procedure, patient, tray)
		if args.has("shot") and args.has("shotstep"):
			_shot_during_test()
		await get_tree().process_frame
		await pb.run_all()
		get_tree().quit()
		return
	if args.has("chaos"):
		var ct := ChaosTest.new()
		ct.proc = procedure
		ct.patient = patient
		ct.tray = tray
		add_child(ct)
		var pb2 := PlayerBot.new()
		add_child(pb2)
		pb2.setup(player, procedure, patient, tray)
		ct.bot = pb2
		await ct.run(int(args.get("chaos", "1")) if args["chaos"].is_valid_int() else 1)
		get_tree().quit()
		return
	if args.has("restarttest"):
		if Procedure.restarts == 0:
			procedure.skip_to(procedure.steps.size())
			await get_tree().create_timer(2.0).timeout
			if state != "end":
				print("RESTART ÉCHEC : pas d'écran de fin")
				get_tree().quit()
				return
			_restart()
			return
		await get_tree().create_timer(0.5).timeout
		print("RESTART OK (étape ", procedure.step, ", état ", state, ")")
		get_tree().quit()
		return
	if args.has("shot"):
		await _take_shot()


## Capture pendant un test (robot) : quand l'étape « shotstep » a commencé depuis « shotdelay »
## secondes ; caméra libre si --cam/--at (sinon la vue du joueur).
func _shot_during_test() -> void:
	var target := int(args["shotstep"])
	var delay := float(args.get("shotdelay", "1.0"))
	procedure.step_changed.connect(func(i: int) -> void:
		if i != target:
			return
		await get_tree().create_timer(delay).timeout
		if args.has("cam"):
			var cam := Camera3D.new()
			cam.fov = 50
			add_child(cam)
			var c: PackedFloat64Array = args["cam"].split_floats(",")
			var t: PackedFloat64Array = args.get("at", "0,1,0").split_floats(",")
			cam.look_at_from_position(Vector3(c[0], c[1], c[2]), Vector3(t[0], t[1], t[2]))
			cam.current = true
			if args.has("mode"):
				patient.set_view_mode(int(args["mode"]))
			for k in 6:
				await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(args["shot"])
		print("CAPTURE ", args["shot"]))


func _take_shot() -> void:
	var view: String = args.get("view", "player")
	if args.has("mode"):
		patient.set_view_mode(int(args["mode"]))
	if args.has("hold") and player:
		player.hand.take_requested.emit(player.hand, tray.instruments[args["hold"]])
	var cam: Camera3D
	match view:
		"menu":
			state = "menu"
			_show_main_menu()
			_menu_t = 0.9
			cam = _menu_cam
		"briefing":
			state = "briefing"
			hud.visible = false
			menus.show_briefing()
			cam = player.camera
		"end":
			procedure.skip_to(procedure.steps.size())
			await get_tree().create_timer(2.2).timeout
			cam = player.camera
			player.look_towards(Vector3(0.0, 1.3, 0.0))
		"player":
			cam = player.camera
			if args.has("at"):
				var t: PackedFloat64Array = args["at"].split_floats(",")
				player.look_towards(Vector3(t[0], t[1], t[2]))
		_:
			cam = Camera3D.new()
			cam.fov = 60
			add_child(cam)
			var presets := {
				"field": [Vector3(0.05, 1.62, 0.36), Vector3(0.0, 1.3, 0.0)],
				"overview": [Vector3(1.9, 2.1, 2.3), Vector3(-0.3, 1.0, 0.0)],
				"xray": [Vector3(0.25, 1.75, 0.75), Vector3(-0.02, 1.2, 0.0)],
			}
			var pr: Array = presets.get(view, presets["overview"])
			var from: Vector3 = pr[0]
			var at: Vector3 = pr[1]
			if args.has("cam"):
				var c: PackedFloat64Array = args["cam"].split_floats(",")
				from = Vector3(c[0], c[1], c[2])
			if args.has("at"):
				var t2: PackedFloat64Array = args["at"].split_floats(",")
				at = Vector3(t2[0], t2[1], t2[2])
			cam.look_at_from_position(from, at)
	cam.current = true
	if hud and not view in ["player"]:
		hud.visible = false
	if menus and not view in ["menu", "briefing", "end", "player"]:
		menus.visible = false  # vue libre : la scène seule (pas le compte rendu de fin)
	for i in int(args.get("frames", "40")):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args["shot"])
	print("CAPTURE ", args["shot"])
	get_tree().quit()
