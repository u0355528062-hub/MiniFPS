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
var _obstacles: Array = []  ## sphères que les câbles contournent (ballon réservoir, collier…)
var _collar_dims := {}
var options := {}  ## {"collar": false} : pas de collier cervical (plaie pénétrante)


func build() -> void:
	if Patient.landmarks.is_empty():
		return
	if options.get("collar", true):
		_collar()
	if options.get("intubated", false):
		_intubation()
	else:
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


## Section réelle du bras (mesurée sur la carte de hauteur de la peau) : centre, demi-largeur,
## demi-hauteur et axe. Le bras repose sur le matelas : son centre est à mi-hauteur.
func _arm_section(side: String, t: float) -> Dictionary:
	var p: Vector3 = _arm_at(side, t)[0]
	var dir := _arm_dir(side, t)
	var top := Patient.body_height(p.x, p.z)
	var hh := maxf(0.015, (top - Patient.TABLE_TOP) * 0.5)
	# Largeur : du centre vers l'extérieur (côté opposé au tronc) jusqu'au matelas
	var out := Vector3(0, 0, 1 if side == "L" else -1)
	var perp := dir.cross(Vector3.UP).normalized()
	if perp.dot(out) < 0.0:
		perp = -perp
	var hw := 0.02
	for k in 40:
		var d := 0.01 + k * 0.0015
		var q := p + perp * d
		if Patient.body_height(q.x, q.z) < Patient.TABLE_TOP + hh * 0.35:
			hw = d
			break
	return {"c": Vector3(p.x, Patient.TABLE_TOP + hh, p.z), "hw": hw, "hh": hh, "dir": dir, "perp": perp, "top": top}


func _arm_dir(side: String, t: float) -> Vector3:
	var p0: Vector3 = _arm_at(side, maxf(0.0, t - 0.04))[0]
	var p1: Vector3 = _arm_at(side, minf(1.0, t + 0.04))[0]
	return (p1 - p0).normalized()


## Câble souple posé par simulation (il repose sur le patient, pend au bord de la table).
func _cable(path: PackedVector3Array, slack: float, r: float, mat: Material, nm: String, pin_a := 2, pin_b := 1, seg := 0.02) -> MeshInstance3D:
	var pts := Cable.smooth(Cable.lay(path, slack, r, seg, pin_a, pin_b, _obstacles))
	return _tube(pts, r, mat, nm)


func _on(x: float, z: float, lift := 0.0) -> Vector3:
	return Cable.on_surface(x, z, lift)


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
	_collar_dims = {"xc": xc, "cy": cy, "ry": ry, "rz": rz}
	for k in 7:
		var a := PI * (0.5 + k / 6.0) - PI * 0.5  # du côté droit au côté gauche, par-dessus
		_obstacles.append([Vector3(xc, cy + cos(a) * ry * 0.8, sin(a) * rz * 0.8), 0.035])


## Dessus du collier cervical au point (x, z) (mousse comprise), -1 en dehors.
func _collar_top(x: float, z: float) -> float:
	if _collar_dims.is_empty():
		return -1.0
	var rz: float = _collar_dims["rz"]
	if absf(z) >= rz:
		return -1.0
	var a := asin(z / rz)
	var front := pow(cos(a), 2.0)
	var xc: float = _collar_dims["xc"]
	if x < xc - 0.038 - 0.006 * front or x > xc + 0.036 + 0.024 * front:
		return -1.0
	return float(_collar_dims["cy"]) + cos(a) * float(_collar_dims["ry"]) + 0.006


