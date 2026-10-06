class_name Patient
extends Node3D
## Le patient, dans l'une des deux positions (voir POSES) :
##  - « lateral » : couché sur le côté gauche, bras droit levé au-dessus de la tête (drain) ; tête
##    vers +X, ventre vers +Z (côté du joueur), site du drain en X = Z = 0 ;
##  - « dos » : couché sur le dos, bras le long du corps ; tête vers +X, face antérieure vers le
##    haut, côté gauche du patient vers +Z (côté du joueur), milieu du sternum en X = Z = 0.
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
const HIDDEN_IN_SKELETON := ["Muscles", "Plevre", "Intercostaux", "Pericarde"]
## Tissus de la paroi thoracique (coupés et écartés dans l'ouverture d'une thoracotomie)
const WALL_PARTS := ["Muscles", "Intercostaux", "Plevre", "Mammaires", "Nerfs", "Arteres", "Veines"]  ## ouverts par la thoracotomie
## Repoussés par l'écarteur de thoracotomie (paroi et squelette)
const SPREAD_PARTS := ["Muscles", "Intercostaux", "Plevre", "Mammaires", "Nerfs", "Arteres", "Veines", "Os", "CoteG5", "CoteG6"]

## Positions du patient : modèle, cartes de hauteur, repères mesurés sur l'atlas, zone du thorax qui
## se soulève (chest_x : montée et descente le long du corps, chest_z : demi-largeur, chest_h :
## hauteur au-dessus de la table), poumon affaissé et son hile, centre du cœur.
const POSES := {
	"lateral": {"glb": "res://assets/models/patient.glb", "skin_map": "res://assets/data/peau_hauteur.bin",
		"drape_glb": "res://assets/models/champ.glb", "drape_map": "res://assets/data/champ_hauteur.bin",
		"landmarks": "", "chest_x": Vector4(-0.34, -0.16, 0.08, 0.2), "chest_z": Vector2(0.1, 0.2),
		"chest_h": Vector2(0.10, 0.30), "collapse": "PoumonD", "hilum": Vector3(0.03, 1.165, -0.01),
		"heart": Vector3(0.015, 1.12, 0.03),
		# Repère de l'atlas (visage, cheveux) : x = -y + 1.14006, y = -z - 0.004, z = x + 1.275
		"atlas": [Vector4(0, -1, 0, 1.14006), Vector4(0, 0, -1, -0.004), Vector4(1, 0, 0, 1.275)]},
	"dos": {"glb": "res://assets/models/patient_dos.glb", "skin_map": "res://assets/data/peau_dos_hauteur.bin",
		"drape_glb": "res://assets/models/drap_dos.glb", "drape_map": "res://assets/data/drap_dos_hauteur.bin",
		"landmarks": "res://assets/data/patient_dos.json", "ribs": "res://assets/data/cotes_dos.bin",
		"chest_x": Vector4(-0.36, -0.2, 0.08, 0.2),
		"chest_z": Vector2(0.1, 0.2), "chest_h": Vector2(0.06, 0.16), "collapse": "PoumonG",
		"hilum": Vector3(0.03, 0.95, 0.06), "heart": Vector3(-0.03, 0.95, 0.03),
		"atlas": [Vector4(0, 0, 1, 0), Vector4(0, -1, 0, 0.95031), Vector4(1, 0, 0, 1.29927)]},
}
static var pose_id := "lateral"
static var _maps_pose := ""
static var HILUM := Vector3(0.03, 1.165, -0.01)  ## hile du poumon affaissé (il s'affaisse vers lui)
static var HEART_C := Vector3(0.015, 1.12, 0.03)
static var collapse_part := "PoumonD"
static var CHEST_X := Vector4(-0.34, -0.16, 0.08, 0.2)
static var CHEST_Z := Vector2(0.1, 0.2)
static var CHEST_H := Vector2(0.10, 0.30)
## Repères anatomiques de la position (sternum, côtes, vaisseaux…), en coordonnées du jeu
static var landmarks := {}
## Carte des côtes (patient sur le dos) : côte ou espace intercostal sous chaque point du thorax, et
## profondeur peau -> plèvre perpendiculairement à la peau (grille de 2,5 mm, calculée dans Blender)
static var _rib_codes := PackedByteArray()
static var _rib_depth := PackedFloat32Array()
static var _rib_grid := [0, 0, 0.0, 0.0, 0.0025]

