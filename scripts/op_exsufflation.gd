class_name OpExsufflation
extends Operation
## Exsufflation à l'aiguille d'un pneumothorax suffocant gauche. Patient couché sur le dos, en
## choc. Repérage du 2e espace intercostal sur la ligne médio-claviculaire (ou du 4e-5e espace sur
## la ligne axillaire, site recommandé chez l'adulte), désinfection rapide, aiguille-cathéter 14G
## perpendiculaire à la peau, au ras du bord supérieur de la côte du dessous, en aspirant : l'air
## comprimé remonte dans la seringue. On laisse le cathéter : l'air sort en sifflant, le poumon se
## regonfle en partie, la tension remonte. Un drain thoracique suivra.
##
## Le point choisi est jugé sur la vraie anatomie (carte des côtes et de la plèvre de l'atlas).

const HINT_SITE := Vector2(0.062, 0.083)  ## 2e espace, ligne médio-claviculaire gauche (X, Z)

var site := Vector3.ZERO  ## point de ponction (sur la peau)
var axis := Vector3.DOWN  ## perpendiculaire à la peau, vers l'intérieur
var flash_depth := 0.047
var marked := false
var catheter: Node3D
var _hiss := 0.0


func _init() -> void:
	id = "exsufflation"
	name = "Exsufflation à l'aiguille"
	tagline = "Pneumothorax suffocant : faire sortir l'air en quelques secondes."
	pose = "dos"
	player_spawn = Vector3(0.02, 0.0, 0.72)
	player_look = Vector3(0.03, 1.02, 0.1)
	tray_pos = Vector3(-0.5, 0.0, 0.66)
	patient_line = "Thomas R., 24 ans — accident de voiture"
	urgency = "URGENCE VITALE"
	intro_title = "Salle de déchocage"
	intro_text = "Choc frontal, ceinture attachée : la sangle a marqué le thorax de l'épaule gauche à la hanche droite. Il étouffe et pâlit à vue d'œil : plus aucun bruit respiratoire à gauche, thorax gauche distendu, trachée déviée vers la droite, veines du cou gonflées, tension qui s'effondre.\n\nC'est un pneumothorax suffocant gauche : l'air comprimé écrase le poumon et le cœur. Pas le temps d'une radio ni d'un drain : fais sortir l'air tout de suite avec une aiguille. Le drain suivra."
	imaging_tex = ""
	imaging_text = "Pas de radio : un pneumothorax suffocant se reconnaît à l'examen et se traite tout de suite.\n\n•  aucun bruit respiratoire à gauche\n•  thorax gauche distendu, sonore\n•  trachée déviée vers la droite\n•  veines du cou gonflées\n•  choc : 78 / 44"
	scan_text = "PAS DE RADIO\nDiagnostic à l'examen :\npneumothorax suffocant gauche"
	header = "DÉCHOCAGE  ·  EXSUFFLATION  ·  HÉMITHORAX GAUCHE"
	summary = "L'air comprimé est sorti : la tension et l'oxygène remontent. Le cathéter reste en place en attendant le drain thoracique."
	breath_rate = 36.0
	vitals = {"hr": 138.0, "spo2": 79.0, "sys": 78, "dia": 44, "temp": 36.3}
	catalog = [
		["feutre", "Feutre dermographique", "proc:feutre", 0.0, 0.0],
		["mikulicz", "Pince à badigeon (chlorhexidine)", "pince_mikulicz", 0.0, 0.0],
		["cathlon", "Cathéter 14G de 8 cm sur seringue", "proc:cathlon", 0.0, 0.0],
	]


func configure_patient(p: Patient) -> void:
	# Pas de champ (urgence) : tout le thorax découvert peut être touché, marqué, piqué
	p.WINDOW_MIN = Vector2(-0.24, -0.23)
	p.WINDOW_MAX = Vector2(0.2, 0.23)
	# Peau détaillée (badigeon, relief) sur l'hémithorax gauche : les deux sites possibles
	p.PATCH_MIN = Vector2(-0.1, -0.02)
	p.PATCH_SIZE = Vector2(0.24, 0.24)
	p.INC_A = HINT_SITE - Vector2(0.0, 0.004)
	p.INC_B = HINT_SITE + Vector2(0.0, 0.004)
	p.paint_r = Vector2(0.034, 0.032)
	p.wound_w = 0.004
	p.WOUND_DEPTH = 0.01
	p.breathe_amp = 0.006
	p.hole_limit = 0.003
	# Conducteur ceinturé : la sangle passait de l'épaule gauche à la hanche droite
	p.belt = Vector4(0.13, 0.17, -0.42, -0.15)
	p.antiseptic = "chlorhexidine"


