class_name SeldingerModels
## Matériel de la voie veineuse centrale (technique de Seldinger), fabriqué par code, pointe vers +Z :
##  - guide : enrouleur en plastique (boucle) et pousse-guide, guide métallique à bout en J ;
##  - dilatateur : tige rigide effilée, embase bleue ;
##  - cathéter central : trois voies, corps blanc gradué, raccords et clamps colorés.


static func guide() -> Node3D:
	var root := Node3D.new()
	var plastic := MeshUtil.mat(Color(0.92, 0.94, 0.96), 0.35)
	var blue := MeshUtil.mat(Color(0.18, 0.42, 0.78), 0.4)
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.85), 0.2, 1.0)
	# Pousse-guide (redresseur du J) tenu entre les doigts
	_tube(root, [Vector3(0, 0, -0.025), Vector3(0, 0, 0.012)], [0.0042, 0.0034], blue)
	_tube(root, [Vector3(0, 0, 0.012), Vector3(0, 0, 0.02)], [0.0026, 0.0016], plastic)
	# Bout en J du guide qui dépasse
	var j := PackedVector3Array()
	for i in 10:
		var t := float(i) / 9.0
		j.append(Vector3(0, -0.004 * (1.0 - cos(t * PI)) * smoothstep(0.4, 1.0, t), 0.02 + 0.012 * sin(t * PI * 0.6)))
	_tube(root, j, [0.00045], steel)
	# Boucle de l'enrouleur derrière la main (dans le plan XZ, centrée sur l'axe)
	var loop := PackedVector3Array()
	for i in 49:
		var a := TAU * i / 48.0
		loop.append(Vector3(sin(a) * 0.055, 0, -0.085 + cos(a) * 0.055))
	_tube(root, loop, [0.0028], plastic)
	_tube(root, [Vector3(0, 0, -0.03), Vector3(0, 0, -0.025)], [0.0034], plastic)
	return root


static func dilator() -> Node3D:
	var root := Node3D.new()
	var white := MeshUtil.mat(Color(0.93, 0.94, 0.95), 0.3)
	var blue := MeshUtil.mat(Color(0.15, 0.4, 0.8), 0.35)
	_tube(root, [Vector3(0, 0, -0.06), Vector3(0, 0, 0.05), Vector3(0, 0, 0.066)], [0.0024, 0.0024, 0.0008], white)
	_tube(root, [Vector3(0, 0, -0.09), Vector3(0, 0, -0.06)], [0.0055, 0.0045], blue)
	return root


static func central_catheter() -> Node3D:
	var root := Node3D.new()
	var body := MeshUtil.mat(Color(0.95, 0.94, 0.9), 0.35)
	var ink := MeshUtil.mat(Color(0.1, 0.1, 0.12), 0.6)
	_tube(root, [Vector3(0, 0, -0.05), Vector3(0, 0, 0.11), Vector3(0, 0, 0.118)], [0.0012, 0.0012, 0.0007], body)
	# Graduations tous les centimètres
	for k in 15:
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.00121
		tm.outer_radius = 0.0013 if k % 5 else 0.0014
		tm.rings = 12
		tm.ring_segments = 3
		r.mesh = tm
		r.material_override = ink
		r.rotation_degrees.x = 90
		r.position = Vector3(0, 0, 0.1 - k * 0.01)
		root.add_child(r)
	# Ailette de fixation et embranchement des trois voies
	MeshUtil.box_instance(root, Vector3(0.016, 0.003, 0.012), Vector3(0, 0, -0.055), body, "Ailette")
	MeshUtil.box_instance(root, Vector3(0.008, 0.006, 0.02), Vector3(0, 0, -0.07), body, "Embranchement")
	var cols := [Color(0.15, 0.35, 0.8), Color(0.55, 0.35, 0.2), Color(0.95, 0.95, 0.95)]
	for i in 3:
		var dx := (i - 1) * 0.006
		var pts := [Vector3(dx * 0.3, 0, -0.078), Vector3(dx, 0, -0.1), Vector3(dx * 1.6, 0, -0.13)]
		_tube(root, pts, [0.0011], body)
		var hub := MeshUtil.mat(cols[i], 0.4)
		_tube(root, [Vector3(dx * 1.6, 0, -0.13), Vector3(dx * 1.7, 0, -0.145)], [0.0028, 0.0024], hub)
		MeshUtil.box_instance(root, Vector3(0.005, 0.004, 0.006), Vector3(dx * 1.3, 0, -0.112), hub, "Clamp")
	return root


static func _tube(parent: Node3D, pts: Array, radii: Array, mat: Material) -> MeshInstance3D:
	var p := PackedVector3Array(pts)
	var r := PackedFloat32Array()
	for i in p.size():
		r.append(radii[mini(i, radii.size() - 1)])
	var mi := MeshInstance3D.new()
	mi.mesh = MeshUtil.tube(p, r, 10, true, true)
	mi.material_override = mat
	parent.add_child(mi)
	return mi
