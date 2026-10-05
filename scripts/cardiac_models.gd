class_name CardiacModels
## Instruments de chirurgie cardiaque fabriqués par code (pointe vers +Z) : bistouri électrique,
## canules de circulation extracorporelle, canule de cardioplégie, palettes de défibrillation
## internes. (Scie sternale : SternalSawModel ; clamp aortique : CrossClampModel.)


static func _tube(parent: Node3D, pts: PackedVector3Array, r: float, mat: Material, name: String, sides := 14, caps := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(r)
	mi.mesh = MeshUtil.tube(pts, rr, sides, caps, caps)
	mi.material_override = mat
	mi.name = name
	parent.add_child(mi)
	return mi


static func _clear(tint: Color, alpha := 0.42) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic_specular = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Bistouri électrique : stylet jaune pâle, deux boutons (coupe jaune, coagulation bleue), lame
## spatule en acier, câble à l'arrière.
static func electrocautery() -> Node3D:
	var root := Node3D.new()
	var shell := MeshUtil.mat(Color(0.9, 0.88, 0.78), 0.42)
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.85), 0.2, 1.0)
	var pen := MeshInstance3D.new()
	pen.name = "Stylet"
	var pts := PackedVector3Array()
	var rr := PackedFloat32Array()
	for i in 12:
		var t := i / 11.0
		pts.append(Vector3(0, 0, lerpf(-0.165, -0.012, t)))
		rr.append(0.0062 * (1.0 - 0.45 * smoothstep(0.75, 1.0, t)) * (1.0 - 0.08 * smoothstep(0.0, 0.1, 1.0 - t)))
	pen.mesh = MeshUtil.tube(pts, rr, 16)
	pen.material_override = shell
	root.add_child(pen)
	MeshUtil.box_instance(root, Vector3(0.006, 0.003, 0.012), Vector3(0, 0.0058, -0.075), MeshUtil.mat(Color(0.95, 0.75, 0.1), 0.35), "BoutonCoupe")
	MeshUtil.box_instance(root, Vector3(0.006, 0.003, 0.012), Vector3(0, 0.0058, -0.058), MeshUtil.mat(Color(0.15, 0.35, 0.8), 0.35), "BoutonCoag")
	_tube(root, PackedVector3Array([Vector3(0, 0, -0.016), Vector3(0, 0, -0.004)]), 0.0016, steel, "Tige")
	MeshUtil.box_instance(root, Vector3(0.0028, 0.0007, 0.016), Vector3(0, 0, 0.006), steel, "Lame")
	var cable := MeshUtil.bezier(Vector3(0, 0, -0.166), Vector3(0, 0, -0.2), Vector3(0.01, 0, -0.23), Vector3(0.024, 0, -0.25), 8)
	_tube(root, cable, 0.0025, MeshUtil.mat(Color(0.93, 0.93, 0.95), 0.5), "Cable")
	return root


## Canule de circulation extracorporelle. Artérielle : tube transparent de 7 mm, collerette, bout
## biseauté rigide. Veineuse : grosse canule à deux étages, panier perforé, renfort bleu.
static func cannula(venous: bool) -> Node3D:
	var root := Node3D.new()
	var r := 0.0062 if venous else 0.0036
	var tube_mat := _clear(Color(0.86, 0.9, 0.95))
	_tube(root, PackedVector3Array([Vector3(0, 0, -0.24), Vector3(0, 0, -0.012)]), r, tube_mat, "Tube", 18)
	if venous:
		# Renfort spiralé (bleu) et panier perforé au bout
		var spiral := PackedVector3Array()
		for i in 120:
			var t := i / 119.0
			var a := t * TAU * 22.0
			spiral.append(Vector3(cos(a) * r * 1.02, sin(a) * r * 1.02, lerpf(-0.2, -0.03, t)))
		_tube(root, spiral, 0.0006, MeshUtil.mat(Color(0.15, 0.3, 0.75), 0.4), "Spirale", 6)
		var basket := MeshUtil.mat(Color(0.25, 0.42, 0.85), 0.35)
		_tube(root, PackedVector3Array([Vector3(0, 0, -0.03), Vector3(0, 0, 0.012)]), r * 0.92, basket, "Panier", 16)
		for k in 10:
			var hole := MeshUtil.cylinder_instance(root, 0.0016, 0.002, Vector3(cos(k * 2.4) * r * 0.93, sin(k * 2.4) * r * 0.93, -0.024 + k * 0.0034), MeshUtil.mat(Color(0.05, 0.06, 0.1), 0.6), "Trou")
			hole.rotation = Vector3(0, 0, k * 2.4 - PI * 0.5)  # axe du trou vers l'extérieur
	else:
		var tipm := MeshUtil.mat(Color(0.92, 0.93, 0.95), 0.25)
		var pts := PackedVector3Array([Vector3(0, 0, -0.012), Vector3(0, 0, 0.004), Vector3(0, -0.001, 0.012)])
		var rr := PackedFloat32Array([0.0034, 0.0029, 0.0018])
		var tip := MeshInstance3D.new()
		tip.name = "Bout"
		tip.mesh = MeshUtil.tube(pts, rr, 16)
		tip.material_override = tipm
		root.add_child(tip)
		# Collerette (butée contre l'aorte) et repère noir
		var flange := MeshUtil.cylinder_instance(root, 0.0068, 0.0018, Vector3(0, 0, -0.013), tipm, "Collerette")
		flange.rotation_degrees.x = 90
		var mark := MeshUtil.cylinder_instance(root, r * 1.03, 0.003, Vector3(0, 0, -0.03), MeshUtil.mat(Color(0.05, 0.05, 0.05), 0.5), "Repere")
		mark.rotation_degrees.x = 90
	# Raccord à l'arrière
	var conn := MeshUtil.cylinder_instance(root, r * 1.35, 0.016, Vector3(0, 0, -0.245), MeshUtil.mat(Color(0.85, 0.85, 0.88), 0.3), "Raccord")
	conn.rotation_degrees.x = 90
	return root


