class_name PatientProps
extends Node3D
## Équipement d'un polytraumatisé en salle de déchocage : collier cervical (accident de moto),
## masque à oxygène à haute concentration avec ballon réservoir, oxymètre au doigt (lumière rouge),
## perfusion au bras levé, câbles de l'ECG. Repères calculés sur l'atlas dans la pose du patient.

const NOSE := Vector3(0.283, 1.14, 0.113)
const MOUTH := Vector3(0.255, 1.14, 0.088)
const FINGER := Vector3(0.643, 1.749, 0.091)
const FOREARM := Vector3(0.405, 1.608, -0.012)
const WRIST := Vector3(0.516, 1.669, 0.033)

var spo2_light: OmniLight3D
var spo2_mat: StandardMaterial3D
var bag: MeshInstance3D
var _t := 0.0
var breath_rate := 30.0


func build() -> void:
	_collar()
	_o2_mask()
	_spo2_clip()
	_iv_line()
	_ecg_wires()


func _mat(c: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	return MeshUtil.mat(c, rough, metal)


## Collier cervical rigide : coque beige, mousse grise à l'intérieur, appui-menton, ouverture
## trachéale à l'avant, fermetures velcro.
func _collar() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	var cy := 1.1401
	var cz := -0.012
	for i in n + 1:
		var a := TAU * i / n
		# a = 0 : avant (+Z), PI/2 : côté droit (haut), PI : nuque
		var front := pow(maxf(0.0, cos(a)), 2.0)
		var x0 := 0.165 - 0.012 * front
		var x1 := 0.228 + 0.022 * front
		var ry := 0.066
		var rz := 0.067 if cos(a) > 0.0 else 0.072
		for k in 2:
			var x: float = lerpf(x0, x1, float(k))
			var p := Vector3(x, cy + sin(a) * ry, cz + cos(a) * rz)
			st.set_uv(Vector2(float(i) / n, float(k)))
			st.add_vertex(p)
	for i in n:
		var a0 := i * 2
		st.add_index(a0)
		st.add_index(a0 + 2)
		st.add_index(a0 + 1)
		st.add_index(a0 + 1)
		st.add_index(a0 + 2)
		st.add_index(a0 + 3)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "CollierCervical"
	mi.mesh = st.commit()
	var shell := _mat(Color(0.86, 0.80, 0.66), 0.55)
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = shell
	add_child(mi)
	# Bords en mousse grise (deux anneaux)
	for x in [0.168, 0.226]:
		var pts := PackedVector3Array()
		for i in n + 1:
			var a := TAU * i / n
			var front := pow(maxf(0.0, cos(a)), 2.0)
			var xx: float = x + (-0.012 if x < 0.2 else 0.022) * front
			var rz := 0.067 if cos(a) > 0.0 else 0.072
			pts.append(Vector3(xx, cy + sin(a) * 0.066, cz + cos(a) * rz))
		var rr := PackedFloat32Array()
		rr.resize(pts.size())
		rr.fill(0.006)
		var foam := MeshInstance3D.new()
		foam.mesh = MeshUtil.tube(pts, rr, 8, false, false)
		foam.material_override = _mat(Color(0.32, 0.34, 0.36), 0.9)
		add_child(foam)
	# Ouverture trachéale (à l'avant) et velcro
	MeshUtil.box_instance(self, Vector3(0.028, 0.022, 0.006), Vector3(0.198, cy, cz + 0.068), _mat(Color(0.12, 0.12, 0.13), 0.8), "OuvertureTracheale")
	for s in [-1.0, 1.0]:
		MeshUtil.box_instance(self, Vector3(0.05, 0.004, 0.035), Vector3(0.198, cy + s * 0.067, cz - 0.03), _mat(Color(0.2, 0.25, 0.4), 0.9), "Velcro")


## Masque à haute concentration : coque transparente verte, ballon réservoir, tuyau d'oxygène.
func _o2_mask() -> void:
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.72, 0.92, 0.82, 0.2)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.22
	clear.metallic_specular = 0.35
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := (NOSE + MOUTH) * 0.5 + Vector3(-0.005, 0.0, 0.012)
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.is_hemisphere = true
	sm.radial_segments = 40
	sm.rings = 16
	shell.mesh = sm
	shell.material_override = clear
	shell.name = "MasqueO2"
	add_child(shell)
	# Hémisphère : son sommet (axe Y) vers l'avant du visage (+Z), allongé du nez au menton (X)
	var bx := Vector3(0.0, 0.046, 0.0)  # largeur (côtés du visage)
	var by := Vector3(0.0, 0.0, 0.034)  # profondeur, sommet vers l'avant
	var bz := Vector3(0.056, 0.0, 0.0)  # hauteur (nez → menton)
	shell.transform = Transform3D(Basis(bx, by, bz), c)
	# Coussin souple du bord
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 8
	rim.mesh = tm
	var rim_mat := clear.duplicate() as StandardMaterial3D
	rim_mat.albedo_color = Color(0.7, 0.9, 0.82, 0.45)
	rim.material_override = rim_mat
	rim.transform = Transform3D(Basis(Vector3(0.0, 0.047, 0.0), Vector3(0.0, 0.0, 0.004), Vector3(0.057, 0.0, 0.0)), c - Vector3(0, 0, 0.002))
	add_child(rim)
	# Raccord et ballon réservoir (se dégonfle à chaque inspiration)
	var port := c + Vector3(-0.03, 0.0, 0.03)
	MeshUtil.cylinder_instance(self, 0.008, 0.02, port, _mat(Color(0.3, 0.75, 0.55, 0.9), 0.3), "Valve")
	bag = MeshInstance3D.new()
	var bs := CapsuleMesh.new()
	bs.radius = 1.0
	bs.height = 3.4
	bs.radial_segments = 24
	bag.mesh = bs
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.45, 0.85, 0.6, 0.45)
	bag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bag_mat.roughness = 0.2
	bag_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bag.material_override = bag_mat
	bag.name = "BallonReservoir"
	bag.position = port + Vector3(-0.025, -0.1, 0.02)
	bag.scale = Vector3(0.032, 0.035, 0.022)
	add_child(bag)
	# Élastique autour de la tête
	var band := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.98
	bt.outer_radius = 1.0
	bt.rings = 48
	bt.ring_segments = 6
	band.mesh = bt
	band.material_override = _mat(Color(0.2, 0.55, 0.4), 0.7)
	band.transform = Transform3D(Basis(Vector3(0.0, 0.082, 0.0), Vector3(0.006, 0.0, 0.0), Vector3(0.0, 0.0, 0.1)), Vector3(0.27, 1.14, -0.005))
	add_child(band)
	# Tuyau d'oxygène vert jusqu'au débitmètre mural
	# Il descend le long du bord de la table puis rejoint le poste d'anesthésie (sous la ligne de vue)
	var pts := PackedVector3Array()
	var ctrl := [port + Vector3(-0.01, 0, 0.01), port + Vector3(-0.02, -0.12, 0.1), Vector3(0.45, 0.86, 0.33), Vector3(0.95, 0.8, 0.3), Vector3(1.3, 0.95, 0.05), Vector3(1.38, 1.12, -0.12)]
	for k in ctrl.size() - 1:
		var a: Vector3 = ctrl[k]
		var b2: Vector3 = ctrl[k + 1]
		var seg := MeshUtil.bezier(a, a.lerp(b2, 0.33) + Vector3.DOWN * 0.03, a.lerp(b2, 0.66) + Vector3.DOWN * 0.03, b2, 10)
		if k > 0:
			seg.remove_at(0)
		pts.append_array(seg)
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.0035)
	var tube := MeshInstance3D.new()
	tube.mesh = MeshUtil.tube(pts, rr, 8)
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.55, 0.9, 0.7, 0.6)
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.roughness = 0.15
	tube.material_override = tmat
	tube.name = "TuyauO2"
	add_child(tube)