# ---- Cartes de hauteur (peau et champ), précalculées dans Blender (grille de 2,5 mm)
static var _skin_h := PackedFloat32Array()
static var _drape_h := PackedFloat32Array()
static var _drape_src := ""  ## carte de hauteur des champs chargée
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
var paint_c := Vector2.INF  ## centre de la zone à badigeonner (INF : centre de l'incision)
var breathe_amp := 0.009
var breath_rate := 30.0
var breath_b := 0.0
var _breath_t := 0.0
var hole_limit := 0.006
var belt := Vector4.ZERO  ## marque de la ceinture de sécurité (segment x0 z0 x1 z1), nulle = aucune
var antiseptic := "betadine"  ## "betadine" (brune) ou "chlorhexidine" (alcoolique colorée, rose orangé)
var stab := Vector4.ZERO  ## plaie au couteau (x, z, angle, longueur), nulle = aucune
var props_options := {}  ## équipement du patient (ex. {"collar": false})
var zone_v_min := 0.0  ## largeur minimale de la zone de peau détaillée (grandes ouvertures)
var wall_taper := 0.72  ## parois de la plaie en V (0 = droites : écarteur posé)
var spread_extra: Array = []  ## autres structures repoussées par l'écarteur (poumons d'une sternotomie)
## Champs propres à l'opération (pontage : grand drap collé autour d'une fenêtre sur le sternum et
## champ de tête jeté sur l'arceau) : "glb", "map" ; vide = champs habituels de la position
var drape_override := {}
var extra_drape: Node3D  ## champ fenêtré posé en cours d'intervention (caché jusque-là)
var _extra_mat: ShaderMaterial
var _extra_map := ""
var _extra_win := [Vector2.ZERO, Vector2.ZERO]
var _extra_shown := false
var _extra_edge := 0.0  ## bord du champ ajouté côté tête (x)
## Thoracotomie : brèche le long de l'espace intercostal (points de la peau, part de l'écartement
## en chaque point), portion coupée t0..t1, demi-largeur coupée, écartement au milieu, profondeur
var ap_path := PackedVector3Array()
var ap_h := PackedFloat32Array()
var ap_t0 := 0.0
var ap_t1 := 0.0
var ap_w0 := 0.0
var ap_spread := 0.0
var ap_depth := 0.045
var ap_fall := Vector2(0.014, 0.085)
var ap_deep := Vector2(0.045, 0.075)
var ap_side := Vector2.ONE
var ap_lift := Vector2.ZERO
var _ap_slopes := PackedVector2Array()
const LIFT_FALL := Vector2(0.03, 0.11)  ## soulèvement d'un bord : s'estompe entre ces distances


## Écarteur à mammaire : soulève le bord gauche (lift.x) ou droit (lift.y) de l'incision, peau et
## paroi ensemble (la brèche doit être définie : set_aperture).
func set_edge_lift(lift: Vector2) -> void:
	ap_lift = lift
	for m in anatomy_mats:
		m.set_shader_parameter("ap_lift", lift)
	for m in [zone_mat, wall_mat, skin_mat]:
		if m:
			m.set_shader_parameter("lift_lr", lift)
var heart_squeeze := 0.0
var beat_gain := 1.0  ## force des battements du cœur (0 : arrêt)
var beat_now := 0.0  ## dilatation du cœur à cet instant (le shader la reçoit aussi)
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
var props: Node3D  ## PatientProps (sur le côté) ou PatientPropsDos (sur le dos)


# ---------------------------------------------------------------- Cartes de hauteur

static func load_maps() -> void:
	if _maps_pose == pose_id:
		return
	_maps_pose = pose_id
	var P: Dictionary = POSES[pose_id]
	_skin_h = _read_map(P["skin_map"])
	_drape_src = ""
	use_drape_map(P["drape_map"])
	CHEST_X = P["chest_x"]
	CHEST_Z = P["chest_z"]
	CHEST_H = P["chest_h"]
	collapse_part = P["collapse"]
	HILUM = P["hilum"]
	HEART_C = P["heart"]
	landmarks = {}
	_load_ribs(P.get("ribs", ""))
	if P["landmarks"] != "":
		var txt := FileAccess.get_file_as_string(P["landmarks"])
		var data: Variant = JSON.parse_string(txt)
		if data is Dictionary:
			landmarks = data
			if landmarks.has("heart_center"):
				HEART_C = lm("heart_center")
			if landmarks.has("hilum_L"):
				HILUM = lm("hilum_L")
		else:
			push_error("Repères illisibles : " + P["landmarks"])


static func _load_ribs(path: String) -> void:
	_rib_codes = PackedByteArray()
	_rib_depth = PackedFloat32Array()
	if path == "" or not FileAccess.file_exists(path):
		return
	var bytes := FileAccess.get_file_as_bytes(path)
	var nx := bytes.decode_s32(0)
	var nz := bytes.decode_s32(4)
	_rib_grid = [nx, nz, bytes.decode_float(8), bytes.decode_float(12), bytes.decode_float(16)]
	_rib_codes = bytes.slice(24, 24 + nx * nz)
	_rib_depth = bytes.slice(24 + nx * nz, 24 + nx * nz * 5).to_float32_array()


