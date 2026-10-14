class_name PatientGear
extends Node3D
## Ce que le soignant pose sur le patient, à l'endroit où il l'a posé : électrodes du scope et de
## l'ECG, pince de l'oxymètre, brassard, garrot, cathéter veineux et sa tubulure, électrodes de
## défibrillation, masque à oxygène, lunettes, masque de nébulisation, collier cervical. Les câbles
## et tuyaux sont des cordes simulées qui reposent sur le patient et pendent du brancard.

## Entrées des câbles (fixées par la salle) : scope, défibrillateur, débitmètre d'O2, poche de soluté
static var monitor_in := Vector3(0.82, 1.42, -0.62)
static var defib_in := Vector3(0.9, 1.08, 0.62)
static var o2_out := Vector3(1.39, 1.36, -0.35)
static var iv_bag := Vector3(0.64, 1.62, -0.31)

const LEAD_COLORS := {"RA": Color(0.92, 0.92, 0.94), "LA": Color(0.15, 0.15, 0.17), "LL": Color(0.85, 0.2, 0.2), "RL": Color(0.1, 0.55, 0.25),
	"V1": Color(0.85, 0.2, 0.2), "V2": Color(0.95, 0.85, 0.2), "V3": Color(0.2, 0.7, 0.3), "V4": Color(0.55, 0.35, 0.2),
	"V5": Color(0.15, 0.15, 0.17), "V6": Color(0.6, 0.3, 0.75)}

var patient: Patient
var electrodes := {}  ## dérivation -> [nœud, point]
var ecg12 := {}
var spo2_side := ""
var cuff_side := ""
var iv := {}  ## {"side", "t", "hub", "line": bool, "fluid": bool}
var tourniquet := {}  ## {"side", "t"}
var pads: Array = []  ## points des deux électrodes de défibrillation
var o2 := ""  ## "", "lunettes", "masque", "nebu", "bavu"
var collar_on := false
var spo2_light: OmniLight3D
var _nodes := {}  ## clé -> Array[Node3D] (pour retirer)
var _follow: Array = []  ## [nœud, position de base] : suivent la peau (respiration, massage)
var _obstacles: Array = []
var _t := 0.0
var _reservoir: MeshInstance3D
var _mist: GPUParticles3D


func build(profile: Dictionary) -> void:
	if profile.get("collar", false):
		set_collar(true)


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


func _own(key: String, n: Node3D) -> Node3D:
	if not _nodes.has(key):
		_nodes[key] = []
	_nodes[key].append(n)
	return n


func _remove(key: String) -> void:
	for n in _nodes.get(key, []):
		for f in _follow.duplicate():
			if f[0] == n:
				_follow.erase(f)
		(n as Node).queue_free()
	_nodes.erase(key)


func has(key: String) -> bool:
	return _nodes.has(key)


func _tube(pts: PackedVector3Array, r: float, mat: Material, key: String, nm := "Tube") -> MeshInstance3D:
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(r)
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = MeshUtil.tube(pts, rr, 8)
	mi.material_override = mat
	add_child(mi)
	_own(key, mi)
	return mi


## Câble souple posé par simulation (pas mis en cache : son trajet dépend du joueur).
func _cable(path: PackedVector3Array, slack: float, r: float, mat: Material, key: String, pin_a := 2, pin_b := 1, seg := 0.025) -> MeshInstance3D:
	var pts := Cable.smooth(Cable._simulate(path, slack, r, seg, pin_a, pin_b, _obstacles))
	return _tube(pts, r, mat, key, "Cable")


func _on(x: float, z: float, lift := 0.0) -> Vector3:
	return Cable.on_surface(x, z, lift)


## Point sur la peau sous (x, z) et normale.
func _skin_at(p: Vector3) -> Array:
	var y := Patient.body_height(p.x, p.z)
	return [Vector3(p.x, y, p.z), Patient.skin_normal(p.x, p.z)]


func _follow_skin(n: Node3D) -> void:
	_follow.append([n, n.position])


# ---------------------------------------------------------------- Électrodes (scope, ECG 12)

