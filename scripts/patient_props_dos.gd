class_name PatientPropsDos
extends Node3D
## Équipement du patient couché sur le dos (polytraumatisé en salle de déchocage) : collier
## cervical, masque à oxygène avec ballon réservoir, oxymètre au doigt, perfusion à l'avant-bras
## droit, électrodes de l'ECG (épaules, flanc gauche), brassard de tension au bras gauche. Tout est
## placé sur les repères mesurés sur l'atlas (Patient.landmarks).

const MONITOR_IN := Vector3(0.78, 1.46, -0.55)  ## entrée des câbles sous le moniteur
const IV_BAG := Vector3(0.95, 1.92, -0.62)

var spo2_light: OmniLight3D
var bag: MeshInstance3D
var breath_rate := 14.0
var _t := 0.0


func build() -> void:
	if Patient.landmarks.is_empty():
		return
	_collar()
	_o2_mask()
	_spo2_clip()
	_iv_line()
	_ecg()
	_bp_cuff()


func _mat(c: Color, rough := 0.5, metal := 0.0) -> StandardMaterial3D:
	return MeshUtil.mat(c, rough, metal)


func _clear(c: Color, rough := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = rough
	m.metallic_specular = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Point de la ligne centrale d'un bras (x, y, z, rayon) à la distance relative t (0 : épaule,
## 1 : bout des doigts).
func _arm_at(side: String, t: float) -> Array:
	var line: Array = Patient.landmarks.get("arm_" + side, [])
	if line.is_empty():
		return [Vector3.ZERO, 0.03]
	var n := line.size()
	var f := clampf((1.0 - t) * (n - 1), 0.0, n - 1.001)
	var i := int(f)
	var a: Array = line[i]
	var b: Array = line[i + 1]
	var k := f - i
	var p := Vector3(lerpf(a[0], b[0], k), lerpf(a[1], b[1], k), lerpf(a[2], b[2], k))
	return [p, lerpf(a[3], b[3], k)]


func _arm_dir(side: String, t: float) -> Vector3:
	var p0: Vector3 = _arm_at(side, maxf(0.0, t - 0.04))[0]
	var p1: Vector3 = _arm_at(side, minf(1.0, t + 0.04))[0]
	return (p1 - p0).normalized()


func _tube(pts: PackedVector3Array, r: float, mat: Material, nm: String) -> MeshInstance3D:
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(r)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = MeshUtil.tube(pts, rr, 8)
	mi.material_override = mat
	add_child(mi)
	return mi


## Collier cervical rigide autour du cou (face antérieure vers le haut) : coque beige, mousse
## grise aux bords, ouverture trachéale, appui-menton plus haut devant.
func _collar() -> void:
	var nk: Dictionary = Patient.landmarks.get("neck", {})
	if nk.is_empty():
		return
	var xc: float = nk["x"]
	var cy: float = (nk["y_front"] + nk["y_back"]) * 0.5
	var ry: float = (nk["y_front"] - nk["y_back"]) * 0.5 + 0.012
	var rz: float = nk["half_width"] + 0.014
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 64
	for i in n + 1:
		var a := TAU * i / n  # 0 : devant (haut), PI : nuque
		var front := pow(maxf(0.0, cos(a)), 2.0)
		var x0 := xc - 0.032 - 0.006 * front
		var x1 := xc + 0.03 + 0.024 * front
		for k in 2:
			st.set_uv(Vector2(float(i) / n, float(k)))
			st.add_vertex(Vector3(lerpf(x0, x1, float(k)), cy + cos(a) * ry, sin(a) * rz))
	for i in n:
		var a0 := i * 2
		st.add_index(a0)
		st.add_index(a0 + 1)
		st.add_index(a0 + 2)
		st.add_index(a0 + 1)
		st.add_index(a0 + 3)
		st.add_index(a0 + 2)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "CollierCervical"
	mi.mesh = st.commit()
	var shell := _mat(Color(0.86, 0.80, 0.66), 0.55)
	shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = shell
	add_child(mi)
	var foam := _mat(Color(0.32, 0.34, 0.36), 0.9)
	for edge in [0, 1]:
		var pts := PackedVector3Array()
		for i in n + 1:
			var a := TAU * i / n
			var front := pow(maxf(0.0, cos(a)), 2.0)
			var x := (xc - 0.032 - 0.006 * front) if edge == 0 else (xc + 0.03 + 0.024 * front)
			pts.append(Vector3(x, cy + cos(a) * ry, sin(a) * rz))
		_tube(pts, 0.006, foam, "Mousse")
	MeshUtil.box_instance(self, Vector3(0.028, 0.006, 0.022), Vector3(xc + 0.004, cy + ry + 0.001, 0.0), _mat(Color(0.12, 0.12, 0.13), 0.8), "OuvertureTracheale")


## Masque à haute concentration sur le nez et la bouche, ballon réservoir posé à côté de la tête,
## tuyau d'oxygène jusqu'au débitmètre du poste d'anesthésie.
func _o2_mask() -> void:
	var nose := Patient.lm("nose_tip")
	var chin := Patient.lm("chin")
	var c := Vector3((nose.x + chin.x) * 0.5 + 0.004, nose.y - 0.012, 0.0)
	var clear := _clear(Color(0.72, 0.92, 0.82, 0.2), 0.22)
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
	# Sommet de l'hémisphère vers le haut, allongé du nez au menton (X), large sur les joues (Z)
	shell.transform = Transform3D(Basis(Vector3(0.0, 0.0, 0.046), Vector3(0.0, 0.034, 0.0), Vector3(0.056, 0.0, 0.0)), c)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 8
	rim.mesh = tm
	rim.material_override = _clear(Color(0.7, 0.9, 0.82, 0.45))
	rim.transform = Transform3D(Basis(Vector3(0.057, 0.0, 0.0), Vector3(0.0, 0.004, 0.0), Vector3(0.0, 0.0, 0.047)), c - Vector3(0, 0.002, 0))
	add_child(rim)
	var port := c + Vector3(-0.03, 0.03, 0.0)
	MeshUtil.cylinder_instance(self, 0.008, 0.02, port, _mat(Color(0.3, 0.75, 0.55), 0.3), "Valve")
	bag = MeshInstance3D.new()
	var bs := CapsuleMesh.new()
	bs.radius = 1.0
	bs.height = 3.4
	bs.radial_segments = 24
	bag.mesh = bs
	bag.material_override = _clear(Color(0.45, 0.85, 0.6, 0.45))
	bag.name = "BallonReservoir"
	bag.position = Vector3(c.x - 0.02, Patient.TABLE_TOP + 0.04, -0.13)
	bag.rotation_degrees = Vector3(0, 0, 90)
	bag.scale = Vector3(0.032, 0.035, 0.022)
	add_child(bag)
	# Élastique autour de la tête (passe sous la nuque, sur l'anneau de gel)
	var occ := Patient.lm("occiput")
	var hc := Vector3(c.x + 0.02, (nose.y + occ.y) * 0.5, 0.0)
	var band := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.98
	bt.outer_radius = 1.0
	bt.rings = 48
	bt.ring_segments = 6
	band.mesh = bt
	band.material_override = _mat(Color(0.2, 0.55, 0.4), 0.7)
	band.transform = Transform3D(Basis(Vector3(0.006, 0.0, 0.0), Vector3(0.0, (nose.y - occ.y) * 0.5, 0.0), Vector3(0.0, 0.0, 0.078)), hc)
	add_child(band)
	var tmat := _clear(Color(0.55, 0.9, 0.7, 0.6), 0.15)
	var pts := MeshUtil.bezier(port, port + Vector3(0.05, 0.02, -0.06), Vector3(0.75, 0.95, -0.25), Vector3(1.38, 1.12, -0.12), 40)
	_tube(pts, 0.0035, tmat, "TuyauO2")


## Oxymètre au bout de l'index droit : pince grise, lueur rouge discrète, câble vers le moniteur.
func _spo2_clip() -> void:
	var tip := Patient.lm("fingertip_R")
	var dir := _arm_dir("R", 0.97)
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var clip := Node3D.new()
	clip.name = "Oxymetre"
	add_child(clip)
	clip.global_transform = Transform3D(Basis(side, up, dir), tip - dir * 0.014 + up * 0.002)
	var shell := _mat(Color(0.82, 0.84, 0.86), 0.4)
	MeshUtil.box_instance(clip, Vector3(0.024, 0.012, 0.034), Vector3(0, 0.011, 0), shell, "Haut")
	MeshUtil.box_instance(clip, Vector3(0.024, 0.010, 0.032), Vector3(0, -0.011, 0), _mat(Color(0.2, 0.45, 0.75), 0.5), "Bas")
	var diode := _mat(Color(1.0, 0.1, 0.1))
	diode.emission_enabled = true
	diode.emission = Color(1.0, 0.08, 0.05)
	diode.emission_energy_multiplier = 3.0
	MeshUtil.box_instance(clip, Vector3(0.006, 0.002, 0.006), Vector3(0, 0.0175, 0.004), diode, "Diode")
	spo2_light = OmniLight3D.new()
	spo2_light.light_color = Color(1.0, 0.15, 0.1)
	spo2_light.light_energy = 0.05
	spo2_light.omni_range = 0.025
	clip.add_child(spo2_light)
	var start := clip.global_transform * Vector3(0, 0, -0.02)
	var pts := MeshUtil.bezier(start, start + Vector3(0.05, -0.03, -0.06), Vector3(0.5, 0.82, -0.45), MONITOR_IN, 40)
	_tube(pts, 0.0018, _mat(Color(0.25, 0.27, 0.3), 0.6), "CableOxymetre")


## Cathéter veineux à l'avant-bras droit sous pansement transparent, tubulure jusqu'à la poche.
func _iv_line() -> void:
	var a: Array = _arm_at("R", 0.72)
	var p: Vector3 = a[0]
	var r: float = a[1]
	var dir := _arm_dir("R", 0.72)
	var top := Vector3(p.x, p.y + r * 0.95, p.z)
	var dress := MeshUtil.box_instance(self, Vector3(0.05, 0.002, 0.04), top, _clear(Color(0.92, 0.95, 1.0, 0.35), 0.15), "Pansement")
	dress.look_at_from_position(top, top + dir, Vector3.UP)
	var hub := top - dir * 0.012 + Vector3.UP * 0.004
	MeshUtil.cylinder_instance(self, 0.004, 0.016, hub, _mat(Color(1.0, 0.85, 0.2), 0.4), "Catheter")
	var pts := MeshUtil.bezier(hub, hub + Vector3(0.06, 0.08, -0.05), Vector3(0.75, 1.5, -0.6), IV_BAG + Vector3(0, -0.18, 0), 40)
	_tube(pts, 0.002, _clear(Color(0.9, 0.95, 1.0, 0.55), 0.1), "Tubulure")


## Électrodes de l'ECG : épaules (sous la clavicule) et flanc gauche, câbles vers le moniteur.
func _ecg() -> void:
	var cl_r := Patient.lm("clavicle_lateral_R")
	var cl_l := Patient.lm("clavicle_lateral_L")
	var spots := [Vector2(cl_r.x - 0.035, cl_r.z + 0.03), Vector2(cl_l.x - 0.035, cl_l.z - 0.03), Vector2(-0.27, 0.11)]
	var cols := [Color(0.9, 0.9, 0.92), Color(0.15, 0.15, 0.17), Color(0.85, 0.2, 0.2)]
	var pad := _mat(Color(0.96, 0.96, 0.94), 0.7)
	for i in spots.size():
		var s: Vector2 = spots[i]
		var y := Patient.body_height(s.x, s.y)
		if y < 0.0:
			continue
		var nrm := Patient.skin_normal(s.x, s.y)
		var p := Vector3(s.x, y, s.y)
		var disc := MeshUtil.cylinder_instance(self, 0.012, 0.0015, p, pad, "Electrode")
		disc.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, nrm)), p + nrm * 0.0008)
		var snap := MeshUtil.cylinder_instance(self, 0.003, 0.004, p, _mat(Color(0.75, 0.76, 0.78), 0.3, 0.8), "Bouton")
		snap.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, nrm)), p + nrm * 0.004)
		var start := p + nrm * 0.006
		var pts := MeshUtil.bezier(start, start + Vector3(0.0, 0.05, -0.04), Vector3(0.45, 1.1, -0.42), MONITOR_IN + Vector3(0, -0.01 * i, 0), 40)
		_tube(pts, 0.0016, _mat(cols[i], 0.55), "CableECG")


