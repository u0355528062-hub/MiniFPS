class_name Patient
extends Node3D
## Karim, 31 ans, accident de moto : pneumothorax droit compressif. Couché sur le côté gauche
## (décubitus latéral), bras droit levé au-dessus de la tête : le flanc droit regarde le plafond.
## Tête vers +X, pieds vers -X, ventre vers +Z (côté du joueur). Site du drain : X = Z = 0.
##
## Anatomie réelle (atlas Z-Anatomy, CC BY-SA 4.0) : peau, côtes, cartilages, sternum, vertèbres,
## muscles du thorax, intercostaux, plèvre, poumons, cœur, gros vaisseaux, nerfs, diaphragme, foie.
## Les tissus internes n'apparaissent que dans la plaie (ou en vue anatomique) ; la pince de Kelly
## y creuse un vrai trajet. La peau du champ opératoire reprend le moteur de plaie physique
## (badigeon, bouton d'anesthésie, incision, bords qui s'écartent, points de suture).

const TABLE_TOP := 0.80
const MASK_RES := 128
const HMAP_RES := 160
## Table d'opération (le dessus) : X, Z
const TABLE_MIN := Vector2(-1.41, -0.30)
const TABLE_MAX := Vector2(0.69, 0.30)
## Repères anatomiques (mesurés sur l'atlas, repère du jeu)
const RIB6_TOP := -0.001  ## bord supérieur de la 6e côte (X) sur la ligne axillaire moyenne
const RIB5_BOTTOM := 0.013  ## bord inférieur de la 5e côte
const RIB_DIR := Vector2(-0.49, 0.87)  ## direction des côtes (X, Z) au site : vers l'avant et le bas
const HILUM := Vector3(0.03, 1.165, -0.01)  ## hile du poumon droit (le poumon s'affaisse vers lui)
const HEART_C := Vector3(0.015, 1.12, 0.03)
const HIDDEN_IN_SKELETON := ["Muscles", "Plevre", "Intercostaux"]  ## masqués en vue squelette

# ---- Cartes de hauteur (peau et champ), précalculées dans Blender (grille de 2,5 mm)
static var _skin_h := PackedFloat32Array()
static var _drape_h := PackedFloat32Array()
static var _nx := 0
static var _nz := 0
static var _x0 := 0.0
static var _z0 := 0.0
static var _step := 0.0025

# ---- Réglages du champ opératoire (fixés par l'opération avant build())
var INC_A := Vector2(-0.006, -0.012)
var INC_B := Vector2(-0.018, 0.012)
var PATCH_MIN := Vector2(-0.12, -0.12)  ## zone de peau détaillée (badigeon, relief)
var PATCH_SIZE := Vector2(0.24, 0.24)
var WINDOW_MIN := Vector2(-0.085, -0.08)  ## fenêtre du champ stérile
var WINDOW_MAX := Vector2(0.085, 0.08)
var WOUND_DEPTH := 0.013  ## peau + graisse sous-cutanée (les muscles réels sont dessous)
var wound_w := 0.006
var paint_r := Vector2(0.06, 0.055)
var breathe_amp := 0.009
var breath_rate := 30.0
var breath_b := 0.0
var _breath_t := 0.0
var hole_limit := 0.006
var skin_y := 1.29  ## hauteur de la peau au centre de l'incision

var skin_mat: ShaderMaterial  ## peau du corps entier
var zone_mat: ShaderMaterial  ## zone fendue de l'incision
var wall_mat: ShaderMaterial
var ghost_mat: ShaderMaterial
var drape_mat: ShaderMaterial
var iodine_img: Image
var iodine_tex: ImageTexture
var height_tex: ImageTexture
var zone_u := 0.04
var zone_v := 0.03

var dir3: Vector3
var perp3: Vector3
var center: Vector3
var half_len := 0.0125

