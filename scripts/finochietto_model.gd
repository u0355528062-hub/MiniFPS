class_name FinochiettoModel
extends Node3D
## Écarteur à crémaillère de Finochietto. La crémaillère (le long de X) est posée en travers, au
## bout de l'incision ; deux bras parallèles à l'incision (le long de -Y) portent les valves
## courbes qui crochètent les côtes au milieu de la plaie (valves vers +Z, dans le thorax). Le
## champ reste dégagé. Une manivelle fait glisser les bras ; set_spread(d) écarte les valves de d.

const BAR_Z := -0.010  ## crémaillère et bras, au-dessus de la peau une fois posé
const BLADE_DEPTH := 0.043
const BLADE_LEN := 0.056  ## longueur des valves, le long de l'incision
const ARM_LEN := 0.062  ## de la crémaillère au milieu des valves

var spread := 0.012
var _arm_a: Node3D
var _arm_b: Node3D
var _crank: Node3D


func _init() -> void:
	var steel := _steel(Color(0.80, 0.82, 0.85), 0.16)
	var satin := _steel(Color(0.64, 0.66, 0.70), 0.34)
	# Crémaillère : barre plate, dents tournées vers les bras, butées aux deux bouts
	MeshUtil.box_instance(self, Vector3(0.15, 0.012, 0.0065), Vector3(0, ARM_LEN, BAR_Z), satin, "Cremaillere")
	for k in 34:
		MeshUtil.box_instance(self, Vector3(0.0016, 0.003, 0.0062), Vector3(-0.066 + k * 0.004, ARM_LEN - 0.0072, BAR_Z), steel, "Dent")
	for sx in [-1.0, 1.0]:
		MeshUtil.box_instance(self, Vector3(0.006, 0.018, 0.009), Vector3(sx * 0.073, ARM_LEN, BAR_Z), satin, "Butee")
	_arm_a = _arm(steel, satin, -1.0)
	_arm_b = _arm(steel, satin, 1.0)
	# Manivelle sur le chariot du bras mobile : moyeu, bras, poignée noire verticale
	_crank = Node3D.new()
	_crank.name = "Manivelle"
	_crank.position = Vector3(0, ARM_LEN, BAR_Z - 0.0095)
	_arm_b.add_child(_crank)
	var hub := MeshUtil.cylinder_instance(_crank, 0.0068, 0.008, Vector3.ZERO, steel, "Moyeu")
	hub.rotation_degrees.x = 90
	MeshUtil.box_instance(_crank, Vector3(0.03, 0.0048, 0.003), Vector3(0.013, 0, -0.0045), steel, "BrasManivelle")
	var grip := MeshUtil.cylinder_instance(_crank, 0.0045, 0.02, Vector3(0.026, 0, -0.015), MeshUtil.mat(Color(0.11, 0.12, 0.13), 0.42), "Poignee")
	grip.rotation_degrees.x = 90
	set_spread(spread)


static func _steel(c: Color, rough: float) -> StandardMaterial3D:
	var m := MeshUtil.mat(c, rough, 1.0)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Un bras : chariot sur la crémaillère, bras le long de l'incision, valve courbe à son bout.
func _arm(steel: Material, satin: Material, side: float) -> Node3D:
	var a := Node3D.new()
	a.name = "Bras%s" % ("A" if side < 0.0 else "B")
	add_child(a)
	MeshUtil.box_instance(a, Vector3(0.018, 0.022, 0.014), Vector3(0, ARM_LEN, BAR_Z), satin, "Chariot")
	MeshUtil.box_instance(a, Vector3(0.0085, ARM_LEN - 0.006, 0.0062), Vector3(side * 0.0012, ARM_LEN * 0.5, BAR_Z), steel, "Bras")
	# Articulation de la valve au bout du bras, puis le montant qui descend vers la valve
	var knuckle := MeshUtil.cylinder_instance(a, 0.0052, 0.012, Vector3(side * 0.0012, 0.0, BAR_Z), satin, "Articulation")
	knuckle.rotation_degrees.z = 90
	MeshUtil.box_instance(a, Vector3(0.0075, 0.016, 0.011), Vector3(side * 0.0012, 0, BAR_Z + 0.0085), steel, "Montant")
	var blade := MeshInstance3D.new()
	blade.name = "Valve"
	blade.mesh = blade_mesh(side)
	blade.material_override = steel
	a.add_child(blade)
	return a


