class_name InstrumentTray
extends Node3D
## Table de Mayo avec champ stérile et instruments rangés, haricot posé sur les jambes du patient.

const TRAY_Y := 1.004

## Position de la table de Mayo (dépend de l'opération : toujours à droite du chirurgien)
static var MAYO_POS := Vector3(0.62, 0.0, 0.56)
## Centres de toutes les tables de Mayo (une seconde quand il y a beaucoup d'instruments)
static var TABLES: Array[Vector3] = []

var instruments: Dictionary = {}  # id -> Instrument
var ordered: Array[Instrument] = []
var dish: Node3D
var dish_center: Vector3

var _steel := MeshUtil.mat(Color(0.86, 0.88, 0.9), 0.18, 1.0)


func build(op: Operation) -> void:
	MAYO_POS = op.tray_pos
	TABLES.clear()
	# Côté de la table d'opération où se trouve la table de Mayo : +Z (à gauche du patient) ou -Z
	var side := -1.0 if MAYO_POS.z < 0.0 else 1.0
	var n: int = op.catalog.size()
	var made: Array[Instrument] = []
	var widths: Array[float] = []
	for i in n:
		var c: Array = op.catalog[i]
		var rot: Vector3 = c[5] if c.size() > 5 else Vector3.ZERO
		var inst: Instrument
		if String(c[2]).begins_with("proc:"):
			inst = Instrument.create_from_node(c[0], c[1], ProcInstruments.build(String(c[2]).substr(5)), c[3], c[4], rot)
		else:
			inst = Instrument.create(c[0], c[1], c[2], c[3], c[4], rot)
		add_child(inst)
		_decorate(inst)
		made.append(inst)
		# Largeur réelle sur le plateau (un écarteur prend plus de place qu'un bistouri)
		var box := inst._local_aabb()
		widths.append(maxf(absf(cos(inst.tray_roll)) * box.size.x + absf(sin(inst.tray_roll)) * box.size.y, 0.04))
	# Beaucoup d'instruments : une seconde table de Mayo, à côté de la première (vers les pieds)
	var groups: Array = [[]]
	var acc := 0.0
	for i in n:
		if acc + widths[i] > 0.45 and not (groups[groups.size() - 1] as Array).is_empty():
			groups.append([])
			acc = 0.0
		(groups[groups.size() - 1] as Array).append(i)
		acc += widths[i] + 0.012
	for g in groups.size():
		var center := MAYO_POS + Vector3(-0.56 * g, 0, 0)
		_mayo_table(center, side)
		var idx: Array = groups[g]
		var total := 0.0
		for i in idx:
			total += widths[i]
		var gap := (0.44 - total) / maxf(idx.size() - 1, 1)
		var cursor := center.x - 0.22
		if idx.size() == 1:
			cursor = center.x - widths[idx[0]] * 0.5
		for j in idx.size():
			var i: int = idx[j]
			var inst := made[i]
			var x := cursor + widths[i] * 0.5
			cursor += widths[i] + gap
			# À plat, pointe vers la table d'opération, légèrement en éventail ; posé sur sa partie
			# la plus basse (les valves d'un écarteur ne traversent pas le champ)
			var roll := Basis(Vector3(0, 0, 1), inst.tray_roll)
			var b := Basis(Vector3.UP, (PI if side > 0.0 else 0.0) + deg_to_rad((j - idx.size() * 0.5) * 1.5)) * roll
			var half := inst.length * 0.5
			var rb := Transform3D(roll, Vector3.ZERO) * inst._local_aabb()
			var lift := maxf(0.006, -rb.position.y + 0.0015)
			inst.tray_transform = Transform3D(b, Vector3(x, TRAY_Y + lift, center.z + side * (0.01 - (0.2 - half) * 0.15)))
			inst.global_transform = inst.tray_transform
			inst.build_samples()
	for inst in made:
		instruments[inst.id] = inst
		ordered.append(inst)

	if op.with_dish:
		_build_dish()
	_props()


