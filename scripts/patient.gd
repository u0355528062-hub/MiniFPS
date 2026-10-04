class_name Patient
extends Node3D
## Patient en décubitus dorsal sous les champs : tête à -X, pieds à +X, côté droit du patient vers +Z.
## Contient la peau du champ opératoire (badigeon, incision, plaie qui s'étire), les organes
## (cæcum, grêle, appendice inflammatoire) et les éléments posés pendant l'opération.
## La plaie est physique : chaque bord a son ouverture, tirée par les écarteurs et rappelée par un
## ressort (elle se détend quand on relâche). Toute la déformation est calculée par la carte graphique.

const TABLE_TOP := 0.95
const MASK_RES := 96
const HMAP_RES := 128
## Pointe de l'appendice dans le fichier anatomie_appendice.glb (origine = base)
const ANAT_TIP := Vector3(0.0089, -0.0287, -0.0467)

# Réglages du champ opératoire (fixés par l'opération avant build())
var INC_A := Vector2(0.1389, 0.0705)  ## début de l'incision (x, z)
var INC_B := Vector2(0.1011, 0.1295)  ## fin de l'incision
var PATCH_MIN := Vector2(-0.03, -0.05)  ## zone de peau détaillée
var PATCH_SIZE := Vector2(0.31, 0.30)
var WINDOW_MIN := Vector2(0.025, -0.005)  ## fenêtre du champ
var WINDOW_MAX := Vector2(0.215, 0.2)
var WOUND_DEPTH := 0.05
var wound_w := 0.022  ## écart d'un bord à ouverture 1
var paint_r := Vector2(0.075, 0.085)  ## demi-axes (x, z) de la zone à désinfecter
var bowl_radii := Vector3(0.1, 0.075, 0.08)  ## cavité : le long, en profondeur, en travers
var op := "appendicectomie"
var bowl_color := Color(0.55, 0.2, 0.17)
var breathe_amp := 0.006  ## soulèvement du thorax à chaque inspiration (m)
var breath_rate := 14.0  ## respirations par minute
var breath_b := 0.0  ## 0 = expiration, 1 = fin d'inspiration
var _breath_t := 0.0
var hole_limit := 1.0  ## profondeur maximale de la plaie ouverte (drain : la peau seule avant la dissection)
var drape_mat: ShaderMaterial

var skin_mat: ShaderMaterial  ## grande grille de peau
var zone_mat: ShaderMaterial  ## zone fendue de l'incision
var wall_mat: ShaderMaterial
var iodine_img: Image
var iodine_tex: ImageTexture
var height_tex: ImageTexture
var zone_u := 0.06
var zone_v := 0.07

var dir3: Vector3  # direction de l'incision (A -> B), horizontale
var perp3: Vector3  # perpendiculaire horizontale (côté +1)
var center: Vector3  # centre de l'incision, sur la peau
var half_len := 0.035

# ---- Plaie physique
var open_l := 0.0  ## ouverture actuelle du bord gauche (v < 0)
var open_r := 0.0
var _vel_l := 0.0
var _vel_r := 0.0
var rest_open := 0.0  ## ouverture au repos (les bords baillent un peu après l'incision)
var held_l := -1.0  ## bord tenu par un écarteur posé (l'aide le tient)
var held_r := -1.0
var drive_l := -1.0  ## bord tiré en ce moment par un instrument (remis à -1 à chaque image)
var drive_r := -1.0
var cut0 := 1.0  ## partie incisée [cut0, cut1] en t (0 = A, 1 = B), vide au départ
var cut1 := 0.0
var bleed0 := 1.0
var bleed1 := 0.0
var opening: float: set = set_opening, get = get_opening
var incision_progress: float: set = set_incision_progress, get = get_incision_progress
var _press := [Vector4.ZERO, Vector4.ZERO]
var _press_set := [false, false]
var bleb := Vector4.ZERO  ## x, z, rayon, hauteur
var abscess := Vector4.ZERO  ## abcès : x, z, rayon, hauteur du dôme
var abscess_red := 0.0  ## rougeur inflammatoire
var bleb_pale := 0.0

# ---- Badigeon
var _iodine_wet := 1.0
var _iod_target := PackedByteArray()
var _iod_total := 0
var _iod_done := 0
var _iod_dirty := false

# ---- Organes
var appendix_skel: Skeleton3D
var appendix_node: MeshInstance3D
var appendix_mat: ShaderMaterial
var meso: MeshInstance3D
var _anat_xf := Transform3D.IDENTITY
var _app_mesh_stump: ArrayMesh
var _app_mesh_piece: ArrayMesh
var _app_skin: Skin
var _rest_line := PackedVector3Array()
var _rest_frames: Array[Basis] = []
var appendix_base: Vector3
var appendix_tip: Vector3
var appendix_rest_tip: Vector3
var appendix_cut := false
var appendix_squeeze := 0.0  ## étranglement de la base par la ligature (0..1)
var ligature: MeshInstance3D
var stitches: Array[Node3D] = []
var wound_light: OmniLight3D


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
	var h := maxf(torso, legs)
	if arm_mode:
		h = maxf(h, arm_height(x, z))
	return TABLE_TOP + h


# ---------------------------------------------------------------- Bras droit (canal carpien)

## Bras droit posé le long du corps, paume vers le haut, doigts vers les pieds (+X).
static var arm_mode := false
const ARM_Z := 0.38
const WRIST_X := 0.125


static func _ell(r: float) -> float:
	return sqrt(maxf(0.0, 1.0 - r * r))