## Brassard de tension au bras gauche, tuyau vers le moniteur.
func _bp_cuff() -> void:
	var a: Array = _arm_at("L", 0.25)
	var p: Vector3 = a[0]
	var r: float = a[1]
	var dir := _arm_dir("L", 0.25)
	var cuff := MeshInstance3D.new()
	cuff.name = "Brassard"
	var cm := CylinderMesh.new()
	cm.top_radius = r + 0.008
	cm.bottom_radius = r + 0.008
	cm.height = 0.13
	cm.radial_segments = 32
	cuff.mesh = cm
	cuff.material_override = _mat(Color(0.12, 0.2, 0.38), 0.8)
	add_child(cuff)
	cuff.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), p)
	var start := p + Vector3.UP * (r + 0.01)
	var pts := MeshUtil.bezier(start, start + Vector3(0.1, 0.1, 0.0), Vector3(0.6, 1.25, -0.3), MONITOR_IN, 40)
	_tube(pts, 0.003, _mat(Color(0.2, 0.22, 0.25), 0.6), "TuyauBrassard")


func _process(delta: float) -> void:
	_t += delta
	if spo2_light:
		spo2_light.light_energy = 0.04 + 0.015 * sin(_t * 9.0)
	if bag:
		var b := 0.5 - 0.5 * cos(TAU * _t * breath_rate / 60.0)
		bag.scale = Vector3(0.032 * (1.0 - 0.25 * b), 0.035, 0.022 * (1.0 - 0.3 * b))
