class_name CecMachine
extends Node3D
## Machine de circulation extracorporelle (cœur-poumon artificiel) du perfusionniste : console sur
## roulettes, cinq pompes à galets sous capot transparent, mât avec réservoir veineux (sang sombre)
## et oxygénateur (sang rouge vif), écran de contrôle. Les pompes tournent quand la CEC marche.
## Repère : la face avant (pompes, écran) regarde vers +Z.

var flow := 0.0  ## débit (L/min) ; 0 = arrêtée
var temp := 36.8
var _rotors: Array[Node3D] = []
var _screen: Label3D
var _pump_labels: Array[Label3D] = []
var _level: MeshInstance3D
var _t := 0.0
## Points de raccordement des lignes (repère local) : sortie artérielle, retour veineux
var art_port := Vector3(0.28, 1.02, 0.12)
var ven_port := Vector3(-0.3, 1.18, 0.12)


func _init() -> void:
	var shell := MeshUtil.mat(Color(0.86, 0.88, 0.9), 0.38, 0.1)
	var dark := MeshUtil.mat(Color(0.12, 0.13, 0.15), 0.45)
	var steel := MeshUtil.mat(Color(0.75, 0.77, 0.8), 0.25, 0.9)
	var glass := CardiacModels._clear(Color(0.85, 0.92, 1.0), 0.25)
	MeshUtil.box_instance(self, Vector3(0.95, 0.62, 0.62), Vector3(0, 0.43, 0), shell, "Console")
	MeshUtil.box_instance(self, Vector3(0.97, 0.03, 0.64), Vector3(0, 0.755, 0), steel, "Plateau")
	MeshUtil.box_instance(self, Vector3(0.9, 0.04, 0.02), Vector3(0, 0.62, 0.312), dark, "Bandeau")
	for x in [-0.4, 0.4]:
		for z in [-0.25, 0.25]:
			var w := MeshUtil.cylinder_instance(self, 0.045, 0.03, Vector3(x, 0.05, z), dark, "Roue")
			w.rotation_degrees.x = 90
	# Cinq pompes à galets
	for i in 5:
		var px := -0.36 + i * 0.18
		var housing := MeshUtil.cylinder_instance(self, 0.075, 0.07, Vector3(px, 0.81, 0.06), shell, "Pompe")
		(housing.mesh as CylinderMesh).radial_segments = 32
		var lid := MeshUtil.cylinder_instance(self, 0.072, 0.045, Vector3(px, 0.87, 0.06), glass, "Capot")
		(lid.mesh as CylinderMesh).radial_segments = 32
		var rotor := Node3D.new()
		rotor.name = "Rotor"
		rotor.position = Vector3(px, 0.858, 0.06)
		add_child(rotor)
		MeshUtil.box_instance(rotor, Vector3(0.12, 0.012, 0.018), Vector3.ZERO, steel, "Bras")
		for s in [-1.0, 1.0]:
			MeshUtil.cylinder_instance(rotor, 0.012, 0.022, Vector3(s * 0.055, 0.0, 0.0), steel, "Galet")
		# Tubulure enroulée dans la pompe (sang)
		var loop := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.058
		tor.outer_radius = 0.068
		loop.mesh = tor
		loop.material_override = MeshUtil.mat(Color(0.45, 0.02, 0.04) if i < 2 else Color(0.62, 0.05, 0.05), 0.15)
		loop.position = Vector3(px, 0.852, 0.06)
		add_child(loop)
		_rotors.append(rotor)
		var lbl := Label3D.new()
		lbl.text = "0"
		lbl.font_size = 40
		lbl.pixel_size = 0.0007
		lbl.modulate = Color(0.4, 1.0, 0.6)
		lbl.outline_size = 0
		lbl.position = Vector3(px, 0.66, 0.313)
		add_child(lbl)
		_pump_labels.append(lbl)
	# Mât, réservoir veineux, oxygénateur, écran
	MeshUtil.cylinder_instance(self, 0.018, 1.2, Vector3(-0.3, 1.36, -0.12), steel, "Mat")
	MeshUtil.box_instance(self, Vector3(0.7, 0.02, 0.03), Vector3(0.0, 1.55, -0.12), steel, "Traverse")
	var res := MeshUtil.cylinder_instance(self, 0.075, 0.24, Vector3(-0.3, 1.28, 0.02), glass, "Reservoir")
	(res.mesh as CylinderMesh).radial_segments = 32
	_level = MeshUtil.cylinder_instance(self, 0.07, 0.12, Vector3(-0.3, 1.22, 0.02), MeshUtil.mat(Color(0.28, 0.01, 0.03), 0.1), "SangVeineux")
	var oxy := MeshUtil.cylinder_instance(self, 0.055, 0.15, Vector3(0.28, 1.05, 0.02), MeshUtil.mat(Color(0.75, 0.08, 0.06), 0.2), "Oxygenateur")
	(oxy.mesh as CylinderMesh).radial_segments = 32
	MeshUtil.cylinder_instance(self, 0.058, 0.03, Vector3(0.28, 1.14, 0.02), shell, "CapotOxy")
	MeshUtil.box_instance(self, Vector3(0.46, 0.3, 0.04), Vector3(0.12, 1.42, -0.1), dark, "Ecran")
	_screen = Label3D.new()
	_screen.font_size = 48
	_screen.pixel_size = 0.0008
	_screen.modulate = Color(0.55, 0.95, 1.0)
	_screen.outline_size = 0
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_screen.position = Vector3(-0.08, 1.42, -0.078)
	add_child(_screen)
	# Bouteille de gaz et panier de tubulures
	MeshUtil.cylinder_instance(self, 0.05, 0.5, Vector3(0.42, 1.0, -0.22), MeshUtil.mat(Color(0.95, 0.95, 0.95), 0.4), "Bouteille")
	_update_screen()


func _process(delta: float) -> void:
	_t += delta
	var rpm := flow * 25.0
	for i in _rotors.size():
		var k := 1.0 if i < 2 else (0.35 if flow > 0.0 else 0.0)
		_rotors[i].rotation.y += delta * rpm * k * TAU / 60.0
	_level.position.y = 1.22 + 0.006 * sin(_t * 1.3) * (1.0 if flow > 0.0 else 0.0)
	if Engine.get_process_frames() % 20 == 0:
		_update_screen()


func _update_screen() -> void:
	var on := flow > 0.0
	_screen.text = "CEC %s\nDÉBIT  %.1f L/min\nT°     %.1f °C\nPRESSION %d mmHg" % ["EN MARCHE" if on else "EN ATTENTE", flow, temp, 62 if on else 0]
	for i in _pump_labels.size():
		_pump_labels[i].text = ("%d" % int(flow * 25.0 * (1.0 if i < 2 else 0.35))) if on else "0"


## Raccords des lignes (repère monde).
func art_port_global() -> Vector3:
	return global_transform * art_port


func ven_port_global() -> Vector3:
	return global_transform * ven_port