## Épaisseur du bras, de la main et des doigts au-dessus de la table.
static func arm_height(x: float, z: float) -> float:
	if x < -0.56 or x > 0.33 or absf(z - ARM_Z) > 0.08:
		return 0.0
	var v := z - ARM_Z  # v > 0 : côté du pouce (vers le chirurgien)
	var h := 0.0
	if x < 0.228:
		var w: float
		var t: float
		if x < WRIST_X:
			var k := smoothstep(-0.5, WRIST_X, x)
			w = lerpf(0.05, 0.03, k)
			t = lerpf(0.07, 0.031, k) * smoothstep(-0.56, -0.46, x)
		else:
			var k := (x - WRIST_X) / (0.228 - WRIST_X)
			w = 0.03 + 0.013 * smoothstep(0.0, 0.35, k)
			t = lerpf(0.031, 0.024, k) * (1.0 - 0.5 * smoothstep(0.85, 1.0, k))
		h = t * _ell(absf(v - 0.003) / w)
		# Éminences thénar (pouce) et hypothénar, pli de flexion du poignet
		h += 0.007 * exp(-pow((x - 0.165) / 0.03, 2.0) - pow((v - 0.022) / 0.013, 2.0))
		h += 0.004 * exp(-pow((x - 0.175) / 0.035, 2.0) - pow((v + 0.022) / 0.01, 2.0))
		h -= 0.0012 * exp(-pow((x - WRIST_X) / 0.003, 2.0)) * smoothstep(0.03, 0.0, absf(v))
	# Doigts (index du côté du pouce), légèrement fléchis
	var fv := [0.019, 0.006, -0.007, -0.019]
	var fl := [0.074, 0.082, 0.077, 0.06]
	for i in 4:
		var s: float = (x - 0.218) / fl[i]
		if s > 0.0 and s < 1.0:
			var r: float = 0.0085 * (1.0 - 0.22 * s)
			var tip := _ell(maxf(0.0, (s - 0.88) / 0.12))
			h = maxf(h, (0.019 - 0.006 * s) * _ell(absf(v - fv[i]) / r) * tip)
	# Pouce : en dehors, vers l'avant
	var a := Vector2(0.14, 0.036)
	var b := Vector2(0.2, 0.062)
	var ab := b - a
	var k2 := clampf((Vector2(x, v) - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var dth := (a + ab * k2).distance_to(Vector2(x, v))
	h = maxf(h, (0.022 - 0.006 * k2) * _ell(dth / (0.0105 * (1.0 - 0.2 * k2))) * _ell(maxf(0.0, (k2 - 0.9) / 0.1)))
	return h


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
	if arm_mode:
		# Le champ recouvre aussi le bras posé le long du corps
		var ah := arm_height(x, z)
		var near_arm := TABLE_TOP + ah + 0.006 if ah > 0.0 else -1.0
		top = maxf(top, _smax(top, near_arm, 0.02))
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
	_build_wound()
	if op == "appendicectomie":
		_build_appendix_anatomy()
	set_opening(0.0)


func _build_drapes() -> void:
	var m := Tex.drape(Color(0.2, 0.4, 0.5), WINDOW_MIN, WINDOW_MAX, breathe_amp)
	drape_mat = m
	var mi := MeshInstance3D.new()
	mi.name = "Champs"
	mi.mesh = MeshUtil.height_grid(-0.64, -0.66, 1.84, 1.32, 150, 110, _drape_height)
	mi.material_override = m
	add_child(mi)

	# Bord roulé du champ autour de la fenêtre (épaisseur du tissu replié)
	var lip := PackedVector3Array()
	var lr := PackedFloat32Array()
	var corners := [Vector2(WINDOW_MIN.x, WINDOW_MIN.y), Vector2(WINDOW_MAX.x, WINDOW_MIN.y), Vector2(WINDOW_MAX.x, WINDOW_MAX.y), Vector2(WINDOW_MIN.x, WINDOW_MAX.y)]
	for k in 4:
		var a2: Vector2 = corners[k]
		var b2: Vector2 = corners[(k + 1) % 4]
		for i in 24:
			var q := a2.lerp(b2, i / 24.0)
			lip.append(Vector3(q.x, _drape_height(q.x, q.y) + 0.002, q.y))
			lr.append(0.0045 + 0.0015 * sin(q.x * 90.0 + q.y * 70.0))
	lip.append(lip[0])
	lr.append(lr[0])
	var lip_mi := MeshInstance3D.new()
	lip_mi.name = "BordChamp"
	lip_mi.mesh = MeshUtil.tube(lip, lr, 8, false, false)
	lip_mi.material_override = Tex.drape(Color(0.18, 0.37, 0.47))
	add_child(lip_mi)

	# Arceau d'anesthésie : sépare le champ stérile de la tête du patient
	var screen_mat := Tex.drape(Color(0.2, 0.4, 0.5))
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
			var y := 0.62 + 0.56 * j / ny
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
	sm.generate_tangents()
	screen.mesh = sm.commit()
	screen.material_override = screen_mat
	add_child(screen)
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.84), 0.25, 0.9)
	var bar := MeshUtil.cylinder_instance(self, 0.008, 1.46, Vector3(-0.64, 1.19, 0), steel, "Barre")
	bar.rotation_degrees.x = 90
	for s in [-1.0, 1.0]:
		MeshUtil.cylinder_instance(self, 0.008, 0.6, Vector3(-0.64, 0.9, s * 0.73), steel, "Montant")


func _build_head() -> void:
	# Buste scanné (Lee Perry-Smith, Infinite-Realities, CC BY 3.0) allongé, côté anesthésie
	var scene: PackedScene = load("res://assets/models/tete_patient.glb")
	var bust: Node3D = scene.instantiate()
	bust.name = "Tete"
	bust.position = Vector3(-0.71, TABLE_TOP + 0.004, 0.0)
	add_child(bust)
	var skin := ShaderMaterial.new()
	skin.shader = preload("res://shaders/head_skin.gdshader")
	skin.set_shader_parameter("albedo_tex", Tex.get_tex_any("res://assets/textures/head_albedo.jpg"))
	skin.set_shader_parameter("normal_tex", Tex.get_tex_any("res://assets/textures/head_normal.jpg"))
	var nose := bust.global_position + Vector3.UP * 0.2
	for mi in _meshes_in(bust):
		mi.material_override = skin
		# Bout du nez = point le plus haut : sert de repère pour placer sonde et pansements
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var best := -1.0e9
		for v in verts:
			var w: Vector3 = mi.global_transform * v
			if w.y > best and absf(w.z) < 0.05:
				best = w.y
				nose = w
	var white := MeshUtil.mat(Color(0.93, 0.93, 0.9), 0.7)
	# Pansements occlusifs sur les yeux
	for side in [-1.0, 1.0]:
		var tape := MeshUtil.box_instance(self, Vector3(0.028, 0.002, 0.02), nose + Vector3(-0.042, -0.018, 0.033 * side), white, "Pansement")
		tape.rotation_degrees = Vector3(12.0 * side, 0, -18)
	_build_airway(nose, white)
	# Charlotte (bonnet) bleue sur le crâne
	var cap := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 1.0
	cs.height = 2.0
	cs.is_hemisphere = true
	cap.mesh = cs
	cap.material_override = Tex.drape(Color(0.2, 0.42, 0.6))
	cap.position = nose + Vector3(-0.135, -0.1, 0.0)
	cap.basis = Basis(Vector3(0, 0, 1), deg_to_rad(90)).scaled(Vector3(1, 1, 1))
	cap.scale = Vector3(0.075, 0.1, 0.085)
	add_child(cap)


