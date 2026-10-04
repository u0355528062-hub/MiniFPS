class_name Patient
extends Node3D
## Patient en décubitus dorsal sous les champs : tête à -X, pieds à +X, côté droit du patient vers +Z.
## Contient la peau du champ opératoire (badigeon, incision, plaie), les organes procéduraux
## (cæcum, grêle, appendice inflammatoire) et les éléments posés pendant l'opération.

const TABLE_TOP := 0.95
## Incision de McBurney (coordonnées monde x, z)
const INC_A := Vector2(0.1389, 0.0705)
const INC_B := Vector2(0.1011, 0.1295)
const PATCH_MIN := Vector2(-0.03, -0.05)
const PATCH_SIZE := Vector2(0.31, 0.30)
const WINDOW_MIN := Vector2(0.0, -0.02)
const WINDOW_MAX := Vector2(0.25, 0.22)
const MASK_RES := 64
const WOUND_DEPTH := 0.05
## Pointe de l'appendice dans le fichier anatomie_appendice.glb (origine = base)
const ANAT_TIP := Vector3(0.0089, -0.0287, -0.0467)

var skin_mat: ShaderMaterial
var iodine_img: Image
var iodine_tex: ImageTexture
var opening := 0.0: set = set_opening
var incision_progress := 0.0: set = set_incision_progress

var dir3: Vector3  # direction de l'incision (A -> B), horizontale
var perp3: Vector3  # perpendiculaire horizontale
var center: Vector3  # centre de l'incision, sur la peau

var wall_mesh := ArrayMesh.new()
var appendix_mesh := ArrayMesh.new()
var appendix_node: MeshInstance3D
var meso: MeshInstance3D
var _anat_xf := Transform3D.IDENTITY
var _app_index := PackedInt32Array()
var _app_s := PackedFloat32Array()
var _app_local := PackedVector3Array()
var _app_nlocal := PackedVector3Array()
var _rest_line := PackedVector3Array()
var _rest_frames: Array[Basis] = []
var appendix_base: Vector3
var appendix_tip: Vector3
var appendix_rest_tip: Vector3
var appendix_cut := false
var ligature: MeshInstance3D
var stitches: Array[Node3D] = []

var _tissue_shader: Shader = preload("res://shaders/tissue.gdshader")


# ---------------------------------------------------------------- Forme du corps

static func _shape(r: float) -> float:
	return pow(1.0 - r * r * r, 1.0 / 3.0) if r < 1.0 else 0.0


static func _torso_thickness(x: float) -> float:
	var t := 0.20 + 0.025 * exp(-pow((x + 0.42) / 0.14, 2.0)) - 0.05 * smoothstep(0.18, 0.42, x)
	return t * smoothstep(-0.72, -0.62, x) * (1.0 - smoothstep(0.30, 0.44, x))


static func _torso_width(x: float) -> float:
	return 0.215 + 0.02 * exp(-pow((x + 0.55) / 0.1, 2.0))


## Hauteur de la peau (ou du matelas hors du corps) au point (x, z).
static func body_height(x: float, z: float) -> float:
	var torso := _torso_thickness(x) * _shape(absf(z) / _torso_width(x))
	var legs := 0.0
	if x > 0.2:
		var lt := 0.125 * smoothstep(0.2, 0.36, x) * (1.0 - 0.3 * smoothstep(0.7, 1.05, x)) * (1.0 - smoothstep(1.02, 1.08, x))
		legs = maxf(lt * _shape(absf(z - 0.095) / 0.09), lt * _shape(absf(z + 0.095) / 0.09))
	return TABLE_TOP + maxf(torso, legs)


static func _smax(a: float, b: float, k := 0.025) -> float:
	var h := clampf(0.5 + 0.5 * (a - b) / k, 0.0, 1.0)
	return lerpf(b, a, h) + k * h * (1.0 - h)


