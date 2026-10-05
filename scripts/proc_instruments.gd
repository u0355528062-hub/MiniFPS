class_name ProcInstruments
## Instruments fabriqués par code (pas de modèle gratuit disponible). Pointe vers +Z, centrés.


static func build(kind: String) -> Node3D:
	match kind:
		"drain":
			return _drain()
		"feutre":
			return _feutre()
		"cathlon":
			return CathlonModel.new()
		"sonde":
			return ProbeModel.new()
		"guide":
			return SeldingerModels.guide()
		"dilatateur":
			return SeldingerModels.dilator()
		"kt_central":
			return SeldingerModels.central_catheter()
		"finochietto":
			return FinochiettoModel.new()
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
	tube.mesh = MeshUtil.tube(_line(-0.16, 0.16, 24), _radii(24, 0.0048), 16, true, true)
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


## Feutre dermographique stérile (marqueur chirurgical) : corps violet, bague blanche, pointe en
## feutre violet de gentiane.
static func _feutre() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = MeshUtil.tube(_line(-0.065, 0.045, 6), _radii(6, 0.0055), 18, true, false)
	body.material_override = MeshUtil.mat(Color(0.42, 0.16, 0.55), 0.35)
	root.add_child(body)
	var ring := MeshUtil.cylinder_instance(root, 0.0058, 0.012, Vector3(0, 0, -0.058), MeshUtil.mat(Color(0.92, 0.92, 0.9), 0.4), "Bague")
	ring.rotation_degrees.x = 90
	var cone := MeshInstance3D.new()
	var pts := PackedVector3Array([Vector3(0, 0, 0.045), Vector3(0, 0, 0.055), Vector3(0, 0, 0.062)])
	var rr := PackedFloat32Array([0.0055, 0.003, 0.0016])
	cone.mesh = MeshUtil.tube(pts, rr, 16, false, false)
	cone.material_override = MeshUtil.mat(Color(0.9, 0.9, 0.9), 0.3)
	root.add_child(cone)
	var felt := MeshInstance3D.new()
	var fp := PackedVector3Array([Vector3(0, 0, 0.062), Vector3(0, 0, 0.068)])
	var fr := PackedFloat32Array([0.0012, 0.0007])
	felt.mesh = MeshUtil.tube(fp, fr, 10, false, true)
	felt.material_override = MeshUtil.mat(Color(0.25, 0.06, 0.32), 0.7)
	root.add_child(felt)
	return root
