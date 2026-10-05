class_name OperatingRoom
extends Node3D
## Bloc opératoire : murs, sol, plafond à flux laminaire, éclairage, mobilier (modèles importés).

const SIZE_X := 7.0
const SIZE_Z := 6.4
const HEIGHT := 3.0
const MODELS := "res://assets/models/"

var room_shader: Shader = preload("res://shaders/room.gdshader")
var scialytique_light: SpotLight3D
var scan_label: Label3D
var clock_label: Label3D
var _clock_t := 0.0


## Table d'opération (le patient est couché dessus, tête vers +X)
const TABLE_X := -0.36


func build() -> void:
	_shell()
	_ceiling_fixtures()
	_lights()
	_furniture()
	_patient_supports()
	_environment_probe()
	_colliders()


func _room_mat(kind: int, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = room_shader
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("tint", tint)
	for t in ["floor_detail", "floor_rough", "floor_normal", "wall_detail"]:
		m.set_shader_parameter(t, Tex.get_tex(t))
	return m


func _shell() -> void:
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE_X, SIZE_Z)
	pm.subdivide_width = 4
	pm.subdivide_depth = 4
	floor_mi.mesh = pm
	floor_mi.material_override = _room_mat(0, Color(0.50, 0.60, 0.60))
	floor_mi.name = "Sol"
	add_child(floor_mi)

	var ceil := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(SIZE_X, SIZE_Z)
	cm.flip_faces = true
	ceil.mesh = cm
	ceil.position.y = HEIGHT
	ceil.material_override = _room_mat(2, Color(0.93, 0.94, 0.94))
	ceil.name = "Plafond"
	add_child(ceil)

	var wall_mat := _room_mat(1, Color(0.66, 0.78, 0.77))
	var t := 0.12
	MeshUtil.box_instance(self, Vector3(SIZE_X, HEIGHT, t), Vector3(0, HEIGHT / 2, -SIZE_Z / 2 - t / 2), wall_mat, "Mur_N")
	MeshUtil.box_instance(self, Vector3(SIZE_X, HEIGHT, t), Vector3(0, HEIGHT / 2, SIZE_Z / 2 + t / 2), wall_mat, "Mur_S")
	MeshUtil.box_instance(self, Vector3(t, HEIGHT, SIZE_Z), Vector3(-SIZE_X / 2 - t / 2, HEIGHT / 2, 0), wall_mat, "Mur_O")
	MeshUtil.box_instance(self, Vector3(t, HEIGHT, SIZE_Z), Vector3(SIZE_X / 2 + t / 2, HEIGHT / 2, 0), wall_mat, "Mur_E")

	# Plinthe à gorge (inox) et lisse de protection
	var steel := MeshUtil.mat(Color(0.75, 0.77, 0.78), 0.3, 0.9)
	for side in [-1.0, 1.0]:
		MeshUtil.box_instance(self, Vector3(SIZE_X, 0.12, 0.02), Vector3(0, 0.06, side * (SIZE_Z / 2 - 0.01)), steel, "Plinthe")
		MeshUtil.box_instance(self, Vector3(SIZE_X, 0.14, 0.03), Vector3(0, 0.95, side * (SIZE_Z / 2 - 0.015)), MeshUtil.mat(Color(0.82, 0.86, 0.86), 0.4), "Lisse")
		MeshUtil.box_instance(self, Vector3(0.02, 0.12, SIZE_Z), Vector3(side * (SIZE_X / 2 - 0.01), 0.06, 0), steel, "Plinthe")

	# Porte coulissante automatique (mur est) avec hublot
	var door := Node3D.new()
	door.name = "Porte"
	door.position = Vector3(SIZE_X / 2 - 0.03, 0, 1.6)
	add_child(door)
	MeshUtil.box_instance(door, Vector3(0.05, 2.2, 1.5), Vector3(0, 1.1, 0), MeshUtil.mat(Color(0.80, 0.83, 0.83), 0.35, 0.6), "Battant")
	MeshUtil.box_instance(door, Vector3(0.06, 0.45, 0.5), Vector3(0, 1.55, 0), MeshUtil.mat(Color(0.12, 0.16, 0.18), 0.05, 0.0), "Hublot")
	MeshUtil.box_instance(door, Vector3(0.07, 0.04, 1.6), Vector3(0, 2.24, 0), steel, "Rail")
	var sign_lbl := Label3D.new()
	sign_lbl.text = "DÉCHOCAGE"
	sign_lbl.font_size = 64
	sign_lbl.pixel_size = 0.0015
	sign_lbl.modulate = Color(0.85, 0.95, 0.95)
	sign_lbl.position = Vector3(-0.04, 2.45, 0)
	sign_lbl.rotation_degrees = Vector3(0, -90, 0)
	door.add_child(sign_lbl)

	# Armoires murales vitrées (mur nord)
	for i in 3:
		var x := -2.4 + i * 1.0
		var cab := Node3D.new()
		cab.position = Vector3(x, 0, -SIZE_Z / 2 + 0.25)
		add_child(cab)
		MeshUtil.box_instance(cab, Vector3(0.95, 2.0, 0.45), Vector3(0, 1.0, 0), MeshUtil.mat(Color(0.88, 0.9, 0.9), 0.35, 0.2), "Armoire")
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.6, 0.75, 0.8, 0.25)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.05
		glass.metallic_specular = 0.9
		MeshUtil.box_instance(cab, Vector3(0.88, 1.2, 0.01), Vector3(0, 1.35, 0.23), glass, "Vitre")
		for s in 3:
			MeshUtil.box_instance(cab, Vector3(0.85, 0.015, 0.38), Vector3(0, 0.95 + s * 0.4, 0), MeshUtil.mat(Color(0.95, 0.95, 0.95), 0.5), "Etagere")
			for b in 6:
				var hue: Color = [Color(0.85, 0.85, 0.9), Color(0.3, 0.55, 0.8), Color(0.9, 0.9, 0.95), Color(0.95, 0.75, 0.3)][(b + s + i) % 4]
				MeshUtil.box_instance(cab, Vector3(0.1, 0.18, 0.25), Vector3(-0.33 + b * 0.13, 1.05 + s * 0.4, 0), MeshUtil.mat(hue, 0.6), "Boite")

	# Négatoscope (radiographie du patient) sur le mur nord, face au joueur
	var neg := Node3D.new()
	neg.position = Vector3(0.95, 1.6, -SIZE_Z / 2 + 0.06)
	neg.rotation_degrees.y = 0
	add_child(neg)
	MeshUtil.box_instance(neg, Vector3(1.1, 0.5, 0.06), Vector3.ZERO, MeshUtil.mat(Color(0.9, 0.9, 0.9), 0.4), "Negatoscope")
	MeshUtil.box_instance(neg, Vector3(1.0, 0.42, 0.01), Vector3(0, 0, 0.035), MeshUtil.emissive(Color(0.75, 0.82, 0.9), 1.2), "Ecran")
	# Radiographie du patient sur le négatoscope
	var film := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.38, 0.4)
	film.mesh = fq
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_texture = load("res://assets/textures/radio_thorax.png")
	fm.albedo_color = Color(1.25, 1.3, 1.35)
	film.material_override = fm
	film.position = Vector3(-0.28, 0, 0.042)
	neg.add_child(film)
	var scan := Label3D.new()
	scan_label = scan
	scan.text = "RADIO THORAX\nPneumothorax droit"
	scan.font_size = 30
	scan.pixel_size = 0.0012
	scan.modulate = Color(0.1, 0.12, 0.15)
	scan.outline_size = 0
	scan.position = Vector3(0.22, 0, 0.045)
	neg.add_child(scan)

	# Horloge murale (mur sud)
	var clock := Label3D.new()
	clock.name = "Horloge"
	clock_label = clock
	clock.text = "08:42"
	clock.font_size = 96
	clock.pixel_size = 0.002
	clock.modulate = Color(1.0, 0.25, 0.2)
	clock.position = Vector3(-1.2, 2.45, SIZE_Z / 2 - 0.02)
	clock.rotation_degrees.y = 180
	add_child(clock)
	MeshUtil.box_instance(self, Vector3(0.5, 0.2, 0.03), Vector3(-1.2, 2.45, SIZE_Z / 2 - 0.005), MeshUtil.mat(Color(0.05, 0.05, 0.06), 0.3), "Cadran")


