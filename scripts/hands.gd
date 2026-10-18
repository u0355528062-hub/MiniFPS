class_name Hands
## Mains gantées du soignant (modèles MakeHuman de tools/blender/build_mains.py) : matériaux (gant
## nitrile, peau de l'avant-bras, manche de la tunique) et pose sur le patient sans le traverser.
## Le bras entier (manche courte de la tunique) va jusqu'à l'épaule : il sort du bord de l'écran.
## Repère des modèles : origine au point de contact du geste, dos de la main vers +Y, doigts vers -Z,
## avant-bras vers +Z.

## Gant nitrile bleu-violet, peau de l'avant-bras, tunique de l'urgentiste (partagés avec le corps)
static var _mats := {}
## Points de contrôle de chaque modèle (sommets du maillage, repère du modèle)
static var _samples := {}


static func glove_mat() -> StandardMaterial3D:
	if not _mats.has("gant"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.25, 0.27, 0.72)
		m.roughness = 0.52
		m.metallic_specular = 0.4
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.12
		m.rim_enabled = true
		m.rim = 0.15
		m.rim_tint = 0.7
		_mats["gant"] = m
	return _mats["gant"]


static func skin_mat() -> StandardMaterial3D:
	if not _mats.has("peau"):
		var m := StandardMaterial3D.new()
		m.albedo_texture = Tex.get_tex("peau_albedo")
		m.albedo_color = Color(0.93, 1.02, 1.04)
		m.normal_enabled = true
		m.normal_texture = Tex.get_tex("peau_normal")
		m.roughness = 0.55
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.25
		m.subsurf_scatter_skin_mode = true
		_mats["peau"] = m
	return _mats["peau"]


static func scrub_mat() -> StandardMaterial3D:
	if not _mats.has("tunique"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.13, 0.4, 0.47)
		m.roughness = 0.92
		m.normal_enabled = true
		m.normal_texture = Tex.get_tex("fabric_normal")
		m.normal_scale = 0.5
		m.uv1_triplanar = true
		m.uv1_world_triplanar = false
		m.uv1_scale = Vector3(14, 14, 14)
		_mats["tunique"] = m
	return _mats["tunique"]


static func pants_mat() -> StandardMaterial3D:
	if not _mats.has("pantalon"):
		var m := scrub_mat().duplicate() as StandardMaterial3D
		m.albedo_color = Color(0.1, 0.33, 0.4)
		_mats["pantalon"] = m
	return _mats["pantalon"]


## Sabots de bloc (caoutchouc blanc)
static func shoes_mat() -> StandardMaterial3D:
	if not _mats.has("sabots"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.86, 0.87)
		m.roughness = 0.45
		_mats["sabots"] = m
	return _mats["sabots"]


## Matériau du jeu pour une surface exportée de Blender (d'après le nom de son matériau).
static func mat_for(name: String) -> Material:
	var n := name.to_lower()
	if n.begins_with("gant"):
		return glove_mat()
	if n.begins_with("peau") or n.begins_with("main"):
		return skin_mat()
	if n.begins_with("tunique"):
		return scrub_mat()
	if n.begins_with("pantalon"):
		return pants_mat()
	if n.begins_with("chaussures"):
		return shoes_mat()
	return null


## Applique les matériaux du soignant à toutes les surfaces d'un modèle.
static func dress(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			var mat := mat_for(src.resource_name if src else "")
			if mat:
				m3.set_surface_override_material(i, mat)


## Modèle de mains (fichier .glb de assets/models), habillé.
static func load_model(file: String) -> Node3D:
	var sc: PackedScene = load("res://assets/models/%s.glb" % file)
	var n: Node3D = sc.instantiate()
	dress(n)
	n.set_meta("fichier", file)
	return n


static func _sample_points(n: Node3D) -> PackedVector3Array:
	var file := String(n.get_meta("fichier", ""))
	if _samples.has(file):
		return _samples[file]
	var pts := PackedVector3Array()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var xf := Transform3D.IDENTITY
		var node: Node = m3
		while node != n and node is Node3D:
			xf = (node as Node3D).transform * xf
			node = node.get_parent()
		for s in m3.mesh.get_surface_count():
			var verts: PackedVector3Array = m3.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var step := maxi(1, verts.size() / 90)
			for i in range(0, verts.size(), step):
				pts.append(xf * verts[i])
	_samples[file] = pts
	return pts


## Pose la main telle quelle (objet tenu) : origine sur le point de contact, dos selon la normale.
static func place(n: Node3D, contact: Vector3, normal: Vector3, fwd: Vector3) -> void:
	var up := normal.normalized()
	var f := (fwd - up * fwd.dot(up)).normalized()
	n.global_transform = Transform3D(Basis(up.cross(-f).normalized(), up, -f).orthonormalized(), contact)


## Pose la main : origine sur le point de contact, dos de la main selon la normale, doigts vers fwd.
## Si la main ou l'avant-bras traverse la peau (ou le drap), le poignet se relève autour du point de
## contact (jusqu'à 75°), sinon toute la main monte.
static func seat(n: Node3D, contact: Vector3, normal: Vector3, fwd: Vector3, min_tilt := 0.0) -> void:
	var up := normal.normalized()
	var f := (fwd - up * fwd.dot(up))
	if f.length() < 0.01:
		f = up.cross(Vector3.RIGHT)
	f = f.normalized()
	var right := up.cross(-f).normalized()
	var b0 := Basis(right, up, -f).orthonormalized()
	var pts := _sample_points(n)
	var best_a := min_tilt
	var best_pen := INF
	var a := min_tilt
	while a <= 75.0:
		var b := b0 * Basis(Vector3.RIGHT, -deg_to_rad(a))
		var pen := _penetration(b, contact, pts)
		if pen < best_pen - 0.0005:
			best_pen = pen
			best_a = a
		if pen <= 0.0:
			break
		a += 5.0
	var bb := b0 * Basis(Vector3.RIGHT, -deg_to_rad(best_a))
	var lift := maxf(0.0, best_pen)
	n.global_transform = Transform3D(bb, contact + Vector3.UP * lift)


## Enfoncement maximal (m) des points de la main sous la surface du patient (ou du brancard).
static func _penetration(b: Basis, origin: Vector3, pts: PackedVector3Array) -> float:
	var worst := -1.0
	for q in pts:
		var lp := b * q
		# Autour du point de contact, la main touche la peau : normal
		if lp.length_squared() < 0.0009:
			continue
		var w := origin + lp
		var top := Patient.top_height(w.x, w.z)
		if top < 0.0:
			continue
		worst = maxf(worst, top + 0.003 - w.y)
	return worst
