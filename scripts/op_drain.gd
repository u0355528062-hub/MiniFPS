class_name OpDrain
extends Operation
## Drain thoracique en urgence (pneumothorax compressif droit) : repérage du 5e espace intercostal
## dans le triangle de sécurité, désinfection, anesthésie locale, incision le long de la 6e côte,
## dissection mousse au ras du bord supérieur de la côte jusqu'à la plèvre, pose du drain vers
## l'apex, branchement au bocal (valve sous eau), fixation.
##
## Profondeurs mesurées sur l'atlas le long du trajet : muscle grand dentelé 18-27 mm, muscles
## intercostaux 31-39 mm, plèvre pariétale 41 mm, poumon (non affaissé) 43 mm.

## Centre de l'incision : sur la 6e côte, ligne axillaire moyenne (repère du jeu)
const SITE := Vector2(-0.012, 0.0)
const INC_HALF := 0.0125
const PLEURA_DEPTH := 0.041

var axis := Vector3.DOWN  ## trajet de la pince : sous la peau, puis au ras du bord supérieur de la 6e côte
var entry := Vector3.ZERO
var tubing: MeshInstance3D
var drain_tube: MeshInstance3D
var bubbles: Array[MeshInstance3D] = []
var bocal_water := Vector3.ZERO
var drained := false
var marked := Vector3.INF
var _bubble_t := 0.0
var _fog_mat: StandardMaterial3D


