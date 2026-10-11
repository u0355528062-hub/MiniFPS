extends SceneTree
func _initialize():
	var s = load("res://scenes/service.tscn").instantiate()
	root.add_child(s)
	for i in 30:
		await process_frame
	for g in s.gis:
		print("GI ", g.global_position, " taille ", g.size, " données ", g.data != null, " visible ", g.visible)
	quit()