# ---- Plaie physique
var open_l := 0.0
var open_r := 0.0
var _vel_l := 0.0
var _vel_r := 0.0
var rest_open := 0.0
var held_l := -1.0
var held_r := -1.0
var drive_l := -1.0
var drive_r := -1.0
var cut0 := 1.0
var cut1 := 0.0
var bleed0 := 1.0
var bleed1 := 0.0
var opening: float: set = set_opening, get = get_opening
var incision_progress: float: set = set_incision_progress, get = get_incision_progress
var _press := [Vector4.ZERO, Vector4.ZERO]
var _press_set := [false, false]
var bleb := Vector4.ZERO
var bleb_pale := 0.0

# ---- Badigeon
var _iodine_wet := 1.0
var _iod_target := PackedByteArray()
var _iod_total := 0
var _iod_done := 0
var _iod_dirty := false

# ---- Anatomie
var body: Node3D
var skin_mesh: MeshInstance3D
var zone_mesh: MeshInstance3D
var walls: MeshInstance3D
var drape: Node3D
var anatomy_mats: Array[ShaderMaterial] = []
var _mats_by_part := {}  ## nom du maillage -> matériaux
var _part_meshes := {}  ## nom du maillage -> MeshInstance3D
var _part_boxes := {}  ## nom du maillage -> boîte englobante (monde), avec marge
var lung_collapse := 0.85  ## poumon droit affaissé (pneumothorax), 0 = ré-expansé
var _lung_target := 0.85
var view_mode := 0  ## 0 normal, 1 muscles (peau fantôme), 2 squelette et organes
var _view_k := 0.0
## Trajet de dissection (pince de Kelly) : de l'entrée sous la peau jusqu'à la profondeur atteinte
var tract_a := Vector3.ZERO
var tract_dir := Vector3.DOWN
var tract_depth := 0.0
var tract_r := 0.0
var pleura_open := false
var heart_rate := 128.0
var _beat_t := 0.0
var stitches: Array[Node3D] = []
var wound_light: OmniLight3D
var props: PatientProps


# ---------------------------------------------------------------- Cartes de hauteur

static func load_maps() -> void:
	if _nx > 0:
		return
	_skin_h = _read_map("res://assets/data/peau_hauteur.bin")
	_drape_h = _read_map("res://assets/data/champ_hauteur.bin")


static func _read_map(path: String) -> PackedFloat32Array:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 24:
		push_error("Carte de hauteur manquante : " + path)
		return PackedFloat32Array()
	_nx = bytes.decode_s32(0)
	_nz = bytes.decode_s32(4)
	_x0 = bytes.decode_float(8)
	_z0 = bytes.decode_float(12)
	_step = bytes.decode_float(16)
	return bytes.slice(24).to_float32_array()


## Valeur interpolée d'une carte ; -1 hors de tout objet.
static func _sample(arr: PackedFloat32Array, x: float, z: float) -> float:
	if arr.is_empty():
		return -1.0
	var fx := (x - _x0) / _step
	var fz := (z - _z0) / _step
	if fx < 0.0 or fz < 0.0 or fx > _nx - 1.001 or fz > _nz - 1.001:
		return -1.0
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var k := j * _nx + i
	var a := arr[k]
	var b := arr[k + 1]
	var c := arr[k + _nx]
	var d := arr[k + _nx + 1]
	if a < 0.0 or b < 0.0 or c < 0.0 or d < 0.0:
		# Bord de la silhouette : pas d'interpolation avec le vide
		return maxf(maxf(a, b), maxf(c, d))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func on_table(x: float, z: float) -> bool:
	return x > TABLE_MIN.x and x < TABLE_MAX.x and z > TABLE_MIN.y and z < TABLE_MAX.y


## Hauteur de la peau au point (x, z), ou du matelas hors du corps.
static func body_height(x: float, z: float) -> float:
	var h := _sample(_skin_h, x, z)
	if h > 0.0:
		return h
	return TABLE_TOP if on_table(x, z) else -1.0