func build_extras() -> void:
	patient.heart_rate = vitals["hr"]
	site = patient.on_skin(Vector3(HINT_SITE.x, 0, HINT_SITE.y))
	axis = -Patient.skin_normal(site.x, site.z)


func on_start() -> void:
	monitor.target_rate = vitals["hr"]
	monitor.target_spo2 = vitals["spo2"]


func define_steps() -> void:
	steps = [
		{"id": "repere", "kind": "mark", "list": "Repérage", "inst": "feutre",
			"title": "Trouve le point de ponction",
			"text": "Côté gauche. Soit le 2e espace intercostal sur la ligne médio-claviculaire (sous le milieu de la clavicule : compte la 2e côte à partir de l'angle du sternum), soit le 4e-5e espace sur la ligne axillaire. Toujours juste au-dessus de la côte du dessous. Marque le point au feutre (V : vue anatomique).",
			"label": "Hémithorax gauche", "ring": 4.2,
			"area": func() -> Vector3: return patient.on_skin(Vector3(0.03, 0, 0.11)),
			"ideal": func() -> Vector3: return patient.on_skin(Vector3(HINT_SITE.x, 0, HINT_SITE.y)),
			"judge": _judge_site, "done": _marked},
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte le point",
			"text": "Un coup de chlorhexidine alcoolique sur le point marqué. Quelques secondes suffisent : il n'y a pas de temps à perdre.",
			"label": "Désinfecte ici", "ring": 1.4,
			"area": func() -> Vector3: return site,
			"done_msg": "Désinfecté"},
		{"id": "ponction", "kind": "needle", "list": "Ponction", "inst": "cathlon",
			"title": "Pique en aspirant",
			"text": "Perpendiculaire à la peau, sur le point marqué. Maintiens le clic : l'aiguille avance doucement ET tu tires le piston. Dès que des bulles d'air remontent dans le sérum, arrête : tu es dans la plèvre. Plus loin, c'est le poumon.",
			"label": "Pique ici", "ring": 0.7,
			"target": func() -> Vector3: return patient.live(site),
			"axis": axis, "flash_depth": flash_depth, "max_depth": flash_depth + 0.018, "flash": "air",
			"deep_msg": "Trop profond : l'aiguille a touché le poumon. Recule un peu.",
			"on_flash": _decompress, "done_msg": "Pschhh ! L'air comprimé sort en sifflant"},
		{"id": "catheter", "kind": "withdraw", "list": "Laisser le cathéter", "inst": "cathlon",
			"title": "Retire l'aiguille, laisse le cathéter",
			"text": "Tiens le cathéter et retire l'aiguille (molette vers le haut, ou R) : le cathéter souple reste dans la plèvre et l'air continue de sortir. Ne le bouche pas : le drain thoracique suivra.",
			"label": "Cathéter", "ring": 0.6,
			"target": func() -> Vector3: return patient.live(site),
			"axis": axis, "max_depth": flash_depth + 0.018,
			"deep_msg": "Trop profond : l'aiguille a touché le poumon.",
			"done": _leave_catheter, "done_msg": "Cathéter en place : il respire mieux"},
	]