static func _rib_index(x: float, z: float) -> int:
	if _rib_codes.is_empty():
		return -1
	var i := int(round((x - _rib_grid[2]) / _rib_grid[4]))
	var j := int(round((z - _rib_grid[3]) / _rib_grid[4]))
	if i < 0 or j < 0 or i >= _rib_grid[0] or j >= _rib_grid[1]:
		return -1
	return j * int(_rib_grid[0]) + i


## Sous le point (x, z) de la peau : n > 0 = sur la n-ième côte, -n = dans le n-ième espace
## intercostal (entre les côtes n et n+1), 0 = hors du gril costal (ou inconnu).
static func rib_code(x: float, z: float) -> int:
	var k := _rib_index(x, z)
	if k < 0:
		return 0
	var v := _rib_codes[k]
	return v - 256 if v > 127 else v


## Profondeur de la plèvre pariétale sous le point (perpendiculairement à la peau), -1 si inconnue.
static func pleura_depth(x: float, z: float) -> float:
	var k := _rib_index(x, z)
	if k < 0:
		return -1.0
	return _rib_depth[k]


## Repère anatomique (point) de la position courante.
static func lm(key: String) -> Vector3:
	var a: Array = landmarks.get(key, [0.0, 0.0, 0.0])
	return Vector3(a[0], a[1], a[2])


## Ligne centrale d'un vaisseau (points) de la position courante.
static func lm_line(key: String) -> PackedVector3Array:
	var out := PackedVector3Array()
	var d: Dictionary = landmarks.get(key, {})
	for a in d.get("points", []):
		out.append(Vector3(a[0], a[1], a[2]))
	return out


## Charge la carte de hauteur des champs (même grille que celle de la peau).
static func use_drape_map(path: String) -> void:
	if path == _drape_src:
		return
	_drape_src = path
	_drape_h = _read_map(path) if ResourceLoader.exists(path) or FileAccess.file_exists(path) else PackedFloat32Array()


## Ouvre la fenêtre dans la carte des champs : la peau y redevient la surface solide.
static func cut_drape_window(wmin: Vector2, wmax: Vector2) -> void:
	if _drape_h.is_empty():
		return
	_drape_src += "#fenetre"  # la carte en mémoire n'est plus celle du fichier
	var i0 := maxi(0, int(ceil((wmin.x - _x0) / _step)))
	var i1 := mini(_nx - 1, int(floor((wmax.x - _x0) / _step)))
	var j0 := maxi(0, int(ceil((wmin.y - _z0) / _step)))
	var j1 := mini(_nz - 1, int(floor((wmax.y - _z0) / _step)))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			_drape_h[j * _nx + i] = -1.0


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
	use_drape_map(drape_override.get("map", POSES[pose_id]["drape_map"]))
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
	props = PatientProps.new() if pose_id == "lateral" else PatientPropsDos.new()
	props.name = "Equipement"
	props.set("options", props_options)
	add_child(props)
	props.build()
	Cable.save_cache()
	set_opening(0.0)


func _tex(t: String) -> Texture2D:
	return Tex.get_tex(t)


func _build_skin_patch() -> void:
	iodine_img = Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_L8)
	iodine_img.fill(Color.BLACK)
	iodine_tex = ImageTexture.create_from_image(iodine_img)
	_compute_paint_target()
	var hmap := Image.create(HMAP_RES, HMAP_RES, false, Image.FORMAT_RF)
	for j in HMAP_RES:
		for i in HMAP_RES:
			var x := PATCH_MIN.x + float(i) / (HMAP_RES - 1) * PATCH_SIZE.x
			var z := PATCH_MIN.y + float(j) / (HMAP_RES - 1) * PATCH_SIZE.y
			hmap.set_pixel(i, j, Color(body_height(x, z), 0, 0))
	height_tex = ImageTexture.create_from_image(hmap)
	zone_u = half_len + 0.022
	zone_v = maxf(clampf(wound_w * 4.0, 0.02, 0.05), zone_v_min)
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
	m.set_shader_parameter("frame_on", 1.0 if windowed_drape() else 0.0)
	m.set_shader_parameter("belt", belt)
	m.set_shader_parameter("stab", stab)
	if antiseptic == "chlorhexidine":
		m.set_shader_parameter("anti_thin", Vector3(0.62, 0.2, 0.15))
		m.set_shader_parameter("anti_thick", Vector3(0.48, 0.07, 0.06))
		m.set_shader_parameter("anti_ring", Vector3(0.4, 0.05, 0.045))
	var at: Array = POSES[pose_id]["atlas"]
	m.set_shader_parameter("atlas_rx", at[0])
	m.set_shader_parameter("atlas_ry", at[1])
	m.set_shader_parameter("atlas_rz", at[2])
	m.set_shader_parameter("zone_u", zone_u)
	m.set_shader_parameter("skin_albedo", _tex("skin_albedo"))
	m.set_shader_parameter("skin_normal", _tex("skin_normal"))
	m.set_shader_parameter("skin_rough", _tex("skin_rough"))
	m.set_shader_parameter("blood_tex", _tex("blood"))
	m.set_shader_parameter("mottle", _tex("tissue_mottle"))
	_common_params(m)
	return m