## Dessus du champ stérile (-1 là où il n'y a pas de champ).
static func drape_height(x: float, z: float) -> float:
	return _sample(_drape_h, x, z)


## Surface solide la plus haute (peau ou champ posé dessus).
static func top_height(x: float, z: float) -> float:
	return maxf(body_height(x, z), drape_height(x, z))


## Normale de la peau (dessus) au point (x, z).
static func skin_normal(x: float, z: float) -> Vector3:
	var e := 0.004
	var hx := (body_height(x + e, z) - body_height(x - e, z)) / (2.0 * e)
	var hz := (body_height(x, z + e) - body_height(x, z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


# ---------------------------------------------------------------- Construction

func build() -> void:
	load_maps()
	var a := Vector3(INC_A.x, 0, INC_A.y)
	var b := Vector3(INC_B.x, 0, INC_B.y)
	dir3 = (b - a).normalized()
	perp3 = dir3.cross(Vector3.UP).normalized()
	var c2 := (INC_A + INC_B) * 0.5
	skin_y = body_height(c2.x, c2.y)
	center = Vector3(c2.x, skin_y, c2.y)
	half_len = INC_A.distance_to(INC_B) * 0.5
	_build_skin_patch()
	_build_body()
	_build_wound()
	_build_drape()
	props = PatientProps.new()
	props.name = "Equipement"
	add_child(props)
	props.build()
	set_opening(0.0)


func _tex(t: String) -> Texture2D:
	return Tex.get_tex(t)


func _build_skin_patch() -> void:
	iodine_img = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_L8)
	iodine_img.fill(Color.BLACK)
	iodine_tex = ImageTexture.create_from_image(iodine_img)
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
	var hmap := Image.create(HMAP_RES, HMAP_RES, false, Image.FORMAT_RF)
	for j in HMAP_RES:
		for i in HMAP_RES:
			var x := PATCH_MIN.x + float(i) / (HMAP_RES - 1) * PATCH_SIZE.x
			var z := PATCH_MIN.y + float(j) / (HMAP_RES - 1) * PATCH_SIZE.y
			hmap.set_pixel(i, j, Color(body_height(x, z), 0, 0))
	height_tex = ImageTexture.create_from_image(hmap)
	zone_u = half_len + 0.022
	zone_v = clampf(wound_w * 4.0, 0.02, 0.05)
	skin_mat = _skin_material(preload("res://shaders/body_skin.gdshader"))
	zone_mat = _skin_material(preload("res://shaders/skin_field.gdshader"))
	zone_mesh = MeshInstance3D.new()
	zone_mesh.name = "PeauIncision"
	zone_mesh.mesh = _zone_mesh()
	zone_mesh.material_override = zone_mat
	add_child(zone_mesh)
	ghost_mat = ShaderMaterial.new()
	ghost_mat.shader = preload("res://shaders/skin_ghost.gdshader")


func _skin_material(sh: Shader) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("iodine_mask", iodine_tex)
	m.set_shader_parameter("win_min", WINDOW_MIN)
	m.set_shader_parameter("win_max", WINDOW_MAX)
	m.set_shader_parameter("zone_u", zone_u)
	m.set_shader_parameter("skin_albedo", _tex("skin_albedo"))
	m.set_shader_parameter("skin_normal", _tex("skin_normal"))
	m.set_shader_parameter("skin_rough", _tex("skin_rough"))
	m.set_shader_parameter("blood_tex", _tex("blood"))
	m.set_shader_parameter("mottle", _tex("tissue_mottle"))
	_common_params(m)
	return m


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


## Zone de l'incision : deux nappes (une par bord) jointes le long du trait.
func _zone_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 72
	var nv := 22
	var base := 0
	for side in [-1.0, 1.0]:
		for j in nv + 1:
			var v: float = side * (zone_v + 0.0012) * pow(float(j) / nv, 1.6)
			for i in nu + 1:
				var u := -(zone_u + 0.0012) + 2.0 * (zone_u + 0.0012) * i / nu
				var p := center + dir3 * u + perp3 * v
				st.set_uv(Vector2(u, v))
				st.set_uv2(Vector2(side, 0.0))
				st.add_vertex(Vector3(p.x, body_height(p.x, p.z), p.z))
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var c := a + nu + 1
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
	m.custom_aabb = AABB(center - Vector3(0.15, 0.12, 0.15), Vector3(0.3, 0.24, 0.3))
	return m


## Corps réel : peau + anatomie, matériaux du jeu.
func _build_body() -> void:
	var scene: PackedScene = load("res://assets/models/patient.glb")
	body = scene.instantiate()
	body.name = "Corps"
	add_child(body)
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		var part := String(m3.name)
		if part == "Peau":
			skin_mesh = m3
			m3.material_override = skin_mat
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			continue
		var mats: Array[ShaderMaterial] = []
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i)
			var kind := src.resource_name.trim_prefix("G_") if src else "Tissue"
			var mat := _anatomy_material(part, kind)
			m3.set_surface_override_material(i, mat)
			mats.append(mat)
			anatomy_mats.append(mat)
		_mats_by_part[part] = mats
		_part_meshes[part] = m3
		_part_boxes[part] = (m3.global_transform * m3.get_aabb()).grow(0.015)
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m3.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		m3.visible = false


