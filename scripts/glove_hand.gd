class_name GloveHand
extends Node3D
## Main gantée (latex) : paume arrondie, quatre doigts à trois phalanges et pouce (tubes à bouts
## ronds), poignet du gant, manche de casaque. Repère : +Z vers le bout des doigts, +Y dos de la
## main, +X côté du pouce. `curl` 0 = main à plat, 1 = doigts repliés ; `blood` tache le gant à
## partir du bout des doigts.

## [x à la base, phalanges (m), rayon à la base, rayon au bout, avance de la base, écart (°)]
const FINGERS := [
	[0.025, [0.040, 0.024, 0.019], 0.0091, 0.0073, 0.0, 5.0],
	[0.0085, [0.045, 0.028, 0.020], 0.0095, 0.0076, 0.004, 0.0],
	[-0.0085, [0.042, 0.026, 0.019], 0.0090, 0.0072, 0.001, -4.0],
	[-0.0245, [0.033, 0.020, 0.017], 0.0079, 0.0065, -0.008, -10.0],
]
const PALM_HALF := Vector3(0.041, 0.0135, 0.046)

var curl := 0.25
var spread := 0.0  ## doigts écartés (0..1)
var _mat: ShaderMaterial
var _fingers: Array[MeshInstance3D] = []
var _thumb: MeshInstance3D
var _sleeve: MeshInstance3D
var _built_curl := -1.0
var elbow_local := Vector3(0.0, 0.08, -0.32)  ## coude (repère de la main) : la manche y va


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/glove.gdshader")
	var palm := MeshInstance3D.new()
	palm.name = "Paume"
	palm.mesh = rounded_box(PALM_HALF, 0.72)
	palm.material_override = _mat
	add_child(palm)
	# Éminence thénar (base du pouce)
	var thenar := MeshInstance3D.new()
	thenar.name = "Thenar"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 10
	thenar.mesh = sm
	thenar.material_override = _mat
	thenar.position = Vector3(0.024, -0.006, -0.02)
	thenar.scale = Vector3(0.02, 0.012, 0.03)
	add_child(thenar)
	# Jointures (dos de la main, à la base des doigts)
	for i in FINGERS.size():
		var fd: Array = FINGERS[i]
		var k := MeshInstance3D.new()
		k.name = "Jointure%d" % i
		var ks := SphereMesh.new()
		ks.radius = float(fd[2]) * 0.95
		ks.height = ks.radius * 2.0
		ks.radial_segments = 12
		ks.rings = 8
		k.mesh = ks
		k.material_override = _mat
		k.position = Vector3(float(fd[0]), 0.0035, PALM_HALF.z - 0.011 + float(fd[4]))
		k.scale = Vector3(1.0, 0.85, 1.0)
		add_child(k)
	for i in FINGERS.size():
		var f := MeshInstance3D.new()
		f.name = "Doigt%d" % i
		f.material_override = _mat
		add_child(f)
		_fingers.append(f)
	_thumb = MeshInstance3D.new()
	_thumb.name = "Pouce"
	_thumb.material_override = _mat
	add_child(_thumb)
	# Poignet du gant (remonte sur la manche)
	var cuff := MeshInstance3D.new()
	cuff.name = "Manchette"
	var pts := PackedVector3Array([Vector3(0, 0.0, -0.03), Vector3(0, 0.002, -0.07), Vector3(0, 0.004, -0.115), Vector3(0, 0.005, -0.15)])
	var rr := PackedFloat32Array([0.0235, 0.0225, 0.0255, 0.03])
	cuff.mesh = MeshUtil.tube(pts, rr, 20, false, false)
	cuff.material_override = _mat
	add_child(cuff)
	_sleeve = MeshInstance3D.new()
	_sleeve.name = "Manche"
	var cloth := MeshUtil.mat(Color(0.2, 0.36, 0.47), 0.92)
	_sleeve.material_override = cloth
	add_child(_sleeve)
	_rebuild()


func set_blood(v: float) -> void:
	_mat.set_shader_parameter("blood", v)


func set_elbow(world_p: Vector3) -> void:
	elbow_local = to_local(world_p)
	_build_sleeve()


func _process(_delta: float) -> void:
	if absf(curl - _built_curl) > 0.004:
		_rebuild()


