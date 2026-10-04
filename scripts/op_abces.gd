class_name OpAbces
extends Operation
## Drainage d'un abcès de la paroi abdominale : la peau est gonflée, rouge, tendue, avec une pointe
## jaunâtre. Anesthésie locale, incision au sommet (le pus jaillit), effondrement des logettes à la
## pince de Kelly (le pus continue de sortir), lavage au sérum à la seringue, mèche de gaze.

const SITE := Vector2(-0.05, 0.1)
const RADIUS := 0.032
const DOME := 0.011

var axis := Vector3.DOWN
var pus: MeshInstance3D  ## pus qui sort et coule sur la peau
var pus_mat: StandardMaterial3D
var streak: MeshInstance3D  ## coulée de pus vers le flanc
var released := 0.0  ## pus sorti (0..1)
var washed := 0.0  ## lavage (0..1)
var _drip_t := 0.0


func _init() -> void:
	id = "abces"
	name = "Drainage d'abcès"
	tagline = "Un gros abcès sur le ventre : rouge, chaud, gonflé de pus. On l'ouvre, on le vide, on le lave et on met une mèche. Opération courte, sous anesthésie locale."
	intro_text = "Inès, 35 ans : depuis 5 jours une boule rouge et très douloureuse sur le ventre, avec de la fièvre. C'est un abcès de 6 cm, plein de pus. Elle est réveillée : il faudra l'endormir localement et attendre que ça agisse avant d'inciser."
	summary = "Abcès incisé, vidé, lavé et méché : la douleur et la fièvre vont tomber."
	header = "BLOC 3  ·  DRAINAGE D'ABCÈS  ·  ANESTHÉSIE LOCALE"
	scan_text = "ÉCHOGRAPHIE\\nCollection liquidienne 5 x 4 cm\\nsous-cutanée, cloisonnée"
	breath_rate = 16.0
	surgeon_spot = Vector3(-0.05, 0.0, 0.6)
	tray_pos = Vector3(0.36, 0.0, 0.58)
	vitals = {"hr": 104.0, "spo2": 98.0, "sys": 128, "dia": 80}
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue (lidocaïne, puis sérum)", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["bistouri", "Bistouri lame 11", "manche_bistouri", 90.0, 0.0],
		["kelly", "Pince de Kelly", "clamp_ligature", 0.0, 0.2],
		["meche", "Mèche de gaze", "proc:meche", 0.0, 0.0],
	]


func configure_patient(p: Patient) -> void:
	p.op = "abces"
	p.INC_A = SITE + Vector2(-0.012, 0.0)
	p.INC_B = SITE + Vector2(0.012, 0.0)
	p.PATCH_MIN = Vector2(-0.17, -0.02)
	p.PATCH_SIZE = Vector2(0.24, 0.24)
	p.WINDOW_MIN = Vector2(-0.13, 0.025)
	p.WINDOW_MAX = Vector2(0.03, 0.18)
	p.paint_r = Vector2(0.05, 0.05)
	p.wound_w = 0.0065
	p.WOUND_DEPTH = 0.022
	p.bowl_radii = Vector3(0.022, 0.018, 0.018)
	p.bowl_color = Color(0.62, 0.42, 0.22)
	p.hole_limit = 0.004  # la coque de l'abcès n'est pas encore ouverte
	p.abscess = Vector4(SITE.x, SITE.y, RADIUS, DOME)
	p.abscess_red = 1.0


func _skin_normal(x: float, z: float) -> Vector3:
	var e := 0.004
	var hx := (Patient.body_height(x + e, z) - Patient.body_height(x - e, z)) / (2.0 * e)
	var hz := (Patient.body_height(x, z + e) - Patient.body_height(x, z - e)) / (2.0 * e)
	return Vector3(-hx, 1.0, -hz).normalized()


func build_extras() -> void:
	axis = -_skin_normal(SITE.x, SITE.y)
	pus_mat = StandardMaterial3D.new()
	pus_mat.albedo_color = Color(0.7, 0.64, 0.36, 0.95)
	pus_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pus_mat.roughness = 0.5
	pus_mat.clearcoat_enabled = true
	pus_mat.clearcoat = 0.18
	pus_mat.subsurf_scatter_enabled = false
	pus_mat.rim_enabled = true
	pus_mat.rim = 0.15
	pus = MeshInstance3D.new()
	pus.name = "Pus"
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 12
	pus.mesh = sm
	pus.material_override = pus_mat
	pus.visible = false
	pus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patient.add_child(pus)
	streak = MeshInstance3D.new()
	streak.name = "CouleePus"
	streak.mesh = sm
	streak.material_override = pus_mat
	streak.visible = false
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patient.add_child(streak)


func on_start() -> void:
	monitor.target_rate = 104.0