## Le point marqué : côté gauche, dans un espace intercostal (pas sur une côte), au bon niveau
## selon la ligne choisie (médio-claviculaire ou axillaire), loin du bord du sternum.
func _judge_site(p: Vector3) -> Dictionary:
	var mm := Vector2(p.x - HINT_SITE.x, p.z - HINT_SITE.y).length() * 1000.0
	if p.z < 0.0:
		return {"ok": false, "mm": mm, "msg": "Côté droit ! Le pneumothorax est à gauche : c'est là qu'on n'entend plus respirer."}
	var code := Patient.rib_code(p.x, p.z)
	if code > 0:
		return {"ok": false, "mm": mm, "msg": "Tu es sur la %de côte : l'aiguille buterait sur l'os. Place-toi dans l'espace juste au-dessus d'une côte." % code}
	if code == 0:
		return {"ok": false, "mm": mm, "msg": "Hors du gril costal. Reste sur le thorax, entre deux côtes."}
	var ics := -code
	var mcl: float = Patient.landmarks.get("mcl_z_L", 0.083)
	var sternum_edge: float = Patient.landmarks.get("sternum_half_width", 0.024)
	var lateral := p.z > 0.115
	var near := _dist_to_rib_below(p, ics + 1)
	var note := ""
	if near > 0.014:
		note = "  (rapproche-toi de la côte du dessous : l'artère et le nerf intercostaux longent le bord inférieur de chaque côte)"
	if lateral:
		if ics == 4 or ics == 5:
			return {"ok": true, "mm": mm, "msg": "Bon repère : %de espace intercostal, ligne axillaire%s" % [ics, note]}
		if ics < 4:
			return {"ok": false, "mm": mm, "msg": "%de espace : trop haut sur la ligne axillaire. Vise le 4e ou le 5e espace (hauteur du mamelon)." % ics}
		return {"ok": false, "mm": mm, "msg": "%de espace : trop bas. Sous le 5e espace, le diaphragme remonte (rate, estomac)." % ics}
	if p.z < sternum_edge + 0.03:
		return {"ok": false, "mm": mm, "msg": "Trop près du sternum : l'artère mammaire interne descend à 1-2 cm de son bord. Va sur la ligne médio-claviculaire, sous le milieu de la clavicule."}
	if absf(p.z - mcl) > 0.026:
		return {"ok": false, "mm": mm, "msg": "Pas sur la ligne médio-claviculaire : place-toi à l'aplomb du milieu de la clavicule."}
	if ics == 1:
		return {"ok": false, "mm": mm, "msg": "1er espace : trop haut, juste sous la clavicule (vaisseaux sous-claviers). Descends d'un espace."}
	if ics >= 3:
		return {"ok": false, "mm": mm, "msg": "%de espace : trop bas sur cette ligne, le cœur n'est pas loin. Remonte au 2e espace." % ics}
	return {"ok": true, "mm": mm, "msg": "Bon repère : 2e espace intercostal, ligne médio-claviculaire%s" % note}


## Distance (m) du point au bord supérieur de la côte `rib`, en descendant le long du corps.
func _dist_to_rib_below(p: Vector3, rib: int) -> float:
	for k in 40:
		var x := p.x - k * 0.0025
		if Patient.rib_code(x, p.z) == rib:
			return k * 0.0025
	return 1.0


func _marked(_hand: SurgeonHand, _instant: bool, p: Variant) -> void:
	var q: Vector3 = p if p is Vector3 else patient.on_skin(Vector3(HINT_SITE.x, 0, HINT_SITE.y))
	site = patient.on_skin(Vector3(q.x, 0, q.z))
	axis = -Patient.skin_normal(site.x, site.z)
	var d := Patient.pleura_depth(site.x, site.z)
	flash_depth = d if d > 0.015 else 0.047
	marked = true
	for m in [patient.skin_mat, patient.zone_mat]:
		m.set_shader_parameter("pen_mark", Vector3(site.x, site.z, 1.0))
	patient.set_paint_center(Vector2(site.x, site.z))
	# Les étapes suivantes visent le point choisi, selon la vraie épaisseur de la paroi
	for s in steps:
		if s["kind"] == "needle" or s["kind"] == "withdraw":
			s["axis"] = axis
			s["max_depth"] = flash_depth + 0.018
		if s["kind"] == "needle":
			s["flash_depth"] = flash_depth


## La pointe arrive dans la plèvre : l'air comprimé sort, la tension remonte, le poumon se regonfle.
func _decompress() -> void:
	_hiss = 6.0
	Sfx.play("souffle", site, 2.0, 1.15)
	patient.set_lung_target(0.35)
	monitor.target_spo2 = 90.0
	monitor.target_rate = 118.0
	monitor.sys = 98
	monitor.dia = 60
	patient.heart_rate = 118.0
	patient.breath_rate = 26.0
	monitor.resp_rate = 26.0
	patient.set_breathe(0.005)


func _leave_catheter(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("cathlon")
	var model := inst.model
	if model.has_method("detach_catheter") and model.get("catheter") != null:
		var c: Node3D = model.call("detach_catheter")
		root.add_child(c)
		# Le cathéter reste dans l'axe de la ponction, son embase dépasse de la peau
		# (repère du cathéter : gaine le long de +Z, de z = 0,014 à 0,086 ; embase en dessous)
		var b := Basis.looking_at(-axis, Vector3.UP if absf(axis.y) < 0.95 else Vector3.FORWARD)
		c.global_transform = Transform3D(b, site - axis * 0.016)
		catheter = c
	if instant:
		_decompress()
	monitor.target_spo2 = 94.0
	monitor.target_rate = 108.0
	monitor.sys = 106
	monitor.dia = 66
	patient.heart_rate = 108.0
	# L'aiguille et la seringue retournent sur la table (le cathéter reste dans le thorax)
	if hand and hand.held == inst:
		hand.put_back()


func process(delta: float) -> void:
	if _hiss > 0.0:
		_hiss -= delta
		Sfx.loop("sifflement", site, clampf(_hiss / 6.0, 0.0, 1.0) * 0.7)