## Masque facial d'anesthésie transparent + harnais, circuit annelé vers le respirateur,
## ligne de capnographie, électrodes ECG et perfusion.
func _build_airway(nose: Vector3, white: Material) -> void:
	var mouth := nose + Vector3(0.03, -0.012, 0.0)
	var mask_c := mouth + Vector3(-0.004, 0.012, 0.0)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.82, 0.95, 0.92, 0.32)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.08
	clear.metallic_specular = 0.9
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Coque du masque (demi-ellipsoïde posé sur le nez et la bouche)
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 32
	shell.mesh = sm
	shell.material_override = clear
	shell.position = mask_c
	shell.scale = Vector3(0.062, 0.04, 0.05)
	shell.name = "MasqueO2"
	add_child(shell)
	# Coussin gonflable (bord du masque)
	var cushion := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 32
	tm.ring_segments = 10
	cushion.mesh = tm
	var cush_mat := StandardMaterial3D.new()
	cush_mat.albedo_color = Color(0.55, 0.75, 0.9, 0.55)
	cush_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cush_mat.roughness = 0.25
	cushion.material_override = cush_mat
	cushion.position = mask_c + Vector3(0, -0.002, 0)
	cushion.scale = Vector3(0.064, 0.05, 0.052)
	add_child(cushion)
	# Coude et raccord
	var elbow_mat := MeshUtil.mat(Color(0.25, 0.55, 0.85, 0.85), 0.3)
	MeshUtil.cylinder_instance(self, 0.011, 0.03, mask_c + Vector3(0, 0.05, 0), elbow_mat, "Coude")
	# Sangles du harnais : de chaque côté du masque vers l'arrière de la tête
	for side in [-1.0, 1.0]:
		var sp := MeshUtil.bezier(mask_c + Vector3(0.0, 0.0, 0.045 * side), mask_c + Vector3(-0.03, -0.02, 0.075 * side), mask_c + Vector3(-0.07, -0.07, 0.08 * side), mask_c + Vector3(-0.09, -0.11, 0.075 * side), 16)
		var sr := PackedFloat32Array()
		sr.resize(sp.size())
		sr.fill(0.0035)
		var strap := MeshInstance3D.new()
		strap.mesh = MeshUtil.tube(sp, sr, 6)
		strap.material_override = MeshUtil.mat(Color(0.1, 0.1, 0.11), 0.6)
		add_child(strap)
	# Circuit annelé (inspiration + expiration) jusqu'au respirateur
	var ribbed := MeshUtil.mat(Color(0.75, 0.88, 0.95, 0.8), 0.3)
	ribbed.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var start := mask_c + Vector3(0, 0.065, 0)
	for k in 2:
		var end := Vector3(-1.2, 1.05, -0.28 + k * 0.08)
		var pts := MeshUtil.bezier(start, start + Vector3(-0.05, 0.12, 0.0), end + Vector3(0.35, 0.25, 0.05 * k), end, 70)
		var rr := PackedFloat32Array()
		for i in pts.size():
			rr.append(0.011 + 0.0016 * sin(i * 2.6))
		var tube := MeshInstance3D.new()
		tube.mesh = MeshUtil.tube(pts, rr, 12)
		tube.material_override = ribbed
		tube.name = "Circuit"
		add_child(tube)
	# Ligne de capnographie (fine, jaune)
	var cap_pts := MeshUtil.bezier(start, start + Vector3(0.02, 0.08, 0.04), Vector3(-1.0, 1.3, -0.2), Vector3(-1.3, 1.35, -0.3), 30)
	var cr := PackedFloat32Array()
	cr.resize(cap_pts.size())
	cr.fill(0.0018)
	var capno := MeshInstance3D.new()
	capno.mesh = MeshUtil.tube(cap_pts, cr, 6)
	capno.material_override = MeshUtil.mat(Color(0.95, 0.85, 0.3), 0.4)
	add_child(capno)
	# Câbles ECG : sortent de sous le champ (électrodes sur le thorax) vers le poste d'anesthésie
	var cols := [Color(0.9, 0.15, 0.1), Color(0.95, 0.9, 0.2), Color(0.2, 0.7, 0.3)]
	for i in 3:
		var pz: float = [-0.2, 0.18, -0.1][i]
		var pe := Vector3(-0.62, _drape_height(-0.62, pz) + 0.002, pz)
		var wp := MeshUtil.bezier(pe, pe + Vector3(-0.08, 0.03, 0.0), Vector3(-1.0, 1.0, -0.3), Vector3(-1.2, 0.98, -0.32 + i * 0.03), 24)
		var wr := PackedFloat32Array()
		wr.resize(wp.size())
		wr.fill(0.0016)
		var wire := MeshInstance3D.new()
		wire.mesh = MeshUtil.tube(wp, wr, 5)
		wire.material_override = MeshUtil.mat(cols[i] * 0.8, 0.5)
		add_child(wire)
	# Perfusion : tubulure du pied à sérum vers le bras (sous le champ)
	var iv := MeshUtil.bezier(Vector3(-1.05, 1.55, -0.55), Vector3(-1.0, 1.1, -0.55), Vector3(-0.7, 1.1, -0.45), Vector3(-0.5, 1.0, -0.33), 30)
	var ir := PackedFloat32Array()
	ir.resize(iv.size())
	ir.fill(0.002)
	var ivm := MeshInstance3D.new()
	ivm.mesh = MeshUtil.tube(iv, ir, 6)
	ivm.material_override = clear
	add_child(ivm)