static func _drape_height(x: float, z: float) -> float:
	var edge := 0.30
	var az := absf(z)
	var bridge := TABLE_TOP + _torso_thickness(x) * _shape(az / (_torso_width(x) * 1.4)) * 0.9
	var legs_bridge := TABLE_TOP + 0.125 * smoothstep(0.2, 0.36, x) * _shape(az / 0.26) * 0.95 * (1.0 - smoothstep(1.0, 1.1, x))
	# Le tissu ne suit pas les arêtes du corps : union lissée de toutes les formes
	var top := _smax(_smax(body_height(x, minf(az, edge) * signf(z)) + 0.006, bridge), legs_bridge)
	top = _smax(top, TABLE_TOP + 0.012)
	# Plis légers
	top += 0.003 * sin(x * 37.0 + z * 11.0) * sin(z * 23.0 - x * 7.0)
	if az > edge:
		var e := az - edge
		var y_edge := _smax(_smax(body_height(x, edge * signf(z)) + 0.006, TABLE_TOP + 0.012), _smax(bridge, legs_bridge))
		top = y_edge - e * e * 30.0 - e * 1.2
		top += 0.01 * sin(x * 21.0) * smoothstep(0.0, 0.2, e)
	if x > 1.08:
		top -= (x - 1.08) * (x - 1.08) * 40.0 + (x - 1.08) * 1.5
	return maxf(top, 0.42)


# ---------------------------------------------------------------- Construction

func build() -> void:
	var a := Vector3(INC_A.x, 0, INC_A.y)
	var b := Vector3(INC_B.x, 0, INC_B.y)
	dir3 = (b - a).normalized()
	perp3 = dir3.cross(Vector3.UP).normalized()
	var c2 := (INC_A + INC_B) * 0.5
	center = Vector3(c2.x, body_height(c2.x, c2.y), c2.y)
	_build_drapes()
	_build_head()
	_build_skin()
	_build_cavity()
	set_opening(0.0)


func _build_drapes() -> void:
	var drape_shader: Shader = preload("res://shaders/drape.gdshader")
	var m := ShaderMaterial.new()
	m.shader = drape_shader
	m.set_shader_parameter("window_min", WINDOW_MIN)
	m.set_shader_parameter("window_max", WINDOW_MAX)
	m.set_shader_parameter("has_window", 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "Champs"
	mi.mesh = MeshUtil.height_grid(-0.64, -0.66, 1.84, 1.32, 150, 110, _drape_height)
	mi.material_override = m
	add_child(mi)

	# Arceau d'anesthésie : sépare le champ stérile de la tête du patient
	var screen_mat := ShaderMaterial.new()
	screen_mat.shader = drape_shader
	screen_mat.set_shader_parameter("fabric", Color(0.16, 0.38, 0.47))
	var screen := MeshInstance3D.new()
	screen.name = "Arceau"
	# Voile vertical légèrement tombant
	var sm := SurfaceTool.new()
	sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nz := 40
	var ny := 16
	for j in ny + 1:
		for i in nz + 1:
			var z := -0.72 + 1.44 * i / nz
			var y := 0.55 + 1.15 * j / ny
			var sag := 0.03 * sin(PI * float(i) / nz) * (1.0 - float(j) / ny) + 0.008 * sin(z * 40.0)
			sm.set_uv(Vector2(float(i) / nz, float(j) / ny))
			sm.add_vertex(Vector3(-0.64 + sag, y, z))
	for j in ny:
		for i in nz:
			var p0 := j * (nz + 1) + i
			sm.add_index(p0)
			sm.add_index(p0 + nz + 1)
			sm.add_index(p0 + 1)
			sm.add_index(p0 + 1)
			sm.add_index(p0 + nz + 1)
			sm.add_index(p0 + nz + 2)
	sm.generate_normals()
	screen.mesh = sm.commit()
	screen.material_override = screen_mat
	add_child(screen)
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.84), 0.25, 0.9)
	var bar := MeshUtil.cylinder_instance(self, 0.008, 1.46, Vector3(-0.64, 1.71, 0), steel, "Barre")
	bar.rotation_degrees.x = 90
	for s in [-1.0, 1.0]:
		MeshUtil.cylinder_instance(self, 0.008, 0.8, Vector3(-0.64, 1.31, s * 0.73), steel, "Montant")