## Une table de Mayo (pied et plateau) couverte d'un champ stérile, centrée en `center`.
func _mayo_table(center: Vector3, side: float) -> void:
	TABLES.append(center)
	var mayo: PackedScene = load("res://assets/models/table_mayo.glb")
	var m: Node3D = mayo.instantiate()
	m.position = center
	if side < 0.0:
		m.rotation_degrees.y = 180.0
	add_child(m)
	var cloth := MeshInstance3D.new()
	cloth.mesh = MeshUtil.height_grid(center.x - 0.26, center.z - 0.22, 0.52, 0.44, 30, 26, func(x: float, z: float) -> float:
		var ex := maxf(absf(x - center.x) - 0.235, 0.0)
		var ez := maxf(absf(z - center.z) - 0.195, 0.0)
		var e := maxf(ex, ez)
		return TRAY_Y - 0.003 - e * 2.6 + 0.0008 * sin(x * 140.0) * sin(z * 90.0))
	cloth.material_override = Tex.drape(Color(0.2, 0.4, 0.5))
	add_child(cloth)


## Pièces procédurales au bout de certains instruments.
func _decorate(inst: Instrument) -> void:
	match inst.id:
		"finochietto", "ecarteur_sternal":
			# Pointe = milieu des valves (la crémaillère est au bout des bras) ; axe vertical
			var mt := inst.model.transform
			inst.tip_local = mt * Vector3(0, 0, (inst.model as FinochiettoModel).blade_depth + 0.0015)
			inst.grip_local = mt * Vector3(0, 0, (inst.model as FinochiettoModel).bar_z)
			inst.back_local = mt * Vector3(0, 0, (inst.model as FinochiettoModel).bar_z - 0.03)
		"bistouri":
			var blade := _blade()
			inst.attach_tip_part(blade)
			inst.set_meta("blade_mat", blade.material_override)
			# La pointe effective est au bout de la lame
			inst.tip_local += Vector3(0, 0, 0.034)
		"mikulicz":
			var ball := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.011
			s.height = 0.02
			ball.mesh = s
			var gauze := Tex.tissue(Color(0.5, 0.2, 0.06), 0.0, 0.0, 0.0, 120.0)
			gauze.set_shader_parameter("wetness", 0.6)
			gauze.set_shader_parameter("normal_strength", 1.4)
			ball.material_override = gauze
			var holder := Node3D.new()
			holder.add_child(ball)
			ball.position = Vector3(0, 0, 0.004)
			inst.attach_tip_part(holder)
			inst.tip_local += Vector3(0, 0, 0.012)
		"porte_aiguille":
			inst.attach_tip_part(_needle())
		"overholt":
			inst.attach_tip_part(_thread_loop())