## Oxymètre de pouls au bout de l'index : pince grise, lumière rouge qui traverse le doigt.
func _spo2_clip() -> void:
	var clip := Node3D.new()
	clip.name = "Oxymetre"
	add_child(clip)
	var dir := (FINGER - WRIST).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	clip.global_transform = Transform3D(Basis(side, up, dir), FINGER - dir * 0.012)
	var shell := _mat(Color(0.82, 0.84, 0.86), 0.4)
	MeshUtil.box_instance(clip, Vector3(0.024, 0.012, 0.034), Vector3(0, 0.011, 0), shell, "Haut")
	MeshUtil.box_instance(clip, Vector3(0.024, 0.010, 0.032), Vector3(0, -0.011, 0), _mat(Color(0.2, 0.45, 0.75), 0.5), "Bas")
	MeshUtil.box_instance(clip, Vector3(0.008, 0.026, 0.006), Vector3(0, 0, -0.016), shell, "Ressort")
	spo2_mat = StandardMaterial3D.new()
	spo2_mat.albedo_color = Color(1.0, 0.1, 0.1)
	spo2_mat.emission_enabled = true
	spo2_mat.emission = Color(1.0, 0.08, 0.05)
	spo2_mat.emission_energy_multiplier = 3.0
	MeshUtil.box_instance(clip, Vector3(0.006, 0.002, 0.006), Vector3(0, 0.0175, 0.004), spo2_mat, "Diode")
	spo2_light = OmniLight3D.new()
	spo2_light.light_color = Color(1.0, 0.15, 0.1)
	spo2_light.light_energy = 0.15
	spo2_light.omni_range = 0.06
	clip.add_child(spo2_light)
	# Câble vers le moniteur
	var start := clip.global_transform * Vector3(0, 0, -0.02)
	var pts := MeshUtil.bezier(start, start + Vector3(0.04, -0.35, -0.08), Vector3(0.74, 0.95, -0.45), Vector3(0.78, 1.46, -0.55), 30)
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.0018)
	var cable := MeshInstance3D.new()
	cable.mesh = MeshUtil.tube(pts, rr, 6)
	cable.material_override = _mat(Color(0.15, 0.3, 0.55), 0.5)
	add_child(cable)