func _build_head() -> void:
	# Tête (derrière l'arceau, visible côté anesthésie), bonnet et masque
	var skin := MeshUtil.mat(Color(0.82, 0.62, 0.52), 0.55)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.095
	sp.height = 0.2
	head.mesh = sp
	head.material_override = skin
	head.position = Vector3(-0.84, TABLE_TOP + 0.1, 0)
	head.scale = Vector3(1.05, 0.95, 0.85)
	add_child(head)
	var cap := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 0.1
	cs.height = 0.2
	cs.is_hemisphere = true
	cap.mesh = cs
	cap.material_override = MeshUtil.mat(Color(0.3, 0.5, 0.65), 0.9)
	cap.position = Vector3(-0.88, TABLE_TOP + 0.1, 0)
	cap.rotation_degrees.z = 90
	add_child(cap)
	var mask_scene: PackedScene = load("res://assets/models/masque.glb")
	if mask_scene:
		var mask: Node3D = mask_scene.instantiate()
		mask.position = Vector3(-0.8, TABLE_TOP + 0.19, 0)
		mask.rotation_degrees = Vector3(0, 90, 0)
		add_child(mask)
	MeshUtil.cylinder_instance(self, 0.05, 0.1, Vector3(-0.72, TABLE_TOP + 0.08, 0), skin, "Cou").rotation_degrees.z = 90


func _build_skin() -> void:
	iodine_img = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_L8)
	iodine_img.fill(Color.BLACK)
	iodine_tex = ImageTexture.create_from_image(iodine_img)
	skin_mat = ShaderMaterial.new()
	skin_mat.shader = preload("res://shaders/skin_field.gdshader")
	skin_mat.set_shader_parameter("iodine_mask", iodine_tex)
	skin_mat.set_shader_parameter("patch_min", PATCH_MIN)
	skin_mat.set_shader_parameter("patch_size", PATCH_SIZE)
	skin_mat.set_shader_parameter("inc_a", INC_A)
	skin_mat.set_shader_parameter("inc_b", INC_B)
	var mi := MeshInstance3D.new()
	mi.name = "Peau"
	mi.mesh = MeshUtil.height_grid(PATCH_MIN.x, PATCH_MIN.y, PATCH_SIZE.x, PATCH_SIZE.y, 110, 110, body_height)
	mi.material_override = skin_mat
	add_child(mi)


