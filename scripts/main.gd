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
	for t in ["autotest", "vrtest", "desktest", "chaos", "restarttest", "handtest"]:
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
	# Opération choisie (menu, ou --op=drain / laparotomie / appendicectomie pour les tests)
	if args.has("op"):
		Procedure.op_id = args["op"]
	var op := Operation.create(Procedure.op_id)
	var spot := op.surgeon_spot
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
	monitor.position = Vector3(-0.72, 1.8, -0.45)
	monitor.look_at(spot + Vector3(0, 1.55, 0.05), Vector3.UP, true)

	panel = GuidePanel.new()
	panel.name = "PanneauGuide"
	add_child(panel)
	panel.build()
	panel.position = Vector3(spot.x - 0.02, 1.44, spot.z - 1.12)
	panel.scale = Vector3.ONE * 0.85
	panel.look_at(spot + Vector3(0, 1.62, 0.02), Vector3.UP, true)

	procedure = Procedure.new()
	procedure.name = "Procedure"
	procedure.op = op
	procedure.patient = patient
	procedure.tray = tray
	procedure.monitor = monitor
	procedure.uis.append(panel.ui)
	add_child(procedure)
	op.proc = procedure
	op.patient = patient
	op.tray = tray
	op.monitor = monitor
	op.root = self
	op.build_extras()
	op.define_steps()

	var xr := XRServer.find_interface("OpenXR")
	var use_vr := xr != null and xr.is_initialized() and not args.has("desktop") and not args.has("autotest")
	if use_vr:
		get_viewport().use_xr = true
		_vr_performance(xr)
		vr_rig = VRRig.new()
		vr_rig.name = "JoueurVR"
		vr_rig.surgeon_spot = spot
		add_child(vr_rig)
		vr_rig.build()
		procedure.is_vr = true
		procedure.hands.append_array(vr_rig.hands)
		vr_rig.position = spot
		vr_rig.continue_pressed.connect(procedure.on_continue)
		vr_rig.menu_moved.connect(procedure.menu_move)
		vr_rig.hand_pinch.connect(procedure.on_hand_pinch)
		_touch_menu(spot)
	elif args.has("vrmock") or args.has("vrtest") or args.has("handtest") or args.get("chaos", "") == "vr":
		# Capture de contrôle du rendu VR sans casque : manettes placées à la main
		vr_rig = VRRig.new()
		vr_rig.sim = true
		vr_rig.surgeon_spot = spot
		add_child(vr_rig)
		vr_rig.position = spot
		vr_rig.hand_pinch.connect(procedure.on_hand_pinch)
		vr_rig.build()
		for h in vr_rig.hands:
			(h as VRHand).sim = true
		procedure.is_vr = true
		procedure.hands.append_array(vr_rig.hands)
		for c in [vr_rig.left, vr_rig.right]:
			c.show_when_tracked = false
			c.visible = true
		var off := spot - Vector3(0.12, 0, 0.6)
		vr_rig.right.global_transform = Transform3D(Basis.looking_at(Vector3(-0.15, -0.55, -0.6).normalized(), Vector3.UP), Vector3(0.24, 1.3, 0.38) + off)
		vr_rig.left.global_transform = Transform3D(Basis.looking_at(Vector3(0.2, -0.3, -0.7).normalized(), Vector3.UP), Vector3(-0.08, 1.25, 0.42) + off)
		_touch_menu(spot)
	elif args.has("autotest"):
		var bot := AutoBot.new()
		bot.name = "Robot"
		bot.patient = patient
		add_child(bot)
		procedure.hands.append(bot)
	else:
		desk_rig = DesktopRig.new()
		desk_rig.name = "JoueurEcran"
		add_child(desk_rig)
		desk_rig.build(spot + Vector3(0, 1.6, 0))
		desk_rig.hand.patient = patient
		procedure.hands.append_array(desk_rig.hands)
		var hud := DesktopHUD.new()
		hud.name = "HUD"
		add_child(hud)
		hud.build(desk_rig.hand, tray.ordered)
		procedure.uis.append(hud.ui)
		panel.visible = false  # en mode écran, la consigne est en surimpression
		procedure.hud = hud
		desk_rig.continue_pressed.connect(procedure.on_continue)
		desk_rig.menu_moved.connect(procedure.menu_move)
		desk_rig.menu_number.connect(procedure.menu_select)
	procedure.setup()
	for ui in procedure.uis:
		ui.set_header(op.header)
	if op.scan_text != "":
		room.scan_label.text = op.scan_text
	patient.breath_rate = op.breath_rate
	monitor.resp_rate = op.breath_rate
	if args.has("perf"):
		var pp := PerfProbe.new()
		pp.proc = procedure
		add_child(pp)

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
	if args.has("handmock") and not args.has("pose"):
		# Capture : mains nues simulées (faux suivi des mains) au lieu des manettes
		var hm := VRBot.new()
		add_child(hm)
		hm.setup(vr_rig, procedure, patient, tray)
		hm.enable_hands()
		if args.has("pinch"):
			hm.R.sim_trigger = 1.0
		await get_tree().process_frame
	if args.has("vrmock") and args.has("hold"):
		var h: SurgeonHand = vr_rig.hands[1]
		h.take(tray.instruments[args["hold"]])
	if args.has("pose"):
		# Capture : une main (nue avec --handmock) tient un instrument, pointe en --tipat, serrage --sq
		var pb := VRBot.new()
		add_child(pb)
		pb.setup(vr_rig, procedure, patient, tray)
		if args.has("handmock"):
			pb.enable_hands()
		await get_tree().process_frame
		await pb.grab_with(pb.R, tray.instruments[args["pose"]])
		var tp: PackedFloat64Array = args.get("tipat", "0.12,1.16,0.1").split_floats(",")
		pb.squeeze(float(args.get("sq", "1")))
		await pb.tip_to(Vector3(tp[0], tp[1], tp[2]), 40)
		_take_shot()
		return
	if args.has("vrtest"):
		var vb := VRBot.new()
		add_child(vb)
		vb.setup(vr_rig, procedure, patient, tray)
		await vb.run()
		get_tree().quit()
		return
	if args.has("handtest"):
		# Partie complète aux mains nues (faux suivi des mains), menu compris
		if Procedure.restarts > 0:
			print("HANDTEST retour au menu OK (étape ", procedure.step, ")")
			get_tree().quit()
			return
		var hb := VRBot.new()
		add_child(hb)
		hb.setup(vr_rig, procedure, patient, tray)
		hb.enable_hands()
		await hb.start_with_pinches()
		await hb.run_all()
		# Fin -> retour au menu au pincement de la main gauche (après le délai de sécurité)
		await get_tree().create_timer(1.8).timeout
		print("HANDTEST retour au menu demandé")
		await hb.pinch(hb.L)
		get_tree().quit()
		return
	if args.has("chaos"):
		var ct := ChaosTest.new()
		ct.proc = procedure
		ct.patient = patient
		ct.tray = tray
		add_child(ct)
		if args["chaos"] == "vr":
			var vb := VRBot.new()
			add_child(vb)
			vb.setup(vr_rig, procedure, patient, tray)
			if args.has("hands"):
				vb.enable_hands()
			ct.bot = vb
		else:
			var db := DesktopBot.new()
			add_child(db)
			db.setup(desk_rig, procedure, patient, tray)
			ct.bot = db
		await ct.run(args["chaos"], int(args.get("seed", "1")))
		get_tree().quit()
		return
	if args.has("desktest"):
		var db := DesktopBot.new()
		add_child(db)
		db.setup(desk_rig, procedure, patient, tray)
		await get_tree().process_frame
		await db.run_all()
		get_tree().quit()
		return
	if args.has("autotest"):
		var ad := AutoDriver.new()
		add_child(ad)
		ad.setup(procedure.hands[0], procedure, patient, tray)
		await ad.run_all()
		if not args.has("shot"):
			get_tree().quit()
			return
	if args.has("restarttest"):
		# Fin de partie -> menu (rechargement de scène) sans erreur
		if Procedure.restarts == 0:
			procedure.skip_to(procedure.steps.size())
			await get_tree().process_frame
			procedure.on_continue()
			return
		await get_tree().create_timer(0.5).timeout
		print("RESTART OK (étape ", procedure.step, ")")
		get_tree().quit()
		return
	if args.has("shot"):
		_take_shot()