func _init() -> void:
	id = "drain"
	name = "Drain thoracique"
	tagline = "Pneumothorax compressif : pose d'un drain entre deux côtes, en urgence."
	intro_title = "Salle de déchocage"
	intro_text = "Karim, 31 ans, accident de moto. Il étouffe : son poumon droit s'est affaissé (pneumothorax compressif) et l'oxygène chute à 84 %. Il est sédaté, couché sur le côté gauche, bras droit levé.\n\nTu vas poser un drain thoracique entre deux côtes, sur le flanc droit, pour laisser sortir l'air et regonfler le poumon."
	surgeon_spot = Vector3(0.0, 0.0, 0.52)
	tray_pos = Vector3(-0.52, 0.0, 0.66)
	summary = "Poumon ré-expansé : l'oxygène est remonté à 98 %. Drain fixé et branché au bocal."
	header = "DÉCHOCAGE  ·  DRAIN THORACIQUE  ·  5e ESPACE INTERCOSTAL DROIT"
	scan_text = "RADIO THORAX DE FACE\nPneumothorax droit compressif\npoumon droit rétracté vers le hile\nmédiastin dévié à gauche"
	breath_rate = 30.0
	vitals = {"hr": 128.0, "spo2": 84.0, "sys": 96, "dia": 58, "temp": 36.4}
	catalog = [
		["feutre", "Feutre dermographique", "proc:feutre", 0.0, 0.0],
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue de lidocaïne 1 %", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 90.0, 0.0],
		["kelly", "Pince de Kelly", "clamp_ligature", 0.0, 0.2],
		["drain", "Drain thoracique 28 Fr", "proc:drain", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille + fil 0", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	var d := Patient.RIB_DIR.normalized()
	p.INC_A = SITE - d * INC_HALF
	p.INC_B = SITE + d * INC_HALF
	p.PATCH_MIN = SITE - Vector2(0.11, 0.11)
	p.PATCH_SIZE = Vector2(0.22, 0.22)
	p.WINDOW_MIN = Vector2(-0.085, -0.08)
	p.WINDOW_MAX = Vector2(0.085, 0.08)
	p.paint_r = Vector2(0.06, 0.055)
	p.wound_w = 0.0095
	p.WOUND_DEPTH = 0.013
	p.breathe_amp = 0.009
	p.hole_limit = 0.006  # sous la peau : les muscles sont à écarter à la pince


func build_extras() -> void:
	var n := Patient.skin_normal(SITE.x, SITE.y)
	axis = (-n + Vector3(0.45, 0.0, 0.0)).normalized()
	entry = patient.center
	patient.heart_rate = vitals["hr"]
	_build_bocal()


## Bocal de drainage (système à valve sous eau), posé au sol à côté du lit.
func _build_bocal() -> void:
	var base := Vector3(-0.42, 0.0, 0.46)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.92, 0.96, 1.0, 0.22)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.04
	clear.metallic_specular = 0.8
	clear.cull_mode = BaseMaterial3D.CULL_DISABLED
	var b := MeshUtil.box_instance(root, Vector3(0.28, 0.3, 0.09), base + Vector3(0, 0.15, 0), clear, "Bocal")
	b.rotation_degrees.y = 12
	MeshUtil.box_instance(root, Vector3(0.29, 0.04, 0.1), base + Vector3(0, 0.32, 0), MeshUtil.mat(Color(0.9, 0.9, 0.88), 0.5), "Couvercle").rotation_degrees.y = 12
	var water := MeshUtil.mat(Color(0.35, 0.65, 0.85, 0.55), 0.06)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	MeshUtil.box_instance(root, Vector3(0.26, 0.12, 0.075), base + Vector3(0, 0.07, 0), water, "Eau").rotation_degrees.y = 12
	# Graduations
	var grad := MeshUtil.mat(Color(0.2, 0.25, 0.3), 0.5)
	for k in 6:
		MeshUtil.box_instance(root, Vector3(0.04, 0.0015, 0.001), base + Vector3(-0.1, 0.04 + k * 0.04, 0.046), grad, "Graduation")
	bocal_water = base + Vector3(0.06, 0.13, 0)
	for k in 6:
		var bub := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.006
		s.height = 0.012
		bub.mesh = s
		bub.material_override = clear
		bub.visible = false
		root.add_child(bub)
		bubbles.append(bub)


func on_start() -> void:
	monitor.target_rate = 128.0
	monitor.target_spo2 = 84.0


func define_steps() -> void:
	var c := patient.center
	steps = [
		{"id": "repere", "kind": "mark", "list": "Repérage", "inst": "feutre",
			"title": "Trouve le 5e espace intercostal",
			"text": "Dans le triangle de sécurité : derrière le bord du grand pectoral, devant le grand dorsal, à hauteur du mamelon (ligne axillaire moyenne). Compte les côtes (touche V : vue anatomique), puis marque le point d'entrée au feutre, juste au-dessus de la 6e côte.",
			"label": "Triangle de sécurité", "ring": 3.4,
			"area": func() -> Vector3: return patient.on_skin(Vector3(SITE.x + 0.01, 0, SITE.y + 0.004)),
			"ideal": func() -> Vector3: return patient.on_skin(Vector3(SITE.x, 0, SITE.y)),
			"judge": _judge_mark, "done": _marked},
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte le flanc",
			"text": "Frotte la compresse imbibée de bétadine sur la peau, en partant du point marqué vers l'extérieur, jusqu'à ce que toute la zone soit brune.",
			"label": "Zone à désinfecter", "ring": 2.2, "done_msg": "Flanc désinfecté"},
		{"id": "anesthesie", "kind": "inject", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Anesthésie locale",
			"text": "Pique l'aiguille sur le repère, maintiens le clic pour pousser le piston : le liquide baisse et un bouton gonfle sous la peau. Injecte tout, puis retire l'aiguille.",
			"label": "Pique ici", "wait": 10.0, "what": "Lidocaïne",
			"target": func() -> Vector3: return patient.on_skin(c) + Vector3.UP * 0.0005,
			"done_msg": "Lidocaïne injectée : attends qu'elle agisse"},
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Incise le long de la côte",
			"text": "Attends que la peau soit endormie (le bouton blanchit). Pose la lame sur « DÉPART », appuie et suis le pointillé : 2,5 cm, parallèle à la côte.",
			"done": _incision_done, "done_msg": "Incision faite"},
		{"id": "dissection", "kind": "spread", "list": "Ouvrir la plèvre", "inst": "kelly",
			"title": "Passe au ras du bord supérieur de la côte",
			"text": "Enfonce la pince de Kelly fermée dans l'incision, vers la tête : elle doit passer AU-DESSUS de la 6e côte (le paquet vasculo-nerveux court sous chaque côte). Ouvre-la (clic relâché), referme, pousse… muscle, intercostaux, puis la plèvre cède : l'air s'échappe.",
			"label": "Entre ici", "depth": PLEURA_DEPTH, "axis": axis,
			"target": func() -> Vector3: return patient.on_skin(c),
			"progress": _dissect_progress,
			"done": _pleura_open, "done_msg": "Pschhh ! L'air s'échappe"},
		{"id": "drain", "kind": "insert", "list": "Pose du drain", "inst": "drain",
			"title": "Pose le drain",
			"text": "Glisse le bout du drain dans le trajet et pousse-le de 9 cm (clic maintenu) : il remonte vers le sommet du poumon. La saturation va remonter.",
			"label": "Drain ici", "depth": 0.09, "axis": axis,
			"target": func() -> Vector3: return patient.on_skin(c),
			"progress": _drain_progress,
			"done": _drain_in, "done_msg": "Drain en place, branché au bocal"},
		{"id": "fixation", "kind": "suture", "list": "Fixation", "inst": "porte_aiguille",
			"title": "Fixe le drain",
			"text": "3 points avec le porte-aiguille : pique à l'entrée (repère), ressors de l'autre côté. 2 points ferment la peau, le 3e tient le drain.",
			"label": "Point", "radius": 0.007,
			"pairs": _fix_pairs, "point": _fix_point, "done": _fixed,
			"done_msg": "Drain fixé : le patient respire !"},
	]