## Masque à haute concentration : coque transparente qui épouse le visage (bord posé sur l'arête
## du nez, les joues et le menton, ou sur le collier), valve en bas, ballon réservoir à droite du
## cou, élastique derrière la tête, tuyau d'oxygène jusqu'au débitmètre.
func _o2_mask() -> void:
	var nose := Patient.lm("nose_tip")
	var x_chin := nose.x - 0.056
	var x_bridge := nose.x + 0.042
	var cx := (x_chin + x_bridge) * 0.5
	var ax := (x_bridge - x_chin) * 0.5
	var az := 0.046
	var apex := Vector3(nose.x + 0.002, nose.y + 0.017, 0.0)
	var n_around := 48
	var n_up := 14
	var rim := PackedVector3Array()
	for i in n_around:
		var a := TAU * i / n_around
		var x := cx + ax * cos(a)
		var z := az * sin(a)
		rim.append(Vector3(x, maxf(Patient.body_height(x, z), _collar_top(x, z)) + 0.003, z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n_up + 1:
		var t := float(k) / n_up
		var hs := cos(t * PI * 0.5)
		var vs := sin(t * PI * 0.5)
		for i in n_around + 1:
			var r := rim[i % n_around]
			st.set_uv(Vector2(float(i) / n_around, t))
			st.add_vertex(Vector3(apex.x + (r.x - apex.x) * hs, lerpf(r.y, apex.y, vs), apex.z + (r.z - apex.z) * hs))
	var row := n_around + 1
	for k in n_up:
		for i in n_around:
			var a0 := k * row + i
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(a0 + row)
			st.add_index(a0 + 1)
			st.add_index(a0 + row + 1)
			st.add_index(a0 + row)
	st.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "MasqueO2"
	shell.mesh = st.commit()
	shell.material_override = _clear(Color(0.72, 0.92, 0.82, 0.18), 0.18)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	# Bourrelet souple du bord, posé sur la peau
	var rim_loop := PackedVector3Array(rim)
	rim_loop.append(rim[0])
	_tube(rim_loop, 0.0032, _clear(Color(0.7, 0.9, 0.82, 0.5), 0.3), "BordMasque")
	# Valve en bas du masque, côté droit du menton (la coque à mi-hauteur, vers -X et -Z)
	var ai := int(n_around * 0.56)
	var rv := rim[ai]
	var tv := 0.4
	var port := Vector3(apex.x + (rv.x - apex.x) * cos(tv * PI * 0.5), lerpf(rv.y, apex.y, sin(tv * PI * 0.5)), apex.z + (rv.z - apex.z) * cos(tv * PI * 0.5))
	var out := Vector3(port.x - apex.x, 0.0, port.z).normalized() * 0.8 + Vector3.UP * 0.6
	out = out.normalized()
	var valve := MeshUtil.cylinder_instance(self, 0.008, 0.018, port, _mat(Color(0.3, 0.75, 0.55), 0.3), "Valve")
	valve.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, out)), port + out * 0.006)
	# Ballon réservoir posé à droite du cou, relié à la valve
	bag = MeshInstance3D.new()
	var bs := CapsuleMesh.new()
	bs.radius = 1.0
	bs.height = 3.4
	bs.radial_segments = 24
	bag.mesh = bs
	bag.material_override = _clear(Color(0.45, 0.85, 0.6, 0.45))
	bag.name = "BallonReservoir"
	var bag_c := Vector3(x_chin - 0.01, 0.0, -0.125)
	bag_c.y = maxf(Patient.body_height(bag_c.x, bag_c.z), Patient.TABLE_TOP) + 0.024
	bag.position = bag_c
	bag.rotation_degrees = Vector3(0, -25, 90)
	bag.scale = Vector3(0.026, 0.032, 0.02)
	add_child(bag)
	var neck_pts := MeshUtil.bezier(port + out * 0.015, port + out * 0.03 + Vector3(-0.01, 0, -0.02), bag_c + Vector3(0.04, 0.03, 0.02), bag_c + Vector3(0.045, 0.01, 0.012), 16)
	_tube(neck_pts, 0.006, _clear(Color(0.55, 0.88, 0.7, 0.55), 0.2), "ColBallon")
	# Élastique autour de la tête (passe sous la nuque, sur l'anneau de gel)
	var occ := Patient.lm("occiput")
	var hc := Vector3(cx + 0.03, (nose.y + occ.y) * 0.5, 0.0)
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
	_obstacles.append([bag_c + Vector3(-0.03, 0, 0), 0.028])
	_obstacles.append([bag_c + Vector3(0.03, 0, 0), 0.028])
	_obstacles.append([Vector3(cx, nose.y - 0.012, 0.0), 0.045])
	# Tuyau d'oxygène : part de la valve, longe le matelas à droite de la tête, pend au bout de la
	# table puis remonte au débitmètre
	var tmat := _clear(Color(0.55, 0.9, 0.7, 0.6), 0.15)
	var head_x := float(Patient.landmarks.get("head_top_x", 0.41))
	var path := PackedVector3Array([port + out * 0.015, port + out * 0.03, _on(cx + 0.02, -0.105, 0.004),
		_on(head_x + 0.06, -0.12, 0.004), _on(Patient.TABLE_MAX.x - 0.02, -0.1, 0.004),
		Vector3(Patient.TABLE_MAX.x + 0.12, 0.55, -0.1), Vector3(1.25, 0.7, -0.12), Vector3(1.38, 1.12, -0.12)])
	_cable(path, 0.05, 0.0035, tmat, "TuyauO2", 2, 1, 0.025)


