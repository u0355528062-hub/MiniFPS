class_name Instrument
extends Node3D
## Instrument chirurgical saisissable. Le modèle est centré, pointe vers +Z local.
## Les ciseaux, pinces et porte-aiguille ont de vraies mâchoires (deux branches qui pivotent), la
## pince De Bakey des mors qui se rapprochent, la seringue un piston qui avance et du liquide.

signal grabbed(inst: Instrument)

## Où les doigts tiennent l'instrument (fraction de la longueur depuis l'arrière)
const GRIP := {
	"bistouri": 0.56, "ciseaux": 0.42, "porte_aiguille": 0.42, "kelly": 0.44, "overholt": 0.44,
	"mikulicz": 0.42, "debakey": 0.4, "langenbeck": 0.2, "roux": 0.24, "seringue": 0.3,
	"drain": 0.3, "feutre": 0.35, "cathlon": 0.18, "sonde": 0.6, "aiguille": 0.18, "guide": 0.7,
	"dilatateur": 0.25, "kt_central": 0.6, "finochietto": 0.22,
}
## Mâchoires : [type (1 = branches croisées, 2 = mors de pince), pivot z (modèle), angle max (°)]
const JAWS := {
	"ciseaux_metzenbaum": [1, 0.074, 15.0],
	"porte_aiguille": [1, 0.118, 9.0],
	"clamp_ligature": [1, 0.0267, 11.0],
	"clamp_overholt": [1, 0.0546, 11.0],
	"pince_debakey": [2, -0.07, 3.4],
}

var id := ""
var label := ""
var length := 0.2
var tip_local := Vector3.ZERO
var grip_local := Vector3.ZERO  ## point tenu entre le pouce et l'index
var back_local := Vector3.ZERO
var tray_transform := Transform3D.IDENTITY
var held := false
var parked := false  ## posé hors de la main (écarteur tenu par l'aide, drain...)
var model: Node3D
var up_mode := "hand"  ## orientation dans la main : "hand", "down" (crochet vers le bas), "world"
var tray_roll := 0.0
## Points de contact (local) : [position, étiquette] — la pointe d'abord
var samples: Array = []
## Résultat du contact à la dernière pose : profondeur de la pointe sous la peau (> 0 = dedans)
var tip_depth := -1.0
var correction := 0.0  ## de combien l'instrument a été remonté pour ne pas traverser
var squeeze := 0.0  ## 0 = ouvert, 1 = fermé (mâchoires)
var has_jaws := false
var jaw_type := 0
var pivot_local := Vector3.ZERO
# Seringue
var is_syringe := false
var volume := 1.0  ## produit restant (0..1)
var _plungers: Array = []  ## [nœud, position d'origine, direction locale du déplacement]
var _liquid: MeshInstance3D
var _barrel_tip := 0.0215
var _branch_a: Node3D
var _branch_b: Node3D
var _jaw_max := 0.0
var _jaw_shown := -1.0
var _src_file := ""

var _overlay := ShaderMaterial.new()
var _meshes: Array[MeshInstance3D] = []
var _tween: Tween
var _mode := 0  # 0 = rien, 1 = à utiliser, 2 = survolé


static func create(p_id: String, p_label: String, file: String, roll_deg := 0.0, scale_to := 0.0, rot := Vector3.ZERO) -> Instrument:
	var scene: PackedScene = load("res://assets/models/" + file + ".glb")
	var inst := create_from_node(p_id, p_label, scene.instantiate(), roll_deg, scale_to, rot, file)
	return inst


## Instrument à partir d'un modèle déjà construit (procédural). Pointe vers +Z.
static func create_from_node(p_id: String, p_label: String, node: Node3D, roll_deg := 0.0, scale_to := 0.0, rot := Vector3.ZERO, file := "") -> Instrument:
	var inst := Instrument.new()
	inst.id = p_id
	inst.label = p_label
	inst.name = p_id
	inst.model = node
	inst._src_file = file
	inst.model.rotation_degrees = rot + Vector3(0, 0, roll_deg)
	inst.add_child(inst.model)
	inst._setup(scale_to)
	return inst


func _setup(scale_to: float) -> void:
	_collect(model)
	var box := _local_aabb()
	if scale_to > 0.0 and box.size.z > 0.0:
		model.scale = Vector3.ONE * (scale_to / box.size.z)
		box = _local_aabb()
	length = box.size.z
	var c := box.get_center()
	tip_local = Vector3(c.x, c.y, box.end.z)
	back_local = Vector3(c.x, c.y, box.position.z)
	grip_local = Vector3(c.x, c.y, box.position.z + length * GRIP.get(id, 0.3))
	match id:
		"langenbeck", "roux":
			up_mode = "down"
		"bistouri":
			up_mode = "world"
			tray_roll = PI * 0.5
	_overlay.shader = preload("res://shaders/highlight.gdshader")
	_overlay.set_shader_parameter("strength", 0.0)
	if JAWS.has(_src_file):
		_articulate(JAWS[_src_file])
	if _src_file == "seringue":
		_setup_syringe()
	for m in _meshes:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Points de contact le long de l'axe (la pointe, puis vers l'arrière).
