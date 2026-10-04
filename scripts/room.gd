class_name OperatingRoom
extends Node3D
## Bloc opératoire : murs, sol, plafond à flux laminaire, éclairage, mobilier (modèles importés).

const SIZE_X := 7.0
const SIZE_Z := 6.4
const HEIGHT := 3.0
const MODELS := "res://assets/models/"

var room_shader: Shader = preload("res://shaders/room.gdshader")
var scialytique_light: SpotLight3D


func build() -> void:
	_shell()
	_ceiling_fixtures()
	_lights()
	_furniture()
	_environment_probe()


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
	sign_lbl.text = "BLOC 2"
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

	# Négatoscope (scanner de l'appendicite) sur le mur ouest
	var neg := Node3D.new()
	neg.position = Vector3(-SIZE_X / 2 + 0.06, 1.55, 0.2)
	neg.rotation_degrees.y = 90
	add_child(neg)
	MeshUtil.box_instance(neg, Vector3(1.1, 0.5, 0.06), Vector3.ZERO, MeshUtil.mat(Color(0.9, 0.9, 0.9), 0.4), "Negatoscope")
	MeshUtil.box_instance(neg, Vector3(1.0, 0.42, 0.01), Vector3(0, 0, 0.035), MeshUtil.emissive(Color(0.75, 0.82, 0.9), 1.2), "Ecran")
	var scan := Label3D.new()
	scan.text = "SCANNER ABDOMINAL\nAppendice épaissi (11 mm)\ninfiltration de la graisse"
	scan.font_size = 40
	scan.pixel_size = 0.0012
	scan.modulate = Color(0.1, 0.12, 0.15)
	scan.outline_size = 0
	scan.position = Vector3(0, 0, 0.045)
	neg.add_child(scan)

	# Horloge murale (mur sud)
	var clock := Label3D.new()
	clock.name = "Horloge"
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
	MeshUtil.box_instance(self, Vector3(2.6, 0.08, 2.0), Vector3(0, HEIGHT - 0.04, 0), frame, "FluxLaminaire")
	for i in 2:
		for j in 2:
			MeshUtil.box_instance(self, Vector3(1.15, 0.01, 0.85), Vector3(-0.62 + i * 1.24, HEIGHT - 0.085, -0.46 + j * 0.92), MeshUtil.emissive(Color(0.96, 0.98, 1.0), 1.6), "Diffuseur")
	# Dalles lumineuses de la salle
	for p in [Vector3(-2.3, 0, -1.8), Vector3(2.3, 0, -1.8), Vector3(-2.3, 0, 1.8), Vector3(2.3, 0, 1.8)]:
		MeshUtil.box_instance(self, Vector3(1.2, 0.03, 0.6), Vector3(p.x, HEIGHT - 0.02, p.z), MeshUtil.emissive(Color(0.97, 0.98, 1.0), 2.0), "Dalle")


func _lights() -> void:
	# Lumière du flux laminaire : large, douce, ombres légères
	var lam := SpotLight3D.new()
	lam.name = "LumiereLaminaire"
	lam.position = Vector3(0, HEIGHT - 0.12, 0)
	lam.rotation_degrees = Vector3(-90, 0, 0)
	lam.spot_angle = 38
	lam.spot_range = 4.0
	lam.light_energy = 0.8
	lam.light_color = Color(0.95, 0.98, 1.0)
	lam.shadow_enabled = true
	lam.light_size = 0.6
	lam.shadow_blur = 1.5
	lam.shadow_bias = 0.08
	lam.shadow_normal_bias = 2.5
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
	scialytique_light.look_at_from_position(Vector3(0.05, 1.95, 0.3), Vector3(0.12, 1.1, 0.1))
	scialytique_light.spot_angle = 24
	scialytique_light.spot_angle_attenuation = 0.6
	scialytique_light.spot_range = 3.0
	scialytique_light.light_energy = 0.8
	scialytique_light.light_color = Color(1.0, 0.97, 0.93)
	scialytique_light.shadow_enabled = true
	scialytique_light.light_size = 0.25
	scialytique_light.shadow_bias = 0.08
	scialytique_light.shadow_normal_bias = 2.5
	scialytique_light.light_specular = 0.6
	var second := SpotLight3D.new()
	second.name = "Scialytique2"
	second.position = Vector3(0.45, 1.9, -0.2)
	add_child(second)
	second.look_at_from_position(second.position, Vector3(0.12, 1.1, 0.1))
	second.spot_angle = 18
	second.spot_range = 3.0
	second.light_energy = 0.5
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
	_place("table_operation", Vector3.ZERO)
	_place("table_sterile_2", Vector3(0.25, 0, 1.75), 90)
	_place("table_sterile_1", Vector3(-1.9, 0, 2.6), 0)
	_place("table_sterile_3", Vector3(2.4, 0, -1.2), 90)
	_place("chariot_pharmacie", Vector3(-2.7, 0, -2.6), 0)
	_place("chariot_inox", Vector3(1.6, 0, -2.75), 0)
	_place("chariot", Vector3(-1.75, 0, 1.0), 90)
	_place("perfusion", Vector3(-1.05, 0, -0.55))
	_place("tabouret", Vector3(1.0, 0, 1.1))
	_place("lavabo", Vector3(1.4, 0, SIZE_Z / 2 - 0.45), 180)
	_place("paravent", Vector3(2.9, 0, 0.2), 90)
	var lamp := _place("scialytique", Vector3(0.1, HEIGHT - 1.3, 0.1), 0)
	# La coupole ne doit pas faire d'ombre à sa propre lumière
	for mi in lamp.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anesthesia_station()


## Poste d'anesthésie simplifié à la tête du patient (machine, arceau).
func _anesthesia_station() -> void:
	var st := Node3D.new()
	st.name = "Anesthesie"
	st.position = Vector3(-1.45, 0, -0.35)
	st.rotation_degrees.y = 90
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
	probe.intensity = 0.45
	add_child(probe)