func _ceiling_fixtures() -> void:
	# Plafond soufflant à flux laminaire au-dessus de la table
	var frame := MeshUtil.mat(Color(0.92, 0.93, 0.94), 0.35, 0.3)
	MeshUtil.box_instance(self, Vector3(2.6, 0.08, 2.0), Vector3(TABLE_X, HEIGHT - 0.04, 0), frame, "FluxLaminaire")
	for i in 2:
		for j in 2:
			MeshUtil.box_instance(self, Vector3(1.15, 0.01, 0.85), Vector3(TABLE_X - 0.62 + i * 1.24, HEIGHT - 0.085, -0.46 + j * 0.92), MeshUtil.emissive(Color(0.96, 0.98, 1.0), 0.9), "Diffuseur")
	# Dalles lumineuses de la salle
	for p in [Vector3(-2.3, 0, -1.8), Vector3(2.3, 0, -1.8), Vector3(-2.3, 0, 1.8), Vector3(2.3, 0, 1.8)]:
		MeshUtil.box_instance(self, Vector3(1.2, 0.03, 0.6), Vector3(p.x, HEIGHT - 0.02, p.z), MeshUtil.emissive(Color(0.97, 0.98, 1.0), 1.1), "Dalle")


func _lights() -> void:
	# Lumière du flux laminaire : large, douce, ombres légères
	var lam := SpotLight3D.new()
	lam.name = "LumiereLaminaire"
	lam.position = Vector3(TABLE_X, HEIGHT - 0.12, 0)
	lam.rotation_degrees = Vector3(-90, 0, 0)
	lam.spot_angle = 38
	lam.spot_range = 4.0
	lam.light_energy = 0.9
	lam.light_color = Color(0.95, 0.98, 1.0)
	lam.shadow_enabled = true
	lam.light_size = 1.2
	lam.shadow_bias = 0.05
	# Pas de reflet direct : avec une source aussi large, le reflet calculé par le moteur couvre
	# toute surface lisse d'un voile blanc. Les dalles se reflètent via la sonde de reflets.
	lam.light_specular = 0.0
	add_child(lam)

	# Éclairage général de la salle
	for p in [Vector3(-2.3, 0, -1.8), Vector3(2.3, 0, -1.8), Vector3(-2.3, 0, 1.8), Vector3(2.3, 0, 1.8)]:
		var l := SpotLight3D.new()
		l.position = Vector3(p.x, HEIGHT - 0.06, p.z)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.spot_angle = 75
		l.spot_range = 4.0
		l.light_energy = 0.75
		l.light_color = Color(0.96, 0.98, 1.0)
		add_child(l)

	# Scialytique : faisceau blanc intense sur le champ opératoire (deux coupoles)
	scialytique_light = SpotLight3D.new()
	scialytique_light.name = "Scialytique"
	add_child(scialytique_light)
	scialytique_light.look_at_from_position(Vector3(-0.05, 2.25, 0.35), Vector3(0.0, 1.3, 0.0))
	scialytique_light.spot_angle = 24
	scialytique_light.spot_angle_attenuation = 0.6
	scialytique_light.spot_range = 3.0
	scialytique_light.light_energy = 0.75
	scialytique_light.light_color = Color(1.0, 0.97, 0.93)
	scialytique_light.shadow_enabled = true
	scialytique_light.light_size = 0.12
	scialytique_light.shadow_bias = 0.08
	scialytique_light.shadow_normal_bias = 2.5
	scialytique_light.light_specular = 0.5
	var second := SpotLight3D.new()
	second.name = "Scialytique2"
	second.position = Vector3(0.4, 2.2, -0.3)
	add_child(second)
	second.look_at_from_position(second.position, Vector3(0.0, 1.3, 0.0))
	second.spot_angle = 20
	second.spot_range = 3.0
	second.light_energy = 0.4
	second.light_color = Color(0.98, 0.98, 1.0)
	second.shadow_enabled = false


