class_name Patient
extends Node3D
## Patient des urgences, couché sur le dos sur le brancard : tête vers +X, côté gauche du patient
## vers +Z (côté du soignant), milieu du sternum en X = Z = 0.
##
## Corps : humain MakeHuman (CC0) couché, textures de peau cuites (tools/blender/build_skin.py),
## cheveux courts en coques, yeux et paupières qui se ferment (cible de forme) ; repères anatomiques
## (sternum, clavicules, côtes et espaces intercostaux de l'atlas Z-Anatomy, bras, cou, visage).
## Les signes cliniques (pâleur, cyanose, sueurs, marbrures, urticaire, rougeur) sont réglés par la physiologie ; le
## thorax se soulève à chaque respiration et s'enfonce sous les mains pendant le massage.
## Zones cliquables (tête, cou, thorax, abdomen, bras, mains, jambes) : vue rapprochée du geste.

const TABLE_TOP := 0.80
## Dessus du matelas du brancard : X, Z
const TABLE_MIN := Vector2(-1.41, -0.30)
const TABLE_MAX := Vector2(0.69, 0.30)
const GLB := "res://assets/models/patient_urg.glb"
const SKIN_MAP := "res://assets/data/peau_dos_hauteur.bin"
const SHEET_GLB := "res://assets/models/drap_dos.glb"
const SHEET_MAP := "res://assets/data/drap_dos_hauteur.bin"
const LANDMARKS := "res://assets/data/patient_dos.json"
const RIBS := "res://assets/data/cotes_dos.bin"
## Couches physiques : corps (visée précise), objets cliquables
const LAYER_BODY := 2
const LAYER_INTERACT := 4
const LAYER_DEVICE := 8
## Thorax qui se soulève (repère du jeu) : montée et descente le long du corps, demi-largeur, hauteur
const CHEST_X := Vector4(-0.36, -0.2, 0.08, 0.2)
const CHEST_Z := Vector2(0.1, 0.2)
const CHEST_H := Vector2(0.06, 0.16)
## Repères le long du bras (ligne centrale, 0 : épaule, 1 : bout du majeur) : coude, poignet
const ARM_ELBOW := 0.333
const ARM_WRIST := 0.667
## Coques des cheveux courts (nombre, longueur des cheveux en m)
const HAIR_SHELLS := 10
const HAIR_LEN := 0.0065

static var landmarks := {}
static var HEART_C := Vector3(-0.024, 0.976, 0.032)
static var _maps_loaded := false
static var _rib_codes := PackedByteArray()
static var _rib_depth := PackedFloat32Array()
static var _rib_grid := [0, 0, 0.0, 0.0, 0.0025]
static var _skin_h := PackedFloat32Array()
static var _drape_h := PackedFloat32Array()
static var _nx := 0
static var _nz := 0
static var _x0 := 0.0
static var _z0 := 0.0
static var _step := 0.0025

var skin_mat: ShaderMaterial
var skin_mesh: MeshInstance3D
var eye_mat: ShaderMaterial
var hair_mat: ShaderMaterial
var _hair_shells: Array[MeshInstance3D] = []
var _eye_meshes: Array = []
## Paupières : ouverture voulue et actuelle (0 fermées, 1 grand ouvertes)
var _lids_target := 0.0
var _lids := 0.0
var sheet: Node3D
var zones := {}  ## id -> Interactable
var gear: PatientGear

## Respiration (pilotée par la physiologie) : fréquence, amplitude (0..1), insufflations au ballon
var resp_rate := 14.0
var tidal := 1.0
var gasping := false  ## gasps de l'arrêt cardiaque : rares, brefs
var breath_now := 0.0  ## soulèvement actuel (m)
var _breath_t := 0.0
var _assist := 0.0  ## insufflation au ballon en cours (0..1)
var _assist_t := 0.0
## Massage : profondeur (m) et point d'appui (x, z)
var comp_depth := 0.0
var comp_point := Vector2(-0.04, 0.0)
const BREATH_AMP := 0.008


# ---------------------------------------------------------------- Cartes et repères