func build_samples() -> void:
	samples.clear()
	var tag := "tip"
	match id:
		"bistouri":
			tag = "blade"
		"seringue", "porte_aiguille", "cathlon", "aiguille":
			tag = "needle"
		"dilatateur":
			tag = "tube"
		"drain":
			tag = "tube"
		"langenbeck", "roux":
			tag = "hook"
	samples.append([tip_local, tag])
	if id == "finochietto":
		# Les deux bouts de la crémaillère
		for bx in [-0.075, 0.075]:
			samples.append([model.transform * Vector3(bx, FinochiettoModel.ARM_LEN, FinochiettoModel.BAR_Z), "body"])
	if id == "bistouri":
		# Ventre de la lame (sous l'axe)
		samples.append([tip_local + Vector3(0, -0.0035, -0.012), "blade"])
	for f in [0.1, 0.25, 0.45, 0.7, 1.0]:
		var p := tip_local.lerp(back_local, f)
		var t := "body"
		if id == "seringue" and f <= 0.25:
			t = "needle"
		elif (id == "cathlon" or id == "aiguille") and f <= 0.45:
			t = "needle"
		elif id == "dilatateur" and f <= 0.45:
			t = "tube"
		elif id == "drain" and f <= 0.45:
			t = "tube"
		elif id in ["kelly", "debakey", "overholt", "ciseaux", "mikulicz"] and f <= 0.1:
			t = "tip"
		samples.append([p, t])


func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	for ch in n.get_children():
		_collect(ch)


