class_name ERRoom
extends Node3D
## Salle de déchocage des urgences : brancard au centre (tête contre la rampe murale de gaz), bras
## plafonnier avec le scope, chariot d'urgence et défibrillateur à droite du soignant,
## électrocardiographe, armoire de matériel, poste informatique, lavabo, distributeurs de gants et de
## solution hydro-alcoolique, écran d'imagerie, porte coulissante vers le couloir.

const X0 := -3.0
const X1 := 1.6
const Z0 := -2.4
const Z1 := 2.6
const HEIGHT := 2.9
const M := "res://assets/models/"

var room_shader: Shader = preload("res://shaders/room.gdshader")
var defib_root: Node3D
var monitor_anchor := Transform3D.IDENTITY
var ecg_root: Node3D
var computer_screen: MeshInstance3D
var imaging_screen: MeshInstance3D
var clock_label: Label3D
var _clock_t := 0.0
var _solids: StaticBody3D


func build() -> void:
	_solids = StaticBody3D.new()
	_solids.name = "Solides"
	add_child(_solids)
	_shell()
	_lights()
	_equipment()
	_probe()


func _room_mat(kind: int, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = room_shader
	m.set_shader_parameter("kind", kind)
	m.set_shader_parameter("tint", tint)
	for t in ["floor_detail", "floor_rough", "floor_normal", "wall_detail"]:
		m.set_shader_parameter(t, Tex.get_tex(t))
	return m


func _solid(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	_solids.add_child(cs)


func _place(file: String, pos: Vector3, yaw_deg := 0.0, solid := true) -> Node3D:
	var res: PackedScene = load(M + file + ".glb")
	if res == null:
		push_warning("Modèle manquant : " + file)
		return null
	var n: Node3D = res.instantiate()
	n.name = file
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	if solid:
		var box := _world_aabb(n)
		if box.size.length() > 0.01:
			_solid(box.get_center(), box.size)
	return n


func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var b := g.global_transform * g.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# ---------------------------------------------------------------- Murs, sol, plafond

func _shell() -> void:
	var sx := X1 - X0
	var sz := Z1 - Z0
	var cx := (X0 + X1) * 0.5
	var cz := (Z0 + Z1) * 0.5
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sx, sz)
	floor_mi.mesh = pm
	floor_mi.position = Vector3(cx, 0, cz)
	floor_mi.material_override = _room_mat(0, Color(0.62, 0.64, 0.62))
	floor_mi.name = "Sol"
	add_child(floor_mi)
	var ceil := MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(sx, sz)
	cm.flip_faces = true
	ceil.mesh = cm
	ceil.position = Vector3(cx, HEIGHT, cz)
	ceil.material_override = _room_mat(2, Color(0.93, 0.94, 0.94))
	ceil.name = "Plafond"
	add_child(ceil)
	var wall := _room_mat(1, Color(0.80, 0.84, 0.85))
	var t := 0.12
	MeshUtil.box_instance(self, Vector3(sx, HEIGHT, t), Vector3(cx, HEIGHT / 2, Z0 - t / 2), wall, "Mur_N")
	MeshUtil.box_instance(self, Vector3(sx, HEIGHT, t), Vector3(cx, HEIGHT / 2, Z1 + t / 2), wall, "Mur_S")
	MeshUtil.box_instance(self, Vector3(t, HEIGHT, sz), Vector3(X0 - t / 2, HEIGHT / 2, cz), wall, "Mur_O")
	MeshUtil.box_instance(self, Vector3(t, HEIGHT, sz), Vector3(X1 + t / 2, HEIGHT / 2, cz), wall, "Mur_E")
	_solid(Vector3(cx, HEIGHT / 2, Z0 - 0.15), Vector3(sx, HEIGHT, 0.3))
	_solid(Vector3(cx, HEIGHT / 2, Z1 + 0.15), Vector3(sx, HEIGHT, 0.3))
	_solid(Vector3(X0 - 0.15, HEIGHT / 2, cz), Vector3(0.3, HEIGHT, sz))
	_solid(Vector3(X1 + 0.15, HEIGHT / 2, cz), Vector3(0.3, HEIGHT, sz))
	_solid(Vector3(cx, -0.05, cz), Vector3(sx, 0.1, sz))
	# Soubassement de protection (stratifié bleu) et lisse anti-chocs
	var guard := MeshUtil.mat(Color(0.28, 0.42, 0.55), 0.45)
	var rail := MeshUtil.mat(Color(0.88, 0.89, 0.9), 0.35)
	var steel := MeshUtil.mat(Color(0.75, 0.77, 0.78), 0.3, 0.9)
	for side in [-1.0, 1.0]:
		var z: float = Z0 + 0.01 if side < 0 else Z1 - 0.01
		MeshUtil.box_instance(self, Vector3(sx, 0.1, 0.02), Vector3(cx, 0.05, z), steel, "Plinthe")
		MeshUtil.box_instance(self, Vector3(sx, 0.16, 0.035), Vector3(cx, 0.92, z), rail, "Lisse")
		MeshUtil.box_instance(self, Vector3(sx, 0.012, 0.03), Vector3(cx, 0.83, z), guard, "Filet")
	for x in [X0 + 0.01, X1 - 0.01]:
		MeshUtil.box_instance(self, Vector3(0.02, 0.1, sz), Vector3(x, 0.05, cz), steel, "Plinthe")
		MeshUtil.box_instance(self, Vector3(0.035, 0.16, sz), Vector3(x, 0.92, cz), rail, "Lisse")
	# Porte coulissante vitrée (mur ouest) et signalétique
	var door := Node3D.new()
	door.name = "Porte"
	door.position = Vector3(X0 + 0.03, 0, 0.6)
	add_child(door)
	var frame := MeshUtil.mat(Color(0.72, 0.74, 0.76), 0.35, 0.6)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.8, 0.85, 0.22)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	for s in [-1.0, 1.0]:
		MeshUtil.box_instance(door, Vector3(0.05, 2.2, 0.8), Vector3(0, 1.1, s * 0.41), MeshUtil.mat(Color(0.86, 0.88, 0.9), 0.35), "Battant")
		MeshUtil.box_instance(door, Vector3(0.055, 1.1, 0.5), Vector3(0, 1.45, s * 0.41), glass, "Vitre")
		MeshUtil.box_instance(door, Vector3(0.06, 0.04, 0.04), Vector3(0, 1.0, s * 0.06), steel, "Poignee")
	MeshUtil.box_instance(door, Vector3(0.08, 0.12, 1.8), Vector3(0, 2.26, 0), frame, "Caisson")
	var sign_lbl := Label3D.new()
	sign_lbl.text = "DÉCHOCAGE 1"
	sign_lbl.font_size = 64
	sign_lbl.pixel_size = 0.0016
	sign_lbl.modulate = Color(0.9, 0.97, 1.0)
	sign_lbl.outline_size = 0
	sign_lbl.position = Vector3(0.06, 2.45, 0)
	sign_lbl.rotation_degrees = Vector3(0, 90, 0)
	door.add_child(sign_lbl)
	MeshUtil.box_instance(door, Vector3(0.02, 0.16, 0.7), Vector3(0.03, 2.45, 0), MeshUtil.mat(Color(0.12, 0.3, 0.55), 0.4), "Panneau")
	# Horloge murale (mur nord)
	clock_label = Label3D.new()
	clock_label.text = "08:42"
	clock_label.font_size = 96
	clock_label.pixel_size = 0.0018
	clock_label.modulate = Color(1.0, 0.25, 0.2)
	clock_label.outline_size = 0
	clock_label.position = Vector3(-1.0, 2.4, Z0 + 0.04)
	add_child(clock_label)
	MeshUtil.box_instance(self, Vector3(0.5, 0.2, 0.03), Vector3(-1.0, 2.4, Z0 + 0.016), MeshUtil.mat(Color(0.05, 0.05, 0.06), 0.3), "Cadran")
	# Dalles lumineuses
	for p in [Vector3(-0.3, 0, -0.9), Vector3(-0.3, 0, 0.9), Vector3(-2.1, 0, -0.9), Vector3(-2.1, 0, 0.9)]:
		MeshUtil.box_instance(self, Vector3(1.2, 0.03, 0.6), Vector3(p.x, HEIGHT - 0.015, p.z), MeshUtil.emissive(Color(0.97, 0.98, 1.0), 1.4), "Dalle")
		MeshUtil.box_instance(self, Vector3(1.24, 0.02, 0.64), Vector3(p.x, HEIGHT - 0.008, p.z), MeshUtil.mat(Color(0.85, 0.86, 0.87), 0.4, 0.5), "Cadre")
	# Lampe d'examen ronde au-dessus du brancard
	var lamp := MeshUtil.cylinder_instance(self, 0.22, 0.05, Vector3(0.0, HEIGHT - 0.03, 0.0), MeshUtil.mat(Color(0.9, 0.91, 0.92), 0.35), "LampeExamen")
	(lamp.mesh as CylinderMesh).radial_segments = 48
	var lens := MeshUtil.cylinder_instance(self, 0.19, 0.01, Vector3(0.0, HEIGHT - 0.058, 0.0), MeshUtil.emissive(Color(1.0, 0.98, 0.94), 2.2), "Diffuseur")
	(lens.mesh as CylinderMesh).radial_segments = 48