## Valve : plaque de 2,4 mm, creusée du côté de la côte, lèvre tournée vers l'extérieur en bas.
static func blade_mesh(side: float) -> ArrayMesh:
	var prof := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		prof.append(Vector2(-0.003 * sin(PI * t), -0.003 + t * 0.041))
	for i in range(1, 6):
		var th := PI - PI * 0.5 * i / 5.0
		prof.append(Vector2(0.0045 + 0.0045 * cos(th), 0.038 + 0.0045 * sin(th)))
	prof.append(Vector2(0.0088, 0.0425))
	var ht := 0.0012
	var hy := BLADE_LEN * 0.5
	var n := prof.size()
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	for i in n:
		var tg := (prof[mini(i + 1, n - 1)] - prof[maxi(i - 1, 0)]).normalized()
		var nn := Vector2(-tg.y, tg.x)
		var p := prof[i]
		outer.append(Vector3(side * (p.x + nn.x * ht), 0, p.y + nn.y * ht))
		inner.append(Vector3(side * (p.x - nn.x * ht), 0, p.y - nn.y * ht))
		nrm.append(Vector3(side * nn.x, 0, nn.y).normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dy := Vector3(0, hy, 0)
	# La plaque se rétrécit un peu vers la lèvre (coins arrondis)
	for i in n - 1:
		var k0 := 1.0 - 0.1 * smoothstep(0.6, 1.0, float(i) / (n - 1))
		var k1 := 1.0 - 0.1 * smoothstep(0.6, 1.0, float(i + 1) / (n - 1))
		var o0 := outer[i]
		var o1 := outer[i + 1]
		var i0 := inner[i]
		var i1 := inner[i + 1]
		_quad(st, o0 - dy * k0, o1 - dy * k1, o1 + dy * k1, o0 + dy * k0, [nrm[i], nrm[i + 1], nrm[i + 1], nrm[i]])
		_quad(st, i0 - dy * k0, i1 - dy * k1, i1 + dy * k1, i0 + dy * k0, [-nrm[i], -nrm[i + 1], -nrm[i + 1], -nrm[i]])
		_quad(st, o0 - dy * k0, o1 - dy * k1, i1 - dy * k1, i0 - dy * k0, [Vector3.DOWN, Vector3.DOWN, Vector3.DOWN, Vector3.DOWN])
		_quad(st, o0 + dy * k0, o1 + dy * k1, i1 + dy * k1, i0 + dy * k0, [Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var e := n - 1
	var tip_n := Vector3(side, 0, 0)
	_quad(st, outer[e] - dy * 0.9, inner[e] - dy * 0.9, inner[e] + dy * 0.9, outer[e] + dy * 0.9, [tip_n, tip_n, tip_n, tip_n])
	var top_n := Vector3(0, 0, -1)
	_quad(st, outer[0] - dy, inner[0] - dy, inner[0] + dy, outer[0] + dy, [top_n, top_n, top_n, top_n])
	return st.commit()


## Quadrilatère dont chaque triangle est tourné vers ses normales (faces avant de Godot).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ns: Array) -> void:
	_tri(st, a, b, c, ns[0], ns[1], ns[2])
	_tri(st, a, c, d, ns[0], ns[2], ns[3])


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	# Godot : sens horaire = face avant ; le produit vectoriel doit donc s'opposer à la normale
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)


func set_spread(d: float) -> void:
	spread = d
	_arm_a.position.x = -d * 0.5
	_arm_b.position.x = d * 0.5
	if _crank:
		_crank.rotation.z = d * 140.0
