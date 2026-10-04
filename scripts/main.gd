extends Node3D
## Point d'entrée : construit le bloc, le patient, les instruments, l'interface et le joueur
## (casque VR si OpenXR est actif, sinon clavier + souris).
## Arguments de ligne de commande (après « -- ») :
##   --desktop            forcer le mode écran
##   --step=N             sauter à l'étape N (0 = désinfection … 9 = fin)
##   --autotest           un robot fait toute l'opération (vérification)
##   --shot=chemin.png    capture d'écran puis quitter   --view=overview|field|tray|panel|desk
##   --cam=x,y,z --at=x,y,z   caméra libre pour la capture

var room: OperatingRoom
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var panel: GuidePanel
var procedure: Procedure
var env: WorldEnvironment
var args := {}
var vr_rig: VRRig
var desk_rig: DesktopRig


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# Tests robots : cadence réaliste (90 images/s comme un casque)
	for t in ["autotest", "vrtest", "desktest", "chaos", "restarttest"]:
		if args.has(t):
			Engine.max_fps = 90
	var sfx := Sfx.new()
	sfx.name = "Sons"
	add_child(sfx)
	_build_environment()
	room = OperatingRoom.new()
	room.name = "Bloc"
	add_child(room)
	room.build()
	patient = Patient.new()
	patient.name = "Patient"
	add_child(patient)
	patient.build()
	tray = InstrumentTray.new()
	tray.name = "Instruments"
	add_child(tray)
	tray.build()

	monitor = VitalMonitor.new()
	monitor.name = "Moniteur"
	add_child(monitor)
	monitor.build()
	monitor.position = Vector3(-0.72, 1.8, -0.45)
	monitor.look_at(Vector3(0.12, 1.55, 0.65), Vector3.UP, true)

	panel = GuidePanel.new()
	panel.name = "PanneauGuide"
	add_child(panel)
	panel.build()
	panel.position = Vector3(0.1, 1.44, -0.52)
	panel.scale = Vector3.ONE * 0.85
	panel.look_at(Vector3(0.12, 1.62, 0.62), Vector3.UP, true)

	procedure = Procedure.new()
	procedure.name = "Procedure"
	procedure.patient = patient
	procedure.tray = tray
	procedure.monitor = monitor
	procedure.uis.append(panel.ui)
	add_child(procedure)

	var xr := XRServer.find_interface("OpenXR")
	var use_vr := xr != null and xr.is_initialized() and not args.has("desktop") and not args.has("autotest")
	if use_vr:
		get_viewport().use_xr = true
		# Air Link + RTX 3050 : on allège ce qui coûte cher en stéréo
		env.environment.ssao_enabled = false
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		vr_rig = VRRig.new()
		vr_rig.name = "JoueurVR"
		add_child(vr_rig)
		vr_rig.build()
		procedure.is_vr = true
		procedure.hands.append_array(vr_rig.hands)
		vr_rig.position = VRRig.SURGEON_SPOT
		vr_rig.continue_pressed.connect(procedure.on_continue)
	elif args.has("vrmock") or args.has("vrtest") or args.get("chaos", "") == "vr":
		# Capture de contrôle du rendu VR sans casque : manettes placées à la main
		vr_rig = VRRig.new()
		vr_rig.sim = true
		add_child(vr_rig)
		vr_rig.build()
		for h in vr_rig.hands:
			(h as VRHand).sim = true
		procedure.is_vr = true
		procedure.hands.append_array(vr_rig.hands)
		for c in [vr_rig.left, vr_rig.right]:
			c.show_when_tracked = false
			c.visible = true
		vr_rig.right.global_transform = Transform3D(Basis.looking_at(Vector3(-0.15, -0.55, -0.6).normalized(), Vector3.UP), Vector3(0.24, 1.3, 0.38))
		vr_rig.left.global_transform = Transform3D(Basis.looking_at(Vector3(0.2, -0.3, -0.7).normalized(), Vector3.UP), Vector3(-0.08, 1.25, 0.42))
	elif args.has("autotest"):
		var bot := AutoBot.new()
		bot.name = "Robot"
		add_child(bot)
		procedure.hands.append(bot)
	else:
		desk_rig = DesktopRig.new()
		desk_rig.name = "JoueurEcran"
		add_child(desk_rig)
		desk_rig.build()
		procedure.hands.append_array(desk_rig.hands)
		var hud := DesktopHUD.new()
		hud.name = "HUD"
		add_child(hud)
		hud.build(desk_rig.hand, tray.ordered)
		procedure.uis.append(hud.ui)
		panel.visible = false  # en mode écran, la consigne est en surimpression
		procedure.hud = hud
		desk_rig.continue_pressed.connect(procedure.on_continue)
	procedure.setup()

	if args.has("step"):
		procedure.skip_to(int(args["step"]))
	if args.has("hide"):
		# Captures « écorché » : masque des éléments par nom (Peau, Champs, Cavite...)
		await get_tree().process_frame
		for n in args["hide"].split(","):
			for node in find_children(n, "", true, false):
				(node as Node3D).visible = false
	if args.has("nolabels"):
		procedure.show_markers = false
	if args.has("vrmock") and args.has("hold"):
		var h: SurgeonHand = vr_rig.hands[1]
		h.take(tray.instruments[args["hold"]])
	if args.has("dbg"):
		await get_tree().create_timer(1.0).timeout
		for id in ["langenbeck", "roux"]:
			var inst: Instrument = tray.instruments[id]
			print(id, " len=", inst.length, " tipL=", inst.tip_local, " tip=", inst.tip_global(), " grip=", inst.grip_global(), " pos=", inst.global_position, " slot=", patient.center)
		get_tree().quit()
	if args.has("vrtest"):
		var vb := VRBot.new()
		add_child(vb)
		vb.setup(vr_rig, procedure, patient, tray)
		await vb.run()
		if not args.has("shot"):
			get_tree().quit()
	if args.has("chaos"):
		var ct := ChaosTest.new()
		ct.proc = procedure
		ct.patient = patient
		ct.tray = tray
		add_child(ct)
		if args["chaos"] == "vr":
			ct.vr_bot = VRBot.new()
			add_child(ct.vr_bot)
			ct.vr_bot.setup(vr_rig, procedure, patient, tray)
		else:
			ct.desk_bot = DesktopBot.new()
			add_child(ct.desk_bot)
			ct.desk_bot.setup(desk_rig, procedure, patient, tray)
		await ct.run(args["chaos"], int(args.get("seed", "1")))
		get_tree().quit()
	if args.has("desktest"):
		# Partie complète à la souris / au clavier (événements simulés)
		var db := DesktopBot.new()
		add_child(db)
		db.setup(desk_rig, procedure, patient, tray)
		await get_tree().process_frame
		db.key(KEY_SPACE)
		await get_tree().create_timer(0.2).timeout
		while procedure.step < Procedure.STEPS.size():
			var s := procedure.step
			await db.do_step()
			if procedure.step == s:
				break
			print("DESKTEST étape réussie : ", Procedure.STEPS[s]["id"])
		print("DESKTEST ", "OK" if db.ok and procedure.step >= Procedure.STEPS.size() else "ÉCHEC")
		get_tree().quit()
	if args.has("restarttest"):
		# Recommencer en fin de partie recharge la scène sans erreur
		if Procedure.restarts == 0:
			procedure.skip_to(Procedure.STEPS.size())
			await get_tree().process_frame
			procedure.on_continue()
		else:
			await get_tree().create_timer(0.5).timeout
			print("RESTART OK (étape ", procedure.step, ")")
			get_tree().quit()
	if args.has("autotest"):
		var bot: AutoBot = procedure.hands[0]
		await bot.run(procedure, patient, tray)
		if not args.has("shot"):
			get_tree().quit()
	if args.has("shot"):
		_take_shot()


