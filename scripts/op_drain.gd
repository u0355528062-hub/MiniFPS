class_name OpDrain
extends Operation
## Drain thoracique en urgence (pneumothorax compressif) : triangle de sécurité, 5e espace
## intercostal, anesthésie locale, incision le long de la côte, dissection mousse jusqu'à la plèvre,
## pose du drain, branchement au bocal, fixation.

const SITE := Vector2(-0.40, 0.148)  ## centre de l'incision (x, z) sur le flanc droit

var axis := Vector3.DOWN  ## direction d'entrée dans le thorax (perpendiculaire à la peau)
var tubing: MeshInstance3D
var bubbles: Array[MeshInstance3D] = []
var bocal_water := Vector3.ZERO
var drained := false
var _bubble_t := 0.0
var _fog_mat: StandardMaterial3D


func _init() -> void:
	id = "drain"
	name = "Drain thoracique"
	tagline = "Urgence : le poumon droit est affaissé (pneumothorax). Petite incision entre deux côtes et pose d'un drain. Pas besoin d'ouvrir le ventre."
	intro_text = "Karim, 31 ans, accident de moto. Il étouffe : poumon droit affaissé, l'oxygène chute (84 %). Il est sédaté. Tu vas poser un drain thoracique sur le côté droit du thorax, entre deux côtes, pour laisser sortir l'air."
	surgeon_spot = Vector3(-0.40, 0.0, 0.62)
	tray_pos = Vector3(0.12, 0.0, 0.58)
	summary = "Poumon ré-expansé : l'oxygène est remonté à 98 %. Drain fixé et branché au bocal."
	header = "DÉCHOCAGE  ·  DRAIN THORACIQUE  ·  5e ESPACE INTERCOSTAL"
	scan_text = "RADIO THORAX\nPneumothorax droit compressif\npoumon droit rétracté, médiastin dévié"
	breath_rate = 30.0
	vitals = {"hr": 128.0, "spo2": 84.0, "sys": 96, "dia": 58}
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue de lidocaïne", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 90.0, 0.0],
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
	p.breathe_amp = 0.009
	p.hole_limit = 0.006  # sous la peau : muscles intercostaux à écarter à la pince


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
			"text": "Le bras droit est relevé. Frotte la compresse de la pince à badigeon sur la peau du flanc jusqu'à ce que toute la zone soit brune.",
			"label": "Zone à désinfecter", "ring": 2.5, "done_msg": "Flanc désinfecté"},
		{"id": "anesthesie", "kind": "inject", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Anesthésie locale",
			"text": "Pique l'aiguille dans la peau sur le repère (entre deux côtes). Relâche un peu le pouce, puis serre-le contre l'index pour pousser le piston : le liquide baisse et un bouton gonfle sous la peau. Injecte tout, puis retire l'aiguille.",
			"label": "Pique ici", "wait": 10.0,
			"target": func() -> Vector3: return patient.on_skin(c) + Vector3.UP * 0.0005,
			"done_msg": "Produit injecté : attends qu'il agisse"},
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Incise le long de la côte",
			"text": "Attends que la peau soit endormie (le bouton blanchit). Puis pose la lame sur « DÉPART », appuie un peu et suis le pointillé : 2,5 cm.",
			"done": _incision_done, "done_msg": "Incision faite"},
		{"id": "dissection", "kind": "spread", "list": "Ouvrir la plèvre", "inst": "kelly",
			"title": "Passe au-dessus de la côte",
			"text": "Enfonce la pince de Kelly fermée dans l'incision. Ouvre-la (écarte le pouce) pour écarter les muscles, referme, pousse plus loin... jusqu'à la plèvre : l'air s'échappera.",
			"label": "Entre ici", "depth": 0.032, "axis": axis,
			"target": func() -> Vector3: return patient.on_skin(c),
			"done": _pleura_open, "done_msg": "Pschhh ! L'air s'échappe"},
		{"id": "drain", "kind": "insert", "list": "Pose du drain", "inst": "drain",
			"title": "Pose le drain",
			"text": "Glisse le bout du drain dans le trou et pousse-le de 9 cm vers l'intérieur du thorax. Le moniteur va remonter.",
			"label": "Drain ici", "depth": 0.09, "axis": _drain_dir(),
			"target": func() -> Vector3: return patient.on_skin(c),
			"done": _drain_in, "done_msg": "Drain en place, branché au bocal"},
		{"id": "fixation", "kind": "suture", "list": "Fixation", "inst": "porte_aiguille",
			"title": "Fixe le drain",
			"text": "3 points avec le porte-aiguille : pique à l'entrée (repère), ressors de l'autre côté. 2 points pour fermer la peau, 1 point juste à côté du drain.",
			"label": "Point", "radius": 0.007,
			"pairs": _fix_pairs, "point": _fix_point, "done": _fixed,
			"done_msg": "Drain fixé : le patient respire !"},
	]