func _anatomy_material(part: String, kind: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/anatomy.gdshader")
	m.set_shader_parameter("detail", _tex("tissue_mottle"))
	m.set_shader_parameter("detail_normal", _tex("tissue_normal"))
	m.set_shader_parameter("fibers", _tex("muscle"))
	m.set_shader_parameter("fibers_normal", _tex("muscle_normal"))
	m.set_shader_parameter("vessels", _tex("vessels"))
	var p := {}
	match kind:
		"Bone":
			p = {"base": Color(0.86, 0.80, 0.68), "alt": Color(0.78, 0.66, 0.52), "rough": 0.5, "wet": 0.25, "sss": 0.15, "scale": 45.0, "cut": Color(0.75, 0.55, 0.45), "cuttable": 0.0}
		"Cartilage":
			p = {"base": Color(0.80, 0.84, 0.86), "alt": Color(0.70, 0.76, 0.82), "rough": 0.25, "wet": 0.6, "sss": 0.55, "scale": 40.0, "cuttable": 0.0}
		"Muscle":
			p = {"base": Color(0.46, 0.07, 0.06), "alt": Color(0.62, 0.13, 0.11), "rough": 0.36, "wet": 0.55, "sss": 0.4, "fiber": 1.0, "scale": 35.0, "cut": Color(0.40, 0.04, 0.04)}
		"Tendon":
			p = {"base": Color(0.86, 0.84, 0.78), "alt": Color(0.74, 0.72, 0.68), "rough": 0.22, "wet": 0.55, "sss": 0.25, "fiber": 0.6, "scale": 50.0}
		"Lung":
			p = {"base": Color(0.84, 0.48, 0.48), "alt": Color(0.66, 0.30, 0.34), "rough": 0.18, "wet": 0.95, "sss": 0.55, "spots": 1.0, "scale": 30.0, "cuttable": 0.0, "vessel": 0.25}
		"Pleura":
			p = {"base": Color(0.90, 0.72, 0.68), "alt": Color(0.82, 0.62, 0.60), "rough": 0.12, "wet": 1.0, "sss": 0.5, "scale": 40.0, "vessel": 0.4, "cut": Color(0.6, 0.15, 0.14)}
		"Heart":
			p = {"base": Color(0.45, 0.08, 0.07), "alt": Color(0.86, 0.70, 0.36), "rough": 0.24, "wet": 0.9, "sss": 0.4, "fiber": 0.35, "scale": 30.0, "cuttable": 0.0, "fat": 1.0}
		"Artery":
			p = {"base": Color(0.62, 0.07, 0.06), "alt": Color(0.75, 0.15, 0.12), "rough": 0.22, "wet": 0.8, "sss": 0.4, "scale": 60.0, "cuttable": 0.0}
		"PulmArtery":
			p = {"base": Color(0.22, 0.16, 0.42), "alt": Color(0.30, 0.22, 0.52), "rough": 0.22, "wet": 0.8, "sss": 0.4, "scale": 60.0, "cuttable": 0.0}
		"Vein":
			p = {"base": Color(0.16, 0.13, 0.38), "alt": Color(0.24, 0.18, 0.46), "rough": 0.22, "wet": 0.8, "sss": 0.4, "scale": 60.0, "cuttable": 0.0}
		"PulmVein":
			p = {"base": Color(0.62, 0.07, 0.06), "alt": Color(0.75, 0.15, 0.12), "rough": 0.22, "wet": 0.8, "sss": 0.4, "scale": 60.0, "cuttable": 0.0}
		"Nerve":
			p = {"base": Color(0.92, 0.86, 0.58), "alt": Color(0.80, 0.74, 0.48), "rough": 0.3, "wet": 0.6, "sss": 0.4, "fiber": 0.5, "scale": 80.0, "cuttable": 0.0}
		"Liver":
			p = {"base": Color(0.38, 0.09, 0.07), "alt": Color(0.48, 0.14, 0.10), "rough": 0.2, "wet": 0.9, "sss": 0.3, "scale": 25.0, "cuttable": 0.0}
		"Mucosa":
			p = {"base": Color(0.88, 0.78, 0.72), "alt": Color(0.80, 0.66, 0.62), "rough": 0.3, "wet": 0.7, "sss": 0.4, "scale": 40.0, "cuttable": 0.0}
		"Fat":
			p = {"base": Color(0.92, 0.78, 0.42), "alt": Color(0.84, 0.66, 0.30), "rough": 0.3, "wet": 0.7, "sss": 0.6, "scale": 40.0, "cuttable": 0.0}
		_:
			p = {"base": Color(0.7, 0.3, 0.28), "alt": Color(0.6, 0.25, 0.22), "rough": 0.35, "wet": 0.6, "sss": 0.3, "scale": 30.0}
	m.set_shader_parameter("base_color", p["base"])
	m.set_shader_parameter("alt_color", p["alt"])
	m.set_shader_parameter("rough", p["rough"])
	m.set_shader_parameter("wetness", p["wet"])
	m.set_shader_parameter("sss", p["sss"])
	m.set_shader_parameter("tex_scale", p["scale"])
	m.set_shader_parameter("fiber", p.get("fiber", 0.0))
	m.set_shader_parameter("spots", p.get("spots", 0.0))
	m.set_shader_parameter("vessel_amount", p.get("vessel", 0.0))
	m.set_shader_parameter("fat_grooves", p.get("fat", 0.0))
	m.set_shader_parameter("cut_color", p.get("cut", Color(0.45, 0.06, 0.05)))
	m.set_shader_parameter("cuttable", p.get("cuttable", 1.0))
	m.set_shader_parameter("is_pleura", 1.0 if part == "Plevre" else 0.0)
	if part == "PoumonD":
		m.set_shader_parameter("hilum", HILUM)
	if part == "Coeur":
		m.set_shader_parameter("beat_c", HEART_C)
	return m


func _build_wound() -> void:
	walls = MeshInstance3D.new()
	walls.name = "ParoiPlaie"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 48
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
	wm.custom_aabb = AABB(center - Vector3(0.15, 0.12, 0.15), Vector3(0.3, 0.24, 0.3))
	walls.mesh = wm
	wall_mat = ShaderMaterial.new()
	wall_mat.shader = preload("res://shaders/wound_wall.gdshader")
	for t in ["fat_albedo", "fat_normal", "muscle", "muscle_normal"]:
		wall_mat.set_shader_parameter(t, _tex(t))
	wall_mat.set_shader_parameter("blood_tex", _tex("blood"))
	wall_mat.set_shader_parameter("depth_m", WOUND_DEPTH)
	_common_params(wall_mat)
	walls.material_override = wall_mat
	walls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(walls)

	wound_light = OmniLight3D.new()
	wound_light.name = "LumierePlaie"
	wound_light.light_color = Color(1.0, 0.93, 0.86)
	wound_light.light_energy = 0.0
	wound_light.omni_range = 0.12
	wound_light.omni_attenuation = 1.4
	wound_light.light_specular = 0.3
	wound_light.position = center + Vector3.UP * 0.06
	add_child(wound_light)


## Champ stérile simulé (tissu tombé sur le patient), fenêtre collée autour du site.
func _build_drape() -> void:
	var scene: PackedScene = load("res://assets/models/champ.glb")
	drape = scene.instantiate()
	drape.name = "Champs"
	add_child(drape)
	drape_mat = Tex.drape(Color(0.17, 0.42, 0.53), WINDOW_MIN, WINDOW_MAX, breathe_amp)
	drape_mat.set_shader_parameter("height_map", height_tex)
	drape_mat.set_shader_parameter("patch_min", PATCH_MIN)
	drape_mat.set_shader_parameter("patch_size", PATCH_SIZE)
	for mi in drape.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = drape_mat


# ---------------------------------------------------------------- Vue anatomique

## 0 : normale  ·  1 : peau fantôme, muscles visibles  ·  2 : squelette, poumons, cœur
func set_view_mode(m: int) -> void:
	view_mode = clampi(m, 0, 2)
	var normal := view_mode == 0
	skin_mesh.material_override = skin_mat if normal else ghost_mat
	zone_mesh.visible = normal
	walls.visible = normal
	drape.visible = normal
	for st in stitches:
		st.visible = normal
	for part in _mats_by_part:
		var show := 1.0
		if view_mode == 2 and part in HIDDEN_IN_SKELETON:
			show = -1.0  # caché
		elif normal:
			show = 0.0  # seulement dans la plaie
		for mat in _mats_by_part[part]:
			mat.set_shader_parameter("show_all", show)


# ---------------------------------------------------------------- Peau : badigeon, incision, plaie

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
	for j in MASK_RES:
		for i in MASK_RES:
			var x := PATCH_MIN.x + (i + 0.5) / MASK_RES * PATCH_SIZE.x
			var z := PATCH_MIN.y + (j + 0.5) / MASK_RES * PATCH_SIZE.y
			var q := Vector2(x - center.x, z - center.z)
			var e := (q.x * q.x) / (paint_r.x * paint_r.x) + (q.y * q.y) / (paint_r.y * paint_r.y)
			if e > 1.25:
				continue
			var v := iodine_img.get_pixel(i, j).r
			var nv := maxf(v, 0.62 * (1.0 - smoothstep(1.0, 1.25, e)))
			iodine_img.set_pixel(i, j, Color(nv, nv, nv))
	_iod_done = _iod_total
	_iod_dirty = true


func incision_point(t: float) -> Vector3:
	var p := INC_A.lerp(INC_B, t)
	return Vector3(p.x, body_height(p.x, p.y) + breath_offset(p.x, p.y), p.y)


func incision_project(p: Vector3) -> Vector2:
	var a := Vector2(INC_A.x, INC_A.y)
	var ab := INC_B - INC_A
	var q := Vector2(p.x, p.z)
	var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return Vector2(t, (a + ab * t).distance_to(q))


func uv_of(p: Vector3) -> Vector2:
	var q := Vector3(p.x - center.x, 0.0, p.z - center.z)
	return Vector2(q.dot(dir3), q.dot(perp3))


func has_cut() -> bool:
	return cut0 <= cut1


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


func edge_open(u: float, side: float) -> float:
	var o := open_l if side < 0.0 else open_r
	var shape := 1.0 + 0.07 * sin(u * 90.0 + side * 1.3) + 0.04 * sin(u * 210.0 + 2.1)
	return maxf(o, 0.0) * wound_w * gap_profile(u) * shape


func edge_point(u: float, side: float, outward := 0.0) -> Vector3:
	var d := edge_open(u, side) + outward
	var p := center + dir3 * u + perp3 * side * d
	return Vector3(p.x, body_height(p.x, p.z) + breath_offset(p.x, p.z), p.z)


## Profondeur autorisée sous la peau en p si p est dans la plaie ouverte (0 sinon).
func hole_depth(p: Vector3) -> float:
	var q := uv_of(p)
	var side := -1.0 if q.y < 0.0 else 1.0
	var d := edge_open(q.x, side)
	if d > 0.0012 and absf(q.y) < d * 0.92:
		return minf(WOUND_DEPTH + 0.06, hole_limit)
	return 0.0


func in_window(x: float, z: float) -> bool:
	return x > WINDOW_MIN.x and x < WINDOW_MAX.x and z > WINDOW_MIN.y and z < WINDOW_MAX.y


func set_opening(v: float) -> void:
	rest_open = v
	open_l = v
	open_r = v
	_vel_l = 0.0
	_vel_r = 0.0


func get_opening() -> float:
	return maxf(open_l, open_r)


func set_press(slot: int, p: Vector3, depth: float, radius := 0.009) -> void:
	_press[slot] = Vector4(p.x, p.z, radius, clampf(depth, 0.0, 0.005))
	_press_set[slot] = true


func set_bleb(p: Vector3, radius: float, height: float) -> void:
	bleb = Vector4(p.x, p.z, radius, height)


func set_breathe(v: float) -> void:
	breathe_amp = v
	if props:
		props.breath_rate = breath_rate
	if drape_mat:
		drape_mat.set_shader_parameter("breathe", v)


## Zone du thorax qui se soulève en respirant (même formule que les shaders).
static func chest_mask(x: float, z: float) -> float:
	return smoothstep(-0.34, -0.16, x) * (1.0 - smoothstep(0.08, 0.2, x)) * (1.0 - smoothstep(0.1, 0.2, absf(z)))


func breath_offset(x: float, z: float) -> float:
	return breathe_amp * breath_b * chest_mask(x, z)


func live(p: Vector3) -> Vector3:
	return p + Vector3.UP * breath_offset(p.x, p.z)


func on_skin(p: Vector3) -> Vector3:
	return Vector3(p.x, body_height(p.x, p.z) + breath_offset(p.x, p.z), p.z)


func set_stitched(v: float) -> void:
	for m in [skin_mat, zone_mat]:
		m.set_shader_parameter("stitched", v)


## Trajet creusé par la pince : de l'entrée (sous la peau) le long de `dir`, jusqu'à `depth`.
func set_tract(entry: Vector3, dir: Vector3, depth: float, radius: float) -> void:
	tract_a = entry
	tract_dir = dir.normalized()
	tract_depth = depth
	tract_r = radius


## Le poumon droit se regonfle (drain en place) : animation sur quelques secondes.
func reexpand_lung() -> void:
	_lung_target = 0.0


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
	var tl := maxf(rest_open, maxf(held_l, drive_l))
	var tr := maxf(rest_open, maxf(held_r, drive_r))
	var sl := _spring(open_l, _vel_l, tl, 520.0 if drive_l >= 0.0 else 170.0, 0.85 if drive_l >= 0.0 else 0.32, dt)
	var sr := _spring(open_r, _vel_r, tr, 520.0 if drive_r >= 0.0 else 170.0, 0.85 if drive_r >= 0.0 else 0.32, dt)
	open_l = clampf(sl.x, 0.0, 1.6)
	_vel_l = sl.y
	open_r = clampf(sr.x, 0.0, 1.6)
	_vel_r = sr.y
	drive_l = -1.0
	drive_r = -1.0
	if cut1 > cut0:
		if bleed1 < bleed0:
			bleed0 = cut0
			bleed1 = cut0
		bleed0 = move_toward(bleed0, cut0, dt * 0.2)
		bleed1 = move_toward(bleed1, cut1, dt * 0.2)
	if _iod_dirty:
		iodine_tex.update(iodine_img)
		_iod_dirty = false
	if _iodine_wet > 0.0:
		_iodine_wet = maxf(0.0, _iodine_wet - delta / 60.0)
	if wound_light:
		wound_light.light_energy = clampf(opening, 0.0, 1.0) * 0.05
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
	for m in [skin_mat, zone_mat]:
		m.set_shader_parameter("bleed", Vector2(bleed0, bleed1))
		m.set_shader_parameter("iodine_wet", _iodine_wet)
		m.set_shader_parameter("bleb_pale", bleb_pale)
		m.set_shader_parameter("show_guide", 0.0 if cut0 <= 0.01 and cut1 >= 0.99 else 1.0)
	# Anatomie : poumon (affaissé, puis regonflé), cœur qui bat, trajet de dissection
	lung_collapse = move_toward(lung_collapse, _lung_target, delta * 0.18)
	_beat_t += delta * heart_rate / 60.0
	var beat := pow(maxf(0.0, sin(TAU * _beat_t)), 6.0) * 0.035
	# La plaie révèle ce qui est dessous : rayon selon l'ouverture et le trajet creusé
	var reveal := clampf(opening * wound_w * 1.6 + tract_r * 2.0, 0.0, 0.035) if has_cut() else 0.0
	var tb := tract_a + tract_dir * tract_depth
	skin_mat.set_shader_parameter("reveal_c", center + Vector3.UP * 0.004)
	skin_mat.set_shader_parameter("reveal_axis", -skin_normal(center.x, center.z))
	skin_mat.set_shader_parameter("reveal_r", reveal)
	for m in anatomy_mats:
		m.set_shader_parameter("reveal_c", center + Vector3.UP * 0.004)
		m.set_shader_parameter("reveal_axis", -skin_normal(center.x, center.z))
		m.set_shader_parameter("reveal_r", reveal)
		m.set_shader_parameter("tract_a", tract_a)
		m.set_shader_parameter("tract_b", tb)
		m.set_shader_parameter("tract_r", tract_r)
		m.set_shader_parameter("pleura_open", 1.0 if pleura_open else 0.0)
		m.set_shader_parameter("collapse", lung_collapse)
		m.set_shader_parameter("breath", breath_b * (1.0 - lung_collapse * 0.8))
		m.set_shader_parameter("beat", beat)
	_cull_anatomy(center + Vector3.UP * 0.004, -skin_normal(center.x, center.z), reveal)


## Les organes que rien ne montre ne sont pas dessinés : aucun avant l'incision, puis ceux que
## traverse le cylindre sous la plaie, ou tous (sauf les masqués) en vue anatomique.
func _cull_anatomy(c: Vector3, axis: Vector3, reveal: float) -> void:
	for part in _part_meshes:
		var show := true
		if view_mode == 2 and part in HIDDEN_IN_SKELETON:
			show = false
		elif view_mode == 0:
			show = reveal > 0.0 and _cylinder_hits(_part_boxes[part], c, axis, reveal)
		var mi: MeshInstance3D = _part_meshes[part]
		if mi.visible != show:
			mi.visible = show


## Le cylindre de la plaie (rayon r, sur 45 cm de profondeur) touche-t-il la boîte ?
static func _cylinder_hits(box: AABB, c: Vector3, axis: Vector3, r: float) -> bool:
	var grown := box.grow(r + 0.006)
	for i in 46:
		if grown.has_point(c + axis * (i * 0.01)):
			return true
	return false


# ---------------------------------------------------------------- Points de suture

func retractor_slot(side: float) -> Vector3:
	var e := edge_point(0.0, side, -0.0025)
	return e - Vector3.UP * 0.006


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
	knot.scale = Vector3(1.3, 1.3, 1.3)
	var tw := knot.create_tween()
	tw.tween_property(knot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stitches.append(knot)