func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.58, 0.64, 0.66)
	e.ambient_light_energy = 0.28
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.66
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 0.5
	e.ssao_intensity = 1.6
	e.ssao_detail = 0.6
	e.glow_enabled = false
	e.glow_intensity = 0.2
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 2.5
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.0
	env.environment = e
	add_child(env)


func _take_shot() -> void:
	var cam: Camera3D
	if desk_rig and args.get("view", "") == "desk":
		cam = desk_rig.camera
	else:
		cam = Camera3D.new()
		cam.fov = 70
		add_child(cam)
		if args.has("cam"):
			var c: PackedFloat64Array = args["cam"].split_floats(",")
			var t: PackedFloat64Array = args.get("at", "0,1,0").split_floats(",")
			cam.look_at_from_position(Vector3(c[0], c[1], c[2]), Vector3(t[0], t[1], t[2]))
		else:
			match args.get("view", "overview"):
				"field":
					cam.look_at_from_position(Vector3(0.12, 1.58, 0.55), Vector3(0.12, 1.14, 0.1))
				"tray":
					cam.look_at_from_position(Vector3(0.35, 1.6, 0.85), Vector3(0.62, 1.05, 0.5))
				"panel":
					cam.look_at_from_position(Vector3(0.12, 1.62, 0.62), Vector3(0.12, 1.45, -0.4))
				_:
					cam.look_at_from_position(Vector3(2.6, 2.1, 2.6), Vector3(0, 0.9, 0))
	cam.current = true
	for i in int(args.get("frames", "40")):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args["shot"])
	print("CAPTURE ", args["shot"])
	get_tree().quit()
