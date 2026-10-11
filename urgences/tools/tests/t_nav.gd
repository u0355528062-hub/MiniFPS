extends SceneTree
func _initialize():
	var s = load("res://scenes/service.tscn").instantiate()
	root.add_child(s)
	for i in 10:
		await physics_frame
	var m = s.get_world_3d().navigation_map
	print("iteration ", NavigationServer3D.map_get_iteration_id(m), " regions ", NavigationServer3D.map_get_regions(m).size(), " actif ", NavigationServer3D.map_is_active(m))
	print("proche entree ", NavigationServer3D.map_get_closest_point(m, Vector3(7, 0, 28.5)))
	print("proche box3 ", NavigationServer3D.map_get_closest_point(m, s.points["box_3"]["entree"]))
	var nm = s.nav.navigation_mesh
	var v = nm.get_vertices()
	var mn = Vector3(1e9,1e9,1e9); var mx = -mn
	for p in v: mn = mn.min(p); mx = mx.max(p)
	print("aabb nav ", mn, mx)
	var c = NavigationServer3D.map_get_path(m, Vector3(7, 0, 28.5), s.points["box_3"]["entree"], true)
	print("chemin ", c.size(), " ", c)
	var c2 = NavigationServer3D.map_get_path(m, Vector3(10, 0, 20), Vector3(10, 0, 14.5), true)
	print("chemin hall-couloir ", c2.size())
	var c3 = NavigationServer3D.map_get_path(m, Vector3(7, 0, 28.5), Vector3(7, 0, 24), true)
	print("chemin dehors-hall ", c3.size())
	quit()
