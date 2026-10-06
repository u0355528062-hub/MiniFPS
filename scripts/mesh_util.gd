class_name MeshUtil
## Fabriques de maillages procéduraux (grilles, tubes, boîtes).


## Grille horizontale déformée par une fonction de hauteur f(x, z) -> y (coordonnées monde).
static func height_grid(x0: float, z0: float, size_x: float, size_z: float, nx: int, nz: int, height: Callable) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz + 1:
		for i in nx + 1:
			var x := x0 + size_x * i / nx
			var z := z0 + size_z * j / nz
			st.set_uv(Vector2(float(i) / nx, float(j) / nz))
			st.add_vertex(Vector3(x, height.call(x, z), z))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Tube le long d'une polyligne, rayon variable, embouts arrondis optionnels.
static func tube(points: PackedVector3Array, radii: PackedFloat32Array, sides: int = 14, cap_start := true, cap_end := true, mesh: ArrayMesh = null) -> ArrayMesh:
	var n := points.size()
	if n < 2:
		return mesh if mesh else ArrayMesh.new()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	# Repères par transport parallèle
	var tangent := (points[1] - points[0]).normalized()
	var normal := tangent.cross(Vector3.UP)
	if normal.length() < 0.01:
		normal = tangent.cross(Vector3.RIGHT)
	normal = normal.normalized()
	var acc := 0.0
	for i in n:
		var t: Vector3
		if i == 0:
			t = (points[1] - points[0]).normalized()
		elif i == n - 1:
			t = (points[n - 1] - points[n - 2]).normalized()
		else:
			t = (points[i + 1] - points[i - 1]).normalized()
		normal = (normal - t * normal.dot(t)).normalized()
		var binormal := t.cross(normal)
		if i > 0:
			acc += points[i].distance_to(points[i - 1])
		for s in sides + 1:
			var a := TAU * s / sides
			var dir := normal * cos(a) + binormal * sin(a)
			verts.append(points[i] + dir * radii[i])
			norms.append(dir)
			uvs.append(Vector2(float(s) / sides, acc * 10.0))
	for i in n - 1:
		for s in sides:
			var a := i * (sides + 1) + s
			var b := a + sides + 1
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	# Embouts hémisphériques
	if cap_end:
		_cap(verts, norms, uvs, idx, points[n - 1], (points[n - 1] - points[n - 2]).normalized(), radii[n - 1], sides)
	if cap_start:
		_cap(verts, norms, uvs, idx, points[0], (points[0] - points[1]).normalized(), radii[0], sides)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := mesh if mesh else ArrayMesh.new()
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _cap(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, center: Vector3, axis: Vector3, r: float, sides: int) -> void:
	var ref := axis.cross(Vector3.UP)
	if ref.length() < 0.01:
		ref = axis.cross(Vector3.RIGHT)
	ref = ref.normalized()
	var bin := axis.cross(ref)
	var rings := 4
	var base := verts.size()
	for k in rings + 1:
		var phi := PI * 0.5 * k / rings
		for s in sides + 1:
			var a := TAU * s / sides
			var dir := (ref * cos(a) + bin * sin(a)) * cos(phi) + axis * sin(phi)
			verts.append(center + dir * r)
			norms.append(dir)
			uvs.append(Vector2(float(s) / sides, 0.0))
	for k in rings:
		for s in sides:
			var a := base + k * (sides + 1) + s
			var b := a + sides + 1
			idx.append_array([a, a + 1, b, a + 1, b + 1, b])


## Points d'une courbe de Bézier cubique.
static func bezier(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in count:
		var t := float(i) / (count - 1)
		var u := 1.0 - t
		out.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return out


static func box_instance(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, name := "Boite") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi


static func cylinder_instance(parent: Node3D, radius: float, height: float, pos: Vector3, mat: Material, name := "Cylindre") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi


static func sphere_instance(parent: Node3D, radius: float, pos: Vector3, mat: Material, name := "Sphere") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.name = name
	parent.add_child(mi)
	return mi


static func mat(color: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