func _common_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("chest_x", CHEST_X)
	m.set_shader_parameter("chest_z", CHEST_Z)
	m.set_shader_parameter("chest_h", CHEST_H)
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
	var scene: PackedScene = load(POSES[pose_id]["glb"])
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
			p = {"base": Color(0.45, 0.08, 0.07), "alt": Color(0.86, 0.70, 0.36), "rough": 0.24, "wet": 0.9, "sss": 0.4, "fiber": 0.35, "scale": 30.0, "cuttable": 0.0, "fat": 0.75, "alt_mix": 0.15}
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
		"Pericardium":
			p = {"base": Color(0.88, 0.82, 0.72), "alt": Color(0.92, 0.80, 0.50), "rough": 0.2, "wet": 0.9, "sss": 0.45, "fat": 0.6, "scale": 35.0, "vessel": 0.3, "cut": Color(0.55, 0.12, 0.1)}
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
	m.set_shader_parameter("alt_mix", p.get("alt_mix", 1.0))
	m.set_shader_parameter("cut_color", p.get("cut", Color(0.45, 0.06, 0.05)))
	m.set_shader_parameter("cuttable", p.get("cuttable", 1.0))
	m.set_shader_parameter("is_pleura", 1.0 if part == "Plevre" else 0.0)
	# Paroi du thorax : écartée dans l'ouverture d'une thoracotomie
	# Brèche de thoracotomie : la paroi est ouverte (2 : plus profond, rien ne pend en travers)
	var wall := 0.0
	if part in ["Nerfs", "Arteres", "Veines", "Mammaires", "Os"]:
		wall = 2.0
	elif part in WALL_PARTS:
		wall = 1.0
	m.set_shader_parameter("wall_tissue", wall)
	m.set_shader_parameter("spreadable", 1.0 if part in SPREAD_PARTS or part in spread_extra else 0.0)
	if OS.get_cmdline_user_args().has("--debugparts"):
		# Diagnostic : chaque structure d'une couleur franche, tranches (faces arrière) en cyan
		var pal := {"Os": Color(1, 1, 1), "CoteG5": Color(1, 1, 0), "CoteG6": Color(1, 0.5, 0), "Muscles": Color(0.8, 0, 0),
			"Intercostaux": Color(1, 0, 1), "Plevre": Color(0, 1, 0), "PoumonG": Color(0.3, 0.6, 1), "PoumonD": Color(0.2, 0.3, 1),
			"Coeur": Color(0.5, 0, 0.1), "Pericarde": Color(0.6, 0.2, 1), "Nerfs": Color(1, 1, 0), "Diaphragme": Color(0.4, 0.3, 0.1),
			"Arteres": Color(1, 0.3, 0.3), "Veines": Color(0, 0, 1), "Coronaires": Color(1, 0.6, 0), "Mammaires": Color(0, 0.5, 0),
			"VeinesCentrales": Color(0, 0.8, 0.8), "ArteresSC": Color(0.6, 0, 0), "Aorte": Color(0.9, 0, 0.5), "ArteresPulm": Color(0.3, 0, 0.6),
			"Trachee": Color(0.6, 0.6, 0.6), "Foie": Color(0.3, 0.15, 0.05)}
		var c: Color = pal.get(part, Color(0.5, 0.5, 0.5))
		m.set_shader_parameter("base_color", c)
		m.set_shader_parameter("alt_color", c)
		m.set_shader_parameter("cut_color", Color(0, 1, 1))
	if part == collapse_part:
		m.set_shader_parameter("hilum", HILUM)
	if part in ["Coeur", "Coronaires", "Pericarde"]:
		m.set_shader_parameter("beat_c", HEART_C)
	if part == "Coeur" and landmarks.has("lad") and landmarks.has("heart_apex"):
		# Graisse épicardique dans les sillons : le long de l'IVA et autour de la base des ventricules
		var lp: Array = landmarks["lad"].get("points", [])
		var arr := PackedVector4Array()
		var n := mini(12, lp.size())
		for k in n:
			var q: Array = lp[int(round(float(k) / maxf(n - 1, 1) * (lp.size() - 1)))]
			arr.append(Vector4(q[0], q[1], q[2], 0.0))
		m.set_shader_parameter("fat_lad", arr)
		m.set_shader_parameter("fat_lad_n", n)
		var apex := lm("heart_apex")
		var hc := lm("heart_center") if landmarks.has("heart_center") else HEART_C
		var axis := (apex - hc).normalized()
		var base := hc - axis * 0.015
		m.set_shader_parameter("fat_av", Vector4(axis.x, axis.y, axis.z, axis.dot(base)))
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
	wall_mat.set_shader_parameter("taper", wall_taper)
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