## Menu à toucher du doigt (VR) : choix de l'opération, commencer, recommencer, recentrer.
func _touch_menu(spot: Vector3) -> void:
	for h in vr_rig.hands:
		(h as VRHand).patient = patient
		(h as VRHand).camera = vr_rig.camera
	var tm := TouchMenu.new()
	tm.name = "MenuTactile"
	add_child(tm)
	tm.build(spot)
	tm.hands.append_array(vr_rig.hands)
	tm.pressed.connect(func(action: String) -> void:
		if action == "recenter":
			vr_rig.recenter()
		else:
			procedure.on_touch_button(action))
	procedure.touch_menu = tm


## Réglages pour le casque (Air Link, carte graphique moyenne) : tenir la fréquence d'images
## avant tout. Une image en retard fait trembler toute la vue dans le casque.
func _vr_performance(xr: XRInterface) -> void:
	env.environment.ssao_enabled = false
	RenderingServer.sub_surface_scattering_set_quality(RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_DISABLED)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp := get_viewport()
	vp.positional_shadow_atlas_size = 2048
	# Rendu fovéal : moins de détails sur les bords de l'image (cartes graphiques qui le gèrent)
	vp.vrs_mode = Viewport.VRS_XR
	if xr is OpenXRInterface:
		(xr as OpenXRInterface).vrs_strength = 1.0
		(xr as OpenXRInterface).vrs_min_radius = 25.0
	# Résolution ajustée en continu pour garder la cadence du casque
	var gov := FrameGovernor.new()
	gov.name = "Regulateur"
	gov.xr = xr
	add_child(gov)


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