func anesthesia_started(wait: float) -> void:
	var b := patient.bleb
	if wait <= 0.0:
		patient.bleb_pale = 1.0
		patient.set_bleb(Vector3(b.x, 0, b.y), 0.016, 0.0012)
		return
	# Le bouton s'étale et blanchit pendant que la lidocaïne agit ; le cœur se calme un peu
	var tw := proc.create_tween().set_parallel(true)
	tw.tween_property(patient, "bleb_pale", 1.0, wait).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(k: float) -> void: patient.set_bleb(Vector3(b.x, 0, b.y), lerpf(b.z, 0.016, k), lerpf(b.w, 0.0012, k)), 0.0, 1.0, wait)
	monitor.target_rate = 122.0


func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	if instant:
		patient.opening = 0.35
	else:
		tween_opening(0.35)


func _pleura_open(_hand: SurgeonHand, instant: bool) -> void:
	patient.hole_limit = 0.05
	if instant:
		patient.opening = 0.6
	else:
		tween_opening(0.6)
		Sfx.play("souffle", patient.center, 0.0)
	monitor.target_spo2 = 88.0
	monitor.target_rate = 118.0


## Le drain entre perpendiculairement puis remonte vers l'apex : on l'incline vers la tête (-X).
func _drain_dir() -> Vector3:
	return (axis + Vector3(-0.35, 0, 0)).normalized()


func _drain_pose() -> Transform3D:
	var inst := instrument("drain")
	var dir := _drain_dir()
	return inst.tip_transform(patient.center + dir * 0.09, dir, Vector3.UP)


func _drain_in(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("drain")
	if hand:
		hand.release_parked()
	# Le drain reste là où on l'a enfoncé (recalé dans l'axe du trajet)
	park(inst, _drain_pose(), instant)
	drained = true
	monitor.target_spo2 = 97.0
	monitor.target_rate = 96.0
	monitor.sys = 112
	monitor.dia = 70
	patient.set_breathe(0.004)
	patient.breath_rate = 18.0
	monitor.resp_rate = 18.0
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
	_fog_mat = clear
	root.add_child(tubing)
	if not instant:
		Sfx.play("bulles", bocal_water, -2.0)


func _fix_pairs() -> Array:
	var c := patient.center
	var out := [patient.stitch_pair(0.12, 0.004), patient.stitch_pair(0.88, 0.004)]
	var side := patient.dir3 * 0.004
	out.append([c - patient.perp3 * 0.011 + side, c + patient.perp3 * 0.011 + side])
	for pair in out:
		for i in 2:
			var p: Vector3 = pair[i]
			pair[i] = Vector3(p.x, Patient.body_height(p.x, p.z), p.z)
	return out


func _fix_point(i: int, instant: bool) -> void:
	var pair: Array = _fix_pairs()[i]
	var p: Vector3 = (pair[0] + pair[1]) * 0.5
	patient.add_stitch_at(p, (pair[1] - pair[0]).normalized(), 0.014)
	if i < 2:
		var left := 0.6 - 0.25 * (i + 1)
		if instant:
			patient.opening = left
		else:
			tween_opening(left)
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
	# Le tuyau s'embue à chaque expiration
	if _fog_mat:
		var b := 0.5 - 0.5 * cos(_bubble_t * TAU / 4.0)
		_fog_mat.albedo_color = Color(0.9, 0.96, 1.0, 0.35 + 0.35 * b)
	if fmod(_bubble_t, 2.6) < delta:
		Sfx.play("bulles", bocal_water, -12.0, randf_range(0.9, 1.1))