func _tissue(base: Color, inflamed := 0.0, vessels := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _tissue_shader
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("inflamed", inflamed)
	m.set_shader_parameter("vessel_amount", vessels)
	return m


func _build_cavity() -> void:
	var walls := MeshInstance3D.new()
	walls.name = "ParoiPlaie"
	walls.mesh = wall_mesh
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/wound_wall.gdshader")
	walls.material_override = wm
	add_child(walls)

	# Fond de la cavité péritonéale : coque retournée, rose sombre humide
	var bowl := MeshInstance3D.new()
	bowl.name = "Cavite"
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.flip_faces = true
	bowl.mesh = sp
	bowl.material_override = _tissue(Color(0.55, 0.2, 0.17), 0.15, 0.9)
	bowl.material_override.set_shader_parameter("clip_y", center.y - 0.012)
	bowl.basis = Basis(dir3 * 0.1, Vector3.UP * 0.075, perp3 * 0.08)
	bowl.position = center - Vector3.UP * 0.075
	add_child(bowl)

	# Organes réels (Z-Anatomy) : origine du fichier = base de l'appendice
	appendix_base = center + dir3 * 0.022 - Vector3.UP * 0.046 + perp3 * 0.002
	var scene: PackedScene = load("res://assets/models/anatomie_appendice.glb")
	var anat: Node3D = scene.instantiate()
	anat.name = "Anatomie"
	add_child(anat)
	# Oriente le groupe pour que l'appendice repose sous la plaie, vers l'autre extrémité de l'incision
	var want := (-dir3 + perp3 * 0.15 - Vector3.UP * 0.12).normalized()
	var q := Quaternion(ANAT_TIP.normalized(), want)
	anat.global_transform = Transform3D(Basis(q), appendix_base)
	_anat_xf = anat.global_transform
	var looks := {
		"Ascending_colon": _tissue(Color(0.84, 0.58, 0.5), 0.12, 0.65),
		"Free_taenia": _tissue(Color(0.92, 0.84, 0.74), 0.0, 0.2),
		"Jejunum": _tissue(Color(0.88, 0.54, 0.48), 0.0, 0.7),
		"Meso-appendix": _tissue(Color(0.95, 0.78, 0.42), 0.25, 0.8),
		"Ileal_branch_of_ileocolic_artery": _tissue(Color(0.62, 0.06, 0.07), 0.0, 0.0),
		"Colic_branch_of_ileocolic_artery": _tissue(Color(0.62, 0.06, 0.07), 0.0, 0.0),
	}
	for mi in _meshes_in(anat):
		var key := String(mi.name)
		if key.begins_with("Vermiform"):
			_init_appendix(mi)
			mi.visible = false
			continue
		var mat: ShaderMaterial = looks.get(key, _tissue(Color(0.85, 0.55, 0.48)))
		mat.set_shader_parameter("clip_y", center.y - 0.012)
		mi.material_override = mat
		if key == "Meso-appendix":
			meso = mi


func _meshes_in(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes_in(c))
	return out


# ---------------------------------------------------------------- Appendice (maillage réel déformable)

func _init_appendix(src: MeshInstance3D) -> void:
	var arr := src.mesh.surface_get_arrays(0)
	var xf := src.global_transform
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	_app_index = arr[Mesh.ARRAY_INDEX]
	appendix_rest_tip = _anat_xf * ANAT_TIP
	appendix_tip = appendix_rest_tip
	var axis := appendix_rest_tip - appendix_base
	var alen := axis.length()
	# Ligne médiane au repos : centroïdes par tranches le long de l'axe base -> pointe
	var bins := 14
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	sums.resize(bins)
	counts.resize(bins)
	for i in bins:
		sums[i] = Vector3.ZERO
		counts[i] = 0
	var world := PackedVector3Array()
	world.resize(verts.size())
	_app_s.resize(verts.size())
	for i in verts.size():
		var w := xf * verts[i]
		world[i] = w
		var s := clampf((w - appendix_base).dot(axis) / (alen * alen), 0.0, 1.0)
		_app_s[i] = s
		var b := mini(int(s * bins), bins - 1)
		sums[b] += w
		counts[b] += 1
	_rest_line = PackedVector3Array([appendix_base])
	for i in bins:
		if counts[i] > 0:
			_rest_line.append(sums[i] / counts[i])
	_rest_line.append(appendix_rest_tip)
	_rest_frames = _frames(_rest_line)
	# Coordonnées locales de chaque sommet dans le repère de la ligne médiane
	_app_local.resize(verts.size())
	_app_nlocal.resize(verts.size())
	var nb := xf.basis.inverse().transposed()
	for i in verts.size():
		var f := _frame_at(_rest_line, _rest_frames, _app_s[i])
		var c: Vector3 = f[0]
		var bas: Basis = f[1]
		_app_local[i] = bas.transposed() * (world[i] - c)
		_app_nlocal[i] = bas.transposed() * (nb * norms[i]).normalized()
	var mi := MeshInstance3D.new()
	mi.name = "Appendice"
	mi.mesh = appendix_mesh
	mi.material_override = _tissue(Color(0.78, 0.38, 0.32), 1.0, 0.9)
	mi.material_override.set_shader_parameter("clip_y", center.y - 0.008)
	add_child(mi)
	appendix_node = mi
	_update_appendix()


## Repères (tangente, normale, binormale) par transport parallèle le long d'une polyligne.
static func _frames(line: PackedVector3Array) -> Array[Basis]:
	var out: Array[Basis] = []
	var n := line.size()
	var t0 := (line[1] - line[0]).normalized()
	var nrm := t0.cross(Vector3.UP)
	if nrm.length() < 0.01:
		nrm = t0.cross(Vector3.RIGHT)
	nrm = nrm.normalized()
	for i in n:
		var t: Vector3
		if i == 0:
			t = (line[1] - line[0]).normalized()
		elif i == n - 1:
			t = (line[n - 1] - line[n - 2]).normalized()
		else:
			t = (line[i + 1] - line[i - 1]).normalized()
		nrm = (nrm - t * nrm.dot(t)).normalized()
		out.append(Basis(nrm, t.cross(nrm), t))
	return out


## Point et repère interpolés au paramètre s (0..1) le long de la polyligne.
static func _frame_at(line: PackedVector3Array, frames: Array[Basis], s: float) -> Array:
	var f := s * (line.size() - 1)
	var i := clampi(int(f), 0, line.size() - 2)
	var k := f - i
	var c := line[i].lerp(line[i + 1], k)
	var q := Quaternion(frames[i].orthonormalized()).slerp(Quaternion(frames[i + 1].orthonormalized()), k)
	return [c, Basis(q)]


func _current_line() -> PackedVector3Array:
	# La ligne au repos est entraînée vers la nouvelle pointe, davantage vers l'extrémité
	var delta := appendix_tip - appendix_rest_tip
	var out := PackedVector3Array()
	for i in _rest_line.size():
		var s := float(i) / (_rest_line.size() - 1)
		var w := pow(s, 1.6)
		var lift := Vector3.UP * delta.length() * 0.35 * sin(PI * s) * smoothstep(0.0, 0.03, delta.length())
		out.append(_rest_line[i] + delta * w + lift)
	return out


func appendix_point(t: float) -> Vector3:
	var line := _current_line()
	return _frame_at(line, _frames(line), t)[0]


func set_appendix_tip(p: Vector3) -> void:
	var off := p - appendix_base
	if off.length() > 0.095:
		off = off.normalized() * 0.095
	appendix_tip = appendix_base + off
	_update_appendix()


func _deformed(s_min: float, s_max: float, origin := Vector3.ZERO) -> ArrayMesh:
	var line := _current_line()
	var frames := _frames(line)
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	v.resize(_app_local.size())
	n.resize(_app_local.size())
	for i in _app_local.size():
		var f := _frame_at(line, frames, _app_s[i])
		var bas: Basis = f[1]
		v[i] = f[0] + bas * _app_local[i] - origin
		n[i] = bas * _app_nlocal[i]
	var idx := PackedInt32Array()
	for k in range(0, _app_index.size(), 3):
		var a := _app_index[k]
		var b := _app_index[k + 1]
		var c := _app_index[k + 2]
		var smax := maxf(_app_s[a], maxf(_app_s[b], _app_s[c]))
		var smin := minf(_app_s[a], minf(_app_s[b], _app_s[c]))
		if smin >= s_min and smax <= s_max:
			idx.append_array([a, b, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func _update_appendix() -> void:
	if _app_local.is_empty():
		return
	var m := _deformed(0.0, 0.3 if appendix_cut else 1.0)
	appendix_mesh.clear_surfaces()
	appendix_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, m.surface_get_arrays(0))
	# Le méso suit la base, on l'efface quand l'appendice est extériorisé
	var moved := appendix_tip.distance_to(appendix_rest_tip) > 0.01
	if meso:
		meso.visible = not moved
	if appendix_node:
		appendix_node.material_override.set_shader_parameter("clip_y", 100.0 if moved else center.y - 0.008)


## Pose le fil de ligature à la base de l'appendice.
func ligate() -> void:
	if ligature:
		return
	ligature = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0036
	tm.outer_radius = 0.0054
	tm.rings = 24
	tm.ring_segments = 8
	ligature.mesh = tm
	ligature.material_override = MeshUtil.mat(Color(0.92, 0.9, 0.82), 0.6)
	add_child(ligature)
	var p := appendix_point(0.18)
	var tan := (appendix_point(0.22) - appendix_point(0.14)).normalized()
	var side := tan.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = tan.cross(Vector3.RIGHT).normalized()
	ligature.global_transform = Transform3D(Basis(side, tan, side.cross(tan)), p)
	for s in [-1.0, 1.0]:
		var end := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0006
		cm.bottom_radius = 0.0006
		cm.height = 0.012
		end.mesh = cm
		end.material_override = ligature.material_override
		add_child(end)
		end.global_position = p + side * 0.006 + Vector3.UP * 0.003 + tan * 0.004 * s
		end.rotation_degrees = Vector3(30 * s, 0, 70)


## Section de l'appendice : la partie libre devient un objet séparé que l'on peut saisir.
func cut() -> Node3D:
	var piece := Node3D.new()
	piece.name = "AppendiceRetire"
	add_child(piece)
	var origin := appendix_point(0.65)
	piece.global_position = origin
	var mi := MeshInstance3D.new()
	mi.mesh = _deformed(0.33, 1.0, origin)
	mi.material_override = appendix_node.material_override
	piece.add_child(mi)
	# Tranches de section rouge sombre
	var raw := _tissue(Color(0.5, 0.06, 0.06), 0.5, 0.0)
	for t in [0.3, 0.33]:
		var cap := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = 0.0055
		cs.height = 0.004
		cap.mesh = cs
		cap.material_override = raw
		var at := appendix_point(t)
		var tan := (appendix_point(t + 0.02) - appendix_point(t - 0.02)).normalized()
		if t < 0.31:
			add_child(cap)
		else:
			piece.add_child(cap)
		cap.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, tan)), at)
	appendix_cut = true
	_update_appendix()
	return piece


