extends SceneTree
## Teste et capture les mini-jeux : RCP (compressions, charge, choc), suture, jauge, intubation.
var resultats := {}

func _initialize() -> void:
	_executer.call_deferred()

func _capture(nom: String) -> void:
	for i in 4:
		await process_frame
	if DisplayServer.get_name() != "headless":
		root.get_texture().get_image().save_png("/tmp/claude-0/scratch/mini_%s.png" % nom)

var cadre: Control

func _executer() -> void:
	root.size = Vector2i(1600, 900)
	cadre = Control.new()
	cadre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cadre)
	await process_frame
	var c := Constantes.new({"fc": 0.0, "rythme": "fv"})
	var rcp = load("res://scripts/minijeux/mini_rcp.gd").new()
	rcp.constantes = c
	rcp.termine.connect(func(ok, q): resultats["rcp"] = [ok, q])
	cadre.add_child(rcp)
	for i in 12:
		rcp._compression()
		OS.delay_msec(540)
		await process_frame
	await _capture("rcp")
	print("fréquence mesurée : %d /min, qualité %d %%" % [int(rcp.frequence()), int(rcp.qualite() * 100)])
	rcp._phase = "charge"
	rcp._charge = 0.99
	await process_frame
	await process_frame
	print("phase après charge : ", rcp._phase)
	rcp._racs()
	await create_timer(3.5).timeout
	print("RCP : ", resultats.get("rcp"))
	var su = load("res://scripts/minijeux/mini_suture.gd").new()
	su.termine.connect(func(ok, q): resultats["suture"] = [ok, q])
	cadre.add_child(su)
	await process_frame
	await process_frame
	for k in su.POINTS:
		for e in 2:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.position = su._cibles[k][e] + Vector2(5, 3)
			su._gui_input(ev)
		if k == 2:
			await _capture("suture")
	await create_timer(2.5).timeout
	print("Suture : ", resultats.get("suture"))
	var ja = load("res://scripts/minijeux/mini_jauge.gd").new()
	ja.termine.connect(func(ok, q): resultats["jauge"] = [ok, q])
	cadre.add_child(ja)
	await _capture("jauge")
	ja._x = ja._zone
	ja._valider()
	await create_timer(1.6).timeout
	print("Jauge : ", resultats.get("jauge"))
	var it = load("res://scripts/minijeux/mini_intubation.gd").new()
	it.termine.connect(func(ok, q): resultats["intubation"] = [ok, q])
	cadre.add_child(it)
	it._preox = 1.0
	it._etape = 2
	await _capture("intubation")
	var ev2 := InputEventMouseButton.new()
	ev2.pressed = true
	ev2.button_index = MOUSE_BUTTON_LEFT
	ev2.position = it._glotte
	it._gui_input(ev2)
	await create_timer(2.5).timeout
	print("Intubation : ", resultats.get("intubation"))
	var ok := resultats.size() == 4
	for k in resultats:
		ok = ok and resultats[k][0]
	print("RÉSULTAT : ", "OK" if ok else "ÉCHEC")
	quit()
