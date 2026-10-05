class_name OpThoracotomie
extends Operation
## Thoracotomie de sauvetage (antérolatérale gauche) : coup de couteau au thorax, arrêt cardiaque à
## l'arrivée (activité électrique sans pouls) par tamponnade. Le seul geste qui peut le sauver :
## ouvrir le thorax, libérer le cœur, fermer la plaie, masser.
##   1. Incision sous le mamelon, du sternum à la ligne axillaire, le long de la 6e côte.
##   2. Muscles intercostaux et plèvre coupés aux ciseaux : le poumon s'affaisse.
##   3. Écarteur de Finochietto : les côtes s'écartent, le péricarde apparaît, tendu, bleu de sang.
##   4. Péricarde ouvert aux ciseaux de bas en haut : les caillots sortent, le cœur est libéré, la
##      plaie du ventricule droit saigne à chaque battement.
##   5. Deux points sur la plaie du ventricule. 6. Massage cardiaque interne : le cœur repart.
## (Premier temps d'une thoracotomie « en clamshell », prolongée à droite si besoin.)

## 5e espace intercostal gauche, à mi-chemin de la 5e et de la 6e côte (mesuré sur l'atlas) : (x, z)
const ICS5 := [Vector2(-0.0485, 0.035), Vector2(-0.0588, 0.05), Vector2(-0.0645, 0.065), Vector2(-0.0663, 0.08),
	Vector2(-0.0617, 0.095), Vector2(-0.0558, 0.11), Vector2(-0.0447, 0.125), Vector2(-0.036, 0.14)]
## Part de l'écartement le long de l'espace : les côtes bougent peu près du sternum et au bout
const ICS5_H := [0.0, 0.6, 0.9, 1.0, 1.0, 0.85, 0.5, 0.0]
const SPREAD := 0.042  ## chaque bord recule de 4,2 cm au milieu (9 cm entre les côtes)
const CUT_W := 0.005  ## demi-largeur de la brèche coupée aux ciseaux
const WALL_DEPTH := 0.028  ## la plèvre pariétale sous la peau (là où coupent les ciseaux)

var inc_a2 := Vector2(-0.060, 0.032)  ## incision (X, Z) : bord du sternum
var inc_b2 := Vector2(-0.052, 0.15)  ## ligne axillaire antérieure (corde de l'espace intercostal)
var ics_path := PackedVector3Array()  ## l'espace intercostal, sur la peau
var ics_h := PackedFloat32Array()
var inward := Vector3.DOWN
var pc_a := Vector3.ZERO  ## ligne d'ouverture du péricarde (sur sa surface)
var pc_b := Vector3.ZERO
var wound_c := Vector3.ZERO  ## plaie du ventricule droit
var wound_dir := Vector3(1, 0, 0)
var wound_n := Vector3.UP
var spread := 0.0
var peri_open := 0.0
var sutured := false
var rosc := false
var _clots: Array[MeshInstance3D] = []
var _drops: Array = []  ## [noeud, vitesse, vie]
var _drop_mat: StandardMaterial3D
var _last_beat := 0.0
var _seated := false
var _heart_follow: Node3D  ## suit le cœur (battements, massage) : points, feutres, caillots
var _felt_mat: StandardMaterial3D
var _thread_mat: StandardMaterial3D
var _hand: GloveHand  ## main du chirurgien pendant le massage
var _hand_xf := Transform3D.IDENTITY
var _hand_ready := false  ## la main est arrivée sur le cœur
var peri_depth := 0.045  ## profondeur du péricarde sous la peau (le long de la ligne d'ouverture)
var heart_depth := 0.05  ## profondeur de la plaie du cœur sous la peau