static func load_maps() -> void:
	if _maps_loaded:
		return
	_maps_loaded = true
	_skin_h = _read_map(SKIN_MAP)
	_drape_h = _read_map(SHEET_MAP)
	var bytes := FileAccess.get_file_as_bytes(RIBS)
	if bytes.size() > 24:
		var nx := bytes.decode_s32(0)
		var nz := bytes.decode_s32(4)
		_rib_grid = [nx, nz, bytes.decode_float(8), bytes.decode_float(12), bytes.decode_float(16)]
		_rib_codes = bytes.slice(24, 24 + nx * nz)
		_rib_depth = bytes.slice(24 + nx * nz, 24 + nx * nz * 5).to_float32_array()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LANDMARKS))
	if data is Dictionary:
		landmarks = data
		if landmarks.has("heart_center"):
			HEART_C = lm("heart_center")
	else:
		push_error("Repères illisibles : " + LANDMARKS)


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
		return maxf(maxf(a, b), maxf(c, d))
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


static func on_table(x: float, z: float) -> bool:
	return x > TABLE_MIN.x and x < TABLE_MAX.x and z > TABLE_MIN.y and z < TABLE_MAX.y


## Hauteur de la peau au point (x, z), ou du matelas hors du corps (-1 hors du brancard).
static func body_height(x: float, z: float) -> float:
	var h := _sample(_skin_h, x, z)
	if h > 0.0:
		return h
	return TABLE_TOP if on_table(x, z) else -1.0


## Dessus du drap (-1 là où il n'y en a pas).
static func drape_height(x: float, z: float) -> float:
	var h := _sample(_drape_h, x, z)
	return h + 0.003 if h > 0.0 else h


static func top_height(x: float, z: float) -> float:
	return maxf(body_height(x, z), drape_height(x, z))