## Patient intubé, ventilé : sonde d'intubation transparente qui sort à la commissure des lèvres,
## fixée par un sparadrap, raccord coudé, filtre, tuyau annelé du respirateur.
func _intubation() -> void:
	var nose := Patient.lm("nose_tip")
	var mx := nose.x - 0.03
	var mz := -0.012
	var my := Patient.body_height(mx, mz)
	var mouth := Vector3(mx, my, mz)
	var head := Vector3(1, 0, 0)
	var up := Vector3.UP
	var clear := _clear(Color(0.92, 0.96, 1.0, 0.55), 0.12)
	var tube := MeshUtil.bezier(mouth - up * 0.012, mouth + up * 0.012, mouth + up * 0.035 + head * 0.004, mouth + up * 0.045 + head * 0.03, 18)
	_tube(tube, 0.0048, clear, "SondeIntubation")
	var line := PackedVector3Array()
	for q in tube:
		line.append(q + Vector3(0, 0, 0.0046))
	_tube(line, 0.0006, _mat(Color(0.2, 0.4, 0.85), 0.4), "LigneOpaque")
	# Sparadrap en travers de la lèvre supérieure
	var tape := MeshUtil.box_instance(self, Vector3(0.014, 0.0015, 0.09), mouth + Vector3(0.004, 0.004, 0.012), _mat(Color(0.95, 0.94, 0.9), 0.85), "Sparadrap")
	tape.rotation_degrees.z = 8.0
	# Raccord coudé, filtre, tuyau du respirateur
	var end := tube[tube.size() - 1]
	var conn := MeshUtil.cylinder_instance(self, 0.0075, 0.016, end, _mat(Color(0.95, 0.95, 0.95), 0.4), "Raccord")
	conn.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, head)), end + head * 0.008)
	var filt := MeshUtil.cylinder_instance(self, 0.016, 0.03, end, _mat(Color(0.94, 0.95, 0.96), 0.35), "Filtre")
	filt.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, head)), end + head * 0.032)
	var hose_start := end + head * 0.05
	var path := PackedVector3Array([hose_start, hose_start + head * 0.03, Cable.on_surface(Patient.TABLE_MAX.x - 0.04, -0.06, 0.012),
		Vector3(Patient.TABLE_MAX.x + 0.12, 0.6, -0.12), Vector3(1.1, 0.5, -0.3), Vector3(1.3, 1.0, -0.35)])
	_cable(path, 0.04, 0.011, _mat(Color(0.55, 0.68, 0.82), 0.45), "TuyauRespirateur", 2, 1, 0.03)


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
	# Câble : le long de la main, du matelas, pend au bord de la table et remonte au scope
	var start := clip.global_transform * Vector3(0, 0, -0.02)
	var path := PackedVector3Array([start, start - dir * 0.02 + up * 0.004, _on(tip.x + 0.06, -0.275, 0.002),
		Vector3(tip.x + 0.16, 0.62, -0.34), Vector3(0.3, 0.42, -0.42), Vector3(0.62, 0.75, -0.52), MONITOR_IN])
	_cable(path, 0.04, 0.0019, _mat(Color(0.25, 0.27, 0.3), 0.6), "CableOxymetre", 2, 1, 0.025)


