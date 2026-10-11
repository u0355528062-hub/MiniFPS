extends SceneTree
## Test de performance : charge la partie, place la caméra sur plusieurs points de vue et
## mesure appels de dessin, objets rendus, primitives, temps CPU (process/physique) et coût
## de chaque système (Profileur). Résultats ajoutés à tools/tests/perf_historique.txt.
## Usage (rendu nécessaire) :
##   xvfb-run -a godot --path . --rendering-driver vulkan -s res://tools/tests/perf.gd -- [--preset ultra]
## Seuils : un dépassement est signalé par « DÉPASSEMENT ».

const SEUILS := {"appels": 2500, "objets": 1200, "primitives_k": 4000, "process_ms": 4.0, "physique_ms": 2.0}

var preset := "ultra"
var depassements := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--preset":
			preset = args[i + 1]
	_executer.call_deferred()


func _executer() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Reglages").choisir_preset(preset)
	var t0 := Time.get_ticks_msec()
	var jeu: Node = load("res://scenes/jeu.tscn").instantiate()
	root.add_child(jeu)
	await process_frame
	var charge_ms := Time.get_ticks_msec() - t0
	for i in 20:
		await process_frame
	var cam := Camera3D.new()
	jeu.add_child(cam)
	var lignes := ["", "=== %s · préréglage %s · chargement %d ms ===" % [Time.get_datetime_string_from_system(), preset, charge_ms]]
	lignes.append("%-16s %8s %8s %10s %10s %10s" % ["vue", "appels", "objets", "prim (k)", "proc (ms)", "phys (ms)"])
	for pose in jeu.poses_capture():
		cam.global_position = pose["position"]
		cam.look_at(pose["cible"], Vector3.UP)
		cam.make_current()
		for i in 6:
			await process_frame
		var s := {"appels": 0.0, "objets": 0.0, "primitives_k": 0.0, "process_ms": 0.0, "physique_ms": 0.0}
		var n := 8
		for i in n:
			await process_frame
			s["appels"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME) / n
			s["objets"] += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME) / n
			s["primitives_k"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0 / n
			s["process_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0 / n
			s["physique_ms"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0 / n
		var alerte := ""
		# En rendu logiciel (llvmpipe), le temps CPU inclut le rendu : il n'est pas significatif.
		var logiciel := RenderingServer.get_video_adapter_name().to_lower().contains("llvmpipe")
		for k in SEUILS:
			if logiciel and k == "process_ms":
				continue
			if s[k] > SEUILS[k]:
				alerte += " DÉPASSEMENT(%s)" % k
				depassements += 1
		lignes.append("%-16s %8d %8d %10.1f %10.2f %10.2f%s" % [pose["nom"], s["appels"], s["objets"], s["primitives_k"],
			s["process_ms"], s["physique_ms"], alerte])
	lignes.append("Systèmes (µs/image) : " + root.get_node("Profileur").resume().replace("\n", " · "))
	lignes.append("Nœuds : %d · objets physiques actifs : %d · mémoire statique : %.0f Mo · mémoire vidéo : %.0f Mo" % [
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	lignes.append("RÉSULTAT : " + ("OK" if depassements == 0 else "%d DÉPASSEMENT(S)" % depassements))
	var texte := "\n".join(lignes)
	print(texte)
	var f := FileAccess.open("res://tools/tests/perf_historique.txt", FileAccess.READ_WRITE if FileAccess.file_exists("res://tools/tests/perf_historique.txt") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_string(texte + "\n")
	quit()