static func skin_normal(x: float, z: float) -> Vector3:
	var e := 0.004
	var hx := (body_height(x + e, z) - body_height(x - e, z)) / (2.0 * e)
	var hz := (body_height(x, z + e) - body_height(x, z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


static func lm(key: String) -> Vector3:
	var a: Array = landmarks.get(key, [0.0, 0.0, 0.0])
	return Vector3(a[0], a[1], a[2])


static func lm_skin(key: String) -> Vector3:
	var d: Dictionary = landmarks.get(key, {})
	var a: Array = d.get("skin", [0.0, 0.0, 0.0])
	return Vector3(a[0], a[1], a[2])


static func _rib_index(x: float, z: float) -> int:
	if _rib_codes.is_empty():
		return -1
	var i := int(round((x - _rib_grid[2]) / _rib_grid[4]))
	var j := int(round((z - _rib_grid[3]) / _rib_grid[4]))
	if i < 0 or j < 0 or i >= _rib_grid[0] or j >= _rib_grid[1]:
		return -1
	return j * int(_rib_grid[0]) + i


## Sous le point (x, z) : n > 0 = sur la n-ième côte, -n = dans le n-ième espace intercostal, 0 = hors du
## gril costal.
static func rib_code(x: float, z: float) -> int:
	var k := _rib_index(x, z)
	if k < 0:
		return 0
	var v := _rib_codes[k]
	return v - 256 if v > 127 else v


## Point d'un bras (ligne centrale mesurée) à la fraction t (0 : épaule, 1 : bout des doigts).
static func arm_point(side: String, t: float) -> Vector3:
	var line: Array = landmarks.get("arm_" + side, [])
	if line.is_empty():
		return Vector3.ZERO
	var n := line.size()
	var f := clampf((1.0 - t) * (n - 1), 0.0, n - 1.001)
	var i := int(f)
	var a: Array = line[i]
	var b: Array = line[i + 1]
	var k := f - i
	return Vector3(lerpf(a[0], b[0], k), lerpf(a[1], b[1], k), lerpf(a[2], b[2], k))


## Dernière phalange de l'index : [articulation, bout] (oxymètre, glycémie capillaire).
static func index_finger(side: String) -> Array:
	return [lm("index_dip_" + side), lm("index_tip_" + side)]


static func arm_dir(side: String, t: float) -> Vector3:
	return (arm_point(side, minf(1.0, t + 0.04)) - arm_point(side, maxf(0.0, t - 0.04))).normalized()


## Point de la peau au-dessus d'un point d'un bras (dessus du bras).
static func arm_top(side: String, t: float) -> Vector3:
	var p := arm_point(side, t)
	return Vector3(p.x, body_height(p.x, p.z), p.z)


# ---------------------------------------------------------------- Construction

func build(profile: Dictionary) -> void:
	load_maps()
	var scene: PackedScene = load(GLB)
	var body: Node3D = scene.instantiate()
	body.name = "Corps"
	add_child(body)
	skin_mat = ShaderMaterial.new()
	skin_mat.shader = preload("res://shaders/patient_skin.gdshader")
	skin_mat.set_shader_parameter("peau_albedo", Tex.get_tex("peau_albedo"))
	skin_mat.set_shader_parameter("peau_normal", Tex.get_tex("peau_normal"))
	skin_mat.set_shader_parameter("peau_masques", Tex.get_tex("peau_masques"))
	skin_mat.set_shader_parameter("peau_poils", Tex.get_tex("peau_poils"))
	skin_mat.set_shader_parameter("skin_normal", Tex.get_tex("skin_normal"))
	skin_mat.set_shader_parameter("skin_rough", Tex.get_tex("skin_rough"))
	skin_mat.set_shader_parameter("mottle", Tex.get_tex("tissue_mottle"))
	skin_mat.set_shader_parameter("chest_x", CHEST_X)
	skin_mat.set_shader_parameter("chest_z", CHEST_Z)
	skin_mat.set_shader_parameter("chest_h", CHEST_H)
	skin_mat.set_shader_parameter("table_top", TABLE_TOP)
	var tl := lm("fingertip_L")
	var tr := lm("fingertip_R")
	skin_mat.set_shader_parameter("fingertips", Vector4(tl.x, tl.z, tr.x, tr.z))
	_set_hair_params(skin_mat, profile)
	skin_mat.set_shader_parameter("skin_tint", profile.get("skin", Color(0.99, 0.95, 0.94)))
	for mi in body.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		match String(m3.name):
			"Peau":
				skin_mesh = m3
				m3.material_override = skin_mat
				# La peau bouge (respiration, massage) : boîte englobante un peu agrandie
				m3.extra_cull_margin = 0.05
				_add_trimesh(m3)
			"Yeux":
				eye_mat = ShaderMaterial.new()
				eye_mat.shader = preload("res://shaders/eye.gdshader")
				eye_mat.set_shader_parameter("iris_tex", Tex.get_tex("oeil_iris"))
				m3.material_override = eye_mat
			"Poils":
				_build_hair(m3, profile)
	_eye_meshes = [skin_mesh]
	_eye_meshes.append_array(_hair_shells)
	_apply_lids()
	# Drap blanc sur les jambes
	var sh: PackedScene = load(SHEET_GLB)
	sheet = sh.instantiate()
	sheet.name = "Drap"
	add_child(sheet)
	var smat := ShaderMaterial.new()
	smat.shader = preload("res://shaders/sheet.gdshader")
	smat.set_shader_parameter("fabric_normal", Tex.get_tex("fabric_normal"))
	smat.set_shader_parameter("fabric_detail", Tex.get_tex("fabric_detail"))
	for mi in sheet.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = smat
		_add_trimesh(mi as MeshInstance3D)
	_build_zones()
	gear = PatientGear.new()
	gear.name = "Equipement"
	gear.patient = self
	add_child(gear)
	gear.build(profile)


## Couleur des poils, barbe naissante et calvitie (zone dégarnie sur le dessus et l'avant du crâne).
func _set_hair_params(m: ShaderMaterial, profile: Dictionary) -> void:
	var head_top := float(landmarks.get("head_top_x", 0.49))
	var nose := lm("nose_tip")
	m.set_shader_parameter("hair_col", profile.get("hair", Color(0.045, 0.032, 0.025)))
	m.set_shader_parameter("stubble", profile.get("stubble", 0.3))
	m.set_shader_parameter("bald", profile.get("bald", 0.0))
	m.set_shader_parameter("crown", Vector4(head_top - 0.035, nose.y - 0.035, 0.0, 0.1))


## Cheveux courts, sourcils, barbe : coques superposées au-dessus de la peau (même maillage décalé
## le long des normales dans le shader, une instance par hauteur).
func _build_hair(src: MeshInstance3D, profile: Dictionary) -> void:
	hair_mat = ShaderMaterial.new()
	hair_mat.shader = preload("res://shaders/hair_shell.gdshader")
	hair_mat.set_shader_parameter("peau_poils", Tex.get_tex("peau_poils"))
	hair_mat.set_shader_parameter("hair_len", HAIR_LEN)
	_set_hair_params(hair_mat, profile)
	src.visible = false
	for i in HAIR_SHELLS:
		var sh := MeshInstance3D.new()
		sh.name = "Cheveux%d" % i
		sh.mesh = src.mesh
		sh.material_override = hair_mat
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sh.set_instance_shader_parameter("shell", (i + 1.0) / HAIR_SHELLS)
		src.get_parent().add_child(sh)
		sh.transform = src.transform
		_hair_shells.append(sh)


## Corps solide pour viser précisément la peau (rayon de la souris en vue rapprochée).
func _add_trimesh(mi: MeshInstance3D) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = LAYER_BODY
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = mi.mesh.create_trimesh_shape()
	sb.add_child(cs)
	mi.add_child(sb)


## Zones cliquables du patient (en vue à la première personne).
func _build_zones() -> void:
	var sn := lm("sternal_notch")
	var xi := lm("xiphoid_tip")
	var head_top := float(landmarks.get("head_top_x", 0.41))
	var nk: Dictionary = landmarks.get("neck", {"x": 0.18, "y_front": 1.03, "y_back": 0.88, "half_width": 0.06})
	_zone("tete", "Tête et visage", Vector3((head_top + 0.22) * 0.5, 0.97, 0.0), Vector3(head_top - 0.22, 0.26, 0.2))
	_zone("cou", "Cou", Vector3(float(nk["x"]), 0.96, 0.0), Vector3(0.07, 0.17, 0.14))
	_zone("thorax", "Thorax", Vector3((sn.x + xi.x) * 0.5 - 0.01, 1.03, 0.0), Vector3(sn.x - xi.x + 0.06, 0.2, 0.32))
	_zone("abdomen", "Abdomen", Vector3(-0.27, 0.98, 0.0), Vector3(0.3, 0.18, 0.3))
	for side in ["L", "R"]:
		var s := 1.0 if side == "L" else -1.0
		var sh := arm_point(side, 0.05)
		var wr := arm_point(side, ARM_WRIST)
		var tip := arm_point(side, 1.0)
		var c := (sh + wr) * 0.5
		var len := Vector2(sh.x - wr.x, sh.z - wr.z).length()
		var z := _zone("bras_" + side, "Bras " + ("gauche" if side == "L" else "droit"), c + Vector3(0, 0.02, 0), Vector3(len, 0.12, 0.1))
		z.rotation.y = atan2(-(sh.z - wr.z), sh.x - wr.x)
		var hc := (wr + tip) * 0.5
		_zone("main_" + side, "Main " + ("gauche" if side == "L" else "droite"), hc + Vector3(0, 0.01, 0), Vector3(0.17, 0.08, 0.1))
		zones["main_" + side].rotation.y = z.rotation.y
		var _u := s
	_zone("jambes", "Jambes", Vector3(-0.92, 0.9, 0.0), Vector3(0.95, 0.22, 0.46))


func _zone(id: String, label: String, c: Vector3, size: Vector3) -> Interactable:
	var it := Interactable.make(self, "patient:" + id, label, "Examiner de près", size, c)
	it.zone = id
	zones[id] = it
	return it


# ---------------------------------------------------------------- État visible

## Signes cliniques (0..1) : pâleur, cyanose, sueurs, marbrures, urticaire, rougeur.
func set_signs(s: Dictionary) -> void:
	for k in ["pallor", "cyanosis", "sweat", "mottling", "urticaria", "flush"]:
		if s.has(k):
			skin_mat.set_shader_parameter(k, clampf(float(s[k]), 0.0, 1.0))
	if eye_mat and s.has("pallor"):
		eye_mat.set_shader_parameter("pallor", clampf(float(s["pallor"]), 0.0, 1.0))


## Ouverture des yeux (0 : fermés, 1 : grands ouverts) ; les paupières y vont en une fraction de
## seconde.
func set_eyes_open(v: float) -> void:
	_lids_target = clampf(v, 0.0, 1.0)


## Diamètre des pupilles (mm) : myosis, mydriase.
func set_pupils(mm: float) -> void:
	if eye_mat:
		eye_mat.set_shader_parameter("pupil_mm", mm)


func _apply_lids() -> void:
	for mi in _eye_meshes:
		var m3 := mi as MeshInstance3D
		if m3 and m3.mesh and m3.mesh.get_blend_shape_count() > 0:
			m3.set_blend_shape_value(0, 1.0 - _lids)


## Une insufflation au ballon : le thorax se soulève (si les voies aériennes sont libres).
func insufflate(effective: bool) -> void:
	_assist_t = 0.0
	_assist = 1.0 if effective else 0.25


## Massage : profondeur d'enfoncement (m) au point d'appui.
func set_compression(depth: float, at := Vector2.INF) -> void:
	comp_depth = depth
	if at != Vector2.INF:
		comp_point = at
	skin_mat.set_shader_parameter("comp", Vector4(comp_point.x, comp_point.y, comp_depth, 0.085))


static func chest_mask(x: float, z: float) -> float:
	return smoothstep(CHEST_X.x, CHEST_X.y, x) * (1.0 - smoothstep(CHEST_X.z, CHEST_X.w, x)) * (1.0 - smoothstep(CHEST_Z.x, CHEST_Z.y, absf(z)))


## Déplacement vertical de la peau au point p (respiration, massage) : pour ce qui est posé dessus.
func skin_offset(p: Vector3) -> float:
	var hfac := smoothstep(TABLE_TOP + CHEST_H.x, TABLE_TOP + CHEST_H.y, p.y)
	var off := breath_now * chest_mask(p.x, p.z) * hfac
	if comp_depth > 0.0:
		var d := Vector2(p.x, p.z) - comp_point
		var r2 := 0.085 * 0.085
		var k := maxf(exp(-d.length_squared() / r2), exp(-d.length_squared() / (r2 * 5.0)) * 0.45)
		off -= comp_depth * k * smoothstep(TABLE_TOP + 0.04, TABLE_TOP + 0.14, p.y)
	return off


func _process(delta: float) -> void:
	# Respiration spontanée (sinus) + insufflations
	var spont := 0.0
	if resp_rate > 0.5 and tidal > 0.01:
		_breath_t += delta * resp_rate / 60.0
		var ph := fmod(_breath_t, 1.0)
		if gasping:
			spont = (sin(clampf(ph / 0.12, 0.0, 1.0) * PI)) * 0.6
		else:
			# Inspiration plus courte que l'expiration
			spont = sin(clampf(ph / 0.4, 0.0, 1.0) * PI * 0.5) if ph < 0.4 else cos(clampf((ph - 0.4) / 0.6, 0.0, 1.0) * PI * 0.5)
			spont = spont * spont
		spont *= tidal
	if _assist > 0.0:
		_assist_t += delta
		var a := sin(clampf(_assist_t / 1.0, 0.0, 1.0) * PI) * _assist
		spont = maxf(spont, a * 1.3)
		if _assist_t > 1.6:
			_assist = 0.0
	breath_now = spont * BREATH_AMP
	if absf(_lids - _lids_target) > 0.001:
		_lids = move_toward(_lids, _lids_target, delta * 5.0)
		_apply_lids()
	skin_mat.set_shader_parameter("breath", breath_now)
