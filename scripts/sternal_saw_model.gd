class_name SternalSawModel
extends Node3D
## Scie sternale alternative : moteur dans un corps en plastique sombre, bague jaune, nez en acier,
## lame qui va et vient quand on appuie (clic), sabot de protection qui glisse sous le sternum et
## protège le cœur. Tuyau d'air comprimé à l'arrière. Pointe (bout du sabot) vers +Z.

var running := 0.0
var _blade: Node3D
var _t := 0.0


func _init() -> void:
	var body := MeshUtil.mat(Color(0.13, 0.16, 0.2), 0.42)
	var grip := MeshUtil.mat(Color(0.07, 0.08, 0.09), 0.75)
	var accent := MeshUtil.mat(Color(0.95, 0.72, 0.1), 0.35)
	var steel := MeshUtil.mat(Color(0.83, 0.85, 0.87), 0.18, 1.0)
	# Corps du moteur et poignée gainée
	var motor := MeshUtil.cylinder_instance(self, 0.021, 0.075, Vector3(0, 0, -0.072), body, "Moteur")
	motor.rotation_degrees.x = 90
	var handle := MeshUtil.cylinder_instance(self, 0.018, 0.07, Vector3(0, 0, -0.142), grip, "Poignee")
	handle.rotation_degrees.x = 90
	for k in 6:
		var rib := MeshUtil.cylinder_instance(self, 0.0188, 0.004, Vector3(0, 0, -0.118 - k * 0.01), grip, "Strie")
		rib.rotation_degrees.x = 90
	var ring := MeshUtil.cylinder_instance(self, 0.0215, 0.008, Vector3(0, 0, -0.104), accent, "Bague")
	ring.rotation_degrees.x = 90
	# Gâchette sous le corps
	MeshUtil.box_instance(self, Vector3(0.008, 0.012, 0.022), Vector3(0, -0.024, -0.09), accent, "Gachette")
	# Nez conique en acier
	var nose := MeshInstance3D.new()
	nose.name = "Nez"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0075
	cm.bottom_radius = 0.0185
	cm.height = 0.026
	cm.radial_segments = 24
	nose.mesh = cm
	nose.material_override = steel
	nose.rotation_degrees.x = 90
	nose.position = Vector3(0, 0, -0.022)
	add_child(nose)
	# Lame (va-et-vient) : plaque fine, dents sur le bord avant
	_blade = Node3D.new()
	_blade.name = "Lame"
	add_child(_blade)
	MeshUtil.box_instance(_blade, Vector3(0.0009, 0.0062, 0.03), Vector3(0, 0.0005, 0.002), steel, "Plaque")
	for k in 9:
		var tooth := MeshUtil.box_instance(_blade, Vector3(0.0011, 0.0016, 0.0016), Vector3(0, 0.0039, -0.009 + k * 0.0026), steel, "Dent")
		tooth.rotation_degrees.x = 45
	# Sabot : bande d'acier le long de la lame, qui se recourbe en avant sous sa pointe
	var pts := PackedVector3Array([Vector3(0, -0.0068, -0.012), Vector3(0, -0.0062, 0.006), Vector3(0, -0.005, 0.019),
		Vector3(0, -0.002, 0.0235), Vector3(0, 0.0025, 0.0248), Vector3(0, 0.0065, 0.0235)])
	var rr := PackedFloat32Array([0.0016, 0.0015, 0.0015, 0.0015, 0.0014, 0.0012])
	var guard := MeshInstance3D.new()
	guard.name = "Sabot"
	guard.mesh = MeshUtil.tube(pts, rr, 10)
	guard.material_override = steel
	add_child(guard)
	# Tuyau d'air comprimé qui part de l'arrière
	var hose := MeshInstance3D.new()
	hose.name = "Tuyau"
	var hp := MeshUtil.bezier(Vector3(0, 0, -0.176), Vector3(0, 0, -0.205), Vector3(0.008, 0, -0.23), Vector3(0.022, 0, -0.255), 10)
	var hr := PackedFloat32Array()
	hr.resize(hp.size())
	hr.fill(0.0055)
	hose.mesh = MeshUtil.tube(hp, hr, 12)
	hose.material_override = MeshUtil.mat(Color(0.1, 0.1, 0.11), 0.6)
	add_child(hose)


func set_squeeze(v: float) -> void:
	running = v


func _process(delta: float) -> void:
	if running > 0.5:
		_t += delta
		_blade.position.z = sin(_t * TAU * 37.0) * 0.0018
	elif _blade.position.z != 0.0:
		_blade.position.z = 0.0
