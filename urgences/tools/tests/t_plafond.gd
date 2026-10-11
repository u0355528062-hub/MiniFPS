extends SceneTree
## Diagnostic : plafond du hall avec/sans sondes de reflets, avec/sans GI voxel.
func _initialize():
	root.size = Vector2i(800, 450)
	var s = load("res://scenes/service.tscn").instantiate()
	root.add_child(s)
	var cam := Camera3D.new()
	s.add_child(cam)
	cam.global_position = Vector3(12.5, 1.65, 24.5)
	cam.look_at(Vector3(4.0, 1.0, 18.0))
	cam.make_current()
	for i in 12: await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/scratch/pl_a.png")
	for p in s.sondes: p.visible = false
	for i in 8: await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/scratch/pl_b.png")
	for g in s.gis: g.visible = false
	for i in 8: await process_frame
	root.get_texture().get_image().save_png("/tmp/claude-0/scratch/pl_c.png")
	quit()
