class_name ProcInstruments
## Instruments fabriqués par code (pas de modèle gratuit disponible). Pointe vers +Z, centrés.


static func build(kind: String) -> Node3D:
	match kind:
		"drain":
			return _drain()
		"aspirateur":
			return _suction()
		"gosset":
			return _gosset_closed()
	return Node3D.new()


static func _line(z0: float, z1: float, n: int, bend := Vector3.ZERO) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(Vector3(0, 0, lerpf(z0, z1, t)) + bend * t * t)
	return pts


static func _radii(n: int, r: float) -> PackedFloat32Array:
	var rr := PackedFloat32Array()
	rr.resize(n)
	rr.fill(r)
	return rr


## Drain thoracique 28 Fr : tube en PVC transparent, ligne radio-opaque bleue, œillets près du bout.
static func _drain() -> Node3D:
	var root := Node3D.new()
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.9, 0.96, 0.98, 0.5)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.1
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	var tube := MeshInstance3D.new()
	tube.mesh = MeshUtil.tube(_line(-0.16, 0.16, 24), _radii(24, 0.0048), 14, true, true)
	tube.material_override = clear
	root.add_child(tube)
	var stripe := MeshInstance3D.new()
	var sp := _line(-0.16, 0.155, 12)
	for i in sp.size():
		sp[i] += Vector3(0, 0.0046, 0)
	stripe.mesh = MeshUtil.tube(sp, _radii(sp.size(), 0.0009), 5)
	stripe.material_override = MeshUtil.mat(Color(0.1, 0.35, 0.85), 0.4)
	root.add_child(stripe)
	var dark := MeshUtil.mat(Color(0.15, 0.2, 0.22), 0.4)
	for k in 3:
		var hole := MeshUtil.cylinder_instance(root, 0.0028, 0.002, Vector3(0.0045, 0, 0.125 - k * 0.018), dark, "Oeillet")
		hole.rotation_degrees.z = 90
	# Repères de longueur (traits noirs)
	for k in 5:
		var mark := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0047
		tm.outer_radius = 0.0051
		mark.mesh = tm
		mark.material_override = dark
		mark.rotation_degrees.x = 90
		mark.position = Vector3(0, 0, 0.06 - k * 0.025)
		root.add_child(mark)
	# Raccord conique au bout opposé
	var conn := MeshUtil.cylinder_instance(root, 0.006, 0.025, Vector3(0, 0, -0.165), MeshUtil.mat(Color(0.85, 0.85, 0.82), 0.4), "Raccord")
	conn.rotation_degrees.x = 90
	return root


## Canule d'aspiration de Yankauer : manche nervuré, tube rigide coudé, embout percé.
static func _suction() -> Node3D:
	var root := Node3D.new()
	var plastic := StandardMaterial3D.new()
	plastic.albedo_color = Color(0.85, 0.92, 0.95, 0.65)
	plastic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastic.roughness = 0.15
	var pts := _line(-0.13, 0.13, 30, Vector3(0, -0.035, 0))
	var rr := PackedFloat32Array()
	for i in pts.size():
		var t := float(i) / (pts.size() - 1)
		rr.append(lerpf(0.0085, 0.0042, smoothstep(0.35, 0.6, t)) + 0.0006 * sin(t * 120.0) * (1.0 - smoothstep(0.3, 0.35, t)))
	var tube := MeshInstance3D.new()
	tube.mesh = MeshUtil.tube(pts, rr, 14, true, true)
	tube.material_override = plastic
	root.add_child(tube)
	var tip := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.0055
	s.height = 0.011
	tip.mesh = s
	tip.material_override = plastic
	tip.position = pts[pts.size() - 1]
	root.add_child(tip)
	# Tubulure qui part vers le bas
	var hose := MeshUtil.bezier(Vector3(0, 0, -0.13), Vector3(0, -0.02, -0.2), Vector3(0, -0.15, -0.25), Vector3(0, -0.3, -0.3), 16)
	var hm := MeshInstance3D.new()
	hm.mesh = MeshUtil.tube(hose, _radii(hose.size(), 0.004), 8)
	hm.material_override = plastic
	root.add_child(hm)
	return root


## Écarteur autostatique de Gosset replié (tenu comme un instrument).
static func _gosset_closed() -> Node3D:
	var root := Node3D.new()
	var steel := MeshUtil.mat(Color(0.85, 0.87, 0.9), 0.2, 1.0)
	MeshUtil.box_instance(root, Vector3(0.012, 0.008, 0.2), Vector3(0, 0, -0.02), steel, "Cremaillere")
	for side in [-1.0, 1.0]:
		MeshUtil.box_instance(root, Vector3(0.05, 0.003, 0.03), Vector3(0.012 * side, -0.01, 0.07), steel, "Valve")
		MeshUtil.box_instance(root, Vector3(0.05, 0.035, 0.003), Vector3(0.012 * side, -0.028, 0.085), steel, "Lame")
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.012
	tm.outer_radius = 0.017
	ring.mesh = tm
	ring.material_override = steel
	ring.rotation_degrees.x = 90
	ring.position = Vector3(0, 0, -0.12)
	root.add_child(ring)
	return root


## Écarteur de Gosset ouvert dans la plaie : deux valves écartées de `width` le long de `perp`.
static func gosset_open(center: Vector3, _along: Vector3, perp: Vector3, width: float, skin_y: float) -> Node3D:
	var root := Node3D.new()
	var steel := MeshUtil.mat(Color(0.85, 0.87, 0.9), 0.2, 1.0)
	root.transform = Transform3D(Basis(perp.normalized(), Vector3.UP, perp.normalized().cross(Vector3.UP)), Vector3(center.x, skin_y, center.z))
	# Barre transversale avec crémaillère
	MeshUtil.box_instance(root, Vector3(width + 0.1, 0.01, 0.014), Vector3(0, 0.035, 0.0), steel, "Barre")
	for k in 9:
		MeshUtil.box_instance(root, Vector3(0.004, 0.006, 0.016), Vector3(-0.04 + k * 0.01, 0.042, 0), steel, "Dent")
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.5
		MeshUtil.box_instance(root, Vector3(0.006, 0.04, 0.012), Vector3(x + side * 0.004, 0.015, 0), steel, "Bras")
		# Valve courbe qui plonge dans la plaie
		var valve := MeshInstance3D.new()
		var pts := PackedVector3Array()
		for i in 8:
			var t := float(i) / 7.0
			pts.append(Vector3(x + side * 0.004 - side * 0.012 * t * t, -0.045 * t, 0))
		var rr := PackedFloat32Array()
		rr.resize(pts.size())
		rr.fill(0.003)
		valve.mesh = MeshUtil.tube(pts, rr, 6)
		valve.material_override = steel
		valve.scale = Vector3(1, 1, 1)
		root.add_child(valve)
		MeshUtil.box_instance(root, Vector3(0.004, 0.035, 0.06), Vector3(x - side * 0.006, -0.025, 0), steel, "Lame")
	return root
