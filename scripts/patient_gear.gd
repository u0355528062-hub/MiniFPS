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

const IV_LIFT := 0.0018  ## hauteur de l'axe du cathéter posé au point de ponction (embase à plat sur la peau)
static var _scenes := {}


static func _scene(file: String) -> PackedScene:
	if not _scenes.has(file):
		_scenes[file] = load("res://assets/models/%s.glb" % file)
	return _scenes[file]


## Longueur de la canule (18G : 45 mm, 20G : 32 mm).
static func cath_len(gauge: String) -> float:
	return 0.045 if gauge == "18" else 0.032


## Repère du cathéter : pointe en p + axe * s, axe dans la direction d de la veine, piquant sous la
## peau (normale n) avec l'angle donné.
static func iv_pose(p: Vector3, d: Vector3, n: Vector3, angle_deg: float, s: float) -> Transform3D:
	d = (d - n * d.dot(n)).normalized()
	var a := deg_to_rad(angle_deg)
	var z := (d * cos(a) - n * sin(a)).normalized()
	var y := (n * cos(a) + d * sin(a)).normalized()
	# (la carte de hauteur peut être un peu au-dessus du maillage : point de ponction 0,8 mm plus bas)
	return Transform3D(Basis(y.cross(z), y, z), p - n * 0.0008 + z * s)


func catheter_node(gauge: String) -> Node3D:
	var n: Node3D = _scene("catheter" + gauge).instantiate()
	n.name = "Catheter%sG" % gauge
	return n


func syringe_node() -> Node3D:
	var n: Node3D = _scene("seringue").instantiate()
	n.name = "Seringue"
	return n


## Profil de la section du bras au point t : points (décalage latéral, hauteur) du dessus du bras,
## mesurés sur la carte de la peau, du bord intérieur au bord extérieur.
func arm_profile(side: String, t: float) -> Dictionary:
	var c := Patient.arm_point(side, t)
	var dir := Patient.arm_dir(side, t)
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var perp := dir.cross(Vector3.UP).normalized()
	var top := Patient.body_height(c.x, c.z)
	var limit := Patient.TABLE_TOP + 0.006
	var edges := [0.0, 0.0]
	for k in 2:
		var sgn := -1.0 if k == 0 else 1.0
		var prev := top
		var o := 0.0
		while o < 0.07:
			o += 0.002
			var q := c + perp * o * sgn
			var hq := Patient.body_height(q.x, q.z)
			# Bord du bras : la peau rejoint le drap, ou remonte vers le tronc
			if hq < limit or (hq > prev + 0.0005 and o > 0.02):
				break
			prev = hq
		edges[k] = o * sgn
	var pts := PackedVector2Array()
	var n := 24
	for i in n + 1:
		var o: float = lerpf(edges[0], edges[1], float(i) / n)
		var q := c + perp * o
		pts.append(Vector2(o, maxf(Patient.body_height(q.x, q.z), limit)))
	return {"c": Vector3(c.x, 0.0, c.z), "dir": dir, "perp": perp, "pts": pts, "edges": edges}