## Électrode autocollante (mousse blanche, bouton pression) et pince de couleur, câble vers le scope
## (ou l'électrocardiographe).
func place_electrode(lead: String, p: Vector3, for_ecg12 := false) -> void:
	var key := ("ecg12_" if for_ecg12 else "ecg_") + lead
	_remove(key)
	var s := _skin_at(p)
	var q: Vector3 = s[0]
	var nrm: Vector3 = s[1]
	var b := Basis(Quaternion(Vector3.UP, nrm))
	var disc := MeshUtil.cylinder_instance(self, 0.012, 0.0015, q, _mat(Color(0.96, 0.96, 0.94), 0.7), "Electrode")
	disc.global_transform = Transform3D(b, q + nrm * 0.0008)
	_own(key, disc)
	_follow_skin(disc)
	var snap := MeshUtil.cylinder_instance(self, 0.003, 0.004, q, _mat(Color(0.75, 0.76, 0.78), 0.3, 0.8), "Bouton")
	snap.global_transform = Transform3D(b, q + nrm * 0.004)
	_own(key, snap)
	_follow_skin(snap)
	var col: Color = LEAD_COLORS.get(lead, Color.WHITE)
	var clip := MeshUtil.box_instance(self, Vector3(0.008, 0.006, 0.016), q + nrm * 0.007, _mat(col, 0.5), "Pince")
	_own(key, clip)
	_follow_skin(clip)
	var start := q + nrm * 0.007
	var dest := monitor_in if not for_ecg12 else Vector3(-0.95, 0.9, 0.82)
	# Le câble quitte le thorax vers le bord du brancard le plus proche puis rejoint l'appareil
	var side := 1.0 if q.z > 0.0 or for_ecg12 else -1.0
	var edge := _on(q.x + (0.06 if not for_ecg12 else -0.05), side * 0.27, 0.003)
	var path := PackedVector3Array([start, start + nrm * 0.012, edge, Vector3(edge.x, 0.55, side * 0.36), dest])
	_cable(path, 0.05, 0.0016, _mat(col, 0.55), key)
	if for_ecg12:
		ecg12[lead] = q
	else:
		electrodes[lead] = q


func remove_ecg12() -> void:
	for lead in ecg12.keys():
		_remove("ecg12_" + lead)
	ecg12.clear()


func scope_leads() -> int:
	return electrodes.size()


# ---------------------------------------------------------------- Oxymètre, brassard

func place_spo2(side: String) -> void:
	_remove("spo2")
	spo2_side = side
	var tip := Patient.arm_point(side, 1.0)
	var dir := Patient.arm_dir(side, 0.97)
	var lat := dir.cross(Vector3.UP).normalized()
	var up := lat.cross(dir).normalized()
	var clip := Node3D.new()
	clip.name = "Oxymetre"
	add_child(clip)
	_own("spo2", clip)
	clip.global_transform = Transform3D(Basis(lat, up, dir), tip - dir * 0.014 + up * 0.002)
	MeshUtil.box_instance(clip, Vector3(0.024, 0.012, 0.034), Vector3(0, 0.011, 0), _mat(Color(0.82, 0.84, 0.86), 0.4), "Haut")
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
	var s := 1.0 if side == "L" else -1.0
	var path := PackedVector3Array([start, start - dir * 0.02 + up * 0.004, _on(tip.x + 0.06, s * 0.275, 0.002),
		Vector3(tip.x + 0.16, 0.62, s * 0.36), Vector3(0.3, 0.42, s * 0.42), monitor_in])
	_cable(path, 0.04, 0.0019, _mat(Color(0.25, 0.27, 0.3), 0.6), "spo2")


func remove_spo2() -> void:
	_remove("spo2")
	spo2_side = ""
	spo2_light = null


## Section du bras au point t : centre, demi-largeur, demi-hauteur, axe (mesurée sur la carte de la peau).
func arm_section(side: String, t: float) -> Dictionary:
	var p := Patient.arm_point(side, t)
	var dir := Patient.arm_dir(side, t)
	var top := Patient.body_height(p.x, p.z)
	var hh := maxf(0.015, (top - Patient.TABLE_TOP) * 0.5)
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


func _band(key: String, side: String, t: float, width: float, thick: float, mat: Material) -> Dictionary:
	var sec := arm_section(side, t)
	var c: Vector3 = sec["c"]
	var dir: Vector3 = sec["dir"]
	var perp: Vector3 = sec["perp"]
	var up := perp.cross(dir).normalized()
	if up.y < 0.0:
		up = -up
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = width
	cm.radial_segments = 40
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	add_child(mi)
	_own(key, mi)
	mi.global_transform = Transform3D(Basis(perp * (float(sec["hw"]) + thick), dir, up * (float(sec["hh"]) + thick)), c)
	sec["up"] = up
	return sec