func _lights() -> void:
	var exam := SpotLight3D.new()
	exam.name = "LumiereExamen"
	exam.position = Vector3(0.0, HEIGHT - 0.07, 0.0)
	exam.rotation_degrees = Vector3(-90, 0, 0)
	exam.spot_angle = 42
	exam.spot_angle_attenuation = 0.8
	exam.spot_range = 4.0
	exam.light_energy = 1.6
	exam.light_color = Color(1.0, 0.97, 0.93)
	exam.shadow_enabled = true
	exam.light_size = 0.35
	exam.shadow_bias = 0.04
	exam.light_specular = 0.5
	add_child(exam)
	var i := 0
	for p in [Vector3(-0.3, 0, -0.9), Vector3(-0.3, 0, 0.9), Vector3(-2.1, 0, -0.9), Vector3(-2.1, 0, 0.9)]:
		var l := SpotLight3D.new()
		l.position = Vector3(p.x, HEIGHT - 0.05, p.z)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.spot_angle = 80
		l.spot_angle_attenuation = 0.5
		l.spot_range = 4.5
		l.light_energy = 1.1
		l.light_color = Color(0.97, 0.98, 1.0)
		l.light_size = 0.5
		l.shadow_enabled = i < 2
		l.light_specular = 0.25
		add_child(l)
		i += 1


