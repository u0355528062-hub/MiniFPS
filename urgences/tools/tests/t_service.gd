extends SceneTree
## Vérifie la construction du service et la navigation (chemin entrée → box 3).
func _initialize():
	var s = load("res://scenes/service.tscn").instantiate()
	root.add_child(s)
	for i in 5:
		await physics_frame
	print("points: ", s.points.keys())
	print("polygones navigation : ", s.nav.navigation_mesh.get_polygon_count())
	var c: PackedVector3Array = s.chemin(Vector3(7, 0, 28.5), s.points["box_3"]["entree"])
	var lg := 0.0
	for i in range(1, c.size()):
		lg += c[i].distance_to(c[i - 1])
	print("chemin entrée → box 3 : %d points, %.1f m" % [c.size(), lg])
	quit()