## Cathéter veineux sur l'avant-bras (pansement transparent) et tubulure jusqu'à la poche.
func _iv_line() -> void:
	var dir := (WRIST - FOREARM).normalized()
	var site := FOREARM + Vector3(0, 0.03, 0.02)
	var dress := MeshUtil.box_instance(self, Vector3(0.05, 0.002, 0.04), site, StandardMaterial3D.new(), "Pansement")
	var dm := dress.material_override as StandardMaterial3D
	dm.albedo_color = Color(0.95, 0.97, 1.0, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.roughness = 0.1
	dress.look_at_from_position(site, site + dir, Vector3.UP)
	var hub := MeshUtil.cylinder_instance(self, 0.004, 0.02, site + dir * 0.012 + Vector3(0, 0.004, 0), _mat(Color(0.95, 0.55, 0.7), 0.4), "Catheter")
	hub.look_at_from_position(hub.position, hub.position + dir, Vector3.UP)
	hub.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var bag_pos := Vector3(0.95, 1.92, -0.62)
	var pts := MeshUtil.bezier(site + dir * 0.025, site + dir * 0.08 + Vector3(0, -0.25, 0.05), bag_pos + Vector3(-0.25, -0.75, 0.1), bag_pos + Vector3(0, -0.12, 0), 40)
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.0018)
	var line := MeshInstance3D.new()
	line.mesh = MeshUtil.tube(pts, rr, 6)
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color(0.9, 0.95, 1.0, 0.5)
	lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lm.roughness = 0.1
	line.material_override = lm
	line.name = "Perfusion"
	add_child(line)


## Câbles des électrodes de l'ECG : sortent de sous le champ, près de l'épaule.
func _ecg_wires() -> void:
	var cols := [Color(0.9, 0.15, 0.1), Color(0.95, 0.85, 0.15), Color(0.15, 0.7, 0.3), Color(0.92, 0.92, 0.9)]
	for i in cols.size():
		var z: float = [0.12, 0.08, -0.1, -0.15][i]
		var x := 0.205
		var y := maxf(Patient.top_height(x, z), Patient.TABLE_TOP) + 0.003
		var pe := Vector3(x, y, z)
		var wp := MeshUtil.bezier(pe, pe + Vector3(0.1, -0.25, 0.0), Vector3(0.7, 0.9, -0.4), Vector3(0.78, 1.46, -0.54), 26)
		var wr := PackedFloat32Array()
		wr.resize(wp.size())
		wr.fill(0.0015)
		var wire := MeshInstance3D.new()
		wire.mesh = MeshUtil.tube(wp, wr, 5)
		wire.material_override = _mat(cols[i] * 0.85, 0.45)
		add_child(wire)


func _process(delta: float) -> void:
	_t += delta
	if spo2_light:
		spo2_light.light_energy = 0.12 + 0.05 * sin(_t * 9.0)
	# Le ballon réservoir se vide un peu à chaque inspiration
	if bag:
		var b := 0.5 - 0.5 * cos(TAU * _t * breath_rate / 60.0)
		bag.scale = Vector3(0.032 * (1.0 - 0.25 * b), 0.035, 0.022 * (1.0 - 0.3 * b))
