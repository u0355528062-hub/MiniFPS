extends Node3D
## Point d'entrée : construit le bloc, le patient, les instruments, l'interface et le joueur
## (casque VR si OpenXR est actif, sinon clavier + souris).
## Arguments de ligne de commande (après « -- ») :
##   --desktop            forcer le mode écran
##   --shot=chemin.png    capture d'écran puis quitter   --view=overview|field|tray|panel
##   --step=N             sauter à l'étape N (tests)

var room: OperatingRoom
var env: WorldEnvironment
var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_build_environment()
	room = OperatingRoom.new()
	room.name = "Bloc"
	add_child(room)
	room.build()
	var patient := Patient.new()
	patient.name = "Patient"
	add_child(patient)
	patient.build()
	var tray := InstrumentTray.new()
	tray.name = "Instruments"
	add_child(tray)
	tray.build()
	if args.has("open"):
		patient.fill_iodine()
		patient.incision_progress = 1.0
		patient.opening = float(args["open"])
		patient.set_appendix_tip(patient.appendix_base + Vector3(-0.02, 0.07, 0.01))
	if args.has("shot"):
		_take_shot()


func _build_environment() -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.06, 0.07)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.58, 0.64, 0.66)
	e.ambient_light_energy = 0.35
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.ssao_enabled = true
	e.ssao_radius = 0.5
	e.ssao_intensity = 1.6
	e.ssao_detail = 0.6
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.5
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.04
	env.environment = e
	add_child(env)


func _take_shot() -> void:
	var cam := Camera3D.new()
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
				cam.look_at_from_position(Vector3(0.1, 1.65, 0.75), Vector3(0.1, 1.45, -0.6))
			_:
				cam.look_at_from_position(Vector3(2.6, 2.1, 2.6), Vector3(0, 0.9, 0))
	cam.current = true
	for i in int(args.get("frames", "40")):
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(args["shot"])
	print("CAPTURE ", args["shot"])
	get_tree().quit()