func define_steps() -> void:
	var c := patient.center
	steps = [
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte autour de l'abcès",
			"text": "Frotte doucement la compresse de la pince à badigeon sur l'abcès et tout autour (c'est très douloureux pour elle), jusqu'à ce que toute la zone soit brune.",
			"label": "Zone à désinfecter", "ring": 2.2, "done_msg": "Peau désinfectée"},
		{"id": "anesthesie", "kind": "inject", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Endors la peau",
			"text": "Pique l'aiguille au bord de l'abcès (repère). Relâche le pouce, puis serre-le contre l'index pour pousser le piston : la lidocaïne fait gonfler la peau. Injecte tout, puis retire l'aiguille.",
			"label": "Pique ici", "wait": 8.0,
			"target": func() -> Vector3: return patient.on_skin(c + patient.perp3 * 0.026),
			"done_msg": "Produit injecté : attends qu'il agisse"},
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Ouvre l'abcès",
			"text": "Attends que la peau soit endormie. Puis incise franchement au sommet de l'abcès, sur le pointillé : le pus va sortir.",
			"done": _incision_done, "done_msg": "Le pus s'écoule"},
		{"id": "logettes", "kind": "spread", "list": "Casser les logettes", "inst": "kelly",
			"title": "Casse les logettes",
			"text": "L'abcès est cloisonné en petites poches. Enfonce la pince de Kelly fermée dans l'incision et ouvre-la (écarte le pouce) dans tous les sens : chaque poche ouverte libère du pus. Va jusqu'au fond.",
			"label": "Entre ici", "depth": 0.018, "axis": axis,
			"target": func() -> Vector3: return patient.on_skin(c),
			"progress": _break_loculi,
			"done": _emptied, "done_msg": "Toutes les poches sont ouvertes"},
		{"id": "lavage", "kind": "inject", "list": "Lavage", "inst": "seringue",
			"title": "Lave la cavité",
			"text": "La seringue est remplie de sérum. Mets l'aiguille dans la cavité ouverte et pousse le piston : le sérum chasse le reste du pus. Vide-la, puis retire-la.",
			"label": "Lave ici", "wait": 0.0, "bleb": false, "what": "Sérum",
			"target": func() -> Vector3: return patient.on_skin(c) - Vector3.UP * 0.004,
			"progress": _wash, "done_msg": "Cavité propre"},
		{"id": "meche", "kind": "insert", "list": "Mèche", "inst": "meche",
			"title": "Mets une mèche",
			"text": "Glisse la mèche de gaze au fond de la cavité avec son stylet : elle laissera le pus continuer à sortir et empêchera la peau de se refermer trop tôt.",
			"label": "Mèche ici", "depth": 0.016, "axis": axis,
			"target": func() -> Vector3: return patient.on_skin(c),
			"done": _wick_in, "done_msg": "Mèche en place : pansement !"},
	]


func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	patient.hole_limit = 0.03
	if instant:
		patient.opening = 0.5
		released = maxf(released, 0.45)
		_update_pus()
	else:
		tween_opening(0.5)
		Sfx.play("ecarte", patient.center, -2.0, 0.7)


## Chaque fois que la pince ouvre une logette, du pus sort.
func _break_loculi(v: float) -> void:
	released = maxf(released, 0.45 + 0.55 * v)


func _emptied(_hand: SurgeonHand, _instant: bool) -> void:
	released = 1.0
	_update_pus()
	monitor.target_rate = 92.0


func _wash(v: float) -> void:
	washed = maxf(washed, v)
	_update_pus()


func _wick_in(hand: SurgeonHand, instant: bool) -> void:
	# La gaze reste dans la cavité (un bout dépasse), le stylet retourne sur la table
	var inst := instrument("meche")
	var gauze := inst.find_child("Gaze", true, false) as Node3D
	if gauze:
		var xf := gauze.global_transform
		if instant:
			xf = inst.tip_transform(patient.center + axis * 0.016, axis, Vector3.UP) * inst.model.transform * gauze.transform
		gauze.get_parent().remove_child(gauze)
		patient.add_child(gauze)
		gauze.global_transform = xf
	if hand:
		hand.put_back()
	patient.abscess_red = 0.6
	monitor.target_rate = 84.0


## Le dôme de l'abcès s'affaisse à mesure que le pus sort ; le pus s'étale sur la peau puis est lavé.
func _update_pus() -> void:
	patient.abscess.w = DOME * (1.0 - 0.85 * released)
	var amount := clampf(released * 1.3, 0.0, 1.0) * (1.0 - washed)
	pus.visible = amount > 0.02
	streak.visible = amount > 0.15
	if pus.visible:
		# Une goutte épaisse qui sort de la fente, puis une coulée qui descend vers le flanc (+Z)
		var c := patient.center
		var down := Vector3(0, 0, 1)
		pus.global_position = patient.on_skin(c + down * 0.0015 * amount) + Vector3.UP * 0.0008
		pus.scale = Vector3(0.0105, 0.0016 + 0.0016 * amount, 0.003 + 0.004 * amount)
		var p2 := patient.on_skin(c + down * (0.0035 + 0.012 * amount)) + Vector3.UP * 0.0003
		streak.global_position = p2
		streak.scale = Vector3(0.0035 + 0.003 * amount, 0.0009 * amount + 0.0003, 0.004 + 0.013 * amount)


func process(delta: float) -> void:
	if patient == null or pus == null:
		return
	# Le pus jaillit dès que la lame ouvre la coque, puis continue de suinter
	if patient.has_cut() and patient.incision_progress > 0.25 and released < 0.45:
		released = minf(0.45, released + delta * 0.35)
		_drip_t -= delta
		if _drip_t <= 0.0:
			_drip_t = 0.6
			Sfx.play("plop", patient.center, -18.0, 1.6)
	if released > 0.0:
		_update_pus()