func place_cuff(side: String) -> void:
	_remove("cuff")
	cuff_side = side
	var sec := _band("cuff", side, 0.25, 0.12, 0.007, _mat(Color(0.12, 0.2, 0.38), 0.85))
	var c: Vector3 = sec["c"]
	var up: Vector3 = sec["up"]
	var top := c + up * (float(sec["hh"]) + 0.008)
	_own("cuff", MeshUtil.cylinder_instance(self, 0.004, 0.012, top + up * 0.005, _mat(Color(0.75, 0.76, 0.78), 0.35, 0.6), "Embout"))
	var s := 1.0 if side == "L" else -1.0
	var start := top + up * 0.011
	var path := PackedVector3Array([start, start + up * 0.012, _on(c.x + 0.02, s * 0.29, 0.003),
		Vector3(c.x + 0.06, 0.45, s * 0.36), Vector3(0.5, 0.6, s * 0.4), monitor_in])
	_cable(path, 0.03, 0.003, _mat(Color(0.2, 0.22, 0.25), 0.6), "cuff")


func remove_cuff() -> void:
	_remove("cuff")
	cuff_side = ""


# ---------------------------------------------------------------- Garrot, voie veineuse

func place_tourniquet(side: String, t: float) -> void:
	_remove("garrot")
	tourniquet = {"side": side, "t": t}
	var sec := _band("garrot", side, t, 0.025, 0.004, _mat(Color(0.25, 0.45, 0.8), 0.6))
	var c: Vector3 = sec["c"]
	var up: Vector3 = sec["up"]
	_own("garrot", MeshUtil.box_instance(self, Vector3(0.03, 0.012, 0.032), c + up * (float(sec["hh"]) + 0.01), _mat(Color(0.1, 0.1, 0.12), 0.5), "Boucle"))


func remove_tourniquet() -> void:
	_remove("garrot")
	tourniquet = {}


## Cathéter veineux posé (point de ponction sur la peau, axe de la veine) sous pansement transparent.
func place_iv(side: String, p: Vector3, dir: Vector3, color := Color(1.0, 0.82, 0.15)) -> void:
	_remove("iv")
	var s := _skin_at(p)
	var top: Vector3 = s[0] + Vector3.UP * 0.001
	var nrm: Vector3 = s[1]
	dir = (dir - nrm * dir.dot(nrm)).normalized()
	var dress := MeshUtil.box_instance(self, Vector3(0.05, 0.002, 0.04), top, _clear(Color(0.92, 0.95, 1.0, 0.35), 0.15), "Pansement")
	dress.look_at_from_position(top, top + dir, nrm)
	_own("iv", dress)
	var hub := top - dir * 0.012 + nrm * 0.004
	var cat := MeshUtil.cylinder_instance(self, 0.004, 0.018, hub, _mat(color, 0.4), "Catheter")
	cat.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, -dir)), hub)
	_own("iv", cat)
	var port := MeshUtil.cylinder_instance(self, 0.0035, 0.008, hub + nrm * 0.005, _mat(Color(0.95, 0.95, 0.95), 0.4), "Robinet")
	_own("iv", port)
	iv = {"side": side, "hub": hub, "port": hub + nrm * 0.009, "dir": dir, "line": false}


func has_iv() -> bool:
	return not iv.is_empty()


## Tubulure de la poche de soluté (sur le mât du brancard) jusqu'au cathéter.
func connect_line() -> void:
	if iv.is_empty():
		return
	_remove("ligne")
	iv["line"] = true
	var hub: Vector3 = iv["hub"]
	var dir: Vector3 = iv["dir"]
	var bag_scene: PackedScene = load("res://assets/models/poche.glb")
	var bag: Node3D = bag_scene.instantiate()
	add_child(bag)
	bag.global_position = iv_bag
	_own("ligne", bag)
	var drip := iv_bag + Vector3(0, -0.31, 0)
	var s := 1.0 if hub.z > 0.0 else -1.0
	var path := PackedVector3Array([hub - dir * 0.01, hub - dir * 0.03 + Vector3.UP * 0.004, _on(hub.x + 0.08, s * 0.28, 0.002),
		Vector3(hub.x + 0.2, 0.62, s * 0.36), Vector3(0.6, 0.9, -0.36), drip])
	_cable(path, 0.05, 0.0021, _clear(Color(0.9, 0.95, 1.0, 0.55), 0.1), "ligne")


func remove_iv() -> void:
	_remove("iv")
	_remove("ligne")
	iv = {}


# ---------------------------------------------------------------- Défibrillation