func _place(file: String, pos: Vector3, yaw_deg := 0.0, scale := 1.0) -> Node3D:
	var res: PackedScene = load(MODELS + file + ".glb")
	if res == null:
		push_warning("Modèle manquant : " + file)
		return null
	var n: Node3D = res.instantiate()
	n.name = file
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	n.scale = Vector3.ONE * scale
	add_child(n)
	return n


func _furniture() -> void:
	var table := _place("table_operation", Vector3(TABLE_X, 0, 0))
	# Table abaissée pour la position latérale (dessus à 0,80 m)
	table.scale = Vector3(1.0, Patient.TABLE_TOP / 0.96, 1.0)
	_place("table_sterile_2", Vector3(0.25, 0, 1.75), 90)
	_place("table_sterile_1", Vector3(-1.9, 0, 2.6), 0)
	_place("table_sterile_3", Vector3(2.4, 0, -1.2), 90)
	_place("chariot_pharmacie", Vector3(-2.7, 0, -2.6), 0)
	_place("chariot_inox", Vector3(1.6, 0, -2.75), 0)
	_place("chariot", Vector3(-1.75, 0, 1.0), 90)
	_place("perfusion", Vector3(0.95, 0, -0.62))
	_place("tabouret", Vector3(1.0, 0, 1.1))
	_place("lavabo", Vector3(1.4, 0, SIZE_Z / 2 - 0.45), 180)
	_place("paravent", Vector3(2.9, 0, 0.2), 90)
	var lamp := _place("scialytique", Vector3(0.05, HEIGHT - 1.05, 0.2), 0)
	# La coupole ne doit pas faire d'ombre à sa propre lumière
	for mi in lamp.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Coupole moins éblouissante : inox satiné plutôt que blanc pur
	for mi in lamp.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var src := m3.mesh.surface_get_material(i) as StandardMaterial3D
			if src:
				var dup := src.duplicate() as StandardMaterial3D
				dup.albedo_color = Color(0.62, 0.64, 0.66)
				dup.roughness = 0.45
				m3.set_surface_override_material(i, dup)
	_anesthesia_station()