## Cathéter veineux à l'avant-bras droit sous pansement transparent, tubulure jusqu'à la poche.
func _iv_line() -> void:
	var sec := _arm_section("R", 0.72)
	var p: Vector3 = sec["c"]
	var dir: Vector3 = sec["dir"]
	var top := Vector3(p.x, float(sec["top"]) + 0.001, p.z)
	var dress := MeshUtil.box_instance(self, Vector3(0.05, 0.002, 0.04), top, _clear(Color(0.92, 0.95, 1.0, 0.35), 0.15), "Pansement")
	dress.look_at_from_position(top, top + dir, Vector3.UP)
	var hub := top - dir * 0.012 + Vector3.UP * 0.004
	var cat := MeshUtil.cylinder_instance(self, 0.004, 0.016, hub, _mat(Color(1.0, 0.85, 0.2), 0.4), "Catheter")
	cat.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dir)), hub)
	# Tubulure : boucle fixée sur l'avant-bras, pend sous la table, remonte au perfuseur
	var drip := IV_BAG + Vector3(0, -0.2, 0)
	var path := PackedVector3Array([hub, hub + dir * 0.02 + Vector3.UP * 0.002, _on(p.x + 0.05, p.z - 0.035, 0.002),
		_on(p.x + 0.12, -0.285, 0.002), Vector3(p.x + 0.25, 0.55, -0.36), Vector3(0.75, 0.62, -0.55), drip])
	_cable(path, 0.05, 0.0021, _clear(Color(0.9, 0.95, 1.0, 0.55), 0.1), "Tubulure", 2, 1, 0.025)


## Électrodes de l'ECG (épaules et flanc gauche, le thorax reste libre pour les gestes) : les
## câbles des épaules rejoignent le boîtier posé à droite de la tête, celui du flanc file sous le
## drap ; le câble tronc pend au bout de la table et remonte au scope.
func _ecg() -> void:
	var cl_r := Patient.lm("clavicle_lateral_R")
	var cl_l := Patient.lm("clavicle_lateral_L")
	var spots := [Vector2(cl_r.x - 0.035, cl_r.z + 0.03), Vector2(cl_l.x - 0.035, cl_l.z - 0.03), Vector2(-0.33, 0.1)]
	if options.get("ecg_lateral", false):
		# Région sous-claviculaire gardée libre (voie centrale) : électrodes sur les moignons d'épaule
		spots[0] = Vector2(cl_r.x - 0.05, cl_r.z - 0.045)
		spots[1] = Vector2(cl_l.x - 0.05, cl_l.z + 0.045)
	var cols := [Color(0.9, 0.9, 0.92), Color(0.15, 0.15, 0.17), Color(0.85, 0.2, 0.2)]
	var pad := _mat(Color(0.96, 0.96, 0.94), 0.7)
	var head_x := float(Patient.landmarks.get("head_top_x", 0.41))
	var yoke := _on(head_x + 0.1, -0.2, 0.008)
	var box := MeshUtil.box_instance(self, Vector3(0.05, 0.016, 0.034), yoke, _mat(Color(0.2, 0.21, 0.23), 0.55), "BoitierECG")
	box.rotation_degrees.y = 20.0
	for i in spots.size():
		var s2: Vector2 = spots[i]
		var y := Patient.body_height(s2.x, s2.y)
		if y < 0.0:
			continue
		var nrm := Patient.skin_normal(s2.x, s2.y)
		var p := Vector3(s2.x, y, s2.y)
		var disc := MeshUtil.cylinder_instance(self, 0.012, 0.0015, p, pad, "Electrode")
		disc.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, nrm)), p + nrm * 0.0008)
		var snap := MeshUtil.cylinder_instance(self, 0.003, 0.004, p, _mat(Color(0.75, 0.76, 0.78), 0.3, 0.8), "Bouton")
		snap.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, nrm)), p + nrm * 0.004)
		var start := p + nrm * 0.006
		# Pince de l'électrode, couleur du câble
		var clip := MeshUtil.box_instance(self, Vector3(0.008, 0.006, 0.016), start, _mat(cols[i], 0.5), "Pince")
		var path := PackedVector3Array([start, start + nrm * 0.01])
		match i:
			0:  # épaule droite : par-dessus l'épaule, le long de la tête
				path.append_array([_on(s2.x + 0.07, -0.165, 0.003), _on(0.3, -0.19, 0.003), yoke + Vector3(-0.025, 0, 0)])
			1:  # épaule gauche : par-dessus l'épaule gauche, contourne le sommet du crâne
				path.append_array([_on(s2.x + 0.07, 0.165, 0.003), _on(0.3, 0.17, 0.003), _on(head_x + 0.05, 0.1, 0.003),
					_on(head_x + 0.08, -0.05, 0.003), yoke + Vector3(-0.01, 0, 0.015)])
			2:  # flanc gauche : file sous le bord du drap
				path.append_array([_on(-0.36, 0.098, 0.002), _on(-0.395, 0.096, -0.002)])
		var pb := 2 if i == 2 else 1
		var c := _cable(path, 0.03, 0.0016, _mat(cols[i], 0.55), "CableECG", 2, pb, 0.018)
		var d: Vector3 = (path[1] - path[0]).normalized()
		clip.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d)), start + d * 0.004)
		c.set_meta("lead", i)
	# Câble tronc : du boîtier, par-dessus le bout de la table, jusqu'au scope
	var trunk := PackedVector3Array([yoke + Vector3(0.025, 0, 0), yoke + Vector3(0.05, 0, 0.0),
		_on(Patient.TABLE_MAX.x - 0.015, -0.22, 0.004), Vector3(Patient.TABLE_MAX.x + 0.08, 0.5, -0.3),
		Vector3(0.74, 0.62, -0.5), MONITOR_IN + Vector3(0, -0.01, 0)])
	_cable(trunk, 0.04, 0.0032, _mat(Color(0.22, 0.23, 0.25), 0.55), "CableTronc", 2, 1, 0.025)


