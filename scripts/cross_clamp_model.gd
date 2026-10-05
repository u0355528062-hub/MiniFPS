class_name CrossClampModel
extends Node3D
## Clamp aortique (type Fogarty) : deux branches croisées à anneaux, crémaillère de verrouillage,
## mors coudés garnis d'inserts souples bleus. Le clic serre (les mors se ferment). Pointe : +Z.

const PIVOT_Z := -0.035
var _a: Node3D
var _b: Node3D
var squeeze := 1.0


func _init() -> void:
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.85), 0.2, 1.0)
	var insert := MeshUtil.mat(Color(0.2, 0.42, 0.85), 0.5)
	_a = _branch(steel, insert, 1.0)
	_b = _branch(steel, insert, -1.0)
	# Axe de l'articulation
	var pin := MeshUtil.cylinder_instance(self, 0.0032, 0.007, Vector3(0, 0, PIVOT_Z), steel, "Axe")
	pin.rotation_degrees.z = 90
	set_squeeze(0.0)


## Une branche : anneau, tige, articulation, mors coudé (vers +Y au bout) avec insert.
func _branch(steel: Material, insert: Material, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Branche"
	pivot.position = Vector3(0, 0, PIVOT_Z)
	add_child(pivot)
	# Tige arrière, de l'articulation à l'anneau (s'écarte en X)
	var shaft := MeshUtil.bezier(Vector3(0, 0, 0), Vector3(side * 0.004, 0, -0.04), Vector3(side * 0.01, 0, -0.09), Vector3(side * 0.016, 0, -0.13), 10)
	CardiacModels._tube(pivot, shaft, 0.0024, steel, "Tige", 10)
	var ring := MeshInstance3D.new()
	ring.name = "Anneau"
	var tor := TorusMesh.new()
	tor.inner_radius = 0.0085
	tor.outer_radius = 0.0115
	ring.mesh = tor
	ring.material_override = steel
	ring.rotation_degrees.x = 90
	ring.position = Vector3(side * 0.022, 0, -0.142)
	pivot.add_child(ring)
	# Crémaillère près des anneaux
	MeshUtil.box_instance(pivot, Vector3(0.002, 0.004, 0.016), Vector3(side * 0.008, side * 0.0035, -0.11), steel, "Cran")
	# Mors : part de l'articulation, coudé à 30° vers +Y
	var jaw := MeshUtil.bezier(Vector3(0, 0, 0), Vector3(0, 0, 0.02), Vector3(0, 0.006, 0.04), Vector3(0, 0.02, 0.06), 10)
	var jm := CardiacModels._tube(pivot, jaw, 0.0021, steel, "Mors", 10)
	jm.position.x = side * 0.0022
	var pad := MeshUtil.bezier(Vector3(0, 0, 0.012), Vector3(0, 0, 0.026), Vector3(0, 0.006, 0.042), Vector3(0, 0.0185, 0.058), 8)
	var pm := CardiacModels._tube(pivot, pad, 0.0016, insert, "Insert", 8)
	pm.position.x = -side * 0.0002
	return pivot


func set_squeeze(v: float) -> void:
	squeeze = v
	# Ouvert au repos (12°), fermé quand on serre
	var a := deg_to_rad(12.0) * (1.0 - clampf(v, 0.0, 1.0))
	_a.basis = Basis(Vector3.UP, a)
	_b.basis = Basis(Vector3.UP, -a)