## Poste d'anesthésie simplifié à la tête du patient (machine, arceau).
func _anesthesia_station() -> void:
	var st := Node3D.new()
	st.name = "Anesthesie"
	st.position = Vector3(1.45, 0, -0.2)
	st.rotation_degrees.y = -90
	add_child(st)
	var body := MeshUtil.mat(Color(0.86, 0.88, 0.9), 0.35, 0.1)
	var dark := MeshUtil.mat(Color(0.12, 0.13, 0.15), 0.4)
	MeshUtil.box_instance(st, Vector3(0.75, 0.9, 0.6), Vector3(0, 0.55, 0), body, "Corps")
	MeshUtil.box_instance(st, Vector3(0.7, 0.05, 0.55), Vector3(0, 1.02, 0), MeshUtil.mat(Color(0.8, 0.82, 0.84), 0.3, 0.5), "Plan")
	MeshUtil.box_instance(st, Vector3(0.6, 0.5, 0.25), Vector3(0, 1.32, -0.15), body, "Tete")
	MeshUtil.box_instance(st, Vector3(0.5, 0.32, 0.02), Vector3(0, 1.36, -0.02), dark, "Ecran")
	MeshUtil.cylinder_instance(st, 0.07, 0.25, Vector3(0.28, 1.2, 0.18), MeshUtil.mat(Color(0.75, 0.82, 0.9, 1), 0.2), "Soufflet")
	for i in 4:
		MeshUtil.cylinder_instance(st, 0.025, 0.04, Vector3(-0.08 * i + 0.1, 0.12, 0.25), dark, "Roue")
	for i in 3:
		MeshUtil.box_instance(st, Vector3(0.68, 0.02, 0.01), Vector3(0, 0.3 + i * 0.22, 0.301), dark, "Tiroir")