func _init() -> void:
	id = "thoracotomie"
	name = "Thoracotomie de sauvetage"
	tagline = "Arrêt cardiaque après une plaie : ouvrir le thorax, masser le cœur."
	pose = "dos"
	player_spawn = Vector3(-0.06, 0.0, 0.62)
	player_look = Vector3(-0.05, 1.0, 0.07)
	tray_pos = Vector3(-0.58, 0.0, 0.64)
	patient_line = "Kevin D., 22 ans — coup de couteau au cœur"
	urgency = "ARRÊT CARDIAQUE"
	intro_title = "Salle de déchocage"
	intro_text = "Coup de couteau sous le mamelon gauche. Il parlait dans le camion ; à l'arrivée, plus de pouls : le scope montre une activité électrique, mais le cœur ne pompe plus. Le sang accumulé dans le péricarde l'étrangle.\n\nIl est intubé, le massage externe ne sert à rien : il faut ouvrir le thorax tout de suite, libérer le cœur, boucher le trou et masser le cœur à la main. Chaque minute compte."
	imaging_tex = ""
	imaging_text = "Arrêt cardiaque traumatique depuis 4 minutes (plaie pénétrante du thorax).\n\n•  activité électrique sans pouls\n•  pas de saturation, pas de tension\n•  échographie : épanchement autour du cœur\n•  indication : thoracotomie de sauvetage"
	scan_text = "ÉCHOGRAPHIE\nÉpanchement péricardique\ncœur immobile"
	header = "DÉCHOCAGE  ·  THORACOTOMIE  ·  ANTÉROLATÉRALE GAUCHE"
	summary = "Le cœur bat à nouveau : 118 par minute, la tension remonte. Le thorax reste ouvert, il part au bloc où le chirurgien terminera la réparation et refermera."
	breath_rate = 14.0
	vitals = {"hr": 34.0, "spo2": 0.0, "sys": 0, "dia": 0, "temp": 35.6}
	catalog = [
		["bistouri", "Bistouri lame 20", "manche_bistouri", 90.0, 0.0],
		["ciseaux", "Ciseaux de Mayo", "ciseaux_metzenbaum", 0.0, 0.0],
		["finochietto", "Écarteur de Finochietto", "proc:finochietto", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille + fil 3/0 sur feutre", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	p.WINDOW_MIN = Vector2(-0.3, -0.22)
	p.WINDOW_MAX = Vector2(0.18, 0.22)
	var mid := (inc_a2 + inc_b2) * 0.5
	p.PATCH_MIN = mid - Vector2(0.14, 0.14)
	p.PATCH_SIZE = Vector2(0.28, 0.28)
	p.INC_A = inc_a2
	p.INC_B = inc_b2
	p.wound_w = 0.042
	# Parois de l'incision : peau et graisse ; en dessous, ce sont les vrais muscles écartés
	p.WOUND_DEPTH = 0.02
	p.wall_taper = 0.15  # l'écarteur tient les bords : parois presque droites
	p.zone_v_min = 0.09
	p.hole_limit = 0.14
	p.breathe_amp = 0.004
	p.stab = Vector4(-0.036, 0.03, 0.35, 0.02)
	p.props_options = {"collar": false, "intubated": true}
	p.init_lung(0.0)  # intubé, ventilé : les poumons sont gonflés jusqu'à l'ouverture de la plèvre


func build_extras() -> void:
	EchoView.load_volume()
	for i in ICS5.size():
		var q: Vector2 = ICS5[i]
		ics_path.append(Vector3(q.x, Patient.body_height(q.x, q.y), q.y))
		ics_h.append(ICS5_H[i])
	var mid := Procedure.path_point(ics_path, 0.5)
	inward = -Patient.skin_normal(mid.x, mid.z)
	patient.heart_rate = 0.0
	patient.beat_gain = 0.0
	# Ligne d'ouverture du péricarde (face antérieure du ventricule gauche, de la pointe vers la
	# base, en avant du nerf phrénique) et plaie du ventricule droit, sur la surface du cœur
	pc_a = _heart_surface(-0.052, 0.067, 2.0)
	pc_b = _heart_surface(-0.03, 0.054, 2.0)
	wound_c = _heart_surface(-0.046, 0.051, 0.0)
	wound_n = (wound_c - Patient.HEART_C).normalized()
	var pm := (pc_a + pc_b) * 0.5
	peri_depth = Patient.body_height(pm.x, pm.z) - pm.y
	heart_depth = Patient.body_height(wound_c.x, wound_c.z) - wound_c.y
	wound_dir = Vector3(1, 0, 0.7).normalized()
	wound_dir = (wound_dir - wound_n * wound_dir.dot(wound_n)).normalized()
	if OS.get_cmdline_user_args().has("--debug"):
		print("DEBUG thoraco cœur=", Patient.HEART_C, " brèche=", mid, " péricarde=", pc_a, " → ", pc_b, " plaie=", wound_c,
			" prof. péricarde=%.3f plaie=%.3f" % [peri_depth, heart_depth])
	patient.set_pericardium(1.0)
	patient.set_heart_wound(wound_c, wound_dir, 0.008, 0.0)
	_heart_follow = Node3D.new()
	_heart_follow.name = "SuitLeCoeur"
	root.add_child(_heart_follow)
	_felt_mat = MeshUtil.mat(Color(0.93, 0.92, 0.88), 0.95)
	_thread_mat = MeshUtil.mat(Color(0.1, 0.2, 0.55), 0.35)
	_build_clots()
	_build_hand()
	_drop_mat = MeshUtil.mat(Color(0.42, 0.02, 0.03), 0.15)
	_drop_mat.metallic_specular = 0.8
	var fin := instrument("finochietto")
	if fin and fin.model is FinochiettoModel:
		(fin.model as FinochiettoModel).set_spread(0.012)


## Point de la surface du cœur (ou à `out_mm` au-dessus : le péricarde) à la verticale de (x, z).
func _heart_surface(x: float, z: float, out_mm: float) -> Vector3:
	for n in 260:
		var y := 1.12 - n * 0.0005
		var smp := EchoView.sample(Vector3(x, y, z))
		if float(smp[1]) <= out_mm:
			return Vector3(x, y, z)
	return Vector3(x, Patient.HEART_C.y + 0.04, z)


func on_start() -> void:
	monitor.arrest = true
	monitor.target_rate = 34.0
	monitor.heart_rate = 34.0
	monitor.target_spo2 = 0.0
	monitor.ecg_voltage = 0.6


func define_steps() -> void:
	steps = [
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Ouvre sous le mamelon",
			"text": "Du bord du sternum jusque sous l'aisselle, le long de la 6e côte (5e espace, sous le mamelon). Un seul grand trait, franchement, jusqu'aux muscles : pas d'anesthésie, il est en arrêt.",
			"done": _incision_done, "done_msg": "Peau, graisse et muscles ouverts"},
		{"id": "paroi", "kind": "cutline", "list": "Ouvrir la plèvre", "inst": "ciseaux",
			"title": "Coupe les intercostaux et la plèvre",
			"text": "Glisse les ciseaux au fond de l'incision, au ras du bord supérieur de la 6e côte, et coupe d'un bout à l'autre (clic maintenu en avançant) : muscles intercostaux puis plèvre. L'air entre, le poumon s'affaisse.",
			"label": "DÉPART", "path": _deep_path, "tol": 0.02, "need": 0.85, "depth": WALL_DEPTH,
			"what": "Intercostaux et plèvre ouverts", "on_progress": _wall_progress,
			"done": _wall_done, "done_msg": "Plèvre ouverte : le poumon s'écarte"},
		{"id": "ecarteur", "kind": "crank", "list": "Écarteur", "inst": "finochietto",
			"title": "Écarte les côtes",
			"text": "Pose l'écarteur de Finochietto dans l'incision (les valves sous les côtes), puis tourne la manivelle (clic maintenu) : les côtes s'écartent de 8 cm.",
			"label": "Valves ici", "ring": 1.0, "target": _seat_tip, "near": 0.05, "seconds": 7.0,
			"what": "Écartement des côtes", "on_seat": _seat, "on_progress": _spread_progress,
			"done": _spread_done, "done_msg": "Le péricarde est là : tendu, bleu de sang"},
		{"id": "pericarde", "kind": "cutline", "list": "Péricarde", "inst": "ciseaux",
			"title": "Ouvre le péricarde",
			"text": "Le sac est tendu par le sang. Pince-le, puis coupe-le de la pointe du cœur vers le haut, en avant du nerf phrénique (clic maintenu en avançant). Attention au cœur dessous.",
			"label": "DÉPART", "a": func() -> Vector3: return pc_a, "b": func() -> Vector3: return pc_b,
			"tol": 0.016, "need": 0.85, "depth": peri_depth, "what": "Péricarde ouvert",
			"on_progress": _peri_progress, "done": _peri_done,
			"done_msg": "Les caillots sortent : le cœur se remet à battre, la plaie saigne"},
		{"id": "suture", "kind": "suture", "list": "Plaie du cœur", "inst": "porte_aiguille",
			"title": "Ferme la plaie du ventricule",
			"text": "Un doigt de l'aide bouche le trou. Deux points en U appuyés sur des feutres de Téflon, de part et d'autre de la plaie : pique d'un côté, ressors de l'autre. Le cœur bat sous l'aiguille : vise bien.",
			"label": "Point", "radius": 0.006, "zone_depth": heart_depth + 0.02,
			"pairs": _heart_pairs, "point": _heart_point, "done": _heart_closed,
			"done_msg": "Plaie fermée : plus de saignement"},
		{"id": "massage", "kind": "pump", "list": "Massage cardiaque", "inst": "",
			"title": "Masse le cœur",
			"text": "Mains nues, le cœur entre les paumes : comprime-le régulièrement, environ 100 fois par minute (un clic par compression, en visant le cœur). L'adrénaline passe ; continue jusqu'à ce qu'il reparte.",
			"label": "Cœur", "ring": 1.4, "target": func() -> Vector3: return Patient.HEART_C + Vector3.UP * 0.05,
			"need": 30, "near": 0.09, "on_compress": _compress, "on_squeeze": _squeeze, "enter": _hand_in,
			"done": _rosc_done, "done_msg": "Le cœur repart !"},
	]


# ---------------------------------------------------------------- Paroi

## L'espace intercostal au fond de l'incision, là où coupent les ciseaux.
func _deep_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in ics_path:
		out.append(p + Vector3.DOWN * WALL_DEPTH)
	return out


func _incision_done(instant: bool) -> void:
	if instant:
		patient.incision_progress = 1.0
	patient.opening = 0.12


func _wall_progress(t0: float, t1: float) -> void:
	patient.set_aperture(ics_path, ics_h, t0, t1, CUT_W, 0.0)


func _wall_done(_h: SurgeonHand, instant: bool) -> void:
	_wall_progress(0.0, 1.0)
	# L'air entre dans la plèvre : le poumon gauche s'affaisse vers son hile et découvre le péricarde
	if instant:
		patient.init_lung(0.92)
	else:
		patient.set_lung_target(0.92)
	patient.set_cavity_blood(1.0)  # hémothorax : du sang au fond de la cavité


# ---------------------------------------------------------------- Écarteur

## Où poser l'écarteur : la pointe des valves au fond de la brèche, au milieu (les côtes sont à
## 1,5-3 cm sous la peau, à la verticale de l'espace intercostal).
func _seat_tip() -> Vector3:
	return Procedure.path_point(ics_path, 0.5) + Vector3.DOWN * 0.032


func _seat_xf(inst: Instrument) -> Transform3D:
	# Barre à peu près parallèle à la peau (inclinée), valves vers le fond de la brèche
	var z := Vector3.DOWN.lerp(inward, 0.45).normalized()
	var along := Procedure.path_point(ics_path, 0.55) - Procedure.path_point(ics_path, 0.45)
	along = (along - z * along.dot(z)).normalized()
	var x := along.cross(z).normalized()  # en travers de l'espace intercostal, dans le plan de la peau
	var y := z.cross(x).normalized()
	return Transform3D(Basis(x, y, z), _seat_tip()) * Transform3D(Basis.IDENTITY, -inst.tip_local)


func _seat(hand: SurgeonHand) -> void:
	if _seated:
		return
	_seated = true
	var inst := instrument("finochietto")
	hand.release_parked()
	park(inst, _seat_xf(inst), false)
	Sfx.play("pose", _seat_tip(), -4.0)


func _spread_done(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("finochietto")
	if not _seated:
		_seated = true
		if hand and hand.held == inst:
			hand.release_parked()
		park(inst, _seat_xf(inst), instant)
	_spread_progress(1.0)


func _spread_progress(p: float) -> void:
	spread = p
	patient.opening = lerpf(0.12, 1.0, p)
	patient.set_aperture(ics_path, ics_h, 0.0, 1.0, CUT_W, SPREAD * p)
	var fin := instrument("finochietto")
	if fin.model is FinochiettoModel:
		# Les valves suivent les bords de la brèche (la barre est inclinée comme la peau)
		var tilt := absf(_seat_xf(fin).basis.x.normalized().dot(Vector3.UP))
		var half := (CUT_W + SPREAD * p) / sqrt(maxf(1.0 - tilt * tilt, 0.5))
		(fin.model as FinochiettoModel).set_spread(maxf(0.012, half * 2.0 + 0.002))


# ---------------------------------------------------------------- Péricarde

## Caillots noirâtres entre le péricarde et le cœur, le long de la ligne d'ouverture.
func _build_clots() -> void:
	var mat := MeshUtil.mat(Color(0.22, 0.02, 0.03), 0.3)
	mat.clearcoat_enabled = true
	mat.clearcoat = 0.6
	for i in 7:
		var c := MeshInstance3D.new()
		c.name = "Caillot"
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 14
		sm.rings = 8
		c.mesh = sm
		c.material_override = mat
		var t := (i + 0.5) / 7.0
		var p := pc_a.lerp(pc_b, t) - wound_n * 0.002
		c.position = p + Vector3(sin(i * 2.3) * 0.006, 0.0, cos(i * 1.7) * 0.006)
		c.scale = Vector3(0.008 + 0.003 * sin(i), 0.004, 0.007 + 0.002 * cos(i * 2.0))
		c.visible = false
		_heart_follow.add_child(c)
		_clots.append(c)


func _peri_progress(t0: float, t1: float) -> void:
	peri_open = t1 - t0
	patient.set_pericardium(lerpf(1.0, 0.3, peri_open), pc_a.lerp(pc_b, t0), pc_a.lerp(pc_b, t1), 0.004 + 0.016 * peri_open)
	for i in _clots.size():
		var t := (i + 0.5) / _clots.size()
		_clots[i].visible = t >= t0 - 0.05 and t <= t1 + 0.05


func _peri_done(_hand: SurgeonHand, instant: bool) -> void:
	peri_open = 1.0
	patient.set_pericardium(0.0, pc_a.lerp(pc_b, -0.15), pc_a.lerp(pc_b, 1.1), 0.024)
	# Les caillots glissent hors du sac et disparaissent ; le cœur libéré bat faiblement
	for i in _clots.size():
		var c := _clots[i]
		c.visible = not instant
		if not instant:
			var tw := root.create_tween()
			tw.tween_property(c, "position", c.position + Vector3(0.0, 0.02, 0.05 + 0.01 * i), 0.9 + 0.1 * i).set_trans(Tween.TRANS_QUAD)
			tw.parallel().tween_property(c, "scale", Vector3.ONE * 0.0005, 0.9 + 0.1 * i)
			tw.tween_callback(c.hide)
	patient.heart_rate = 46.0
	patient.beat_gain = 0.55
	monitor.target_rate = 46.0
	monitor.ecg_voltage = 0.8


# ---------------------------------------------------------------- Plaie du cœur

func _heart_pairs() -> Array:
	var across := wound_n.cross(wound_dir).normalized()
	var out := []
	for k in [-0.45, 0.45]:
		var c: Vector3 = wound_c + wound_dir * 0.008 * k
		out.append([c - across * 0.005 + wound_n * 0.001, c + across * 0.005 + wound_n * 0.001])
	return out


func _heart_point(i: int, instant: bool) -> void:
	var pair: Array = _heart_pairs()[i]
	var p: Vector3 = (pair[0] + pair[1]) * 0.5
	_cardiac_stitch(pair[0], pair[1])
	patient.set_heart_wound(wound_c, wound_dir, 0.008, 0.5 * (i + 1))
	if not instant:
		Sfx.play("fil", p, -6.0)


## Point en U appuyé sur deux feutres de Téflon (ils empêchent le fil de couper le muscle), de part
## et d'autre de la plaie : deux brins parallèles par-dessus, noué sur le feutre d'entrée.
func _cardiac_stitch(a: Vector3, b: Vector3) -> void:
	var across := (b - a).normalized()
	var n := wound_n
	var along := n.cross(across).normalized()
	var node := Node3D.new()
	node.name = "PointCoeur"
	_heart_follow.add_child(node)
	var basis := Basis(along, n, across)
	for q in [a, b]:
		var pl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.0072, 0.0013, 0.0034)
		pl.mesh = bm
		pl.material_override = _felt_mat
		node.add_child(pl)
		pl.transform = Transform3D(basis, q + n * 0.0009)
	for off in [-0.0019, 0.0019]:
		var pts := PackedVector3Array()
		var rr := PackedFloat32Array()
		for k in 9:
			var t := k / 8.0
			pts.append(a.lerp(b, t) + along * off + n * (0.0019 + 0.0011 * sin(PI * t)))
			rr.append(0.00034)
		var th := MeshInstance3D.new()
		th.mesh = MeshUtil.tube(pts, rr, 6)
		th.material_override = _thread_mat
		node.add_child(th)
	var knot := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.0011
	sm.height = 0.0022
	knot.mesh = sm
	knot.material_override = _thread_mat
	knot.position = a + n * 0.0027
	node.add_child(knot)
	for sgn in [-1.0, 1.0]:
		var tail := MeshInstance3D.new()
		var tp := PackedVector3Array([a + n * 0.0027, a + n * 0.0036 - across * 0.0045 + along * 0.0022 * sgn])
		tail.mesh = MeshUtil.tube(tp, PackedFloat32Array([0.0003, 0.0003]), 6)
		tail.material_override = _thread_mat
		node.add_child(tail)


func _heart_closed(instant: bool) -> void:
	sutured = true
	patient.set_heart_wound(wound_c, wound_dir, 0.008, 1.0)
	if not instant:
		for h in proc.hands:
			if h.held and h.held.id == "porte_aiguille":
				h.put_back()


# ---------------------------------------------------------------- Massage

## Main droite gantée à plat sur la face antérieure des ventricules, doigts vers le sternum ; le
## poignet sort par l'incision vers le chirurgien (côté gauche du patient).
func _build_hand() -> void:
	var on_heart := _heart_surface(-0.045, 0.06, 0.0)
	var n := (on_heart - Patient.HEART_C).normalized()
	var fingers := Vector3(0.3, -0.1, -1.0)
	fingers = (fingers - n * fingers.dot(n)).normalized()
	var x := n.cross(fingers).normalized()
	_hand_xf = Transform3D(Basis(x, n, fingers), on_heart + n * (GloveHand.PALM_HALF.y + 0.003) - fingers * 0.028)
	_hand = GloveHand.new()
	_hand.name = "MainMassage"
	_hand.visible = false
	root.add_child(_hand)
	_hand.global_transform = _hand_xf
	_hand.set_blood(0.9)
	_hand.set_elbow(_hand_xf.origin + Vector3(0.02, 0.26, 0.34))


func _hand_in() -> void:
	_hand.visible = true
	_hand.curl = 0.3
	var from := _hand_xf.translated(Vector3(0, 0.12, 0.1))
	_hand.global_transform = from
	var tw := root.create_tween()
	tw.tween_property(_hand, "global_transform", _hand_xf, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _hand_ready = true)


func _hand_out() -> void:
	_hand_ready = false
	var tw := root.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(_hand, "global_transform", _hand_xf.translated(Vector3(0, 0.16, 0.14)), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_hand.hide)


func _compress(_n: int) -> void:
	monitor.compression()
	Sfx.play("ecarte", Patient.HEART_C, -10.0, randf_range(0.9, 1.05))


func _squeeze(v: float) -> void:
	patient.set_heart_squeeze(v)
	if _hand_ready:
		# La paume suit la face du cœur qui s'aplatit ; les doigts se referment
		_hand.curl = 0.3 + 0.4 * v
		var n := _hand_xf.basis.y
		_hand.global_transform = _hand_xf.translated(-n * 0.013 * v)


func _rosc_done(instant: bool) -> void:
	rosc = true
	if instant:
		_hand_ready = false
		_hand.hide()
	else:
		_hand_out()
	patient.set_heart_squeeze(0.0)
	monitor.arrest = false
	monitor.spo2 = 70.0
	monitor.target_spo2 = 94.0
	monitor.target_rate = 118.0
	monitor.sys = 86
	monitor.dia = 52
	monitor.ecg_voltage = 1.0
	patient.heart_rate = 118.0
	patient.beat_gain = 1.0


# ---------------------------------------------------------------- Animation

func process(delta: float) -> void:
	# Ce qui est posé sur le cœur suit ses battements et le massage (même déformation que le shader)
	if _heart_follow:
		var sq := patient.heart_squeeze
		var hb := Basis.from_scale(Vector3(1.0 + 0.08 * sq, 1.0 - 0.32 * sq, 1.0 + 0.1 * sq) * (1.0 + patient.beat_now))
		_heart_follow.transform = Transform3D(hb, Patient.HEART_C - hb * Patient.HEART_C)
	# Le cœur libéré mais encore ouvert saigne à chaque battement
	if peri_open > 0.6 and not sutured and patient.beat_gain > 0.0:
		var ph := fmod(Time.get_ticks_msec() / 1000.0 * patient.heart_rate / 60.0, 1.0)
		if ph < _last_beat:
			_spurt(5 if patient.heart_wound_closed() < 0.25 else 2)
		_last_beat = ph
	for i in range(_drops.size() - 1, -1, -1):
		var d: Array = _drops[i]
		var node: MeshInstance3D = d[0]
		var vel: Vector3 = d[1]
		vel += Vector3.DOWN * 9.8 * delta
		node.position += vel * delta
		d[1] = vel
		d[2] = float(d[2]) - delta
		if float(d[2]) <= 0.0 or node.position.y < Patient.HEART_C.y - 0.03:
			node.queue_free()
			_drops.remove_at(i)


func _spurt(n: int) -> void:
	for k in n:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.0016 + randf() * 0.0012
		sm.height = sm.radius * 2.0
		sm.radial_segments = 8
		sm.rings = 4
		m.mesh = sm
		m.material_override = _drop_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(m)
		m.position = wound_c + wound_n * 0.002
		var v := (wound_n * 0.55 + Vector3(randf_range(-0.12, 0.12), randf_range(0.0, 0.1), randf_range(-0.12, 0.12))) * (0.6 + randf() * 0.4)
		_drops.append([m, v, 0.7])