# ---------------------------------------------------------------- Peau : badigeon, incision, plaie

## Peint l'antiseptique autour d'un point. Renvoie la couverture de la zone à préparer (0..1).
func paint_iodine(p: Vector3, radius := 0.022) -> float:
	var cx := (p.x - PATCH_MIN.x) / PATCH_SIZE.x * MASK_RES
	var cz := (p.z - PATCH_MIN.y) / PATCH_SIZE.y * MASK_RES
	var r := radius / PATCH_SIZE.x * MASK_RES
	for j in range(int(cz - r) - 1, int(cz + r) + 2):
		for i in range(int(cx - r) - 1, int(cx + r) + 2):
			if i < 0 or j < 0 or i >= MASK_RES or j >= MASK_RES:
				continue
			var d := Vector2(i + 0.5 - cx, j + 0.5 - cz).length() / r
			if d < 1.0:
				var v := iodine_img.get_pixel(i, j).r
				iodine_img.set_pixel(i, j, Color.from_hsv(0, 0, minf(1.0, v + (1.0 - d) * 0.55 + 0.25)))
	iodine_tex.update(iodine_img)
	return iodine_coverage()


func iodine_coverage() -> float:
	var total := 0
	var done := 0
	for j in MASK_RES:
		for i in MASK_RES:
			var x := PATCH_MIN.x + (i + 0.5) / MASK_RES * PATCH_SIZE.x
			var z := PATCH_MIN.y + (j + 0.5) / MASK_RES * PATCH_SIZE.y
			# Zone à préparer : ellipse centrée sur l'incision
			var q := Vector2(x - center.x, z - center.z)
			if (q.x * q.x) / (0.075 * 0.075) + (q.y * q.y) / (0.085 * 0.085) > 1.0:
				continue
			total += 1
			if iodine_img.get_pixel(i, j).r > 0.45:
				done += 1
	return float(done) / maxf(1.0, total)