## Champs fenêtrés (collés autour de la fenêtre WINDOW_MIN..WINDOW_MAX) ?
func windowed_drape() -> bool:
	return pose_id == "lateral" or not drape_override.is_empty()


## Champ stérile simulé (tissu tombé sur le patient), fenêtre collée autour du site ; sur le dos,
## drap qui couvre le bas du corps (pas de champ : urgence), ou champs propres à l'opération.
func _build_drape() -> void:
	var path: String = drape_override.get("glb", POSES[pose_id]["drape_glb"])
	if not ResourceLoader.exists(path):
		return
	var scene: PackedScene = load(path)
	drape = scene.instantiate()
	drape.name = "Champs"
	add_child(drape)
	if windowed_drape():
		drape_mat = _drape_material(Color(0.17, 0.42, 0.53), WINDOW_MIN, WINDOW_MAX)
	else:
		drape_mat = _drape_material(Color(0.80, 0.84, 0.86), Vector2.ZERO, Vector2.ZERO)
	var head_mat: ShaderMaterial = null
	for mi in drape.find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial = drape_mat
		if String(mi.name).begins_with("ChampTete"):
			# Champ de tête : pend de l'arceau (rien de collé, ne bouge pas avec la respiration)
			if head_mat == null:
				head_mat = drape_mat.duplicate()
				head_mat.set_shader_parameter("has_window", 0.0)
				head_mat.set_shader_parameter("breathe", 0.0)
			m = head_mat
		(mi as MeshInstance3D).material_override = m


func _drape_material(color: Color, win_min: Vector2, win_max: Vector2) -> ShaderMaterial:
	var m := Tex.drape(color, win_min, win_max, breathe_amp)
	m.set_shader_parameter("chest_x", CHEST_X)
	m.set_shader_parameter("chest_z", CHEST_Z)
	m.set_shader_parameter("chest_h", CHEST_H)
	m.set_shader_parameter("height_map", height_tex)
	m.set_shader_parameter("patch_min", PATCH_MIN)
	m.set_shader_parameter("patch_size", PATCH_SIZE)
	# Hauteur de la peau de tout le corps : le bord adhésif colle le drap à plat autour de la fenêtre
	var img := Image.create_from_data(_nx, _nz, false, Image.FORMAT_RF, _skin_h.to_byte_array())
	m.set_shader_parameter("body_map", ImageTexture.create_from_image(img))
	m.set_shader_parameter("body_min", Vector2(_x0, _z0))
	m.set_shader_parameter("body_cells", Vector3(_nx, _nz, _step))
	return m


## Champ fenêtré posé en cours d'intervention (voie centrale : après la désinfection, comme au bloc).
## Construit caché ; reveal_extra_drape() le fait tomber sur le patient et la fenêtre devient la
## seule peau accessible.
func add_extra_drape(glb: String, map: String, win_min: Vector2, win_max: Vector2, head_edge: float) -> void:
	if not ResourceLoader.exists(glb):
		return
	extra_drape = (load(glb) as PackedScene).instantiate()
	extra_drape.name = "ChampFenetre"
	extra_drape.visible = false
	add_child(extra_drape)
	_extra_mat = _drape_material(Color(0.17, 0.42, 0.53), win_min, win_max)
	for mi in extra_drape.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = _extra_mat
	_extra_map = map
	_extra_win = [win_min, win_max]
	_extra_edge = head_edge