## Garrot à boucle autour du bras au point t : bande élastique bleue de 25 mm qui épouse le dessus
## du bras (passe sous le bras dans le matelas, invisible) et boucle à clip grise posée à plat sur la
## bande, bout libre couché le long de la bande. slack : 0 serré (la bande marque un peu la peau),
## 1 lâche (bande soulevée) ; preview : aperçu translucide avant de serrer.
func tourniquet_node(side: String, t: float, slack := 0.0, preview := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Garrot"
	var pr := arm_profile(side, t)
	var c: Vector3 = pr["c"]
	var dir: Vector3 = pr["dir"]
	var perp: Vector3 = pr["perp"]
	var prof: PackedVector2Array = pr["pts"]
	var lift := lerpf(-0.0006, 0.012, clampf(slack, 0.0, 1.0))
	var thick := 0.0022
	var band := _mat(Color(0.16, 0.4, 0.85), 0.7)
	var clip := _mat(Color(0.86, 0.88, 0.9), 0.35)
	var clip_dark := _mat(Color(0.58, 0.62, 0.68), 0.4)
	if preview:
		for m in [band, clip, clip_dark]:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.45
	# Boucle fermée dans le plan de la section : dessus du bras (soulevé si lâche), puis les côtés
	# qui descendent sous le niveau du matelas, et retour par-dessous.
	# Dessous du bras : deux quarts d'ellipse du bord (la plus grande largeur) au point d'appui
	var loop := PackedVector2Array()
	# (la carte de hauteur ne voit que le dessus : on suppose une section à peu près ronde)
	var pa := prof[0] + Vector2(-0.0015 - lift * 0.5, lift)
	var pb := prof[prof.size() - 1] + Vector2(0.0015 + lift * 0.5, lift)
	var top_y := prof[prof.size() / 2].y
	var bottom := maxf(Patient.TABLE_TOP - 0.003, top_y - (pb.x - pa.x) * 1.02)
	var cm := (pa.x + pb.x) * 0.5
	for i in 8:
		var ph := PI * 0.5 * (1.0 - i / 8.0)
		loop.append(Vector2(cm + (pa.x - cm) * cos(ph), pa.y - (pa.y - bottom) * sin(ph)))
	for i in range(1, prof.size() - 1):
		var q := prof[i]
		loop.append(Vector2(q.x, q.y + lift))
	for i in 8:
		var ph := PI * 0.5 * i / 8.0
		loop.append(Vector2(cm + (pb.x - cm) * cos(ph), pb.y - (pb.y - bottom) * sin(ph)))
	var m := loop.size()
	var norms := PackedVector2Array()
	for i in m:
		var a := loop[(i - 1 + m) % m]
		var b := loop[(i + 1) % m]
		var tg := (b - a).normalized()
		norms.append(Vector2(tg.y, -tg.x))
	# La normale doit pointer vers l'extérieur (vers le haut sur le dessus)
	var mid := m / 2
	if norms[mid].y < 0.0:
		for i in m:
			norms[i] = -norms[i]
	var to3 := func(v: Vector2) -> Vector3:
		return c + perp * v.x + Vector3.UP * v.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wdt := 0.0125
	for i in m:
		var p3: Vector3 = to3.call(loop[i])
		var n3 := (perp * norms[i].x + Vector3.UP * norms[i].y).normalized()
		for e in [[-wdt, 0.0], [wdt, 0.0], [wdt, thick], [-wdt, thick]]:
			st.add_vertex(p3 + n3 * float(e[1]) + dir * float(e[0]))
	for i in m:
		var b0 := i * 4
		var b1 := ((i + 1) % m) * 4
		for f in [[3, 2], [0, 3], [1, 0], [2, 1]]:
			var p0: int = f[0]
			var p1: int = f[1]
			st.add_index(b0 + p0)
			st.add_index(b1 + p0)
			st.add_index(b0 + p1)
			st.add_index(b0 + p1)
			st.add_index(b1 + p0)
			st.add_index(b1 + p1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Bande"
	mi.mesh = st.commit()
	var dm := band.duplicate() as StandardMaterial3D
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = dm
	root.add_child(mi)
	# Boucle à clip : sur le dessus du bras, un peu vers l'extérieur, à plat sur la bande
	var ib := 8 + int(prof.size() * 0.6)
	var pos: Vector3 = to3.call(loop[ib])
	var n0 := (perp * norms[ib].x + Vector3.UP * norms[ib].y).normalized()
	var tan := n0.cross(dir).normalized()
	var bas := Basis(tan, n0, dir).orthonormalized()
	var body := MeshUtil.box_instance(root, Vector3(0.02, 0.0035, 0.027), Vector3.ZERO, clip, "Boucle")
	body.transform = Transform3D(bas, pos + n0 * (thick + 0.0018))
	var btn := MeshUtil.box_instance(root, Vector3(0.014, 0.0012, 0.006), Vector3.ZERO, clip_dark, "Poussoir")
	btn.transform = Transform3D(bas, pos + n0 * (thick + 0.0042))
	# Bout libre : couché sur la bande, vers le milieu du bras
	var it := 8 + int(prof.size() * 0.4)
	var pt: Vector3 = to3.call(loop[it])
	var nt := (perp * norms[it].x + Vector3.UP * norms[it].y).normalized()
	var tt := nt.cross(dir).normalized()
	var tail := MeshUtil.box_instance(root, Vector3(0.03, 0.0014, wdt * 2.0 - 0.003), Vector3.ZERO, band, "BoutLibre")
	tail.transform = Transform3D(Basis(tt, nt, dir).orthonormalized(), pt + nt * (thick + 0.0008))
	return root


func place_tourniquet(side: String, t: float) -> void:
	_remove("garrot")
	tourniquet = {"side": side, "t": t}
	var n := tourniquet_node(side, t)
	add_child(n)
	IVProcedure.gear_layer(n)
	_own("garrot", n)


func remove_tourniquet() -> void:
	_remove("garrot")
	tourniquet = {}


## Cathéter veineux posé (point de ponction sur la peau, axe de la veine vers le coude), aiguille
## retirée et bouchon vissé. node : le cathéter tenu pendant la pose (sinon on en crée un).
func place_iv(side: String, p: Vector3, dir: Vector3, gauge := "18", node: Node3D = null) -> void:
	_remove("iv")
	_remove("ligne")
	_remove("pansement")
	var s := _skin_at(p)
	var q: Vector3 = s[0]
	var nrm: Vector3 = s[1]
	dir = (dir - nrm * dir.dot(nrm)).normalized()
	var L := cath_len(gauge)
	if node == null:
		node = catheter_node(gauge)
	if node.get_parent():
		node.get_parent().remove_child(node)
	add_child(node)
	IVProcedure.gear_layer(node)
	node.global_transform = iv_pose(q, dir, nrm, IVProcedure.ANGLE_FLAT, IVProcedure.DEPTH_VEIN)
	node.global_position += nrm * IV_LIFT
	var cat := node.find_child("Catheter", true, false) as Node3D
	cat.position.z = L - 0.002 - IVProcedure.DEPTH_VEIN
	(node.find_child("Aiguille", true, false) as Node3D).visible = false
	(node.find_child("Reflux", true, false) as Node3D).visible = false
	(node.find_child("Obturateur", true, false) as Node3D).visible = true
	_own("iv", node)
	var xf := node.global_transform
	var o := cat.position
	iv = {"side": side, "p": q, "dir": dir, "gauge": gauge, "node": node, "line": false, "dressing": false,
		"hub": xf * (o + Vector3(0, 0, -L - 0.009)), "port": xf * (o + Vector3(0, 0.0088, -L - 0.0085)),
		"port_up": xf.basis.y.normalized(), "rear": xf * (o + Vector3(0, 0, -L - 0.0185)), "axis": xf.basis.z.normalized()}


func has_iv() -> bool:
	return not iv.is_empty()


## Pansement transparent adhésif (type film semi-perméable) : film fin qui épouse la peau et le
## cathéter (ailettes, embase), cadre blanc renforcé avec une encoche pour le site d'injection.
## Créé en l'air (on le colle avec dressing_progress), posé par add_dressing.
func dressing_node() -> Node3D:
	var root := Node3D.new()
	root.name = "Pansement"
	if iv.is_empty():
		return root
	var p: Vector3 = iv["p"]
	var d: Vector3 = iv["dir"]
	d = Vector3(d.x, 0.0, d.z).normalized()
	var lat := Vector3(-d.z, 0.0, d.x)
	var c := p + d * 0.012
	var u0 := -0.026
	var u1 := 0.03
	var v0 := 0.032
	var nu := 30
	var nv := 26
	var film := SurfaceTool.new()
	film.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := []
	for j in nv + 1:
		var row := []
		for i in nu + 1:
			var u := lerpf(u0, u1, float(i) / nu)
			var v := lerpf(-v0, v0, float(j) / nv)
			var w := c + d * u + lat * v
			var y := Patient.body_height(w.x, w.z) + 0.0006
			# Le film recouvre les ailettes et l'embase (encoche autour du site d'injection)
			var uh := u + 0.012  # 0 au point de ponction
			var hub := (1.0 - smoothstep(0.0036, 0.0075, absf(v))) * smoothstep(0.004, -0.004, uh) * 0.0068
			var wing := (1.0 - smoothstep(0.012, 0.017, absf(v))) * smoothstep(0.003, -0.002, uh) * smoothstep(-0.03, -0.024, uh) * 0.0016
			y += maxf(hub, wing)
			row.append(Vector3(w.x, y, w.z) - c)
		verts.append(row)
	for j in nv:
		for i in nu:
			var a: Vector3 = verts[j][i]
			var b: Vector3 = verts[j][i + 1]
			var cc: Vector3 = verts[j + 1][i]
			var dd: Vector3 = verts[j + 1][i + 1]
			var u := lerpf(u0, u1, (i + 0.5) / nu)
			var v := lerpf(-v0, v0, (j + 0.5) / nv)
			var notch := u < u0 + 0.014 and absf(v) < 0.007
			if notch:
				continue
			var border := u < u0 + 0.0045 or u > u1 - 0.0045 or absf(v) > v0 - 0.0045 or (u < u0 + 0.0185 and absf(v) < 0.0115)
			var stt := frame if border else film
			var lift := Vector3(0, 0.00025, 0) if border else Vector3.ZERO
			for q in [a, b, cc, b, dd, cc]:
				stt.set_uv(Vector2((q as Vector3).dot(d), (q as Vector3).dot(lat)) * 20.0)
				stt.add_vertex(q + lift)
	for stt in [film, frame]:
		stt.generate_normals()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.93, 0.96, 1.0, 0.16)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.roughness = 0.14
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frm := StandardMaterial3D.new()
	frm.albedo_color = Color(0.97, 0.97, 0.95, 0.88)
	frm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frm.roughness = 0.65
	frm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for e in [[film, fm, "Film"], [frame, frm, "Cadre"]]:
		var mi := MeshInstance3D.new()
		mi.name = e[2]
		mi.mesh = (e[0] as SurfaceTool).commit()
		mi.material_override = e[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	add_child(root)
	IVProcedure.gear_layer(root)
	root.global_position = c
	root.set_meta("base", c)
	dressing_progress(root, 0.0)
	return root


## Pansement en cours de pose : il descend sur la peau et se plaque (k de 0 à 1).
func dressing_progress(node: Node3D, k: float) -> void:
	var base: Vector3 = node.get_meta("base", node.global_position)
	node.global_position = base + Vector3.UP * (1.0 - k) * 0.014
	node.scale = Vector3(1.0, lerpf(1.6, 1.0, k), 1.0)


func add_dressing(node: Node3D = null) -> void:
	if iv.is_empty():
		return
	_remove("pansement")
	if node == null:
		node = dressing_node()
	dressing_progress(node, 1.0)
	_own("pansement", node)
	iv["dressing"] = true


## Tubulure de la poche de soluté (sur la potence) jusqu'au cathéter : prolongateur et robinet à
## trois voies à l'arrière de l'embase, tubulure posée sur le drap et pendant du brancard, régulateur
## à molette, chambre compte-gouttes sous la poche.
func connect_line() -> void:
	if iv.is_empty():
		return
	_remove("ligne")
	iv["line"] = true
	var node: Node3D = iv["node"]
	(node.find_child("Obturateur", true, false) as Node3D).visible = false
	var rear: Vector3 = iv["rear"]
	var axis: Vector3 = iv["axis"]
	var back := -Vector3(axis.x, 0.0, axis.z).normalized()
	var clear := _clear(Color(0.9, 0.95, 1.0, 0.5), 0.15)
	var white := _mat(Color(0.94, 0.94, 0.92), 0.45)
	var blue := _mat(Color(0.15, 0.35, 0.85), 0.4)
	# Embout luer vissé et prolongateur jusqu'au robinet
	var luer := MeshUtil.cylinder_instance(self, 0.0036, 0.008, rear, white, "EmboutLuer")
	luer.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, -axis)), rear - axis * 0.003)
	_own("ligne", luer)
	var sk := _on(rear.x + back.x * 0.05, rear.z + back.z * 0.05, 0.004)
	var ext := MeshUtil.bezier(rear - axis * 0.007, rear - axis * 0.02, sk - back * 0.02, sk, 10)
	_tube(ext, 0.0016, clear, "ligne", "Prolongateur")
	# Robinet à trois voies (corps blanc, robinet bleu)
	var rob := Node3D.new()
	rob.name = "Robinet3voies"
	add_child(rob)
	_own("ligne", rob)
	var lat := Vector3.UP.cross(back).normalized()
	rob.global_transform = Transform3D(Basis(lat, Vector3.UP, back), sk + back * 0.012)
	MeshUtil.box_instance(rob, Vector3(0.008, 0.008, 0.024), Vector3.ZERO, white, "Corps")
	MeshUtil.cylinder_instance(rob, 0.0028, 0.012, Vector3(0, 0.008, 0), white, "Voie")
	MeshUtil.box_instance(rob, Vector3(0.022, 0.003, 0.006), Vector3(0, 0.0055, 0), blue, "Manette")
	MeshUtil.cylinder_instance(rob, 0.0032, 0.003, Vector3(0, 0.0145, 0), blue, "Bouchon")
	# Tubulure jusqu'à la chambre compte-gouttes
	var start := sk + back * 0.026
	var drip := iv_bag + Vector3(-0.018, -0.322, 0)
	var s := 1.0 if rear.z > 0.0 else -1.0
	var path := PackedVector3Array([start, start + back * 0.02 + Vector3.UP * 0.003, _on(start.x - 0.06, s * 0.29, 0.002),
		Vector3(start.x - 0.08, 0.6, s * 0.4), Vector3(lerpf(start.x, iv_bag.x, 0.5), 1.05, lerpf(s * 0.4, iv_bag.z, 0.6)), drip])
	var pts := Cable.smooth(Cable._simulate(path, 0.04, 0.0021, 0.025, 2, 2, _obstacles))
	_tube(pts, 0.0021, clear, "ligne", "Tubulure")
	# Régulateur à molette sur la partie qui pend
	var k := int(pts.size() * 0.8)
	var a := pts[k]
	var b := pts[mini(k + 1, pts.size() - 1)]
	var reg := MeshUtil.box_instance(self, Vector3(0.016, 0.05, 0.012), a, white, "Regulateur")
	var tdir := (b - a).normalized()
	var ref := Vector3.RIGHT if absf(tdir.x) < 0.9 else Vector3.FORWARD
	reg.global_transform = Transform3D(Basis(ref.cross(tdir).normalized(), tdir, ref.cross(tdir).cross(tdir).normalized()).orthonormalized(), a)
	_own("ligne", reg)
	var bag: Node3D = _scene("poche").instantiate()
	add_child(bag)
	bag.global_position = iv_bag
	_own("ligne", bag)
	IVProcedure.gear_layer(luer)


func remove_iv() -> void:
	_remove("iv")
	_remove("ligne")
	_remove("pansement")
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