func fill_iodine() -> void:
	iodine_img.fill(Color.WHITE)
	iodine_tex.update(iodine_img)


func incision_point(t: float) -> Vector3:
	var p := INC_A.lerp(INC_B, t)
	return Vector3(p.x, body_height(p.x, p.y), p.y)


## Paramètre t (0..1) du point de l'incision le plus proche de p, et distance horizontale.
func incision_project(p: Vector3) -> Vector2:
	var a := Vector2(INC_A.x, INC_A.y)
	var ab := INC_B - INC_A
	var q := Vector2(p.x, p.z)
	var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(t, (a + ab * t).distance_to(q))


func set_incision_progress(v: float) -> void:
	incision_progress = v
	if skin_mat:
		skin_mat.set_shader_parameter("incision_progress", v)
		skin_mat.set_shader_parameter("show_guide", 1.0 if v < 0.999 else 0.0)


func set_opening(v: float) -> void:
	opening = v
	if skin_mat == null:
		return
	skin_mat.set_shader_parameter("opening", v)
	_rebuild_walls()


func set_stitched(v: float) -> void:
	skin_mat.set_shader_parameter("stitched", v)


func _rebuild_walls() -> void:
	wall_mesh.clear_surfaces()
	if opening <= 0.01:
		return
	var half_len := INC_A.distance_to(INC_B) * 0.5 + 0.004
	var half_w := opening * 0.018
	var k := 48
	var levels := 6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in levels + 1:
		var f := float(j) / levels
		var shrink := 1.0 - 0.3 * pow(f, 1.4)
		for i in k + 1:
			var a := TAU * i / k
			var p := center + dir3 * cos(a) * half_len * shrink + perp3 * sin(a) * half_w * shrink
			# Le haut suit la peau, puis on descend
			var top := body_height(p.x, p.z) + 0.0004
			p.y = top - WOUND_DEPTH * f
			st.set_uv(Vector2(float(i) / k, f))
			st.add_vertex(p)
	for j in levels:
		for i in k:
			var p0 := j * (k + 1) + i
			st.add_index(p0)
			st.add_index(p0 + 1)
			st.add_index(p0 + k + 1)
			st.add_index(p0 + 1)
			st.add_index(p0 + k + 2)
			st.add_index(p0 + k + 1)
	st.generate_normals()
	st.commit(wall_mesh)


