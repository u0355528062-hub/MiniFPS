class_name InstrumentTray
extends Node3D
## Table de Mayo avec champ stérile et instruments rangés, haricot posé sur les jambes du patient.

const MAYO_POS := Vector3(0.62, 0.0, 0.56)
const TRAY_Y := 1.004

## id, nom affiché, fichier, roulis (pour poser à plat), longueur visée (0 = taille réelle)
const CATALOG := [
	["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
	["bistouri", "Bistouri lame 15", "manche_bistouri", 0.0, 0.0],
	["langenbeck", "Écarteur de Langenbeck", "ecarteur_langenbeck", 0.0, 0.0],
	["roux", "Écarteur de Roux", "ecarteur_roux", 0.0, 0.0],
	["debakey", "Pince De Bakey", "pince_debakey", 90.0, 0.0],
	["overholt", "Overholt + fil de ligature", "clamp_overholt", 0.0, 0.0],
	["ciseaux", "Ciseaux de Metzenbaum", "ciseaux_metzenbaum", 0.0, 0.19],
	["porte_aiguille", "Porte-aiguille + fil", "porte_aiguille", 0.0, 0.19],
]

var instruments: Dictionary = {}  # id -> Instrument
var ordered: Array[Instrument] = []
var dish: Node3D
var dish_center: Vector3

var _steel := MeshUtil.mat(Color(0.86, 0.88, 0.9), 0.18, 1.0)


func build() -> void:
	var mayo: PackedScene = load("res://assets/models/table_mayo.glb")
	var m: Node3D = mayo.instantiate()
	m.position = MAYO_POS
	add_child(m)

	# Champ stérile bleu-vert sur le plateau
	var drape := Tex.drape(Color(0.2, 0.4, 0.5))
	var cloth := MeshInstance3D.new()
	cloth.mesh = MeshUtil.height_grid(MAYO_POS.x - 0.26, MAYO_POS.z - 0.22, 0.52, 0.44, 30, 26, func(x: float, z: float) -> float:
		var ex := maxf(absf(x - MAYO_POS.x) - 0.235, 0.0)
		var ez := maxf(absf(z - MAYO_POS.z) - 0.195, 0.0)
		var e := maxf(ex, ez)
		return TRAY_Y - 0.003 - e * 2.6 + 0.0008 * sin(x * 140.0) * sin(z * 90.0))
	cloth.material_override = drape
	add_child(cloth)

	var n := CATALOG.size()
	for i in n:
		var c: Array = CATALOG[i]
		var inst := Instrument.create(c[0], c[1], c[2], c[3], c[4])
		add_child(inst)
		_decorate(inst)
		var x := MAYO_POS.x - 0.2 + 0.4 * i / (n - 1)
		# À plat, pointe vers la table d'opération (-Z), légèrement en éventail
		var b := Basis(Vector3.UP, PI + deg_to_rad((i - n * 0.5) * 1.5))
		var half := inst.length * 0.5
		inst.tray_transform = Transform3D(b, Vector3(x, TRAY_Y + 0.006, MAYO_POS.z + 0.01 - (0.2 - half) * 0.15))
		inst.global_transform = inst.tray_transform
		instruments[inst.id] = inst
		ordered.append(inst)

	_build_dish()
	_props()


## Pièces procédurales au bout de certains instruments.
func _decorate(inst: Instrument) -> void:
	match inst.id:
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
	# Lame n°15 : contour dans le plan XZ, ventre arrondi côté -X, très fine
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
				st.set_normal(Vector3(0, side, 0))
				st.add_vertex(Vector3(p.x, side * 0.0002, p.y))
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
	var brushed := MeshUtil.mat(Color(0.62, 0.64, 0.66), 0.38, 0.9)
	MeshUtil.cylinder_instance(self, 0.012, top_y, base + Vector3(0, top_y * 0.5, 0), brushed, "PiedGueridon")
	var foot := MeshUtil.cylinder_instance(self, 0.16, 0.02, base + Vector3(0, 0.03, 0), brushed, "SocleGueridon")
	(foot.mesh as CylinderMesh).top_radius = 0.12
	var plate := MeshUtil.cylinder_instance(self, 0.17, 0.012, base + Vector3(0, top_y, 0), brushed, "PlateauGueridon")
	(plate.mesh as CylinderMesh).radial_segments = 48
	var rim := MeshUtil.cylinder_instance(self, 0.172, 0.02, base + Vector3(0, top_y + 0.012, 0), brushed, "RebordGueridon")
	(rim.mesh as CylinderMesh).top_radius = 0.175
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
	c.position = Vector3(MAYO_POS.x + 0.17, TRAY_Y + 0.02, MAYO_POS.z + 0.16)
	add_child(c)
	var iod := MeshUtil.cylinder_instance(c, 0.028, 0.002, Vector3(0, 0.0, 0), MeshUtil.mat(Color(0.35, 0.12, 0.02), 0.08), "Betadine")
	iod.position = Vector3(0, 0.006, 0)
	var syr: PackedScene = load("res://assets/models/seringue.glb")
	var s: Node3D = syr.instantiate()
	s.position = Vector3(MAYO_POS.x - 0.15, TRAY_Y + 0.008, MAYO_POS.z + 0.17)
	s.rotation_degrees = Vector3(90, 0, 80)
	add_child(s)