## shift : décalage de la fenêtre (le point de ponction marqué n'est pas toujours au même endroit) ;
## le bord adhésif est recollé autour de la nouvelle fenêtre par le shader du champ.
func reveal_extra_drape(instant: bool, shift := Vector2.ZERO) -> void:
	if extra_drape == null or _extra_shown:
		return
	extra_drape.visible = view_mode == 0
	_extra_shown = true
	WINDOW_MIN = _extra_win[0] + shift
	WINDOW_MAX = _extra_win[1] + shift
	_extra_mat.set_shader_parameter("window_min", WINDOW_MIN)
	_extra_mat.set_shader_parameter("window_max", WINDOW_MAX)
	for m in [skin_mat, zone_mat]:
		if m:
			m.set_shader_parameter("win_min", WINDOW_MIN)
			m.set_shader_parameter("win_max", WINDOW_MAX)
			m.set_shader_parameter("frame_on", 1.0)
	use_drape_map(_extra_map)
	cut_drape_window(WINDOW_MIN, WINDOW_MAX)
	if props and props.has_method("hide_under_drape"):
		props.hide_under_drape(_extra_edge)
	if not instant:
		# Le champ tombe sur le patient
		extra_drape.position.y = 0.14
		var tw := create_tween()
		tw.tween_property(extra_drape, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# ---------------------------------------------------------------- Vue anatomique

## 0 : normale  ·  1 : peau fantôme, muscles visibles  ·  2 : squelette, poumons, cœur
func set_view_mode(m: int) -> void:
	view_mode = clampi(m, 0, 2)
	var normal := view_mode == 0
	skin_mesh.material_override = skin_mat if normal else ghost_mat
	zone_mesh.visible = normal
	walls.visible = normal
	if drape:
		drape.visible = normal
	if extra_drape:
		extra_drape.visible = normal and _extra_shown
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


## Humidité du badigeon (1 : vient d'être passé, brillant ; 0 : sec).
func set_iodine_wet(v: float) -> void:
	_iodine_wet = v


func iodine_coverage() -> float:
	return float(_iod_done) / maxf(1.0, _iod_total)


func _paint_center() -> Vector2:
	return paint_c if paint_c != Vector2.INF else Vector2(center.x, center.z)


## Zone à badigeonner : ellipse de demi-axes paint_r autour du centre choisi.
func _compute_paint_target() -> void:
	var pc := _paint_center()
	_iod_target.resize(MASK_RES * MASK_RES)
	_iod_total = 0
	_iod_done = 0
	for j in MASK_RES:
		for i in MASK_RES:
			var x := PATCH_MIN.x + (i + 0.5) / MASK_RES * PATCH_SIZE.x
			var z := PATCH_MIN.y + (j + 0.5) / MASK_RES * PATCH_SIZE.y
			var q := Vector2(x - pc.x, z - pc.y)
			var inside := (q.x * q.x) / (paint_r.x * paint_r.x) + (q.y * q.y) / (paint_r.y * paint_r.y) <= 1.0
			_iod_target[j * MASK_RES + i] = 1 if inside else 0
			if inside:
				_iod_total += 1
				if iodine_img and iodine_img.get_pixel(i, j).r > 0.45:
					_iod_done += 1


## Déplace la zone à badigeonner (autour du point marqué, par exemple).
func set_paint_center(c: Vector2) -> void:
	paint_c = c
	_compute_paint_target()


func fill_iodine() -> void:
	var pc := _paint_center()
	for j in MASK_RES:
		for i in MASK_RES:
			var x := PATCH_MIN.x + (i + 0.5) / MASK_RES * PATCH_SIZE.x
			var z := PATCH_MIN.y + (j + 0.5) / MASK_RES * PATCH_SIZE.y
			var q := Vector2(x - pc.x, z - pc.y)
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
	if _extra_mat:
		_extra_mat.set_shader_parameter("breathe", v)


## Zone du thorax qui se soulève en respirant (même formule que les shaders).
static func chest_mask(x: float, z: float) -> float:
	return smoothstep(CHEST_X.x, CHEST_X.y, x) * (1.0 - smoothstep(CHEST_X.z, CHEST_X.w, x)) * (1.0 - smoothstep(CHEST_Z.x, CHEST_Z.y, absf(z)))


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


## État de départ du poumon (0 = bien gonflé, 0,85 = pneumothorax), sans transition.
func init_lung(v: float) -> void:
	lung_collapse = v
	_lung_target = v


## Affaissement visé du poumon (0 = regonflé) : il y va progressivement.
func set_lung_target(v: float) -> void:
	_lung_target = clampf(v, 0.0, 1.0)


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
	if _extra_mat and _extra_shown:
		_extra_mat.set_shader_parameter("breath_b", breath_b)
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
	var beat := pow(maxf(0.0, sin(TAU * _beat_t)), 6.0) * 0.035 * beat_gain
	beat_now = beat
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
			show = (reveal > 0.0 and _cylinder_hits(_part_boxes[part], c, axis, reveal)) or _aperture_hits(_part_boxes[part])
		var mi: MeshInstance3D = _part_meshes[part]
		if mi.visible != show:
			mi.visible = show


## La brèche de la thoracotomie (et ce qui est dessous, sur 20 cm) touche-t-elle la boîte ?
func _aperture_hits(box: AABB) -> bool:
	if ap_path.size() < 2 or ap_t1 <= ap_t0:
		return false
	var grown := box.grow(aperture_gap(0.5) * 1.2 + 0.05)
	for i in 13:
		var p := aperture_point(lerpf(ap_t0, ap_t1, i / 12.0))
		for k in 21:
			if grown.has_point(p + Vector3.DOWN * (k * 0.01)):
				return true
	return false


## Thoracotomie : brèche le long du tracé `path` (points de la peau), `h` = part de l'écartement en
## chaque point (0 aux bouts), coupée de t0 à t1, demi-largeur coupée w0, écartement `spread`.
func set_aperture(path: PackedVector3Array, h: PackedFloat32Array, t0: float, t1: float, w0: float, spread: float, depth := 0.045,
		fall := Vector2(0.014, 0.085), deep := Vector2(0.045, 0.075), side := Vector2.ONE, lift := Vector2.ZERO, wall_vis := 0.0) -> void:
	ap_path = path
	ap_h = h
	ap_t0 = t0
	ap_t1 = t1
	ap_w0 = w0
	ap_spread = spread
	ap_depth = depth
	ap_fall = fall
	ap_deep = deep
	ap_side = side
	ap_lift = lift
	var n := mini(path.size(), 10)
	var pts := PackedVector4Array()
	pts.resize(10)
	var slopes := PackedVector2Array()
	slopes.resize(10)
	var e := 0.01
	for i in n:
		pts[i] = Vector4(path[i].x, path[i].y, path[i].z, h[i])
		var x := path[i].x
		var z := path[i].z
		slopes[i] = Vector2((body_height(x + e, z) - body_height(x - e, z)) / (2.0 * e), (body_height(x, z + e) - body_height(x, z - e)) / (2.0 * e))
	_ap_slopes = slopes
	for m in anatomy_mats:
		m.set_shader_parameter("ap_pts", pts)
		m.set_shader_parameter("ap_slope", slopes)
		m.set_shader_parameter("ap_n", n)
		m.set_shader_parameter("ap_t0", t0)
		m.set_shader_parameter("ap_t1", t1)
		m.set_shader_parameter("ap_w0", w0)
		m.set_shader_parameter("ap_spread", spread)
		m.set_shader_parameter("ap_depth", depth)
		m.set_shader_parameter("ap_fall", fall)
		m.set_shader_parameter("ap_deep", deep)
		m.set_shader_parameter("ap_side", side)
		m.set_shader_parameter("ap_lift", lift)
		m.set_shader_parameter("ap_wall_vis", wall_vis)
	# La paroi repoussée sort de la boîte de ses maillages : marge de visibilité
	for part in SPREAD_PARTS + spread_extra:
		var mi: MeshInstance3D = _part_meshes.get(part)
		if mi:
			mi.extra_cull_margin = 0.06 if spread > 0.0 else 0.0


## Où se trouve, la paroi écartée, le point p de la paroi au repos (même calcul que le shader).
func breach_displace(p: Vector3) -> Vector3:
	if ap_path.size() < 2 or (ap_spread <= 0.0 and ap_lift == Vector2.ZERO):
		return p
	var best := INF
	var rx := 0.0
	var ry := 0.0
	var rw := 0.0
	var dir := Vector2.ZERO
	var slope := Vector2.ZERO
	for k in mini(ap_path.size(), 10) - 1:
		var a := ap_path[k]
		var b := ap_path[k + 1]
		var ab := Vector2(b.x - a.x, b.z - a.z)
		var av := Vector2(p.x - a.x, p.z - a.z)
		var t := clampf(av.dot(ab) / maxf(ab.length_squared(), 1e-10), 0.0, 1.0)
		var d := (av - ab * t).length()
		if d < best:
			best = d
			var sgn := 1.0 if ab.y * av.x - ab.x * av.y >= 0.0 else -1.0
			dir = Vector2(ab.y, -ab.x).normalized() * sgn
			slope = _ap_slopes[k].lerp(_ap_slopes[k + 1], t) if _ap_slopes.size() > k + 1 else Vector2.ZERO
			rx = d * sgn
			ry = lerpf(a.y, b.y, t) - p.y
			rw = lerpf(ap_h[k], ap_h[k + 1], t)
	var dw := (1.0 - smoothstep(ap_deep.x, ap_deep.y, ry)) * smoothstep(-0.03, -0.01, ry)
	var w := rw * (1.0 - smoothstep(ap_fall.x, ap_fall.y, absf(rx))) * dw
	var wl := rw * (1.0 - smoothstep(LIFT_FALL.x, LIFT_FALL.y, absf(rx))) * dw
	var plus := rx >= 0.0
	var dxz := dir * ap_spread * w * (ap_side.x if plus else ap_side.y)
	return p + Vector3(dxz.x, slope.dot(dxz) + wl * (ap_lift.x if plus else ap_lift.y), dxz.y)


var _floor_cache := {}


## Thorax ouvert : hauteur de ce qu'on voit au fond de la brèche en (x, z) — cœur, gros
## vaisseaux, foie — ou -INF hors de la brèche. La visée s'y pose (sinon on viserait la peau
## « absente » au-dessus du trou et l'instrument arriverait à côté).
func breach_floor(x: float, z: float) -> float:
	if ap_path.size() < 2 or ap_spread < 0.01:
		return -INF
	var best := INF
	var gap := 0.0
	for k in ap_path.size() - 1:
		var a := Vector2(ap_path[k].x, ap_path[k].z)
		var b := Vector2(ap_path[k + 1].x, ap_path[k + 1].z)
		var ab := b - a
		var av := Vector2(x, z) - a
		var t := clampf(av.dot(ab) / maxf(ab.length_squared(), 1e-10), 0.0, 1.0)
		var d := (av - ab * t).length()
		if d < best:
			best = d
			var plus := ab.y * av.x - ab.x * av.y >= 0.0
			gap = ap_w0 + ap_spread * lerpf(ap_h[k], ap_h[k + 1], t) * (ap_side.x if plus else ap_side.y)
	if best > gap:
		return -INF
	var key := Vector2i(roundi(x * 500.0), roundi(z * 500.0))
	if _floor_cache.has(key):
		return _floor_cache[key]
	var top := body_height(x, z)
	var y := top - 0.06
	for n in 260:
		var yy := top - 0.015 - n * 0.0005
		var lab: int = EchoView.sample(Vector3(x, yy, z))[0]
		if lab == 2 or lab == 3 or lab == 6:
			y = yy
			break
	_floor_cache[key] = y
	return y


## Point du tracé de la brèche (t de 0 à 1, à intervalles égaux entre les points).
func aperture_point(t: float) -> Vector3:
	if ap_path.size() < 2:
		return Vector3.ZERO
	var f := clampf(t, 0.0, 1.0) * (ap_path.size() - 1)
	var i := mini(int(f), ap_path.size() - 2)
	return ap_path[i].lerp(ap_path[i + 1], f - i)


## Demi-largeur ouverte de la brèche en t.
func aperture_gap(t: float) -> float:
	if ap_h.size() < 2:
		return 0.0
	var f := clampf(t, 0.0, 1.0) * (ap_h.size() - 1)
	var i := mini(int(f), ap_h.size() - 2)
	return ap_w0 + ap_spread * lerpf(ap_h[i], ap_h[i + 1], f - i)


## Hémothorax : du sang stagne au fond de la cavité ouverte (0..1).
func set_cavity_blood(v: float) -> void:
	for m in anatomy_mats:
		m.set_shader_parameter("cavity_blood", v)


## Péricarde : distendu par le sang (tense 0..1), fenêtre ouverte le long de a → b (demi-largeur w).
func set_pericardium(tense_v: float, a := Vector3.ZERO, b := Vector3.ZERO, w := 0.0) -> void:
	for m in _mats_by_part.get("Pericarde", []):
		m.set_shader_parameter("tense", tense_v)
		m.set_shader_parameter("pc_a", a)
		m.set_shader_parameter("pc_b", b)
		m.set_shader_parameter("pc_w", w)


var _wound_closed := 0.0


func heart_wound_closed() -> float:
	return _wound_closed


## Plaie du cœur (centre, direction, demi-longueur), refermée de 0 à 1.
func set_heart_wound(c: Vector3, dir: Vector3, half_len: float, closed: float) -> void:
	_wound_closed = closed
	for part in ["Coeur", "Coronaires"]:
		for m in _mats_by_part.get(part, []):
			m.set_shader_parameter("heart_wound", Vector4(c.x, c.y, c.z, half_len))
			m.set_shader_parameter("heart_wound_dir", dir.normalized())
			m.set_shader_parameter("heart_wound_closed", closed)


## Fibrillation ventriculaire (0..1) : la surface du cœur frémit.
func set_fibrillation(v: float) -> void:
	for part in ["Coeur", "Coronaires"]:
		for m in _mats_by_part.get(part, []):
			m.set_shader_parameter("fibrillation", v)


## Cœur arrêté par la cardioplégie froide (0..1) : flasque et plus pâle.
func set_heart_cold(v: float) -> void:
	for part in ["Coeur", "Coronaires"]:
		for m in _mats_by_part.get(part, []):
			m.set_shader_parameter("cold", v)


## Artère mammaire gauche prélevée : on cache celle de l'atlas (le greffon la remplace).
func set_lima_hidden(v: bool) -> void:
	for m in _mats_by_part.get("Mammaires", []):
		m.set_shader_parameter("hide_left", 1.0 if v else 0.0)


## Le cœur comprimé entre les mains (massage interne), 0..1.
func set_heart_squeeze(v: float) -> void:
	heart_squeeze = v
	for part in ["Coeur", "Coronaires", "Pericarde"]:
		for m in _mats_by_part.get(part, []):
			m.set_shader_parameter("squeeze", v)


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