## Coussin sous la tête (position latérale), appui-bras sous le bras droit levé.
func _patient_supports() -> void:
	# Matelas à dépression moulé sous le corps (décubitus latéral), planche à bras fixée au rail et
	# coussin de gel sous l'avant-bras gauche : modelés dans Blender d'après le dessous du corps.
	var sup := _place("matelas", Vector3.ZERO)
	if sup:
		sup.name = "Supports"
		var vinyl := StandardMaterial3D.new()
		vinyl.albedo_color = Color(0.09, 0.15, 0.24)
		vinyl.roughness = 0.42
		vinyl.normal_enabled = true
		vinyl.normal_texture = Tex.get_tex("fabric_normal")
		vinyl.normal_scale = 0.35
		vinyl.uv1_triplanar = true
		vinyl.uv1_scale = Vector3(6, 6, 6)
		var gel := MeshUtil.mat(Color(0.16, 0.42, 0.62), 0.22)
		gel.clearcoat_enabled = true
		gel.clearcoat = 0.5
		var board := MeshUtil.mat(Color(0.07, 0.075, 0.085), 0.62)
		var clamp_mat := MeshUtil.mat(Color(0.78, 0.8, 0.82), 0.25, 0.9)
		for mi in sup.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var n := String(g.name)
			g.material_override = vinyl if n == "Matelas" else (gel if n == "CoussinBras" else (board if n == "Planche" else clamp_mat))
	# Têtière en mousse (housse vinyle gris-bleu) sous la tête, en position latérale
	var foam := MeshUtil.mat(Color(0.18, 0.22, 0.27), 0.55)
	var pillow := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.25, 0.30)
	pillow.mesh = bm
	pillow.material_override = foam
	pillow.position = Vector3(0.43, Patient.TABLE_TOP + 0.125, -0.01)
	pillow.name = "Tetiere"
	add_child(pillow)
	# Bourrelet arrondi du bord supérieur (la housse est rebondie)
	for zz in [-0.16, 0.14]:
		var edge := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.02
		cm.height = 0.28
		edge.mesh = cm
		edge.material_override = foam
		edge.rotation_degrees.z = 90
		edge.position = Vector3(0.43, Patient.TABLE_TOP + 0.23, zz)
		add_child(edge)
	# Appui-bras : coussin de gel sous le coude et l'avant-bras droit (il en épouse le dessous), sur
	# une tige fixée au rail de la table
	var arm := Node3D.new()
	arm.name = "AppuiBras"
	add_child(arm)
	var gel := MeshUtil.mat(Color(0.16, 0.42, 0.62), 0.22)
	gel.clearcoat_enabled = true
	gel.clearcoat = 0.5
	var pad := MeshInstance3D.new()
	pad.name = "Gouttiere"
	pad.mesh = _forearm_pad()
	pad.material_override = gel
	arm.add_child(pad)
	var steel := MeshUtil.mat(Color(0.78, 0.8, 0.82), 0.25, 0.9)
	var pole_x := 0.42
	MeshUtil.cylinder_instance(arm, 0.012, 1.52 - Patient.TABLE_TOP, Vector3(pole_x, (1.52 + Patient.TABLE_TOP) * 0.5, -0.27), steel, "Tige")
	var bar := MeshUtil.cylinder_instance(arm, 0.01, 0.26, Vector3(pole_x, 1.52, -0.14), steel, "Bras")
	bar.rotation_degrees.x = 90