## Brassard de tension au bras gauche, tuyau vers le moniteur.
func _bp_cuff() -> void:
	var sec := _arm_section("L", 0.25)
	var c: Vector3 = sec["c"]
	var dir: Vector3 = sec["dir"]
	var perp: Vector3 = sec["perp"]
	var up := perp.cross(dir).normalized()
	if up.y < 0.0:
		up = -up
	var hw: float = sec["hw"]
	var hh: float = sec["hh"]
	var cuff := MeshInstance3D.new()
	cuff.name = "Brassard"
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.12
	cm.radial_segments = 40
	cm.rings = 1
	cuff.mesh = cm
	var fabric := _mat(Color(0.12, 0.2, 0.38), 0.85)
	cuff.material_override = fabric
	add_child(cuff)
	# Section elliptique du bras + 7 mm d'épaisseur ; le dessous entre dans le matelas (bras posé)
	cuff.global_transform = Transform3D(Basis(perp * (hw + 0.007), dir, up * (hh + 0.007)), c)
	# Bord rabattu (velcro) et embout du tuyau sur le dessus
	var edge := MeshInstance3D.new()
	var em := CylinderMesh.new()
	em.top_radius = 1.0
	em.bottom_radius = 1.0
	em.height = 0.012
	em.radial_segments = 40
	em.rings = 1
	edge.mesh = em
	edge.material_override = _mat(Color(0.08, 0.13, 0.26), 0.9)
	add_child(edge)
	edge.global_transform = Transform3D(Basis(perp * (hw + 0.0085), dir, up * (hh + 0.0085)), c + dir * 0.045)
	var top := c + up * (hh + 0.008)
	MeshUtil.cylinder_instance(self, 0.004, 0.012, top + up * 0.005, _mat(Color(0.75, 0.76, 0.78), 0.35, 0.6), "Embout")
	# Tuyau : quitte le brassard vers l'extérieur, tombe du bord de la table, traîne au sol
	# jusqu'à la tête du lit et remonte au scope
	var start := top + up * 0.011
	var path := PackedVector3Array([start, start + up * 0.012 + perp * 0.006, _on(c.x + 0.02, Patient.TABLE_MAX.y - 0.012, 0.003),
		Vector3(c.x + 0.06, 0.45, Patient.TABLE_MAX.y + 0.05), Vector3(c.x + 0.2, 0.004, 0.45),
		Vector3(0.62, 0.004, 0.42), Vector3(0.86, 0.004, 0.1), Vector3(0.88, 0.004, -0.3), Vector3(0.82, 0.5, -0.52), MONITOR_IN + Vector3(0, -0.02, 0)])
	_cable(path, 0.03, 0.003, _mat(Color(0.2, 0.22, 0.25), 0.6), "TuyauBrassard", 2, 1, 0.03)


func _process(delta: float) -> void:
	_t += delta
	if spo2_light:
		spo2_light.light_energy = 0.04 + 0.015 * sin(_t * 9.0)
	if bag:
		var b := 0.5 - 0.5 * cos(TAU * _t * breath_rate / 60.0)
		bag.scale = Vector3(0.026 * (1.0 - 0.25 * b), 0.032, 0.02 * (1.0 - 0.3 * b))