## Canule de cardioplégie : aiguille-évent de 14 G sur un raccord en Y, ligne transparente.
static func cardioplegia_needle() -> Node3D:
	var root := Node3D.new()
	var steel := MeshUtil.mat(Color(0.85, 0.86, 0.88), 0.15, 1.0)
	_tube(root, PackedVector3Array([Vector3(0, 0, -0.004), Vector3(0, 0, 0.016)]), 0.0011, steel, "Aiguille", 10)
	var hub := MeshUtil.cylinder_instance(root, 0.0045, 0.018, Vector3(0, 0, -0.013), MeshUtil.mat(Color(0.95, 0.95, 0.97), 0.3), "Raccord")
	hub.rotation_degrees.x = 90
	MeshUtil.box_instance(root, Vector3(0.016, 0.004, 0.006), Vector3(0, 0, -0.012), MeshUtil.mat(Color(0.95, 0.95, 0.97), 0.3), "Ailettes")
	var side := MeshUtil.bezier(Vector3(0, 0.002, -0.016), Vector3(0, 0.012, -0.03), Vector3(0, 0.02, -0.05), Vector3(0, 0.024, -0.09), 8)
	_tube(root, side, 0.0019, _clear(Color(0.9, 0.95, 1.0), 0.5), "Event")
	_tube(root, PackedVector3Array([Vector3(0, 0, -0.022), Vector3(0, 0, -0.16)]), 0.0022, _clear(Color(0.9, 0.95, 1.0), 0.5), "Ligne")
	return root


## Palettes de défibrillation internes : deux cuillères (6 cm) au bout de manches isolés, tenues
## ensemble, qui enserrent le cœur.
static func internal_paddles() -> Node3D:
	var root := Node3D.new()
	var steel := MeshUtil.mat(Color(0.82, 0.84, 0.86), 0.25, 1.0)
	var insul := MeshUtil.mat(Color(0.08, 0.09, 0.1), 0.6)
	for side in [-1.0, 1.0]:
		var handle := MeshUtil.bezier(Vector3(side * 0.012, 0, -0.2), Vector3(side * 0.014, 0, -0.12), Vector3(side * 0.03, 0, -0.06), Vector3(side * 0.034, 0, -0.03), 10)
		_tube(root, handle, 0.006, insul, "Manche")
		_tube(root, PackedVector3Array([Vector3(side * 0.034, 0, -0.032), Vector3(side * 0.034, 0, -0.012)]), 0.0028, steel, "Tige")
		var cup := MeshInstance3D.new()
		cup.name = "Palette"
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.is_hemisphere = true
		sm.radial_segments = 24
		sm.rings = 8
		cup.mesh = sm
		cup.material_override = steel
		cup.scale = Vector3(0.006, 0.022, 0.02)
		cup.rotation_degrees.z = -90.0 * side
		cup.position = Vector3(side * 0.03, 0, 0.004)
		root.add_child(cup)
	# Câbles réunis à l'arrière
	_tube(root, PackedVector3Array([Vector3(0, 0, -0.2), Vector3(0, 0, -0.26)]), 0.004, insul, "Cable")
	return root