## Coussin allongé (section arrondie, bouts effilés) dont le dessus suit le dessous de l'avant-bras
## droit levé, mesuré sur le modèle tous les 10 % de l'axe coude -> poignet.
func _forearm_pad() -> ArrayMesh:
	var a := Vector3(0.30, 0.0, -0.045)
	var b := Vector3(0.52, 0.0, 0.025)
	var under := [1.4358, 1.4502, 1.4781, 1.4984, 1.5142, 1.5261, 1.5420, 1.5609, 1.5830, 1.6003, 1.6140, 1.6259, 1.6375, 1.6426]
	var t0 := -0.15
	var dt := 0.1
	var half_w := 0.05
	var half_h := 0.016
	var n := 40
	var ring := 14
	var path: Array[Vector3] = []
	for k in n + 1:
		var t := lerpf(-0.12, 1.12, float(k) / n)
		var f := clampf((t - t0) / dt, 0.0, under.size() - 1.001)
		var i := int(f)
		var y: float = lerpf(under[i], under[i + 1], f - i)
		var p := a.lerp(b, t)
		path.append(Vector3(p.x, y - 0.004 - half_h, p.z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n + 1:
		var tan := (path[mini(k + 1, n)] - path[maxi(k - 1, 0)]).normalized()
		var side := tan.cross(Vector3.UP).normalized()
		var up := side.cross(tan).normalized()
		var u := float(k) / n
		var taper := sqrt(clampf(minf(u, 1.0 - u) / 0.07, 0.0, 1.0))
		for r in ring:
			var ang := TAU * r / ring
			# Section en coussin : plus large que haute, coins arrondis
			var c := cos(ang)
			var sn := sin(ang)
			var off := side * signf(c) * pow(absf(c), 0.6) * half_w + up * signf(sn) * pow(absf(sn), 0.6) * half_h
			st.add_vertex(path[k] + off * maxf(taper, 0.02))
	for k in n:
		for r in ring:
			var i0 := k * ring + r
			var i1 := k * ring + (r + 1) % ring
			var j0 := i0 + ring
			var j1 := i1 + ring
			# Sens horaire vu de l'extérieur (faces avant dans Godot)
			st.add_index(i0)
			st.add_index(i1)
			st.add_index(j0)
			st.add_index(i1)
			st.add_index(j1)
			st.add_index(j0)
	st.generate_normals()
	return st.commit()


## Murs et meubles solides pour le joueur.
func _colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "Solides"
	add_child(body)
	var add_box := func(center: Vector3, size: Vector3) -> void:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		cs.position = center
		body.add_child(cs)
	var t := 0.3
	add_box.call(Vector3(0, HEIGHT / 2, -SIZE_Z / 2 - t / 2), Vector3(SIZE_X, HEIGHT, t))
	add_box.call(Vector3(0, HEIGHT / 2, SIZE_Z / 2 + t / 2), Vector3(SIZE_X, HEIGHT, t))
	add_box.call(Vector3(-SIZE_X / 2 - t / 2, HEIGHT / 2, 0), Vector3(t, HEIGHT, SIZE_Z))
	add_box.call(Vector3(SIZE_X / 2 + t / 2, HEIGHT / 2, 0), Vector3(t, HEIGHT, SIZE_Z))
	add_box.call(Vector3(0, -0.05, 0), Vector3(SIZE_X, 0.1, SIZE_Z))
	# Table + patient (on peut s'en approcher à ~25 cm)
	add_box.call(Vector3(TABLE_X, 0.7, 0), Vector3(2.15, 1.4, 0.72))
	# Planche à bras qui dépasse de la table côté joueur
	var sup := get_node_or_null("Supports")
	if sup:
		for mi in sup.find_children("Planche", "MeshInstance3D", true, false):
			var pb := _world_aabb(mi)
			add_box.call(Vector3(pb.get_center().x, 0.45, pb.get_center().z), Vector3(pb.size.x, 0.9, pb.size.z))
	# Meubles : boîte englobante de chaque modèle
	for n in get_children():
		if n is Node3D and String(n.name) in ["table_sterile_1", "table_sterile_2", "table_sterile_3", "chariot_pharmacie", "chariot_inox", "chariot", "lavabo", "paravent", "Anesthesie", "tabouret", "perfusion"]:
			var box := _world_aabb(n)
			if box.size.length() > 0.01:
				add_box.call(box.get_center(), box.size)


func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var b := g.global_transform * g.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	if n is MeshInstance3D:
		var g2 := n as MeshInstance3D
		out = g2.global_transform * g2.get_aabb() if first else out.merge(g2.global_transform * g2.get_aabb())
	return out


func _environment_probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "Reflets"
	probe.size = Vector3(SIZE_X, HEIGHT, SIZE_Z)
	probe.position = Vector3(0, HEIGHT / 2, 0)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.55, 0.62, 0.64)
	probe.ambient_color_energy = 0.5
	probe.intensity = 0.25
	add_child(probe)


## Horloge murale : l'heure réelle (mise à jour toutes les 10 s).
func _process(delta: float) -> void:
	_clock_t -= delta
	if _clock_t <= 0.0 and clock_label:
		_clock_t = 10.0
		var t := Time.get_time_dict_from_system()
		clock_label.text = "%02d:%02d" % [t.hour, t.minute]