## Le point marqué est-il dans le 5e espace, ligne axillaire moyenne ? (repère du jeu : X vers la
## tête, Z vers l'avant)
func _judge_mark(p: Vector3) -> Dictionary:
	var dx := p.x - SITE.x
	var dz := p.z - SITE.y
	var mm := Vector2(dx, dz).length() * 1000.0
	if dx < -0.017:
		return {"ok": false, "mm": mm, "msg": "Trop bas : 6e espace ou plus bas. Le diaphragme remonte jusque-là : risque de blesser le foie."}
	if dx > 0.028:
		return {"ok": false, "mm": mm, "msg": "Trop haut : vers l'aisselle (nerf thoracique long, vaisseaux axillaires). Descends d'un espace."}
	if dz > 0.035:
		return {"ok": false, "mm": mm, "msg": "Trop en avant : tu es sur le grand pectoral, hors du triangle de sécurité."}
	if dz < -0.032:
		return {"ok": false, "mm": mm, "msg": "Trop en arrière : bord du grand dorsal, hors du triangle de sécurité."}
	return {"ok": true, "mm": mm, "msg": "Bon repère : 5e espace, ligne axillaire moyenne (%d mm)" % int(mm)}


func _marked(_hand: SurgeonHand, _instant: bool, p: Variant) -> void:
	marked = p if p is Vector3 else patient.on_skin(Vector3(SITE.x, 0, SITE.y))
	for m in [patient.skin_mat, patient.zone_mat]:
		m.set_shader_parameter("pen_mark", Vector3(marked.x, marked.z, 1.0))
		m.set_shader_parameter("guide_on", 1.0)


func anesthesia_started(wait: float) -> void:
	var b := patient.bleb
	if wait <= 0.0:
		patient.bleb_pale = 1.0
		patient.set_bleb(Vector3(b.x, 0, b.y), 0.016, 0.0012)
		return
	var tw := proc.create_tween().set_parallel(true)
	tw.tween_property(patient, "bleb_pale", 1.0, wait).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(k: float) -> void: patient.set_bleb(Vector3(b.x, 0, b.y), lerpf(b.z, 0.016, k), lerpf(b.w, 0.0012, k)), 0.0, 1.0, wait)
	monitor.target_rate = 122.0
	patient.heart_rate = 122.0


func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	if instant:
		patient.opening = 0.35
	else:
		tween_opening(0.35)


## La pince creuse : le trajet s'approfondit et s'élargit quand on ouvre les mors.
func _dissect_progress(k: float, jaw: float) -> void:
	var d := PLEURA_DEPTH * k
	var r := 0.0028 + 0.0032 * clampf(jaw, 0.0, 1.0) * clampf(k * 3.0, 0.0, 1.0)
	patient.set_tract(entry - axis * 0.004, axis, maxf(d, patient.tract_depth), maxf(r, patient.tract_r))


func _pleura_open(_hand: SurgeonHand, instant: bool) -> void:
	patient.hole_limit = 0.12
	patient.pleura_open = true
	patient.set_tract(entry - axis * 0.004, axis, PLEURA_DEPTH + 0.004, 0.0062)
	if instant:
		patient.opening = 0.6
	else:
		tween_opening(0.6)
		Sfx.play("souffle", patient.center, 0.0)
		_air_puff()
	monitor.target_spo2 = 88.0
	monitor.target_rate = 118.0
	patient.heart_rate = 118.0