func _build_skin() -> void:
	iodine_img = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_L8)
	iodine_img.fill(Color.BLACK)
	iodine_tex = ImageTexture.create_from_image(iodine_img)
	# Zone à préparer (ellipse centrée sur l'incision) : comptée au fur et à mesure du badigeon
	_iod_target.resize(MASK_RES * MASK_RES)
	_iod_total = 0
	for j in MASK_RES:
		for i in MASK_RES:
			var x := PATCH_MIN.x + (i + 0.5) / MASK_RES * PATCH_SIZE.x
			var z := PATCH_MIN.y + (j + 0.5) / MASK_RES * PATCH_SIZE.y
			var q := Vector2(x - center.x, z - center.z)
			var inside := (q.x * q.x) / (paint_r.x * paint_r.x) + (q.y * q.y) / (paint_r.y * paint_r.y) <= 1.0
			_iod_target[j * MASK_RES + i] = 1 if inside else 0
			if inside:
				_iod_total += 1
	# Relief de la peau en texture : la carte graphique déplace la peau sans rien recalculer
	var hmap := Image.create(HMAP_RES, HMAP_RES, false, Image.FORMAT_RF)
	for j in HMAP_RES:
		for i in HMAP_RES:
			var x := PATCH_MIN.x + float(i) / (HMAP_RES - 1) * PATCH_SIZE.x
			var z := PATCH_MIN.y + float(j) / (HMAP_RES - 1) * PATCH_SIZE.y
			hmap.set_pixel(i, j, Color(body_height(x, z), 0, 0))
	height_tex = ImageTexture.create_from_image(hmap)

	half_len = INC_A.distance_to(INC_B) * 0.5
	zone_u = half_len + 0.028
	zone_v = clampf(wound_w * 3.2, 0.03, 0.075)
	skin_mat = _skin_material(false)
	zone_mat = _skin_material(true)
	var mi := MeshInstance3D.new()
	mi.name = "Peau"
	var res := 150 if arm_mode else 100
	mi.mesh = MeshUtil.height_grid(PATCH_MIN.x, PATCH_MIN.y, PATCH_SIZE.x, PATCH_SIZE.y, res, res, body_height)
	mi.material_override = skin_mat
	add_child(mi)
	var zone := MeshInstance3D.new()
	zone.name = "PeauIncision"
	zone.mesh = _zone_mesh()
	zone.material_override = zone_mat
	add_child(zone)


func _skin_material(is_zone: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/skin_field.gdshader")
	m.set_shader_parameter("is_zone", 1.0 if is_zone else 0.0)
	m.set_shader_parameter("iodine_mask", iodine_tex)
	m.set_shader_parameter("win_min", WINDOW_MIN)
	m.set_shader_parameter("win_max", WINDOW_MAX)
	m.set_shader_parameter("zone_u", zone_u)
	m.set_shader_parameter("skin_albedo", Tex.get_tex("skin_albedo"))
	m.set_shader_parameter("skin_normal", Tex.get_tex("skin_normal"))
	m.set_shader_parameter("skin_rough", Tex.get_tex("skin_rough"))
	m.set_shader_parameter("blood_tex", Tex.get_tex("blood"))
	_common_params(m)
	return m


## Paramètres partagés par la peau et les parois (géométrie de l'incision).
func _common_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("height_map", height_tex)
	m.set_shader_parameter("patch_min", PATCH_MIN)
	m.set_shader_parameter("patch_size", PATCH_SIZE)
	m.set_shader_parameter("inc_a", INC_A)
	m.set_shader_parameter("inc_b", INC_B)
	m.set_shader_parameter("wound_w", wound_w)
	m.set_shader_parameter("zone_v", zone_v)


func _all_mats() -> Array[ShaderMaterial]:
	var out: Array[ShaderMaterial] = []
	for m in [skin_mat, zone_mat, wall_mat]:
		if m:
			out.append(m)
	return out


## Zone de l'incision : deux nappes (une par bord) jointes le long du trait, plus fines près du trait.
func _zone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 72
	var nv := 20
	var base := 0
	for side in [-1.0, 1.0]:
		for j in nv + 1:
			var v: float = side * (zone_v + 0.001) * pow(float(j) / nv, 1.7)
			for i in nu + 1:
				var u := -(zone_u + 0.001) + 2.0 * (zone_u + 0.001) * i / nu
				var p := center + dir3 * u + perp3 * v
				st.set_uv(Vector2(u, v))
				st.set_uv2(Vector2(side, 0.0))
				st.add_vertex(Vector3(p.x, body_height(p.x, p.z), p.z))
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var c := a + nu + 1
				# Faces dans le sens de Godot (horaire vu de dessus) pour les deux nappes
				if side > 0.0:
					st.add_index(a)
					st.add_index(a + 1)
					st.add_index(c)
					st.add_index(a + 1)
					st.add_index(c + 1)
					st.add_index(c)
				else:
					st.add_index(a)
					st.add_index(c)
					st.add_index(a + 1)
					st.add_index(a + 1)
					st.add_index(c)
					st.add_index(c + 1)
		base += (nu + 1) * (nv + 1)
	st.generate_normals()
	var m := st.commit()
	m.custom_aabb = AABB(center - Vector3(0.2, 0.15, 0.2), Vector3(0.4, 0.3, 0.4))
	return m


func _build_wound() -> void:
	var walls := MeshInstance3D.new()
	walls.name = "ParoiPlaie"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 56
	var levels := 8
	var base := 0
	for side in [-1.0, 1.0]:
		for j in levels + 1:
			for i in nu + 1:
				var u := -half_len - 0.004 + (2.0 * half_len + 0.008) * i / nu
				st.set_uv(Vector2(u, float(j) / levels))
				st.set_uv2(Vector2(side, 0.0))
				st.add_vertex(center)
		for j in levels:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var c := a + nu + 1
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(c)
				st.add_index(a + 1)
				st.add_index(c + 1)
				st.add_index(c)
		base += (nu + 1) * (levels + 1)
	var wm := st.commit()
	wm.custom_aabb = AABB(center - Vector3(0.2, 0.15, 0.2), Vector3(0.4, 0.3, 0.4))
	walls.mesh = wm
	wall_mat = ShaderMaterial.new()
	wall_mat.shader = preload("res://shaders/wound_wall.gdshader")
	for t in ["fat_albedo", "fat_normal", "muscle", "muscle_normal"]:
		wall_mat.set_shader_parameter(t, Tex.get_tex(t))
	wall_mat.set_shader_parameter("blood_tex", Tex.get_tex("blood"))
	wall_mat.set_shader_parameter("depth_m", WOUND_DEPTH)
	_common_params(wall_mat)
	walls.material_override = wall_mat
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)

	# Lumière d'appoint dans la plaie (le scialytique éclaire le fond en vrai)
	wound_light = OmniLight3D.new()
	wound_light.name = "LumierePlaie"
	wound_light.light_color = Color(1.0, 0.93, 0.86)
	wound_light.light_energy = 0.0
	wound_light.omni_range = 0.25
	wound_light.omni_attenuation = 1.2
	wound_light.light_specular = 0.4
	wound_light.position = center + Vector3.UP * 0.12
	add_child(wound_light)

	# Fond de la cavité : coque retournée, rose sombre humide
	var bowl := MeshInstance3D.new()
	bowl.name = "Cavite"
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 32
	sp.rings = 16
	sp.flip_faces = true
	bowl.mesh = sp
	bowl.material_override = _tissue(bowl_color, 0.15, 0.9)
	bowl.material_override.set_shader_parameter("clip_y", center.y - 0.012)
	bowl.basis = Basis(dir3 * bowl_radii.x, Vector3.UP * bowl_radii.y, perp3 * bowl_radii.z)
	bowl.position = center - Vector3.UP * bowl_radii.y
	bowl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bowl)