## Repère d'un écarteur posé dans la plaie (side = -1 ou +1 de part et d'autre de l'incision).
func retractor_slot(side: float) -> Vector3:
	return center + perp3 * side * 0.016 + Vector3.UP * 0.002


func add_stitch(t: float) -> void:
	var p := incision_point(t) + Vector3.UP * 0.0012
	var knot := Node3D.new()
	add_child(knot)
	knot.global_position = p
	var thread := MeshUtil.mat(Color(0.12, 0.16, 0.45), 0.4)
	var bar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0007
	cm.bottom_radius = 0.0007
	cm.height = 0.016
	bar.mesh = cm
	bar.material_override = thread
	knot.add_child(bar)
	bar.global_basis = Basis.looking_at(perp3, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.0018
	bs.height = 0.0036
	ball.mesh = bs
	ball.material_override = thread
	ball.position = perp3 * 0.006 + Vector3.UP * 0.0008
	knot.add_child(ball)
	for s in [-1.0, 1.0]:
		var end := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0004
		em.bottom_radius = 0.0004
		em.height = 0.007
		end.mesh = em
		end.material_override = thread
		end.position = perp3 * 0.009 + dir3 * 0.0025 * s + Vector3.UP * 0.001
		end.rotation = Vector3(0.4 * s, 0.3, 1.3)
		knot.add_child(end)
	stitches.append(knot)
