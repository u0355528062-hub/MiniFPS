class_name Patient
extends Node3D
## Patient en décubitus dorsal sous les champs : tête à -X, pieds à +X, côté droit du patient vers +Z.
## Contient la peau du champ opératoire (badigeon, incision, plaie), les organes procéduraux
## (cæcum, grêle, appendice inflammatoire) et les éléments posés pendant l'opération.

const TABLE_TOP := 0.95
## Incision de McBurney (coordonnées monde x, z)
const INC_A := Vector2(0.136, 0.075)
const INC_B := Vector2(0.104, 0.125)
const PATCH_MIN := Vector2(-0.03, -0.05)
const PATCH_SIZE := Vector2(0.31, 0.30)
const WINDOW_MIN := Vector2(0.0, -0.02)
const WINDOW_MAX := Vector2(0.25, 0.22)
const MASK_RES := 64
const WOUND_DEPTH := 0.045

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


static func _drape_height(x: float, z: float) -> float:
	var edge := 0.30
	var az := absf(z)
	var bridge := TABLE_TOP + _torso_thickness(x) * _shape(az / (_torso_width(x) * 1.4)) * 0.9
	var legs_bridge := TABLE_TOP + 0.125 * smoothstep(0.2, 0.36, x) * _shape(az / 0.26) * 0.95 * (1.0 - smoothstep(1.0, 1.1, x))
	var top := maxf(maxf(body_height(x, minf(az, edge) * signf(z)) + 0.006, bridge), legs_bridge)
	top = maxf(top, TABLE_TOP + 0.012)
	# Plis légers
	top += 0.003 * sin(x * 37.0 + z * 11.0) * sin(z * 23.0 - x * 7.0)
	if az > edge:
		var e := az - edge
		var y_edge := maxf(maxf(body_height(x, edge * signf(z)) + 0.006, TABLE_TOP + 0.012), maxf(bridge, legs_bridge))
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
	_build_appendix()
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

	# Fond de la cavité : coque retournée, rouge sombre humide
	var bowl := MeshInstance3D.new()
	bowl.name = "Cavite"
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.flip_faces = true
	bowl.mesh = sp
	bowl.material_override = _tissue(Color(0.42, 0.12, 0.1), 0.3, 0.9)
	bowl.basis = Basis(dir3 * 0.075, Vector3.UP * 0.05, perp3 * 0.06)
	bowl.position = center - Vector3.UP * 0.05
	add_child(bowl)

	var d := center.y
	# Cæcum : gros tube rosé avec bosselures (haustrations)
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 13:
		var t := float(i) / 12.0
		pts.append(Vector3(center.x + 0.08 - 0.16 * t, d - 0.068 + 0.004 * sin(t * 9.0), center.z + 0.012 - 0.01 * t))
		rad.append(0.024 * (1.0 + 0.08 * sin(t * 40.0)))
	var cecum := MeshInstance3D.new()
	cecum.name = "Caecum"
	cecum.mesh = MeshUtil.tube(pts, rad, 18)
	cecum.material_override = _tissue(Color(0.82, 0.56, 0.48), 0.1, 0.5)
	add_child(cecum)

	# Anses grêles
	var bowel_mat := _tissue(Color(0.86, 0.52, 0.46), 0.0, 0.7)
	var loops := [
		[Vector3(-0.05, -0.062, -0.035), Vector3(0.0, -0.05, -0.06), Vector3(0.04, -0.05, -0.01), Vector3(0.07, -0.064, -0.04)],
		[Vector3(-0.07, -0.07, 0.03), Vector3(-0.03, -0.055, 0.05), Vector3(0.0, -0.058, 0.0), Vector3(-0.04, -0.07, -0.02)],
	]
	for l in loops:
		var lp := MeshUtil.bezier(center + l[0], center + l[1], center + l[2], center + l[3], 18)
		var lr := PackedFloat32Array()
		lr.resize(lp.size())
		lr.fill(0.0115)
		var lm := MeshInstance3D.new()
		lm.mesh = MeshUtil.tube(lp, lr, 14)
		lm.material_override = bowel_mat
		add_child(lm)
	# Franges graisseuses
	var fat := _tissue(Color(0.95, 0.78, 0.38), 0.0, 0.2)
	for f in [Vector3(0.03, -0.052, 0.025), Vector3(-0.025, -0.055, 0.03), Vector3(0.045, -0.058, -0.02)]:
		var fm := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.009
		fs.height = 0.014
		fm.mesh = fs
		fm.material_override = fat
		fm.position = center + f
		add_child(fm)