func _tissue(base: Color, inflamed := 0.0, vessels := 0.6, fibrin := 0.0, scale := 14.0) -> ShaderMaterial:
	return Tex.tissue(base, inflamed, vessels, fibrin, scale)


func _build_appendix_anatomy() -> void:
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
		"Ascending_colon": _tissue(Color(0.86, 0.6, 0.52), 0.15, 0.75, 0.0, 12.0),
		"Free_taenia": _tissue(Color(0.94, 0.86, 0.76), 0.0, 0.15, 0.0, 20.0),
		"Jejunum": _tissue(Color(0.9, 0.56, 0.5), 0.0, 0.8, 0.0, 16.0),
		"Meso-appendix": _tissue(Color(0.97, 0.8, 0.42), 0.3, 0.9, 0.0, 18.0),
		"Ileal_branch_of_ileocolic_artery": _tissue(Color(0.62, 0.06, 0.07), 0.0, 0.0),
		"Colic_branch_of_ileocolic_artery": _tissue(Color(0.62, 0.06, 0.07), 0.0, 0.0),
	}
	for mi in _meshes_in(anat):
		var key := String(mi.name)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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


# ---------------------------------------------------------------- Appendice (maillage réel, squelette)

## L'appendice est déformé par un petit squelette le long de sa ligne médiane : la carte graphique
## déforme les 5000 sommets, le processeur ne pose que 16 os par image.
func _init_appendix(src: MeshInstance3D) -> void:
	var arr := src.mesh.surface_get_arrays(0)
	var xf := src.global_transform
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var index: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	appendix_rest_tip = _anat_xf * ANAT_TIP
	appendix_tip = appendix_rest_tip
	var axis := appendix_rest_tip - appendix_base
	var alen := axis.length()
	var bins := 14
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	sums.resize(bins)
	counts.resize(bins)
	for i in bins:
		sums[i] = Vector3.ZERO
		counts[i] = 0
	var world := PackedVector3Array()
	var wnorm := PackedVector3Array()
	var svals := PackedFloat32Array()
	world.resize(verts.size())
	wnorm.resize(verts.size())
	svals.resize(verts.size())
	var nb := xf.basis.inverse().transposed()
	for i in verts.size():
		var w := xf * verts[i]
		world[i] = w
		wnorm[i] = (nb * norms[i]).normalized()
		var s := clampf((w - appendix_base).dot(axis) / (alen * alen), 0.0, 1.0)
		svals[i] = s
		var b := mini(int(s * bins), bins - 1)
		sums[b] += w
		counts[b] += 1
	_rest_line = PackedVector3Array([appendix_base])
	for i in bins:
		if counts[i] > 0:
			_rest_line.append(sums[i] / counts[i])
	_rest_line.append(appendix_rest_tip)
	_rest_frames = _frames(_rest_line)
	var nbones := _rest_line.size()
	appendix_skel = Skeleton3D.new()
	appendix_skel.name = "SqueletteAppendice"
	add_child(appendix_skel)
	_app_skin = Skin.new()
	for i in nbones:
		var rx := Transform3D(_rest_frames[i], _rest_line[i])
		appendix_skel.add_bone("b%d" % i)
		appendix_skel.set_bone_rest(i, rx)
		appendix_skel.set_bone_pose(i, rx)
		_app_skin.add_bind(i, rx.affine_inverse())
	# Poids : chaque sommet suit les deux os qui l'encadrent le long de l'appendice
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for i in verts.size():
		# Paramètre le long de la ligne au repos (les os sont aux points de la ligne)
		var f := _line_param(svals[i]) * (nbones - 1)
		var i0 := clampi(int(f), 0, nbones - 2)
		var k := clampf(f - i0, 0.0, 1.0)
		bones[i * 4] = i0
		bones[i * 4 + 1] = i0 + 1
		weights[i * 4] = 1.0 - k
		weights[i * 4 + 1] = k
	# Trois parties : moignon, tranche de section, partie retirée
	var parts := [PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
	for t in range(0, index.size(), 3):
		var a := index[t]
		var b := index[t + 1]
		var c := index[t + 2]
		var smax := maxf(svals[a], maxf(svals[b], svals[c]))
		var smin := minf(svals[a], minf(svals[b], svals[c]))
		var which := 0 if smax <= 0.30 else (2 if smin >= 0.33 else 1)
		parts[which].append_array([a, b, c])
	var full := ArrayMesh.new()
	_app_mesh_stump = ArrayMesh.new()
	_app_mesh_piece = ArrayMesh.new()
	for p in 3:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = world
		arrays[Mesh.ARRAY_NORMAL] = wnorm
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		arrays[Mesh.ARRAY_INDEX] = parts[p]
		if (parts[p] as PackedInt32Array).is_empty():
			continue
		full.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if p == 0:
			_app_mesh_stump.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		elif p == 2:
			_app_mesh_piece.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Appendice"
	mi.mesh = full
	mi.skin = _app_skin
	appendix_mat = _tissue(Color(0.78, 0.36, 0.3), 1.0, 1.0, 0.55, 22.0)
	appendix_mat.set_shader_parameter("clip_y", center.y - 0.008)
	mi.material_override = appendix_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	appendix_skel.add_child(mi)
	appendix_node = mi
	_update_appendix()


## Paramètre (0..1) le long des points de la ligne médiane pour une abscisse s le long de l'axe.
func _line_param(s: float) -> float:
	# Les points de la ligne sont la base, les centres des tranches (non vides) puis la pointe
	var n := _rest_line.size()
	var axis := appendix_rest_tip - appendix_base
	var alen2 := axis.length_squared()
	var prev := 0.0
	for i in range(1, n):
		var si := clampf((_rest_line[i] - appendix_base).dot(axis) / alen2, 0.0, 1.0)
		if s <= si:
			var k := (s - prev) / maxf(si - prev, 1e-5)
			return (i - 1 + clampf(k, 0.0, 1.0)) / float(n - 1)
		prev = si
	return 1.0


## Repères (tangente, normale, binormale) par transport parallèle le long d'une polyligne.
static func _frames(line: PackedVector3Array) -> Array[Basis]:
	var out: Array[Basis] = []
	var n := line.size()
	var nrm := (line[1] - line[0]).normalized().cross(Vector3.UP)
	if nrm.length() < 0.01:
		nrm = (line[1] - line[0]).normalized().cross(Vector3.RIGHT)
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


## Point interpolé au paramètre s (0..1) le long de la polyligne.
static func _point_at(line: PackedVector3Array, s: float) -> Vector3:
	var f := clampf(s, 0.0, 1.0) * (line.size() - 1)
	var i := clampi(int(f), 0, line.size() - 2)
	return line[i].lerp(line[i + 1], f - i)


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
	if _rest_line.is_empty():
		return center
	return _point_at(_current_line(), _line_param(t))


func set_appendix_tip(p: Vector3) -> void:
	var off := p - appendix_base
	if off.length() > 0.095:
		off = off.normalized() * 0.095
	appendix_tip = appendix_base + off
	_update_appendix()


func _update_appendix() -> void:
	if appendix_skel == null:
		return
	var line := _current_line()
	var frames := _frames(line)
	var lig := _line_param(0.18) * (line.size() - 1)
	for i in line.size():
		var b := frames[i]
		# La ligature étrangle la base
		var sq := appendix_squeeze * exp(-pow((i - lig) / 0.8, 2.0)) * 0.5
		if sq > 0.001:
			b = Basis(b.x * (1.0 - sq), b.y * (1.0 - sq), b.z)
		appendix_skel.set_bone_pose(i, Transform3D(b, line[i]))
	# Le méso suit la base, on l'efface quand l'appendice est extériorisé
	var moved := appendix_tip.distance_to(appendix_rest_tip) > 0.01
	if meso:
		meso.visible = not moved
	if appendix_mat:
		appendix_mat.set_shader_parameter("clip_y", 100.0 if moved else center.y - 0.008)


## Fil de ligature : boucle autour de la base, plus ou moins serrée (0 = lâche, 1 = nœud serré).
func set_ligature(tight: float) -> void:
	if ligature == null:
		ligature = MeshInstance3D.new()
		ligature.name = "Ligature"
		var tm := TorusMesh.new()
		tm.rings = 24
		tm.ring_segments = 8
		ligature.mesh = tm
		ligature.material_override = MeshUtil.mat(Color(0.92, 0.9, 0.82), 0.6)
		add_child(ligature)
	var tm2 := ligature.mesh as TorusMesh
	var r := lerpf(0.011, 0.0042, clampf(tight, 0.0, 1.0))
	tm2.inner_radius = r
	tm2.outer_radius = r + 0.0016
	appendix_squeeze = clampf((tight - 0.6) / 0.4, 0.0, 1.0)
	_update_appendix()
	var p := appendix_point(0.18)
	var tan := (appendix_point(0.22) - appendix_point(0.14)).normalized()
	var side := tan.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = tan.cross(Vector3.RIGHT).normalized()
	ligature.global_transform = Transform3D(Basis(side, tan, side.cross(tan)), p)


## Nœud définitif : boucle serrée et deux brins coupés.
func ligate() -> void:
	set_ligature(1.0)
	var p := appendix_point(0.18)
	var tan := (appendix_point(0.22) - appendix_point(0.14)).normalized()
	var side := tan.cross(Vector3.UP).normalized()
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
	# Copie figée du squelette pour la partie retirée
	var sk := Skeleton3D.new()
	piece.add_child(sk)
	sk.position = -origin
	for i in appendix_skel.get_bone_count():
		sk.add_bone("b%d" % i)
		sk.set_bone_rest(i, appendix_skel.get_bone_rest(i))
		sk.set_bone_pose(i, appendix_skel.get_bone_pose(i))
	var mi := MeshInstance3D.new()
	mi.mesh = _app_mesh_piece
	mi.skin = _app_skin
	mi.material_override = appendix_mat
	sk.add_child(mi)
	appendix_node.mesh = _app_mesh_stump
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
	return piece


# ---------------------------------------------------------------- Peau : badigeon, incision, plaie

## Peint l'antiseptique autour d'un point. Renvoie la couverture de la zone à préparer (0..1).
func paint_iodine(p: Vector3, radius := 0.02, strength := 1.0) -> float:
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
				var nv := minf(1.0, v + ((1.0 - d) * 0.35 + 0.12) * strength)
				iodine_img.set_pixel(i, j, Color(nv, nv, nv))
				if v <= 0.45 and nv > 0.45 and _iod_target[j * MASK_RES + i] == 1:
					_iod_done += 1
	_iod_dirty = true
	_iodine_wet = 1.0
	return iodine_coverage()


func iodine_coverage() -> float:
	return float(_iod_done) / maxf(1.0, _iod_total)


func fill_iodine() -> void:
	# Complète la zone (garde les traînées déjà peintes, plus foncées)
	for j in MASK_RES:
		for i in MASK_RES:
			var v := iodine_img.get_pixel(i, j).r
			var nv := maxf(v, 0.62)
			iodine_img.set_pixel(i, j, Color(nv, nv, nv))
	_iod_done = _iod_total
	_iod_dirty = true


func incision_point(t: float) -> Vector3:
	var p := INC_A.lerp(INC_B, t)
	return Vector3(p.x, body_height(p.x, p.y) + breath_offset(p.x, p.y), p.y)


## Paramètre t (0..1) du point de l'incision le plus proche de p, et distance horizontale.
func incision_project(p: Vector3) -> Vector2:
	var a := Vector2(INC_A.x, INC_A.y)
	var ab := INC_B - INC_A
	var q := Vector2(p.x, p.z)
	var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(t, (a + ab * t).distance_to(q))


## Coordonnées (u le long de l'incision depuis le milieu, v en travers) d'un point.
func uv_of(p: Vector3) -> Vector2:
	var q := Vector3(p.x - center.x, 0.0, p.z - center.z)
	return Vector2(q.dot(dir3), q.dot(perp3))


func has_cut() -> bool:
	return cut0 <= cut1


## Prolonge l'incision jusqu'au paramètre t.
func extend_cut(t: float) -> void:
	if cut0 > cut1:
		cut0 = t
		cut1 = t
	cut0 = minf(cut0, t)
	cut1 = maxf(cut1, t)


func set_incision_progress(v: float) -> void:
	cut0 = 0.0 if v > 0.0 else 1.0
	cut1 = v if v > 0.0 else 0.0
	if v >= 0.999:
		bleed0 = 0.0
		bleed1 = 1.0


func get_incision_progress() -> float:
	return maxf(0.0, cut1 - cut0)


func gap_profile(u: float) -> float:
	if cut1 <= cut0:
		return 0.0
	var u0 := (cut0 - 0.5) * 2.0 * half_len
	var u1 := (cut1 - 0.5) * 2.0 * half_len
	var hl := (u1 - u0) * 0.5 + 0.003
	var k := (u - (u0 + u1) * 0.5) / hl
	return sqrt(maxf(0.0, 1.0 - k * k))


## Écart du bord `side` au point u (même formule que wound_common.gdshaderinc).
func edge_open(u: float, side: float) -> float:
	var o := open_l if side < 0.0 else open_r
	var shape := 1.0 + 0.07 * sin(u * 90.0 + side * 1.3) + 0.04 * sin(u * 210.0 + 2.1)
	return maxf(o, 0.0) * wound_w * gap_profile(u) * shape


## Point du bord de la plaie (sur la peau) à l'abscisse u.
func edge_point(u: float, side: float, outward := 0.0) -> Vector3:
	var d := edge_open(u, side) + outward
	var p := center + dir3 * u + perp3 * side * d
	return Vector3(p.x, body_height(p.x, p.z) + breath_offset(p.x, p.z), p.z)


## Profondeur autorisée sous la peau en p si p est dans la plaie ouverte (0 sinon).
func hole_depth(p: Vector3) -> float:
	var q := uv_of(p)
	var side := -1.0 if q.y < 0.0 else 1.0
	var d := edge_open(q.x, side)
	if d > 0.0015 and absf(q.y) < d * 0.92:
		return minf(WOUND_DEPTH + 0.015, hole_limit)
	return 0.0


func in_window(x: float, z: float) -> bool:
	return x > WINDOW_MIN.x and x < WINDOW_MAX.x and z > WINDOW_MIN.y and z < WINDOW_MAX.y


## Ouverture des deux bords (lecture : la plus grande ; écriture : immédiate, sans ressort).
func set_opening(v: float) -> void:
	rest_open = v
	open_l = v
	open_r = v
	_vel_l = 0.0
	_vel_r = 0.0


func get_opening() -> float:
	return maxf(open_l, open_r)


## Peau enfoncée par l'instrument de la main `slot` (profondeur 0 = rien).
func set_press(slot: int, p: Vector3, depth: float, radius := 0.011) -> void:
	_press[slot] = Vector4(p.x, p.z, radius, clampf(depth, 0.0, 0.006))
	_press_set[slot] = true


func set_bleb(p: Vector3, radius: float, height: float) -> void:
	bleb = Vector4(p.x, p.z, radius, height)


## Amplitude de la respiration visible sur les champs (détresse = plus ample).
func set_breathe(v: float) -> void:
	breathe_amp = v
	if drape_mat:
		drape_mat.set_shader_parameter("breathe", v)


## Zone du thorax qui se soulève en respirant (même formule que les shaders).
static func chest_mask(x: float, z: float) -> float:
	return (1.0 - smoothstep(-0.25, -0.05, x)) * smoothstep(-0.7, -0.5, x) * (1.0 - smoothstep(0.12, 0.3, absf(z)))


## Hauteur ajoutée en ce moment : respiration et gonflement d'un abcès.
func breath_offset(x: float, z: float) -> float:
	var h := breathe_amp * breath_b * chest_mask(x, z)
	if abscess.w > 0.0:
		var d := Vector2(x - abscess.x, z - abscess.y).length() / abscess.z
		if d < 1.0:
			h += abscess.w * (1.0 - d * d) * (1.0 - d * d)
	return h


## Point de la peau qui suit la respiration.
func live(p: Vector3) -> Vector3:
	return p + Vector3.UP * breath_offset(p.x, p.z)


## Point posé sur la peau (relief, respiration, abcès compris) à la verticale de p.
func on_skin(p: Vector3) -> Vector3:
	return Vector3(p.x, body_height(p.x, p.z) + breath_offset(p.x, p.z), p.z)


func set_stitched(v: float) -> void:
	for m in [skin_mat, zone_mat]:
		m.set_shader_parameter("stitched", v)


static func _spring(x: float, v: float, target: float, k: float, zeta: float, dt: float) -> Vector2:
	var c := 2.0 * sqrt(k) * zeta
	var h := dt * 0.5
	for i in 2:
		v += (k * (target - x) - c * v) * h
		x += v * h
	return Vector2(x, v)


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_breath_t += delta * breath_rate / 60.0
	breath_b = 0.5 - 0.5 * cos(TAU * _breath_t)
	if drape_mat:
		drape_mat.set_shader_parameter("breath_b", breath_b)
	# Bords de la plaie : ressorts (suivent l'instrument qui tire, se détendent quand on lâche)
	var tl := maxf(rest_open, maxf(held_l, drive_l))
	var tr := maxf(rest_open, maxf(held_r, drive_r))
	var sl := _spring(open_l, _vel_l, tl, 520.0 if drive_l >= 0.0 else 170.0, 0.85 if drive_l >= 0.0 else 0.32, dt)
	var sr := _spring(open_r, _vel_r, tr, 520.0 if drive_r >= 0.0 else 170.0, 0.85 if drive_r >= 0.0 else 0.32, dt)
	open_l = clampf(sl.x, 0.0, 1.35)
	_vel_l = sl.y
	open_r = clampf(sr.x, 0.0, 1.35)
	_vel_r = sr.y
	drive_l = -1.0
	drive_r = -1.0
	# Le sang perle derrière la lame avec un temps de retard
	if cut1 > cut0:
		if bleed1 < bleed0:
			bleed0 = cut0
			bleed1 = cut0
		bleed0 = move_toward(bleed0, cut0, dt * 0.2)
		bleed1 = move_toward(bleed1, cut1, dt * 0.2)
	if _iod_dirty:
		iodine_tex.update(iodine_img)
		_iod_dirty = false
	# La bétadine sèche doucement : elle devient plus mate
	if _iodine_wet > 0.0:
		_iodine_wet = maxf(0.0, _iodine_wet - delta / 60.0)
	if wound_light:
		wound_light.light_energy = clampf(opening, 0.0, 1.0) * 0.02
	for i in 2:
		if not _press_set[i]:
			_press[i] = Vector4.ZERO
		_press_set[i] = false
	for m in _all_mats():
		m.set_shader_parameter("open_lr", Vector2(open_l, open_r))
		m.set_shader_parameter("cut", Vector2(cut0, cut1))
		m.set_shader_parameter("press_a", _press[0])
		m.set_shader_parameter("press_b", _press[1])
		m.set_shader_parameter("bleb", bleb)
		m.set_shader_parameter("breath_now", breathe_amp * breath_b)
		m.set_shader_parameter("abscess", abscess)
	for m in [skin_mat, zone_mat]:
		m.set_shader_parameter("bleed", Vector2(bleed0, bleed1))
		m.set_shader_parameter("iodine_wet", _iodine_wet)
		m.set_shader_parameter("bleb_pale", bleb_pale)
		m.set_shader_parameter("abscess_red", abscess_red)
		m.set_shader_parameter("show_guide", 0.0 if cut0 <= 0.01 and cut1 >= 0.99 else 1.0)


## Repère d'un écarteur posé dans la plaie (side = -1 ou +1 de part et d'autre de l'incision).
func retractor_slot(side: float) -> Vector3:
	var e := edge_point(0.0, side, -0.0025)
	return e - Vector3.UP * 0.006


## Points d'entrée et de sortie de l'aiguille pour un point de suture à l'abscisse t.
func stitch_pair(t: float, bite := 0.005) -> Array:
	var u := (t - 0.5) * 2.0 * half_len
	return [edge_point(u, -1.0, bite), edge_point(u, 1.0, bite)]


func add_stitch(t: float) -> void:
	add_stitch_at(incision_point(t), perp3)


## Point séparé : fil bleu en travers de `across`, nœud sur le côté.
func add_stitch_at(p0: Vector3, across: Vector3, length := 0.016) -> void:
	var p := p0 + Vector3.UP * 0.0012
	var acr := across.normalized()
	var along := acr.cross(Vector3.UP).normalized()
	var knot := Node3D.new()
	add_child(knot)
	knot.global_position = p
	var thread := MeshUtil.mat(Color(0.12, 0.16, 0.45), 0.4)
	var bar := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0007
	cm.bottom_radius = 0.0007
	cm.height = length
	bar.mesh = cm
	bar.material_override = thread
	knot.add_child(bar)
	bar.global_basis = Basis.looking_at(acr, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	var ball := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.0018
	bs.height = 0.0036
	ball.mesh = bs
	ball.material_override = thread
	ball.position = acr * length * 0.38 + Vector3.UP * 0.0008
	knot.add_child(ball)
	for sgn in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0004
		em.bottom_radius = 0.0004
		em.height = 0.007
		e.mesh = em
		e.material_override = thread
		e.position = acr * length * 0.56 + along * 0.0025 * sgn + Vector3.UP * 0.001
		e.rotation = Vector3(0.4 * sgn, 0.3, 1.3)
		knot.add_child(e)
	# Le nœud se serre : petite animation d'apparition
	knot.scale = Vector3(1.3, 1.3, 1.3)
	var tw := knot.create_tween()
	tw.tween_property(knot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stitches.append(knot)
