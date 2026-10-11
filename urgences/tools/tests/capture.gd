extends SceneTree
## Captures d'écran pour juger le rendu.
## Usage : xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/tests/capture.gd -- \
##         --scene res://scenes/box_examen.tscn --sortie /chemin/dossier [--images 40] [--preset ultra]
## La scène peut définir poses_capture() -> Array[Dictionary] {nom, position, cible, fov?}.

var scene_path := "res://scenes/box_examen.tscn"
var sortie := "user://captures"
var images_attente := 40
var preset := "ultra"
var largeur := 1600
var hauteur := 900


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--scene": scene_path = args[i + 1]; i += 1
			"--sortie": sortie = args[i + 1]; i += 1
			"--images": images_attente = int(args[i + 1]); i += 1
			"--preset": preset = args[i + 1]; i += 1
			"--taille":
				var t: PackedStringArray = args[i + 1].split("x")
				largeur = int(t[0]); hauteur = int(t[1]); i += 1
		i += 1
	_executer.call_deferred()


func _executer() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	root.size = Vector2i(largeur, hauteur)
	var reglages := root.get_node_or_null("Reglages")
	if reglages:
		reglages.choisir_preset(preset)
	var scene: Node = load(scene_path).instantiate()
	if scene.has_method("preparer_capture"):
		scene.preparer_capture()
	root.add_child(scene)
	await process_frame
	var poses: Array = []
	if scene.has_method("poses_capture"):
		poses = scene.poses_capture()
	if poses.is_empty():
		poses = [{"nom": "defaut"}]
	var cam := Camera3D.new()
	scene.add_child(cam)
	for pose in poses:
		if pose.has("position"):
			cam.global_position = pose["position"]
			cam.look_at(pose["cible"], Vector3.UP)
			cam.fov = pose.get("fov", 70.0)
			cam.make_current()
		if pose.has("avant") and scene.has_method(pose["avant"]):
			scene.call(pose["avant"])
		for f in images_attente:
			await process_frame
		var img := root.get_texture().get_image()
		var chemin := sortie.path_join("%s.png" % pose["nom"])
		img.save_png(chemin)
		print("CAPTURE ", chemin)
	quit()
