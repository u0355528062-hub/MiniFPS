class_name OpDrain
extends Operation
## Drain thoracique en urgence (pneumothorax compressif) : triangle de sécurité, 5e espace
## intercostal, anesthésie locale, incision le long de la côte, dissection mousse jusqu'à la plèvre,
## pose du drain, branchement au bocal, fixation.

const SITE := Vector2(-0.40, 0.148)  ## centre de l'incision (x, z) sur le flanc droit

var axis := Vector3.DOWN  ## direction d'entrée dans le thorax (perpendiculaire à la peau)
var bleb: MeshInstance3D
var tubing: MeshInstance3D
var bubbles: Array[MeshInstance3D] = []
var bocal_water := Vector3.ZERO
var drained := false
var _bubble_t := 0.0


func _init() -> void:
	id = "drain"
	name = "Drain thoracique"
	tagline = "Urgence : le poumon droit est affaissé (pneumothorax). Petite incision entre deux côtes et pose d'un drain. Pas besoin d'ouvrir le ventre."
	intro_text = "Karim, 31 ans, accident de moto. Il étouffe : poumon droit affaissé, l'oxygène chute (84 %). Il est sédaté. Tu vas poser un drain thoracique sur le côté droit du thorax, entre deux côtes, pour laisser sortir l'air."
	surgeon_spot = Vector3(-0.40, 0.0, 0.62)
	tray_pos = Vector3(0.12, 0.0, 0.58)
	summary = "Poumon ré-expansé : l'oxygène est remonté à 98 %. Drain fixé et branché au bocal."
	vitals = {"hr": 128.0, "spo2": 84.0, "sys": 96, "dia": 58}
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue de lidocaïne", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 0.0, 0.0],
		["kelly", "Pince de Kelly", "clamp_ligature", 0.0, 0.2],
		["drain", "Drain thoracique 28 Fr", "proc:drain", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille + fil", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	p.op = "drain"
	p.INC_A = SITE + Vector2(0.0, -0.013)
	p.INC_B = SITE + Vector2(0.0, 0.013)
	p.PATCH_MIN = Vector2(-0.53, 0.03)
	p.PATCH_SIZE = Vector2(0.26, 0.25)
	p.WINDOW_MIN = Vector2(-0.49, 0.07)
	p.WINDOW_MAX = Vector2(-0.31, 0.25)
	p.paint_r = Vector2(0.055, 0.05)
	p.wound_w = 0.006
	p.WOUND_DEPTH = 0.035
	p.bowl_radii = Vector3(0.025, 0.03, 0.02)
	p.bowl_color = Color(0.48, 0.12, 0.1)
	p.breathe_amp = 0.014


func _skin_normal(x: float, z: float) -> Vector3:
	var e := 0.004
	var hx := (Patient.body_height(x + e, z) - Patient.body_height(x - e, z)) / (2.0 * e)
	var hz := (Patient.body_height(x, z + e) - Patient.body_height(x, z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


func build_extras() -> void:
	axis = -_skin_normal(SITE.x, SITE.y)
	var c := patient.center
	# Côtes (5e et 6e) de part et d'autre de l'incision, sous la peau
	var bone := tissue(Color(0.93, 0.88, 0.78), 0.0, 0.1, 0.0, 30.0)
	bone.set_shader_parameter("wetness", 0.5)
	for dx in [-0.016, 0.016]:
		var pts := PackedVector3Array()
		for i in 9:
			var z := c.z - 0.03 + 0.06 * i / 8.0
			var n := _skin_normal(c.x + dx, z)
			var surf := Vector3(c.x + dx, Patient.body_height(c.x + dx, z), z)
			pts.append(surf - n * 0.02)
		var rr := PackedFloat32Array()
		rr.resize(pts.size())
		rr.fill(0.0065)
		var rib := MeshInstance3D.new()
		rib.name = "Cote"
		rib.mesh = MeshUtil.tube(pts, rr, 12)
		rib.material_override = bone
		patient.add_child(rib)
	# Plèvre et poumon au fond : rose, brillant
	var lung := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.05
	lung.mesh = sm
	lung.material_override = tissue(Color(0.85, 0.5, 0.5), 0.0, 0.5, 0.0, 30.0)
	lung.position = c + axis * 0.06
	lung.name = "Poumon"
	patient.add_child(lung)
	# Bouton d'anesthésie locale (apparaît pendant l'injection)
	bleb = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.008
	bs.height = 0.006
	bleb.mesh = bs
	bleb.material_override = MeshUtil.mat(Color(0.86, 0.66, 0.56), 0.5)
	bleb.position = c + Vector3.UP * 0.0005
	bleb.scale = Vector3.ZERO
	patient.add_child(bleb)
	_build_bocal()


## Bocal de drainage (système à valve sous eau) posé au sol à côté du lit.
func _build_bocal() -> void:
	var base := Vector3(-0.62, 0.0, 0.78)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.92, 0.96, 1.0, 0.25)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.05
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshUtil.box_instance(root, Vector3(0.28, 0.3, 0.09), base + Vector3(0, 0.15, 0), clear, "Bocal")
	MeshUtil.box_instance(root, Vector3(0.29, 0.04, 0.1), base + Vector3(0, 0.32, 0), MeshUtil.mat(Color(0.9, 0.9, 0.88), 0.5), "Couvercle")
	var water := MeshUtil.mat(Color(0.35, 0.65, 0.85, 0.6), 0.1)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	MeshUtil.box_instance(root, Vector3(0.26, 0.12, 0.075), base + Vector3(0, 0.07, 0), water, "Eau")
	bocal_water = base + Vector3(0.06, 0.13, 0)
	for k in 6:
		var b := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.006
		s.height = 0.012
		b.mesh = s
		b.material_override = clear
		b.visible = false
		root.add_child(b)
		bubbles.append(b)


func on_start() -> void:
	monitor.target_rate = 128.0
	monitor.target_spo2 = 84.0


func define_steps() -> void:
	var c := patient.center
	steps = [
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte le flanc droit",
			"text": "Le bras droit est relevé. Frotte la peau du flanc avec la pince à badigeon (gâchette appuyée) jusqu'à 100 %.",
			"label": "Zone à désinfecter", "ring": 2.5, "done_msg": "Flanc désinfecté"},
		{"id": "anesthesie", "kind": "hold", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Anesthésie locale",
			"text": "Pique avec la seringue sur le repère (5e espace entre deux côtes) et maintiens la gâchette pour injecter la lidocaïne.",
			"label": "Injecte ici", "radius": 0.02, "duration": 2.0, "progress_label": "Injection…",
			"target": func() -> Vector3: return c + Vector3.UP * 0.001,
			"progress": func(v: float) -> void: bleb.scale = Vector3(1.0, 0.6, 1.0) * v,
			"done_msg": "La zone est endormie"},
		{"id": "incision", "kind": "trace", "list": "Incision", "inst": "bistouri",
			"title": "Incise le long de la côte",
			"text": "Petite incision de 2,5 cm : pose la lame sur « DÉPART » et suis le pointillé, gâchette appuyée.",
			"done": _incision_done, "done_msg": "Incision faite"},
		{"id": "dissection", "kind": "push", "list": "Ouvrir la plèvre", "inst": "kelly",
			"title": "Passe au-dessus de la côte",
			"text": "Enfonce la pince de Kelly dans l'incision (gâchette appuyée) en glissant au-dessus de la côte jusqu'à la plèvre. Tu entendras l'air sortir.",
			"label": "Enfonce ici", "radius": 0.015, "depth": 0.032, "axis": axis, "progress_label": "Dissection…",
			"target": func() -> Vector3: return c,
			"progress": func(v: float) -> void: patient.opening = maxf(patient.opening, 0.35 + 0.65 * v),
			"done": _pleura_open, "done_msg": "Pschhh ! L'air s'échappe"},
		{"id": "drain", "kind": "push", "list": "Pose du drain", "inst": "drain",
			"title": "Pose le drain",
			"text": "Glisse le drain dans le trou (gâchette appuyée) et pousse-le de 9 cm vers le haut du thorax. Le moniteur va remonter.",
			"label": "Drain ici", "radius": 0.015, "depth": 0.09, "axis": axis, "progress_label": "Insertion du drain…",
			"target": func() -> Vector3: return c,
			"done": _drain_in, "done_msg": "Drain en place, branché au bocal"},
		{"id": "fixation", "kind": "points", "list": "Fixation", "inst": "porte_aiguille",
			"title": "Fixe le drain",
			"text": "Avec le porte-aiguille, fais les 3 points : 2 points pour fermer la peau et 1 point en bourse autour du drain (gâchette sur chaque repère).",
			"label": "Point", "radius": 0.016,
			"points": _fix_points, "point": _fix_point, "done": _fixed,
			"done_msg": "Drain fixé : le patient respire !"},
	]


func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	if instant:
		patient.opening = 0.35
	else:
		tween_opening(0.35, 0.4)


func _pleura_open(_hand: SurgeonHand, instant: bool) -> void:
	patient.opening = 1.0
	if not instant:
		Sfx.play("souffle", patient.center, 0.0)
	monitor.target_spo2 = 88.0
	monitor.target_rate = 118.0


func _drain_pose() -> Transform3D:
	var inst := instrument("drain")
	# Le drain entre perpendiculairement puis remonte vers l'apex : on l'incline vers la tête (-X)
	var dir := (axis + Vector3(-0.35, 0, 0)).normalized()
	return inst.tip_transform(patient.center + dir * 0.09, dir, Vector3.UP)


func _drain_in(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("drain")
	if hand:
		hand.release_parked()
	park(inst, _drain_pose(), instant)
	drained = true
	monitor.target_spo2 = 97.0
	monitor.target_rate = 96.0
	monitor.sys = 112
	monitor.dia = 70
	patient.set_breathe(0.006)
	# Tubulure du bout du drain jusqu'au bocal
	var outer := _drain_pose() * Vector3(0, 0, -0.17)
	var pts := MeshUtil.bezier(outer, outer + Vector3(0.0, -0.05, 0.12), bocal_water + Vector3(0, 0.45, 0.0), bocal_water + Vector3(0, 0.2, 0), 30)
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.005)
	tubing = MeshInstance3D.new()
	tubing.name = "Tubulure"
	tubing.mesh = MeshUtil.tube(pts, rr, 10)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.9, 0.96, 1.0, 0.45)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.1
	tubing.material_override = clear
	root.add_child(tubing)
	if not instant:
		Sfx.play("bulles", bocal_water, -2.0)