func _probe() -> void:
	var probe := ReflectionProbe.new()
	probe.name = "Reflets"
	probe.size = Vector3(X1 - X0, HEIGHT, Z1 - Z0)
	probe.position = Vector3((X0 + X1) * 0.5, HEIGHT / 2, (Z0 + Z1) * 0.5)
	probe.box_projection = true
	probe.interior = true
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.62, 0.66, 0.68)
	probe.ambient_color_energy = 0.55
	probe.intensity = 0.4
	add_child(probe)


# ---------------------------------------------------------------- Équipement

func _equipment() -> void:
	_place("brancard", Vector3.ZERO, 0.0, false)
	# Brancard et patient : on s'en approche à ~20 cm
	_solid(Vector3(-0.39, 0.55, 0.0), Vector3(2.2, 1.1, 0.7))
	var pendant := _place("bras_plafonnier", Vector3(1.05, 0.0, -1.2), 0.0, false)
	_solid(Vector3(1.05, 1.9, -0.65), Vector3(0.26, 1.4, 0.26))
	var scope_xf := Transform3D(Basis.IDENTITY, Vector3(0.82, 1.6, -0.62))
	scope_xf = scope_xf.looking_at(Vector3(-0.1, 1.55, 0.7), Vector3.UP, true)
	monitor_anchor = scope_xf
	PatientGear.monitor_in = Vector3(1.0, 1.3, -0.6)
	_place("rampe", Vector3(X1, 0.0, 0.0), -90.0, false)
	PatientGear.o2_out = Vector3(1.44, 1.36, -0.35)
	PatientGear.iv_bag = Vector3(0.64, 1.62, -0.31)
	# Chariot d'urgence et défibrillateur (à droite du soignant)
	_place("chariot_pharmacie", Vector3(1.0, 0.0, 0.95), -90.0)
	defib_root = _place("defibrillateur", Vector3(0.98, 1.02, 0.92), -70.0, false)
	PatientGear.defib_in = defib_root.global_transform * Vector3(0.2, 0.09, 0.05)
	ecg_root = _place("ecg", Vector3(-1.0, 0.0, 1.05), 160.0)
	_place("armoire", Vector3(-1.2, 0.0, Z0 + 0.24), 0.0)
	_place("armoire", Vector3(-2.45, 0.0, Z0 + 0.24), 0.0)
	var poste := _place("poste", Vector3(-2.1, 0.0, Z1), 180.0)
	for mi in poste.find_children("Ecran", "MeshInstance3D", true, false):
		computer_screen = mi
	_place("lavabo", Vector3(0.2, 0.0, Z1 - 0.32), 180.0)
	_place("chariot", Vector3(-2.3, 0.0, -1.2), 90.0)
	_place("tabouret", Vector3(-1.5, 0.0, 0.85), 0.0, false)
	_place("perfusion", Vector3(-0.2, 0.0, -0.75), 0.0)
	# Distributeurs muraux : gants, solution hydro-alcoolique (près du lavabo)
	var white := MeshUtil.mat(Color(0.92, 0.93, 0.94), 0.4)
	MeshUtil.box_instance(self, Vector3(0.26, 0.14, 0.09), Vector3(-0.55, 1.35, Z1 - 0.05), white, "BoiteGants")
	MeshUtil.box_instance(self, Vector3(0.24, 0.04, 0.005), Vector3(-0.55, 1.36, Z1 - 0.096), MeshUtil.mat(Color(0.2, 0.4, 0.85), 0.5), "Gants")
	MeshUtil.box_instance(self, Vector3(0.1, 0.22, 0.09), Vector3(-0.85, 1.3, Z1 - 0.05), white, "SHA")
	MeshUtil.box_instance(self, Vector3(0.06, 0.03, 0.05), Vector3(-0.85, 1.17, Z1 - 0.08), MeshUtil.mat(Color(0.15, 0.6, 0.35), 0.4), "Pompe")
	# Collecteur à aiguilles sur la rampe
	MeshUtil.box_instance(self, Vector3(0.12, 0.16, 0.1), Vector3(X1 - 0.08, 1.05, 0.62), MeshUtil.mat(Color(0.95, 0.8, 0.05), 0.4), "Collecteur")
	# Écran d'imagerie (radios) au mur nord
	var scr := Node3D.new()
	scr.name = "EcranImagerie"
	scr.position = Vector3(0.35, 1.7, Z0 + 0.04)
	add_child(scr)
	MeshUtil.box_instance(scr, Vector3(0.9, 0.56, 0.05), Vector3.ZERO, MeshUtil.mat(Color(0.06, 0.06, 0.07), 0.3), "Cadre")
	imaging_screen = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.84, 0.5)
	imaging_screen.mesh = q
	imaging_screen.position = Vector3(0, 0, 0.027)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.02, 0.025, 0.03)
	imaging_screen.material_override = sm
	scr.add_child(imaging_screen)