## Bouffée d'air humide qui sort du trajet quand la plèvre s'ouvre.
func _air_puff() -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.2
	p.one_shot = true
	p.explosiveness = 0.8
	var pm := ParticleProcessMaterial.new()
	pm.direction = -axis
	pm.spread = 25.0
	pm.initial_velocity_min = 0.08
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0, 0.02, 0)
	pm.damping_min = 0.15
	pm.damping_max = 0.3
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.35))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.95, 0.97, 1.0, 1.0)
	q.material = mat
	p.draw_pass_1 = q
	root.add_child(p)
	p.global_position = patient.center + Vector3.UP * 0.004
	p.emitting = true
	var t := root.get_tree().create_timer(2.0)
	t.timeout.connect(p.queue_free)


func _drain_progress(_k: float) -> void:
	pass


## Trajet final du drain (souple) : de la peau, par le trajet creusé, puis le long de la paroi vers
## l'apex (vers la tête), entre le poumon et les côtes.
func _drain_path() -> PackedVector3Array:
	var outside := entry - axis * 0.004
	var p_pleura := entry + axis * (PLEURA_DEPTH + 0.004)
	var apex := p_pleura + Vector3(0.075, -0.012, -0.012)
	return MeshUtil.bezier(outside, p_pleura, p_pleura + Vector3(0.03, -0.012, 0.0), apex, 24)


func _drain_in(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("drain")
	if hand:
		hand.release_parked()
	# Le drain rigide de la main devient le drain souple en place (il épouse la paroi)
	inst.parked = true
	inst.held = false
	inst.visible = false
	proc.parked.append(inst)
	var path := _drain_path()
	var outer := entry - axis * 0.004 + (-axis) * 0.0
	var ext := MeshUtil.bezier(outer, outer - axis * 0.05, outer + Vector3(-0.06, 0.03, 0.12), outer + Vector3(-0.14, 0.0, 0.2), 16)
	var all := PackedVector3Array()
	for i in range(ext.size() - 1, 0, -1):
		all.append(ext[i])
	all.append_array(path)
	var rr := PackedFloat32Array()
	rr.resize(all.size())
	rr.fill(0.0048)
	drain_tube = MeshInstance3D.new()
	drain_tube.name = "DrainEnPlace"
	drain_tube.mesh = MeshUtil.tube(all, rr, 16)
	var clear := StandardMaterial3D.new()
	clear.albedo_color = Color(0.9, 0.96, 0.98, 0.55)
	clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	clear.roughness = 0.08
	clear.metallic_specular = 0.7
	drain_tube.material_override = clear
	root.add_child(drain_tube)
	drained = true
	patient.reexpand_lung()
	monitor.target_spo2 = 97.0
	monitor.target_rate = 96.0
	patient.heart_rate = 96.0
	monitor.sys = 112
	monitor.dia = 70
	patient.set_breathe(0.004)
	patient.breath_rate = 18.0
	monitor.resp_rate = 18.0
	# Tubulure du bout du drain jusqu'au bocal
	var tail := outer + Vector3(-0.14, 0.0, 0.2)
	var pts := MeshUtil.bezier(tail, tail + Vector3(-0.05, -0.05, 0.08), bocal_water + Vector3(0, 0.55, 0.05), bocal_water + Vector3(0, 0.2, 0), 30)
	var tr := PackedFloat32Array()
	tr.resize(pts.size())
	tr.fill(0.005)
	tubing = MeshInstance3D.new()
	tubing.name = "Tubulure"
	tubing.mesh = MeshUtil.tube(pts, tr, 12)
	var tube_mat := clear.duplicate() as StandardMaterial3D
	tubing.material_override = tube_mat
	_fog_mat = tube_mat
	root.add_child(tubing)
	if not instant:
		Sfx.play("bulles", bocal_water, -2.0)


func _fix_pairs() -> Array:
	var c := patient.center
	var out := [patient.stitch_pair(0.1, 0.004), patient.stitch_pair(0.9, 0.004)]
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
	patient.heart_rate = 88.0


## Bulles dans le bocal tant que le drain évacue de l'air ; buée dans le tuyau à chaque expiration.
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
	if _fog_mat:
		var bb := 0.5 - 0.5 * cos(_bubble_t * TAU / 3.3)
		_fog_mat.albedo_color = Color(0.9, 0.96, 1.0, 0.35 + 0.35 * bb)
	if fmod(_bubble_t, 2.6) < delta:
		Sfx.play("bulles", bocal_water, -12.0, randf_range(0.9, 1.1))