func _rebuild() -> void:
	_built_curl = curl
	for i in FINGERS.size():
		var f: Array = FINGERS[i]
		var lens: Array = f[1]
		# Flexion à chaque articulation : métacarpo-phalangienne, puis les deux interphalangiennes
		var bends := [deg_to_rad(8.0 + 42.0 * curl), deg_to_rad(10.0 + 55.0 * curl), deg_to_rad(6.0 + 30.0 * curl)]
		var yaw := deg_to_rad(float(f[5]) * (1.0 + spread))
		var p := Vector3(f[0], 0.001, PALM_HALF.z - 0.012 + float(f[4]))
		var ang := 0.0
		var pts := PackedVector3Array([p - Vector3(0, 0, 0.012)])
		var rad := PackedFloat32Array([float(f[2]) * 1.05])
		var total := 0.0
		for l in lens:
			total += float(l)
		var run := 0.0
		for k in 3:
			ang += bends[k]
			var d := Vector3(sin(yaw) * cos(ang), -sin(ang), cos(yaw) * cos(ang)).normalized()
			var n := 4
			for s in n:
				p += d * float(lens[k]) / n
				run += float(lens[k]) / n
				pts.append(p)
				# Un peu plus épais aux articulations
				var knuckle := 0.04 * (1.0 - absf(float(s + 1) / n - 1.0) * 2.0) if s == n - 1 and k < 2 else 0.0
				rad.append(lerpf(float(f[2]), float(f[3]), run / total) * (1.0 + knuckle))
		_fingers[i].mesh = MeshUtil.tube(pts, rad, 14, true, true)
	# Pouce : part de l'éminence thénar, en avant et vers la paume
	var tb := Vector3(0.03, -0.006, -0.012)
	var tang := deg_to_rad(20.0 + 35.0 * curl)
	var tdir := Vector3(0.62, -0.28 - 0.3 * curl, 0.73).normalized()
	var tpts := PackedVector3Array([tb])
	var trad := PackedFloat32Array([0.0115])
	var tp := tb
	var tl := [0.03, 0.028, 0.024]
	for k in 3:
		tdir = (Basis(Vector3(0, 1, 0), -tang * 0.45) * tdir).normalized()
		tdir = (tdir + Vector3(0, -0.12 * curl, 0)).normalized()
		for s in 3:
			tp += tdir * float(tl[k]) / 3.0
			tpts.append(tp)
			trad.append(lerpf(0.0112, 0.0082, float(k * 3 + s + 1) / 9.0))
	_thumb.mesh = MeshUtil.tube(tpts, trad, 14, true, true)
	_build_sleeve()


func _build_sleeve() -> void:
	if _sleeve == null:
		return
	var a := Vector3(0, 0.005, -0.13)
	var pts := MeshUtil.bezier(a, a + Vector3(0, 0.0, -0.08), elbow_local + Vector3(0, -0.02, 0.1), elbow_local, 10)
	var rr := PackedFloat32Array()
	for i in pts.size():
		rr.append(lerpf(0.031, 0.045, float(i) / (pts.size() - 1)))
	_sleeve.mesh = MeshUtil.tube(pts, rr, 18, true, true)


## Boîte aux coins arrondis (superellipsoïde) : demi-tailles `half`, exposant e (1 = ellipsoïde).
static func rounded_box(half: Vector3, e: float, nu := 28, nv := 16) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nv + 1:
		var v := -PI * 0.5 + PI * j / nv
		for i in nu + 1:
			var u := -PI + TAU * i / nu
			var cv := cos(v)
			var sv := sin(v)
			var p := Vector3(half.x * _sp(cv, e) * _sp(cos(u), e), half.y * _sp(sv, e), half.z * _sp(cv, e) * _sp(sin(u), e))
			var n := Vector3(_sp(cv, 2.0 - e) * _sp(cos(u), 2.0 - e) / half.x, _sp(sv, 2.0 - e) / half.y, _sp(cv, 2.0 - e) * _sp(sin(u), 2.0 - e) / half.z)
			st.set_normal(n.normalized() if n.length() > 1e-6 else Vector3(0, signf(sv), 0))
			st.set_uv(Vector2(float(i) / nu, float(j) / nv))
			st.add_vertex(p)
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			var b := a + nu + 1
			# Sens horaire vu de l'extérieur (faces avant de Godot)
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	return st.commit()


static func _sp(c: float, e: float) -> float:
	return signf(c) * pow(absf(c), e)