func _local_aabb() -> AABB:
	var box := AABB()
	var first := true
	for m in _meshes:
		if not m.visible:
			continue
		var xf := _transform_to_self(m)
		var b: AABB = xf * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _transform_to_self(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != self and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## Transformation d'un nœud vers l'espace du modèle (avant la rotation / l'échelle du modèle).
func _transform_to_model(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != model and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


# ---------------------------------------------------------------- Mâchoires

## Sépare le modèle en deux branches qui pivotent (ciseaux, pinces, porte-aiguille).
func _articulate(cfg: Array) -> void:
	jaw_type = cfg[0]
	var pivot_z: float = cfg[1]
	_jaw_max = deg_to_rad(cfg[2])
	var pivot := Vector3(0, 0, pivot_z)
	_branch_a = Node3D.new()
	_branch_b = Node3D.new()
	var heel := Node3D.new()
	_branch_a.name = "BrancheA"
	_branch_b.name = "BrancheB"
	heel.name = "Talon"
	for n in [_branch_a, _branch_b, heel]:
		model.add_child(n)
		n.position = pivot
	pivot_local = model.transform * pivot
	var new_meshes: Array[MeshInstance3D] = []
	for mi: MeshInstance3D in _meshes.duplicate():
		var to_model := _transform_to_model(mi)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var index: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			if index.is_empty():
				continue
			var world := PackedVector3Array()
			world.resize(verts.size())
			for i in verts.size():
				world[i] = to_model * verts[i]
			var side := _branch_sides(world, index, pivot_z)
			for b in 3:
				var idx := PackedInt32Array()
				for t in range(0, index.size(), 3):
					if side[t / 3] == b:
						idx.append_array([index[t], index[t + 1], index[t + 2]])
				if idx.is_empty():
					continue
				var out := arr.duplicate()
				# Sommets exprimés depuis le pivot
				var local := PackedVector3Array()
				local.resize(world.size())
				for i in world.size():
					local[i] = world[i] - pivot
				out[Mesh.ARRAY_VERTEX] = local
				if out[Mesh.ARRAY_NORMAL] != null:
					var nb := to_model.basis.inverse().transposed()
					var nn: PackedVector3Array = (out[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
					for i in nn.size():
						nn[i] = (nb * nn[i]).normalized()
					out[Mesh.ARRAY_NORMAL] = nn
				if out[Mesh.ARRAY_TANGENT] != null:
					var tg: PackedFloat32Array = (out[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
					for i in tg.size() / 4:
						var tv := (to_model.basis * Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])).normalized()
						tg[i * 4] = tv.x
						tg[i * 4 + 1] = tv.y
						tg[i * 4 + 2] = tv.z
					out[Mesh.ARRAY_TANGENT] = tg
				out[Mesh.ARRAY_INDEX] = idx
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
				am.surface_set_material(0, mi.get_active_material(s))
				var part := MeshInstance3D.new()
				part.mesh = am
				[_branch_a, _branch_b, heel][b].add_child(part)
				new_meshes.append(part)
		mi.visible = false
		_meshes.erase(mi)
	_meshes.append_array(new_meshes)
	has_jaws = true
	set_squeeze(1.0)


## Branche de chaque triangle : 0 = celle dont l'anneau est à +X (ou le mors du haut).
func _branch_sides(world: PackedVector3Array, index: PackedInt32Array, pivot_z: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(index.size() / 3)
	# Ciseaux : chaque moitié est une pièce séparée → on suit la connexité
	var comp := PackedInt32Array()
	if jaw_type == 1 and _src_file == "ciseaux_metzenbaum":
		comp = _components(world, index)
	var comp_side := {}
	if not comp.is_empty():
		var sums := {}
		for i in world.size():
			if world[i].z < pivot_z - 0.1:
				sums[comp[i]] = sums.get(comp[i], 0.0) + world[i].x
		for k in sums:
			comp_side[k] = 0 if sums[k] > 0.0 else 1
	for t in range(0, index.size(), 3):
		var c := (world[index[t]] + world[index[t + 1]] + world[index[t + 2]]) / 3.0
		var b := 0
		if jaw_type == 2:
			b = 0 if c.y > 0.0 else 1
			if c.z < pivot_z:
				b = 2  # talon de la pince : ne bouge pas
		elif not comp.is_empty():
			b = comp_side.get(comp[index[t]], 0)
		else:
			# Anneaux du côté du pivot opposé aux mors : les branches se croisent au pivot
			var right := c.x > 0.0
			b = (0 if right else 1) if c.z < pivot_z else (1 if right else 0)
		out[t / 3] = b
	return out


static func _find_root(parent: PackedInt32Array, i: int) -> int:
	while parent[i] != i:
		parent[i] = parent[parent[i]]
		i = parent[i]
	return i


static func _components(world: PackedVector3Array, index: PackedInt32Array) -> PackedInt32Array:
	var parent := PackedInt32Array()
	parent.resize(world.size())
	var weld := PackedInt32Array()
	weld.resize(world.size())
	var key_of := {}
	for i in world.size():
		var k := Vector3i((world[i] * 20000.0).round())
		if not key_of.has(k):
			key_of[k] = i
		weld[i] = key_of[k]
		parent[i] = i
	for t in range(0, index.size(), 3):
		var a := _find_root(parent, weld[index[t]])
		var b := _find_root(parent, weld[index[t + 1]])
		var c := _find_root(parent, weld[index[t + 2]])
		parent[b] = a
		parent[_find_root(parent, c)] = _find_root(parent, a)
	var out := PackedInt32Array()
	out.resize(world.size())
	for i in world.size():
		out[i] = _find_root(parent, weld[i])
	return out


## 0 = mâchoires ouvertes, 1 = fermées.
func set_squeeze(v: float) -> void:
	squeeze = clampf(v, 0.0, 1.0)
	if not has_jaws or absf(squeeze - _jaw_shown) < 0.002:
		return
	_jaw_shown = squeeze
	var a := (1.0 - squeeze) * _jaw_max
	if jaw_type == 1:
		_branch_a.basis = Basis(Vector3.UP, -a)
		_branch_b.basis = Basis(Vector3.UP, a)
	else:
		# Pince : les mors se rapprochent quand on serre (ouverte au repos)
		var close := squeeze * _jaw_max
		_branch_a.basis = Basis(Vector3.RIGHT, close)
		_branch_b.basis = Basis(Vector3.RIGHT, -close)


## Pivot (ou talon) en coordonnées monde : sert à savoir si une cible est entre les lames.
func pivot_global() -> Vector3:
	return global_transform * Vector3(tip_local.x, tip_local.y, pivot_local.z)


## Distance d'un point au segment pivot → pointe (là où les mâchoires saisissent ou coupent).
func jaw_distance(p: Vector3) -> float:
	var a := pivot_global()
	var b := tip_global()
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return (a + ab * k).distance_to(p)


# ---------------------------------------------------------------- Seringue

func _setup_syringe() -> void:
	is_syringe = true
	for mi in _meshes:
		var n := String(mi.name).to_lower()
		if n.begins_with("plunger"):
			var to_model := _transform_to_model(mi.get_parent() as Node3D) if mi.get_parent() != model else Transform3D.IDENTITY
			_plungers.append([mi, mi.position, to_model.basis.inverse() * Vector3.UP])
		elif n.begins_with("barrel"):
			# Corps transparent : on voit le liquide
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.92, 0.95, 0.97, 0.22)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.08
			m.metallic_specular = 0.8
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = m
	# Liquide (lidocaïne : incolore, légèrement bleuté pour qu'on le voie)
	_liquid = MeshInstance3D.new()
	_liquid.name = "Liquide"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0061
	cm.bottom_radius = 0.0061
	cm.height = 1.0
	cm.radial_segments = 20
	_liquid.mesh = cm
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.72, 0.86, 0.98, 0.42)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.roughness = 0.05
	lm.metallic_specular = 0.9
	lm.rim_enabled = true
	lm.rim = 0.4
	_liquid.material_override = lm
	_liquid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(_liquid)
	# Graduations
	var grad := MeshUtil.mat(Color(0.1, 0.12, 0.15), 0.6)
	for k in 6:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.0073
		tm.outer_radius = 0.00745 if k % 2 == 1 else 0.0076
		tm.rings = 24
		tm.ring_segments = 3
		ring.mesh = tm
		ring.material_override = grad
		ring.position = Vector3(0, -0.035 + k * 0.0105, 0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(ring)
	set_volume(1.0)


## Produit restant : le piston avance, le liquide diminue.
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	if not is_syringe:
		return
	var offset := lerpf(0.019, -0.0315, volume)
	for p in _plungers:
		(p[0] as Node3D).position = (p[1] as Vector3) + (p[2] as Vector3) * offset
	var bottom := 0.0015 + offset  # face du joint en caoutchouc
	var h := maxf(_barrel_tip - bottom, 0.0004)
	_liquid.scale = Vector3(1, h, 1)
	_liquid.position = Vector3(0, bottom + h * 0.5, 0)
	_liquid.visible = volume > 0.01


# ---------------------------------------------------------------- Pose

## Ajoute une pièce procédurale (lame, compresse, aiguille...) attachée à la pointe.
func attach_tip_part(part: Node3D) -> void:
	add_child(part)
	part.position = tip_local
	_collect(part)


func tip_global() -> Vector3:
	return global_transform * tip_local


func grip_global() -> Vector3:
	return global_transform * grip_local


## Axe de l'instrument (vers la pointe), en monde.
func axis_global() -> Vector3:
	return (global_transform.basis * (tip_local - back_local)).normalized()


## 0 = normal, 1 = instrument demandé (pulsation cyan), 2 = survolé (blanc)
func set_highlight(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	for m in _meshes:
		m.material_overlay = _overlay if mode > 0 else null
	_overlay.set_shader_parameter("strength", 0.7 if mode == 1 else 0.6)
	_overlay.set_shader_parameter("glow", Color(0.2, 0.95, 0.85) if mode == 1 else Color(0.9, 0.95, 1.0))


func take() -> void:
	held = true
	parked = false
	if _tween:
		_tween.kill()
	grabbed.emit(self)


## Retour sur la table : l'instrument passe par-dessus (il ne traverse ni le patient ni les champs).
func return_to_tray() -> void:
	held = false
	parked = false
	tip_depth = -1.0
	if _tween:
		_tween.kill()
	var from := global_transform
	var to := tray_transform
	var lift := maxf(from.origin.y, to.origin.y) + 0.14
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		var e := k * k * (3.0 - 2.0 * k)
		var p := from.origin.lerp(to.origin, e)
		p.y = lerpf(lerpf(from.origin.y, to.origin.y, e), lift, sin(PI * e))
		global_transform = Transform3D(Basis(Quaternion(from.basis.orthonormalized()).slerp(Quaternion(to.basis.orthonormalized()), e)), p),
		0.0, 1.0, 0.55)
	_tween.tween_callback(func() -> void:
		set_squeeze(1.0 if jaw_type == 1 else 0.0)
		Sfx.play("pose", to.origin, -14.0, randf_range(0.95, 1.1)))


func park(xf: Transform3D) -> void:
	held = false
	parked = true
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_transform", xf, 0.3)


## Transformation qui met la pointe en `tip`, l'axe de l'instrument suivant `axis` (vers la pointe).
func tip_transform(tip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> Transform3D:
	var b := _basis_for(axis, up_hint)
	return Transform3D(b, tip - b * tip_local)


func _basis_for(axis: Vector3, up_hint: Vector3) -> Basis:
	var z := axis.normalized()
	var x := up_hint.cross(z)
	if x.length() < 0.01:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	return Basis(x, z.cross(x), z)


## Pose la pointe en `tip` (souris, robot) en respectant les contacts.
func pose_tip(tip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> void:
	place(tip_transform(tip, axis, up_hint))


## Transformation qui met le point de prise en `grip` (main VR).
func grip_transform(grip: Vector3, axis: Vector3, up_hint := Vector3.UP) -> Transform3D:
	var b := _basis_for(axis, up_hint)
	return Transform3D(b, grip - b * grip_local)


## Place l'instrument tenu : la pose voulue est corrigée pour ne rien traverser.
func place(xf: Transform3D) -> void:
	global_transform = Contact.solve(self, xf)