## Électrodes de défibrillation (patchs) aux points choisis, câble vers le défibrillateur.
func place_pad(p: Vector3) -> void:
	if pads.size() >= 2:
		return
	var key := "pad%d" % pads.size()
	var s := _skin_at(p)
	var q: Vector3 = s[0]
	var nrm: Vector3 = s[1]
	var scene: PackedScene = load("res://assets/models/electrode_defib.glb")
	var pad: Node3D = scene.instantiate()
	add_child(pad)
	# Le patch est modélisé à plat (Z Blender = normale) : Y du jeu = normale de la peau
	var fwd := Vector3(1, 0, 0)
	fwd = (fwd - nrm * fwd.dot(nrm)).normalized()
	pad.global_transform = Transform3D(Basis(nrm.cross(fwd), nrm, fwd).orthonormalized(), q + nrm * 0.001)
	_own(key, pad)
	_follow_skin(pad)
	var start := q + nrm * 0.004
	var side := 1.0
	var edge := _on(q.x + 0.05, side * 0.27, 0.003)
	var path := PackedVector3Array([start, start + nrm * 0.015, edge, Vector3(edge.x + 0.1, 0.7, side * 0.38), defib_in])
	_cable(path, 0.05, 0.0028, _mat(Color(0.2, 0.2, 0.22), 0.55), key)
	pads.append(q)


func remove_pads() -> void:
	_remove("pad0")
	_remove("pad1")
	pads.clear()


# ---------------------------------------------------------------- Oxygène

## Oxygénothérapie posée sur le visage : "lunettes", "masque" (haute concentration), "nebu", "".
func set_o2(kind: String) -> void:
	_remove("o2")
	_reservoir = null
	_mist = null
	o2 = kind
	match kind:
		"masque":
			_mask(true, false)
		"nebu":
			_mask(false, true)
		"lunettes":
			_cannula()