func _build_appendix() -> void:
	appendix_base = center + dir3 * 0.012 - Vector3.UP * 0.046 + perp3 * 0.002
	appendix_rest_tip = appendix_base - dir3 * 0.042 + perp3 * 0.01 - Vector3.UP * 0.004
	appendix_tip = appendix_rest_tip
	var mi := MeshInstance3D.new()
	mi.name = "Appendice"
	mi.mesh = appendix_mesh
	mi.material_override = _tissue(Color(0.78, 0.38, 0.32), 1.0, 0.9)
	add_child(mi)
	_update_appendix()


# ---------------------------------------------------------------- Appendice

func appendix_curve(count := 16) -> PackedVector3Array:
	var span := appendix_tip - appendix_base
	var p1 := appendix_base + Vector3.UP * 0.014 + span * 0.15
	var p2 := appendix_tip + Vector3.UP * 0.008 - span * 0.3
	return MeshUtil.bezier(appendix_base, p1, p2, appendix_tip, count)


func appendix_point(t: float) -> Vector3:
	var span := appendix_tip - appendix_base
	var p1 := appendix_base + Vector3.UP * 0.014 + span * 0.15
	var p2 := appendix_tip + Vector3.UP * 0.008 - span * 0.3
	var u := 1.0 - t
	return appendix_base * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + appendix_tip * t * t * t


static func _appendix_radius(t: float) -> float:
	return lerpf(0.0042, 0.0068, smoothstep(0.0, 0.6, t)) - 0.0008 * smoothstep(0.85, 1.0, t)


func set_appendix_tip(p: Vector3) -> void:
	var off := p - appendix_base
	if off.length() > 0.085:
		off = off.normalized() * 0.085
	appendix_tip = appendix_base + off
	_update_appendix()


func _update_appendix() -> void:
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var t_end := 0.3 if appendix_cut else 1.0
	for i in 16:
		var t := t_end * i / 15.0
		pts.append(appendix_point(t))
		rad.append(_appendix_radius(t))
	MeshUtil.tube(pts, rad, 14, false, true, appendix_mesh)


## Pose le fil de ligature à la base de l'appendice.
func ligate() -> void:
	if ligature:
		return
	ligature = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0034
	tm.outer_radius = 0.0052
	tm.rings = 24
	tm.ring_segments = 8
	ligature.mesh = tm
	ligature.material_override = MeshUtil.mat(Color(0.92, 0.9, 0.82), 0.6)
	add_child(ligature)
	var p := appendix_point(0.18)
	var tan := (appendix_point(0.2) - appendix_point(0.16)).normalized()
	var side := tan.cross(Vector3.FORWARD).normalized()
	if side.length() < 0.1:
		side = tan.cross(Vector3.RIGHT).normalized()
	ligature.global_transform = Transform3D(Basis(side, tan, side.cross(tan)), p)
	# Deux brins coupés courts
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
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 14:
		var t := lerpf(0.33, 1.0, i / 13.0)
		pts.append(appendix_point(t) - origin)
		rad.append(_appendix_radius(t))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshUtil.tube(pts, rad, 14, true, true)
	mi.material_override = _tissue(Color(0.78, 0.38, 0.32), 1.0, 0.9)
	piece.add_child(mi)
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
	var half_w := opening * 0.03
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