## Affiche une image (radiographie) sur l'écran d'imagerie.
func show_imaging(tex: Texture2D) -> void:
	var sm := imaging_screen.material_override as StandardMaterial3D
	sm.albedo_texture = tex
	sm.albedo_color = Color(1.1, 1.1, 1.1)


## Interactables de la salle (le jeu les relie à ses actions).
func add_interactables(owner_node: Node3D) -> void:
	Interactable.make(owner_node, "chariot", "Chariot d'urgence", "Ouvrir les tiroirs", Vector3(0.6, 0.95, 0.85), Vector3(1.0, 0.6, 0.95))
	Interactable.make(owner_node, "defib", "Défibrillateur", "Utiliser", Vector3(0.36, 0.3, 0.3), defib_root.global_position + Vector3(0, 0.14, 0))
	Interactable.make(owner_node, "scope", "Scope (moniteur)", "Regarder de près", Vector3(0.42, 0.32, 0.15), monitor_anchor.origin)
	Interactable.make(owner_node, "rampe", "Débitmètre d'oxygène", "Régler le débit", Vector3(0.18, 0.4, 0.2), Vector3(1.47, 1.5, -0.35))
	Interactable.make(owner_node, "ecg", "Électrocardiographe", "Utiliser", Vector3(0.45, 0.25, 0.42), ecg_root.global_position + Vector3(0, 0.92, 0))
	Interactable.make(owner_node, "poste", "Poste informatique", "Ouvrir le dossier", Vector3(0.9, 0.6, 0.5), Vector3(-2.1, 1.3, Z1 - 0.2))
	Interactable.make(owner_node, "armoire", "Armoire de matériel", "Ouvrir", Vector3(1.2, 1.9, 0.5), Vector3(-1.2, 0.95, Z0 + 0.24))
	Interactable.make(owner_node, "gants", "Gants d'examen", "Mettre des gants", Vector3(0.28, 0.16, 0.12), Vector3(-0.55, 1.35, Z1 - 0.05))
	Interactable.make(owner_node, "sha", "Solution hydro-alcoolique", "Se frictionner les mains", Vector3(0.14, 0.3, 0.12), Vector3(-0.85, 1.28, Z1 - 0.05))
	Interactable.make(owner_node, "lavabo", "Lavabo", "Se laver les mains", Vector3(1.4, 0.4, 0.6), Vector3(0.2, 0.9, Z1 - 0.32))
	Interactable.make(owner_node, "imagerie", "Écran d'imagerie", "Regarder les images", Vector3(0.9, 0.56, 0.1), Vector3(0.35, 1.7, Z0 + 0.04))


## Horloge murale : l'heure réelle.
func _process(delta: float) -> void:
	_clock_t -= delta
	if _clock_t <= 0.0 and clock_label:
		_clock_t = 10.0
		var tm := Time.get_time_dict_from_system()
		clock_label.text = "%02d:%02d" % [tm.hour, tm.minute]