func _blade() -> MeshInstance3D:
	# Lame n°15 : contour dans le plan YZ, ventre tranchant vers le bas (-Y), très fine
	var outline := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		var z := t * 0.034
		var w := 0.0045 * sin(PI * pow(t, 0.7)) + 0.0012 * (1.0 - t)
		outline.append(Vector2(-w, z))
	for i in range(12, -1, -1):
		var t := float(i) / 12.0
		outline.append(Vector2(0.0018 * (1.0 - t), t * 0.034))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := Geometry2D.triangulate_polygon(outline)
	for side in [1.0, -1.0]:
		for k in range(0, tris.size(), 3):
			var ids := [tris[k], tris[k + 1], tris[k + 2]] if side > 0 else [tris[k], tris[k + 2], tris[k + 1]]
			for id in ids:
				var p: Vector2 = outline[id]
				st.set_normal(Vector3(side, 0, 0))
				st.add_vertex(Vector3(side * 0.0002, p.x, p.y))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := MeshUtil.mat(Color(0.92, 0.93, 0.95), 0.12, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	return mi


func _needle() -> Node3D:
	var root := Node3D.new()
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	for i in 12:
		var a := PI * 0.85 * i / 11.0
		pts.append(Vector3(0.007 * cos(a) - 0.007, -0.007 * sin(a) * 0.2, 0.004 + 0.007 * sin(a)))
		rad.append(0.00045)
	var nm := MeshInstance3D.new()
	nm.mesh = MeshUtil.tube(pts, rad, 6)
	nm.material_override = MeshUtil.mat(Color(0.8, 0.82, 0.85), 0.2, 1.0)
	root.add_child(nm)
	var tp := MeshUtil.bezier(pts[pts.size() - 1], Vector3(-0.03, -0.01, 0.0), Vector3(-0.05, -0.02, -0.06), Vector3(-0.04, -0.03, -0.12), 14)
	var tr := PackedFloat32Array()
	tr.resize(tp.size())
	tr.fill(0.00035)
	var thread := MeshInstance3D.new()
	thread.mesh = MeshUtil.tube(tp, tr, 5)
	thread.material_override = MeshUtil.mat(Color(0.15, 0.2, 0.55), 0.5)
	root.add_child(thread)
	return root


func _thread_loop() -> Node3D:
	var root := Node3D.new()
	var tp := MeshUtil.bezier(Vector3(0, 0, 0.001), Vector3(0.02, -0.004, -0.01), Vector3(0.03, -0.01, -0.05), Vector3(0.015, -0.02, -0.1), 14)
	var tr := PackedFloat32Array()
	tr.resize(tp.size())
	tr.fill(0.0005)
	var thread := MeshInstance3D.new()
	thread.mesh = MeshUtil.tube(tp, tr, 5)
	thread.material_override = MeshUtil.mat(Color(0.93, 0.91, 0.84), 0.6)
	root.add_child(thread)
	return root


## Guéridon inox à gauche du chirurgien, avec le haricot qui recevra l'appendice.
func _build_dish() -> void:
	var base := Vector3(-0.28, 0.0, 0.62)
	var top_y := 0.98
	var brushed := MeshUtil.mat(Color(0.55, 0.57, 0.6), 0.45, 0.85)
	MeshUtil.cylinder_instance(self, 0.012, top_y, base + Vector3(0, top_y * 0.5, 0), brushed, "PiedGueridon")
	var foot := MeshUtil.cylinder_instance(self, 0.16, 0.02, base + Vector3(0, 0.03, 0), brushed, "SocleGueridon")
	(foot.mesh as CylinderMesh).top_radius = 0.12
	var plate := MeshUtil.cylinder_instance(self, 0.17, 0.012, base + Vector3(0, top_y, 0), brushed, "PlateauGueridon")
	(plate.mesh as CylinderMesh).radial_segments = 48
	# Rebord : anneau fin autour du plateau
	var rim := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.166
	tor.outer_radius = 0.176
	tor.rings = 48
	rim.mesh = tor
	rim.material_override = brushed
	rim.position = base + Vector3(0, top_y + 0.008, 0)
	add_child(rim)
	# Petit champ stérile sur le plateau
	var cloth := MeshUtil.cylinder_instance(self, 0.16, 0.002, base + Vector3(0, top_y + 0.008, 0), Tex.drape(Color(0.2, 0.4, 0.5)), "ChampGueridon")
	(cloth.mesh as CylinderMesh).radial_segments = 40
	var scene: PackedScene = load("res://assets/models/bassin.glb")
	dish = scene.instantiate()
	dish_center = base + Vector3(0, top_y + 0.02, 0)
	dish.position = base + Vector3(0, top_y + 0.009, 0)
	dish.rotation_degrees = Vector3(0, 25, 0)
	add_child(dish)


func _props() -> void:
	# Cupule (antiseptique) et seringue sur le coin du plateau, instruments de réserve sur la table arrière
	var cup: PackedScene = load("res://assets/models/cupule.glb")
	var c: Node3D = cup.instantiate()
	var side := -1.0 if MAYO_POS.z < 0.0 else 1.0
	c.position = Vector3(MAYO_POS.x + 0.17, TRAY_Y + 0.02, MAYO_POS.z + side * 0.16)
	add_child(c)
	var iod := MeshUtil.cylinder_instance(c, 0.028, 0.002, Vector3(0, 0.0, 0), MeshUtil.mat(Color(0.35, 0.12, 0.02), 0.08), "Betadine")
	iod.position = Vector3(0, 0.006, 0)
	var syr: PackedScene = load("res://assets/models/seringue.glb")
	var s: Node3D = syr.instantiate()
	s.position = Vector3(MAYO_POS.x - 0.15, TRAY_Y + 0.008, MAYO_POS.z + side * 0.17)
	s.rotation_degrees = Vector3(90, 0, 80)
	add_child(s)