func _fix_points() -> Array:
	var c := patient.center
	return [
		patient.incision_point(0.1) + Vector3.UP * 0.001,
		patient.incision_point(0.9) + Vector3.UP * 0.001,
		c + patient.perp3 * 0.011 + Vector3.UP * 0.001,
	]


func _fix_point(i: int, instant: bool) -> void:
	var p: Vector3 = _fix_points()[i]
	patient.add_stitch_at(p, patient.perp3 if i < 2 else patient.dir3, 0.012)
	if not instant:
		Sfx.play("fil", p, -6.0)


func _fixed(_instant: bool) -> void:
	monitor.target_spo2 = 98.0
	monitor.target_rate = 88.0


## Bulles dans le bocal tant que le drain évacue de l'air.
func process(delta: float) -> void:
	if not drained:
		return
	_bubble_t += delta
	for k in bubbles.size():
		var b := bubbles[k]
		var ph := fmod(_bubble_t * 0.9 + k / float(bubbles.size()), 1.0)
		b.visible = true
		b.global_position = bocal_water + Vector3(0.004 * sin(k * 2.0 + _bubble_t * 6.0), -0.09 + ph * 0.1, 0.0)
		b.scale = Vector3.ONE * (0.6 + 0.6 * ph)
	if fmod(_bubble_t, 2.6) < delta:
		Sfx.play("bulles", bocal_water, -12.0, randf_range(0.9, 1.1))