func _mask(reservoir: bool, nebu: bool) -> void:
	var nose := Patient.lm("nose_tip")
	var x_chin := nose.x - 0.056
	var x_bridge := nose.x + 0.042
	var cx := (x_chin + x_bridge) * 0.5
	var ax := (x_bridge - x_chin) * 0.5
	var az := 0.046
	var apex := Vector3(nose.x + 0.002, nose.y + 0.017, 0.0)
	var n_around := 40
	var n_up := 12
	var rim := PackedVector3Array()
	for i in n_around:
		var a := TAU * i / n_around
		var x := cx + ax * cos(a)
		var z := az * sin(a)
		rim.append(Vector3(x, Patient.body_height(x, z) + 0.003, z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in n_up + 1:
		var t := float(k) / n_up
		var hs := cos(t * PI * 0.5)
		var vs := sin(t * PI * 0.5)
		for i in n_around + 1:
			var r := rim[i % n_around]
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
	shell.name = "Masque"
	shell.mesh = st.commit()
	shell.material_override = _clear(Color(0.72, 0.92, 0.82, 0.2) if not nebu else Color(0.85, 0.9, 0.95, 0.25), 0.18)
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	_own("o2", shell)
	var loop := PackedVector3Array(rim)
	loop.append(rim[0])
	_tube(loop, 0.0032, _clear(Color(0.7, 0.9, 0.82, 0.5), 0.3), "o2", "Bord")
	var port := Vector3(cx - 0.02, apex.y - 0.006, -0.03)
	var feed := port
	if reservoir:
		_reservoir = MeshInstance3D.new()
		var bs := CapsuleMesh.new()
		bs.radius = 1.0
		bs.height = 3.4
		_reservoir.mesh = bs
		_reservoir.material_override = _clear(Color(0.45, 0.85, 0.6, 0.45))
		var bag_c := Vector3(x_chin - 0.01, 0.0, -0.125)
		bag_c.y = maxf(Patient.body_height(bag_c.x, bag_c.z), Patient.TABLE_TOP) + 0.024
		_reservoir.position = bag_c
		_reservoir.rotation_degrees = Vector3(0, -25, 90)
		_reservoir.scale = Vector3(0.026, 0.032, 0.02)
		add_child(_reservoir)
		_own("o2", _reservoir)
		_tube(MeshUtil.bezier(port, port + Vector3(-0.01, 0.01, -0.03), bag_c + Vector3(0.04, 0.03, 0.02), bag_c + Vector3(0.045, 0.01, 0.012), 14), 0.006, _clear(Color(0.55, 0.88, 0.7, 0.55), 0.2), "o2")
		feed = bag_c + Vector3(-0.045, 0.0, 0.0)
	if nebu:
		# Chambre de nébulisation sous le masque, brouillard qui s'échappe
		var cup := MeshUtil.cylinder_instance(self, 0.017, 0.05, port + Vector3(-0.01, -0.01, -0.03), _clear(Color(0.9, 0.95, 1.0, 0.5), 0.1), "Nebuliseur")
		cup.rotation_degrees = Vector3(0, 0, 60)
		_own("o2", cup)
		feed = port + Vector3(-0.03, -0.03, -0.05)
		_mist = GPUParticles3D.new()
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 35.0
		pm.initial_velocity_min = 0.02
		pm.initial_velocity_max = 0.05
		pm.gravity = Vector3(0, 0.01, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.4
		pm.color = Color(1, 1, 1, 0.25)
		_mist.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(0.02, 0.02)
		var mm := StandardMaterial3D.new()
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mm.albedo_color = Color(1, 1, 1, 0.12)
		mm.vertex_color_use_as_albedo = true
		qm.material = mm
		_mist.draw_pass_1 = qm
		_mist.amount = 24
		_mist.lifetime = 1.4
		_mist.position = Vector3(cx, apex.y + 0.01, 0.0)
		add_child(_mist)
		_own("o2", _mist)
	# Élastique et tuyau d'oxygène jusqu'au débitmètre mural
	var occ := Patient.lm("occiput")
	var hc := Vector3(cx + 0.03, (nose.y + occ.y) * 0.5, 0.0)
	var band := MeshInstance3D.new()
	var bt := TorusMesh.new()
	bt.inner_radius = 0.98
	bt.outer_radius = 1.0
	bt.rings = 40
	bt.ring_segments = 6
	band.mesh = bt
	band.material_override = _mat(Color(0.2, 0.55, 0.4), 0.7)
	band.transform = Transform3D(Basis(Vector3(0.006, 0.0, 0.0), Vector3(0.0, (nose.y - occ.y) * 0.5, 0.0), Vector3(0.0, 0.0, 0.078)), hc)
	add_child(band)
	_own("o2", band)
	_o2_tube(feed)


func _o2_tube(from: Vector3) -> void:
	var head_x := float(Patient.landmarks.get("head_top_x", 0.41))
	var path := PackedVector3Array([from, from + Vector3(0.0, 0.01, -0.02), _on(head_x + 0.02, -0.14, 0.004),
		_on(Patient.TABLE_MAX.x - 0.03, -0.18, 0.004), Vector3(Patient.TABLE_MAX.x + 0.15, 0.85, -0.3), o2_out])
	_cable(path, 0.05, 0.0035, _clear(Color(0.55, 0.9, 0.7, 0.6), 0.15), "o2", 2, 1, 0.03)


## Lunettes à oxygène : deux embouts dans les narines, tubulure sur les oreilles.
func _cannula() -> void:
	var nose := Patient.lm("nose_tip")
	var under := Vector3(nose.x - 0.012, nose.y - 0.006, 0.0)
	var mat := _clear(Color(0.75, 0.95, 0.85, 0.7), 0.2)
	for s in [-1.0, 1.0]:
		var ear := Vector3(nose.x - 0.04, Patient.lm("occiput").y + 0.07, s * 0.075)
		var pts := MeshUtil.bezier(under + Vector3(0, 0, s * 0.008), under + Vector3(-0.01, -0.003, s * 0.04), ear + Vector3(0.03, 0.04, 0), ear, 18)
		_tube(pts, 0.0022, mat, "o2", "Lunettes")
	_o2_tube(Vector3(nose.x - 0.04, Patient.lm("occiput").y + 0.05, -0.08))


# ---------------------------------------------------------------- Collier cervical

func set_collar(on: bool) -> void:
	_remove("collier")
	collar_on = on
	if not on:
		return
	var nk: Dictionary = Patient.landmarks.get("neck", {})
	if nk.is_empty():
		return
	var xc: float = nk["x"]
	var cy: float = (nk["y_front"] + nk["y_back"]) * 0.5
	var ry: float = (nk["y_front"] - nk["y_back"]) * 0.5 + 0.012
	var rz: float = nk["half_width"] + 0.014
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 56
	for i in n + 1:
		var a := TAU * i / n
		var front := pow(maxf(0.0, cos(a)), 2.0)
		var x0 := xc - 0.032 - 0.006 * front
		var x1 := xc + 0.03 + 0.024 * front
		for k in 2:
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
	_own("collier", mi)


# ---------------------------------------------------------------- Animation

func _process(delta: float) -> void:
	_t += delta
	if spo2_light:
		spo2_light.light_energy = 0.04 + 0.015 * sin(_t * 9.0)
	if _reservoir:
		var b := 0.5 - 0.5 * cos(TAU * _t * maxf(patient.resp_rate, 1.0) / 60.0)
		_reservoir.scale = Vector3(0.026 * (1.0 - 0.25 * b), 0.032, 0.02 * (1.0 - 0.3 * b))
	for f in _follow:
		var n: Node3D = f[0]
		if is_instance_valid(n):
			var base: Vector3 = f[1]
			n.position = base + Vector3.UP * patient.skin_offset(base)
