class_name OpPontage
extends Operation
## Pontage coronarien : l'artère mammaire interne gauche est branchée sur l'interventriculaire
## antérieure (IVA) bouchée, cœur arrêté, sous circulation extracorporelle (CEC).
##   1. Incision médiane, du creux sus-sternal à l'appendice xiphoïde.
##   2. Sternotomie à la scie (le sabot passe sous le sternum et protège le cœur).
##   3. Écarteur sternal : le sternum s'ouvre, le péricarde apparaît.
##   4. Artère mammaire interne gauche libérée au bistouri électrique (l'aide soulève le bord
##      gauche du sternum) : elle devient le greffon.
##   5. Péricarde ouvert : le cœur bat.  6-7. Canules dans l'aorte et l'oreillette droite : CEC.
##   8. Clamp sur l'aorte, cardioplégie : le cœur s'arrête.  9. IVA ouverte au bistouri.
##  10. Anastomose (surjet) de la mammaire sur l'IVA.  11. Déclampage : le cœur fibrille.
##  12. Choc interne : il repart.  13. Décanulation, fin de la CEC.  14. Fils d'acier sur le sternum.

## Ligne médiane du sternum (x, z), du creux sus-sternal à l'appendice xiphoïde
const STERNUM := [Vector2(0.098, 0.0), Vector2(0.074, 0.0), Vector2(0.049, 0.0), Vector2(0.024, 0.0),
	Vector2(-0.001, 0.0), Vector2(-0.026, 0.0), Vector2(-0.05, 0.0), Vector2(-0.074, 0.0)]
## Part de l'écartement le long du sternum (fermé aux deux bouts)
const STERNUM_H := [0.0, 0.7, 0.95, 1.0, 1.0, 0.95, 0.7, 0.0]
const SPREAD := 0.045  ## chaque moitié du sternum recule de 4,5 cm
const CUT_W := 0.003  ## trait de scie
const SAW_DEPTH := 0.02  ## la lame traverse l'os (sternum épais de 1,5 à 2 cm)
const FALL := Vector2(0.03, 0.16)  ## l'écartement gagne toute la paroi (les côtes plient)
const DEEP := Vector2(0.032, 0.06)  ## ... mais pas le cœur ni le péricarde
const LIMA_LIFT := 0.026  ## l'aide soulève le bord gauche du sternum
const PERI_W := 0.052  ## demi-largeur de l'ouverture du péricarde (large : toute la face avant du cœur)
const WOUND_DEPTH := 0.012  ## peau et graisse au-dessus du sternum
const CLOSE_SPREAD := 0.12  ## écartement restant quand l'écarteur est retiré
const CLOSE_OPEN := 0.45  ## ouverture de la peau pendant la pose des fils d'acier

var sternum := PackedVector3Array()  ## ligne médiane, sur la peau
var sternum_h := PackedFloat32Array()
var spread := 0.0
var inward := Vector3.DOWN
var lima_rest := PackedVector3Array()  ## artère mammaire gauche (atlas), au repos
var pc_a := Vector3.ZERO  ## ligne d'ouverture du péricarde
var pc_b := Vector3.ZERO
var peri_depth := 0.04
var aorta_top := Vector3.ZERO  ## où entre la canule aortique
var aorta_clamp := Vector3.ZERO  ## où se pose le clamp (entre la canule et le cœur)
var aorta_r := 0.015
var ra_point := Vector3.ZERO  ## auricule droite (canule veineuse)
var lad_c := Vector3.ZERO  ## artériotomie sur l'IVA
var lad_dir := Vector3(1, 0, 0)
var lad_n := Vector3.UP
var lima_harvested := false
var graft_on := 0.0  ## greffon amené sur l'IVA (0 = sur la paroi, 1 = cousu)
var on_bypass := false
var cold := 0.0
var _cec: CecMachine
var _heart_follow: Node3D
var _graft: MeshInstance3D
var _graft_fat: MeshInstance3D
var _graft_clip: MeshInstance3D
var _graft_route := PackedVector3Array()  ## points de passage du greffon cousu (cœur au repos)
var _lines: Array[MeshInstance3D] = []
var _wires: Array[Node3D] = []
var _stays: Array[Node3D] = []
var _staple_nodes: Array[Node3D] = []
var _thread_mat: StandardMaterial3D
var _wire_mat: StandardMaterial3D
var _vf_at := -1.0  ## moment où le cœur se met à fibriller après le déclampage
var _t := 0.0
var _graft_t := 0.0


func _init() -> void:
	id = "pontage"
	name = "Pontage coronarien"
	tagline = "Infarctus : cœur arrêté sous machine, nouvelle artère sur l'IVA."
	pose = "dos"
	player_spawn = Vector3(0.0, 0.0, -0.58)
	player_look = Vector3(0.0, 1.0, 0.02)
	tray_pos = Vector3(-0.55, 0.0, -0.66)
	patient_line = "Gérard M., 64 ans — angor instable"
	urgency = "PONTAGE PROGRAMMÉ EN URGENCE"
	intro_title = "Bloc de chirurgie cardiaque"
	intro_text = "Douleurs dans la poitrine au moindre effort depuis trois jours. La coronarographie montre l'artère interventriculaire antérieure (IVA) bouchée à 95 % à son origine : une grande partie du cœur manque de sang.\n\nTu vas lui faire un pontage : brancher l'artère mammaire interne gauche, qui longe le sternum par dedans, sur l'IVA en aval du rétrécissement. Le cœur sera arrêté pendant la couture, la machine de circulation extracorporelle fera son travail."
	imaging_tex = ""
	imaging_text = "Coronarographie : sténose serrée (95 %) de l'IVA proximale.\n\n•  fonction du cœur conservée\n•  carotides et artères mammaires saines\n•  indication : pontage mammaire interne gauche sur l'IVA"
	scan_text = "CORONAROGRAPHIE\nIVA proximale\nsténose 95 %"
	header = "BLOC CARDIAQUE  ·  PONTAGE AORTO-CORONAIRE"
	summary = "Le cœur bat, l'artère mammaire irrigue l'IVA. Le sternum est fermé aux fils d'acier ; il part en réanimation, réveillé dans quelques heures."
	breath_rate = 12.0
	vitals = {"hr": 72.0, "spo2": 98.0, "sys": 132, "dia": 78}
	catalog = [
		["bistouri", "Bistouri lame 15", "manche_bistouri", 90.0, 0.0],
		["scie_sternale", "Scie sternale", "proc:scie_sternale", 0.0, 0.0],
		["ecarteur_sternal", "Écarteur sternal", "proc:ecarteur_sternal", 0.0, 0.0],
		["bistouri_electrique", "Bistouri électrique", "proc:bistouri_electrique", 0.0, 0.0],
		["ciseaux", "Ciseaux de Metzenbaum", "ciseaux_metzenbaum", 0.0, 0.0],
		["canule_aortique", "Canule aortique", "proc:canule_aortique", 0.0, 0.0],
		["canule_veineuse", "Canule veineuse", "proc:canule_veineuse", 0.0, 0.0],
		["clamp_aortique", "Clamp aortique", "proc:clamp_aortique", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille (8/0, fils d'acier)", "porte_aiguille", 0.0, 0.19],
		["palettes", "Palettes de défibrillation internes", "proc:palettes", 0.0, 0.0],
	]


func configure_patient(p: Patient) -> void:
	# Champs du bloc : fenêtre sur le sternum (film adhésif iodé), le reste du corps est couvert
	p.WINDOW_MIN = Vector2(-0.115, -0.08)
	p.WINDOW_MAX = Vector2(0.13, 0.08)
	p.drape_override = {"glb": "res://assets/models/champ_sternum.glb", "map": "res://assets/data/champ_sternum_hauteur.bin"}
	p.PATCH_MIN = Vector2(-0.16, -0.16)
	p.PATCH_SIZE = Vector2(0.32, 0.32)
	p.INC_A = STERNUM[0]
	p.INC_B = STERNUM[STERNUM.size() - 1]
	p.paint_r = Vector2(0.17, 0.12)  # badigeon sur toute la fenêtre
	p.wound_w = 0.05
	p.WOUND_DEPTH = WOUND_DEPTH  # peau et graisse ; dessous, le sternum
	p.wall_taper = 0.1
	p.zone_v_min = 0.12
	p.hole_limit = 0.14
	p.breathe_amp = 0.003
	p.props_options = {"collar": false, "intubated": true, "draped": true}
	# Les bords antérieurs des poumons suivent la paroi quand le sternum s'écarte
	p.spread_extra = ["PoumonG", "PoumonD"]
	p.init_lung(0.0)


func build_extras() -> void:
	EchoView.load_volume()
	for i in STERNUM.size():
		var q: Vector2 = STERNUM[i]
		sternum.append(Vector3(q.x, Patient.body_height(q.x, q.y), q.y))
		sternum_h.append(STERNUM_H[i])
	var mid := Procedure.path_point(sternum, 0.5)
	inward = -Patient.skin_normal(mid.x, mid.z)
	patient.heart_rate = 72.0
	patient.beat_gain = 1.0
	patient.fill_iodine()
	patient.set_iodine_wet(0.3)  # badigeon séché sous le film adhésif
	# Artère mammaire gauche (atlas) : portion qui longe le sternum
	var lm: Dictionary = Patient.landmarks.get("lima", {})
	for q in lm.get("points", []):
		var v := Vector3(q[0], q[1], q[2])
		if v.x < 0.088 and v.x > -0.036:
			lima_rest.append(v)
	# Péricarde : au-dessus du cœur et de l'aorte, un peu à gauche de la ligne médiane
	pc_a = _tissue_top(0.042, 0.018, 2.0)
	pc_b = _tissue_top(-0.036, 0.018, 2.0)
	var pm := (pc_a + pc_b) * 0.5
	peri_depth = Patient.body_height(pm.x, pm.z) - pm.y
	# Aorte ascendante : canule en haut, clamp plus bas (entre la canule et le cœur)
	var ao: Dictionary = Patient.landmarks.get("aorta_ascending", {})
	var apts: Array = ao.get("points", [])
	var arad: Array = ao.get("radius", [])
	if apts.size() > 16:
		var c1 := Vector3(apts[16][0], apts[16][1], apts[16][2])
		var c2 := Vector3(apts[8][0], apts[8][1], apts[8][2])
		aorta_r = float(arad[16])
		aorta_top = c1 + Vector3.UP * aorta_r
		aorta_clamp = c2
	else:
		aorta_top = Vector3(0.046, 0.993, 0.006)
		aorta_clamp = Vector3(0.03, 0.974, 0.011)
	# Auricule droite : à droite de la racine de l'aorte, visible depuis la place du chirurgien
	ra_point = _tissue_top(0.024, -0.012, 0.0)
	# IVA (artère interventriculaire antérieure) : artériotomie au tiers moyen
	var lad: Dictionary = Patient.landmarks.get("lad", {})
	var lp: Array = lad.get("points", [])
	if lp.size() > 16:
		var a := Vector3(lp[13][0], lp[13][1], lp[13][2])
		var b := Vector3(lp[15][0], lp[15][1], lp[15][2])
		lad_c = (a + b) * 0.5
		lad_dir = (b - a).normalized()
	else:
		lad_c = Vector3(-0.015, 1.02, 0.055)
	lad_n = (lad_c - Patient.HEART_C).normalized()
	lad_dir = (lad_dir - lad_n * lad_dir.dot(lad_n)).normalized()
	lad_c += lad_n * 0.0025
	if OS.get_cmdline_user_args().has("--debug"):
		print("DEBUG pontage sternum=", sternum[0], "→", sternum[sternum.size() - 1], " péricarde=", pc_a, "→", pc_b,
			" aorte=", aorta_top, " clamp=", aorta_clamp, " OD=", ra_point, " IVA=", lad_c, " mammaire=", lima_rest.size())
	patient.set_aperture(sternum, sternum_h, 0.0, 0.0, CUT_W, 0.0, 0.045, FALL, DEEP)
	_heart_follow = Node3D.new()
	_heart_follow.name = "SuitLeCoeur"
	root.add_child(_heart_follow)
	_thread_mat = MeshUtil.mat(Color(0.1, 0.2, 0.55), 0.35)
	_wire_mat = MeshUtil.mat(Color(0.78, 0.8, 0.83), 0.22, 1.0)
	_cec = CecMachine.new()
	_cec.name = "MachineCEC"
	_cec.position = Vector3(0.02, 0.0, 1.22)
	_cec.rotation_degrees.y = 180.0
	root.add_child(_cec)
	# Arceau d'anesthésie (sous le champ de tête) : barre au-dessus du cou, montants fixés aux rails
	var steel := MeshUtil.mat(Color(0.7, 0.72, 0.75), 0.3, 0.9)
	var bar := MeshUtil.cylinder_instance(root, 0.009, 0.92, Vector3(0.215, 1.27, 0.0), steel, "Arceau")
	bar.rotation_degrees.x = 90.0
	for zs in [-0.4, 0.4]:
		MeshUtil.cylinder_instance(root, 0.009, 1.27 - 0.74, Vector3(0.215, (1.27 + 0.74) * 0.5, zs), steel, "MontantArceau")
		MeshUtil.box_instance(root, Vector3(0.03, 0.025, 0.11), Vector3(0.215, 0.755, zs * 0.875), steel, "PinceRail")
	var ret := instrument("ecarteur_sternal")
	if ret and ret.model is FinochiettoModel:
		(ret.model as FinochiettoModel).set_spread(0.012)


## Premier tissu (cœur, vaisseaux) sous la peau à la verticale de (x, z), `out_mm` au-dessus.
func _tissue_top(x: float, z: float, out_mm: float) -> Vector3:
	var top := Patient.body_height(x, z)
	for n in 240:
		var y := top - 0.025 - n * 0.0005
		var smp := EchoView.sample(Vector3(x, y, z))
		var lab: int = smp[0]
		if lab == 3 or lab == 6:
			return Vector3(x, y + out_mm * 0.001, z)
	return Vector3(x, Patient.HEART_C.y + 0.04, z)


func on_start() -> void:
	monitor.target_rate = 72.0
	monitor.heart_rate = 72.0
	monitor.target_spo2 = 98.0


func define_steps() -> void:
	steps = [
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Ouvre sur la ligne médiane",
			"text": "Du creux au-dessus du sternum jusqu'à la pointe de l'appendice xiphoïde, en plein milieu : un trait franc jusqu'à l'os.",
			"done": _incision_done, "done_msg": "Le sternum est à nu"},
		{"id": "sternotomie", "kind": "cutline", "list": "Sternotomie", "inst": "scie_sternale",
			"title": "Ouvre le sternum à la scie",
			"text": "Glisse le sabot de la scie sous le haut du sternum, puis descends tout droit sur la ligne médiane en gardant le clic enfoncé. Le sabot protège le cœur, juste dessous. L'anesthésiste arrête de ventiler pendant la coupe.",
			"label": "DÉPART", "path": _saw_path, "tol": 0.016, "need": 0.88, "depth": SAW_DEPTH, "sound": "scie",
			"what": "Sternum coupé", "on_progress": _saw_progress, "done": _saw_done,
			"done_msg": "Sternum ouvert de haut en bas"},
		{"id": "ecarteur", "kind": "crank", "list": "Écarteur sternal", "inst": "ecarteur_sternal",
			"title": "Écarte le sternum",
			"text": "Pose l'écarteur entre les deux moitiés du sternum (la crémaillère vers les pieds), puis tourne la manivelle doucement (clic maintenu) : un écartement trop brutal casse les côtes.",
			"label": "Valves ici", "ring": 1.2, "target": _ret_tip, "near": 0.05, "seconds": 6.0,
			"what": "Écartement du sternum", "on_seat": _ret_seat, "on_progress": _ret_progress,
			"done": _ret_done, "done_msg": "Le péricarde est à nu, le cœur bat dessous"},
		{"id": "mammaire", "kind": "cutline", "list": "Artère mammaire", "inst": "bistouri_electrique",
			"title": "Libère l'artère mammaire interne gauche",
			"text": "L'aide soulève le bord gauche du sternum. L'artère descend contre la face interne de la paroi, à 1 ou 2 cm du sternum : décolle-la au bistouri électrique, de haut en bas, avec ses veines et sa graisse (clic maintenu en suivant l'artère).",
			"label": "DÉPART", "path": _lima_path, "tol": 0.018, "need": 0.85, "depth": 0.03, "sound": "bistouri_elec",
			"what": "Mammaire libérée", "enter": _lima_enter, "on_progress": _lima_progress, "done": _lima_done,
			"done_msg": "Greffon prêt : l'artère mammaire bat, coupée et clippée en bas"},
		{"id": "pericarde", "kind": "cutline", "list": "Péricarde", "inst": "ciseaux",
			"title": "Ouvre le péricarde",
			"text": "Le sac fibreux qui entoure le cœur : ouvre-le de haut en bas, de l'aorte jusqu'au diaphragme (clic maintenu en avançant). Les bords sont ensuite suspendus à la peau.",
			"label": "DÉPART", "a": func() -> Vector3: return pc_a, "b": func() -> Vector3: return pc_b,
			"tol": 0.016, "need": 0.85, "depth": peri_depth, "what": "Péricarde ouvert",
			"on_progress": _peri_progress, "done": _peri_done, "done_msg": "Le cœur est à nu : l'IVA descend sur sa face avant"},
		{"id": "canule_ao", "kind": "insert", "list": "Canule aortique", "inst": "canule_aortique",
			"title": "Canule dans l'aorte",
			"text": "Au milieu de la bourse déjà en place sur l'aorte ascendante, enfonce la canule (clic maintenu), bout tourné vers la crosse : c'est par elle que la machine renverra le sang oxygéné.",
			"label": "Aorte", "target": func() -> Vector3: return aorta_top, "axis": _aorta_axis(), "depth": 0.012,
			"zone_r": 0.016, "zone_depth": 0.12, "what": "Canule enfoncée", "done": _ao_done, "done_msg": "Canule aortique en place, purgée"},
		{"id": "canule_vei", "kind": "insert", "list": "Canule veineuse", "inst": "canule_veineuse",
			"title": "Canule dans l'oreillette droite",
			"text": "Par l'auricule droite, pousse la grosse canule veineuse vers la veine cave inférieure (clic maintenu) : tout le sang du corps partira vers la machine.",
			"label": "Oreillette droite", "target": func() -> Vector3: return ra_point, "axis": Vector3(-0.45, -0.88, -0.1).normalized(),
			"depth": 0.03, "zone_r": 0.02, "zone_depth": 0.15, "what": "Canule enfoncée", "done": _vei_done,
			"done_msg": "Départ de la CEC : la machine fait le travail du cœur et des poumons"},
		{"id": "clampage", "kind": "crank", "list": "Clampage aortique", "inst": "clamp_aortique",
			"title": "Clampe l'aorte",
			"text": "Pose le clamp en travers de l'aorte ascendante, entre la canule et le cœur, et ferme-le (clic). Le perfusionniste injecte alors la cardioplégie froide : le cœur va s'arrêter.",
			"label": "Clamp ici", "ring": 1.0, "target": func() -> Vector3: return aorta_clamp + Vector3.UP * aorta_r,
			"near": 0.04, "seconds": 0.5, "what": "Clampage", "on_seat": _clamp_seat, "done": _clamp_done,
			"done_msg": "Cardioplégie : le cœur s'arrête, flasque et froid"},
		{"id": "arteriotomie", "kind": "cutline", "list": "Ouverture de l'IVA", "inst": "bistouri",
			"title": "Ouvre l'IVA",
			"text": "Sur la face avant du cœur, l'IVA descend vers la pointe. En aval du rétrécissement, incise-la sur 6 mm dans sa longueur, juste la paroi de devant (clic maintenu en suivant l'artère).",
			"label": "IVA", "path": _lad_path, "tol": 0.008, "need": 0.8, "depth": 0.04, "what": "IVA ouverte",
			"on_progress": _lad_progress, "done": _lad_done, "done_msg": "IVA ouverte sur 6 mm"},
		{"id": "anastomose", "kind": "suture", "list": "Anastomose", "inst": "porte_aiguille",
			"title": "Couds la mammaire sur l'IVA",
			"text": "Surjet au fil 8/0 : chaque point passe dans le bout du greffon puis dans le bord de l'IVA, tout autour de l'ouverture. Six points.",
			"label": "Point", "radius": 0.004, "zone_depth": 0.08, "enter": _graft_bring,
			"pairs": _anast_pairs, "point": _anast_point, "done": _anast_done,
			"done_msg": "Anastomose terminée, étanche"},
		{"id": "declampage", "kind": "pick", "list": "Déclampage", "inst": "clamp_aortique",
			"title": "Enlève le clamp",
			"text": "Mains nues : vise le clamp sur l'aorte et clique pour le retirer. Le sang chaud revient dans les coronaires et dans le greffon.",
			"label": "Clamp", "near": 0.06, "done": _unclamp_done,
			"done_msg": "Le sang revient… le cœur fibrille !"},
		{"id": "choc", "kind": "crank", "list": "Défibrillation", "inst": "palettes",
			"title": "Choc électrique interne",
			"text": "Fibrillation ventriculaire : le cœur tremble sans battre. Pose les palettes de part et d'autre du cœur et choque (clic).",
			"label": "Cœur", "ring": 1.4, "target": func() -> Vector3: return Patient.HEART_C + Vector3.UP * 0.05,
			"near": 0.07, "seconds": 0.3, "what": "Choc", "done": _shock_done,
			"done_msg": "Choc délivré : le cœur repart en rythme régulier"},
		{"id": "decanulation", "kind": "pick", "list": "Décanulation", "inst": "canule_aortique",
			"title": "Arrête la CEC, retire les canules",
			"text": "Le cœur a repris la main : la machine ralentit puis s'arrête. Retire la canule aortique (main vide, clic dessus) ; l'aide noue la bourse, la canule veineuse est déjà retirée.",
			"label": "Canule", "near": 0.06, "target": func() -> Vector3: return _cannula_grip("canule_aortique"),
			"enter": _wean, "done": _decan_done,
			"done_msg": "Sevrage réussi : le cœur assure seul la circulation"},
		{"id": "fermeture", "kind": "suture", "list": "Fermeture du sternum", "inst": "porte_aiguille",
			"title": "Ferme le sternum aux fils d'acier",
			"text": "L'écarteur est retiré. Passe cinq fils d'acier autour des deux moitiés du sternum : pique d'un côté, ressors de l'autre. Ils seront serrés et torsadés.",
			"label": "Fil d'acier", "radius": 0.006, "zone_depth": 0.04, "enter": _close_enter,
			"pairs": _wire_pairs, "point": _wire_point, "done": _close_done,
			"done_msg": "Sternum fermé"},
	]


# ---------------------------------------------------------------- Sternotomie

func _incision_done(instant: bool) -> void:
	if instant:
		patient.incision_progress = 1.0
	patient.opening = 0.08


func _saw_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in sternum:
		out.append(p + Vector3.DOWN * SAW_DEPTH)
	return out


func _saw_progress(t0: float, t1: float) -> void:
	patient.set_aperture(sternum, sternum_h, t0, t1, CUT_W, 0.0, 0.045, FALL, DEEP)


func _saw_done(_h: SurgeonHand, _instant: bool) -> void:
	_saw_progress(0.0, 1.0)


# ---------------------------------------------------------------- Écarteur

func _ret_tip() -> Vector3:
	return Procedure.path_point(sternum, 0.5) + Vector3.DOWN * 0.03


func _ret_xf(inst: Instrument) -> Transform3D:
	# Valves contre les berges du sternum, crémaillère vers les pieds
	var z := Vector3.DOWN.lerp(inward, 0.45).normalized()
	var y := Vector3(-1, 0, 0)
	y = (y - z * y.dot(z)).normalized()
	var x := y.cross(z).normalized()
	return Transform3D(Basis(x, y, z), _ret_tip()) * Transform3D(Basis.IDENTITY, -inst.tip_local)


func _ret_seat(hand: SurgeonHand) -> void:
	var inst := instrument("ecarteur_sternal")
	if inst.parked:
		return
	hand.release_parked()
	park(inst, _ret_xf(inst), false)
	Sfx.play("pose", _ret_tip(), -4.0)


func _ret_done(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("ecarteur_sternal")
	if not inst.parked:
		if hand and hand.held == inst:
			hand.release_parked()
		park(inst, _ret_xf(inst), instant)
	_ret_progress(1.0)


func _ret_progress(p: float) -> void:
	spread = p
	patient.opening = lerpf(0.08, 1.0, p)
	patient.set_aperture(sternum, sternum_h, 0.0, 1.0, CUT_W, SPREAD * p, 0.045, FALL, DEEP)
	_set_retractor(p)
	if p > 0.0:
		patient.set_cavity_blood(0.35)


func _set_retractor(p: float) -> void:
	var fin := instrument("ecarteur_sternal")
	if fin.model is FinochiettoModel:
		var tilt := absf(_ret_xf(fin).basis.x.normalized().dot(Vector3.UP))
		var half := (CUT_W + SPREAD * p) / sqrt(maxf(1.0 - tilt * tilt, 0.5))
		(fin.model as FinochiettoModel).set_spread(maxf(0.012, half * 2.0 + 0.004))


# ---------------------------------------------------------------- Artère mammaire

## L'artère mammaire telle qu'elle se trouve, la paroi écartée et le bord gauche soulevé.
func _lima_path() -> PackedVector3Array:
	var out := PackedVector3Array()
	if lima_rest.is_empty():
		return PackedVector3Array([Procedure.path_point(sternum, 0.2) + Vector3(0, -0.03, 0.06), Procedure.path_point(sternum, 0.8) + Vector3(0, -0.03, 0.05)])
	var n := 7
	for i in n:
		var f := float(i) / (n - 1) * (lima_rest.size() - 1)
		var k := mini(int(f), lima_rest.size() - 2)
		var p := lima_rest[k].lerp(lima_rest[k + 1], f - k)
		out.append(patient.breach_displace(p) + Vector3.UP * 0.002)
	return out


func _lima_enter() -> void:
	# L'aide soulève le bord gauche du sternum (la valve gauche de l'écarteur se relève)
	var tw := root.create_tween()
	tw.tween_method(_lift_left, 0.0, LIMA_LIFT, 1.2).set_trans(Tween.TRANS_SINE)


func _lift_left(v: float) -> void:
	patient.set_edge_lift(Vector2(v, 0.0))
	var fin := instrument("ecarteur_sternal")
	if fin and fin.model is FinochiettoModel:
		var fm := fin.model as FinochiettoModel
		fm.set_lift(asin(clampf(v / fm.arm_len, 0.0, 0.9)))


func _lima_progress(_t0: float, _t1: float) -> void:
	for h in proc.hands:
		if h.held and h.held.id == "bistouri_electrique" and h.squeeze_value() > 0.5 and Engine.get_process_frames() % 3 == 0:
			_smoke(h.tip())


func _lima_done(_h: SurgeonHand, instant: bool) -> void:
	lima_harvested = true
	patient.set_lima_hidden(true)
	_build_graft()
	if instant:
		_lift_left(0.0)
	else:
		var tw := root.create_tween()
		tw.tween_interval(0.6)
		tw.tween_method(_lift_left, LIMA_LIFT, 0.0, 1.0).set_trans(Tween.TRANS_SINE)


## Fumée blanche du bistouri électrique.
func _smoke(p: Vector3) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.004
	sm.height = 0.008
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.92, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	m.global_position = p
	var tw := m.create_tween()
	tw.set_parallel()
	tw.tween_property(m, "global_position", p + Vector3(randf_range(-0.01, 0.01), 0.05, randf_range(-0.01, 0.01)), 1.2)
	tw.tween_property(m, "scale", Vector3.ONE * 3.5, 1.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tw.chain().tween_callback(m.queue_free)


## Greffon : l'artère mammaire (rouge) dans sa graisse, avec un clip au bout.
func _build_graft() -> void:
	# Artère rouge vif dans une fine gaine rosée (fascia, petites veines) : bien visible sur la
	# graisse jaune du cœur
	var art := MeshUtil.mat(Color(0.72, 0.07, 0.06), 0.25)
	art.clearcoat_enabled = true
	art.clearcoat = 0.7
	var fat := StandardMaterial3D.new()
	fat.albedo_color = Color(0.9, 0.52, 0.42, 0.5)
	if OS.get_cmdline_user_args().has("--debugparts"):
		fat.albedo_color = Color(0.0, 1.0, 0.2, 0.9)
	fat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fat.roughness = 0.35
	fat.clearcoat_enabled = true
	fat.clearcoat = 0.5
	_graft = MeshInstance3D.new()
	_graft.name = "Greffon"
	_graft.material_override = art
	root.add_child(_graft)
	_graft_fat = MeshInstance3D.new()
	_graft_fat.name = "GreffonGraisse"
	_graft_fat.material_override = fat
	root.add_child(_graft_fat)
	_graft_clip = MeshInstance3D.new()
	_graft_clip.name = "Clip"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.007, 0.0015, 0.0025)
	_graft_clip.mesh = bm
	_graft_clip.material_override = MeshUtil.mat(Color(0.75, 0.62, 0.3), 0.25, 1.0)
	root.add_child(_graft_clip)
	_update_graft()


## Tracé du greffon : de son origine (sous la clavicule) le long de la paroi, puis (graft_on) jusqu'à
## l'IVA, en passant par l'ouverture du péricarde.
func _update_graft() -> void:
	if _graft == null:
		return
	var path := _lima_path()
	var top := path[0]
	var hf := _heart_follow.transform if _heart_follow else Transform3D.IDENTITY
	var end := hf * lad_c
	if _graft_route.is_empty():
		# Trajet du greffon cousu : il sort de sous le bord gauche du sternum, entre dans le
		# péricarde au-dessus de l'artère pulmonaire, puis se couche sur la face avant du cœur
		_graft_route = PackedVector3Array([_tissue_top(0.062, 0.03, 5.0), _tissue_top(0.03, 0.042, 4.0), _tissue_top(0.004, 0.052, 3.5)])
	var ctrl := PackedVector3Array([top, _graft_route[0], hf * _graft_route[1], hf * _graft_route[2], end])
	var curve := Cable.smooth(ctrl, 5)
	var n := curve.size()
	var pts := PackedVector3Array()
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(Procedure.path_point(path, t).lerp(curve[i], graft_on))
	var rr := PackedFloat32Array()
	var rf := PackedFloat32Array()
	for i in n:
		var t := float(i) / (n - 1)
		rr.append(lerpf(0.0024, 0.0018, t))
		rf.append(lerpf(0.0038, 0.0024, t))
	_graft.mesh = MeshUtil.tube(pts, rr, 10)
	_graft_fat.mesh = MeshUtil.tube(pts, rf, 10)
	if OS.get_cmdline_user_args().has("--debug") and graft_on > 0.99 and not has_meta("graft_dbg"):
		set_meta("graft_dbg", true)
		print("DEBUG greffon ", pts[0], " → ", pts[n >> 1], " → ", pts[n - 1], " route=", _graft_route, " visible=", _graft.is_visible_in_tree())
	var e := pts[n - 1]
	var d := (pts[n - 1] - pts[n - 2]).normalized()
	_graft_clip.visible = graft_on < 0.5
	_graft_clip.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), e + d * 0.002)


# ---------------------------------------------------------------- Péricarde

func _peri_progress(t0: float, t1: float) -> void:
	patient.set_pericardium(0.0, pc_a.lerp(pc_b, t0), pc_a.lerp(pc_b, t1), 0.004 + 0.012 * (t1 - t0))


func _peri_done(_h: SurgeonHand, _instant: bool) -> void:
	# Bords suspendus : grande fenêtre sur le cœur et l'aorte
	patient.set_pericardium(0.0, pc_a.lerp(pc_b, -0.1), pc_a.lerp(pc_b, 1.08), PERI_W)
	_stay_sutures()


## Fils de suspension : quatre points sur les bords du péricarde ouvert, tirés et noués sur le bord
## de la peau (le cœur est présenté dans un berceau).
func _stay_sutures() -> void:
	for st in _stays:
		st.queue_free()
	_stays.clear()
	var a := pc_a.lerp(pc_b, -0.1)
	var b := pc_a.lerp(pc_b, 1.08)
	var mi: MeshInstance3D = patient._part_meshes.get("Pericarde")
	var verts := PackedVector3Array()
	if mi and mi.mesh:
		var xf := mi.global_transform
		for k in mi.mesh.get_surface_count():
			for v in mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
				verts.append(xf * v)
	var mat := MeshUtil.mat(Color(0.86, 0.86, 0.82), 0.6)
	for q in [[0.3, 1.0], [0.72, 1.0], [0.3, -1.0], [0.72, -1.0]]:
		var p0 := _peri_edge(verts, a, b, q[0], q[1])
		var uv := patient.uv_of(p0)
		var p3 := patient.edge_point(uv.x, signf(uv.y), 0.012) + Vector3.UP * 0.003
		var up := Vector3.UP
		# Le fil monte du péricarde, passe par-dessus le bord du sternum et descend sur la peau
		var pts := MeshUtil.bezier(p0, p0 + up * 0.05, p3 + up * 0.022 + (p0 - p3) * 0.1, p3, 16)
		var th := MeshInstance3D.new()
		th.name = "FilSuspension"
		th.mesh = MeshUtil.tube(pts, ProcInstruments._radii(pts.size(), 0.00045), 5)
		th.material_override = mat
		root.add_child(th)
		_stays.append(th)
		MeshUtil.cylinder_instance(th, 0.0018, 0.0016, p3 + Vector3.UP * 0.0008, mat, "Noeud")


## Point du bord du péricarde ouvert (à PERI_W du tracé), à t le long du tracé, du côté `side`.
func _peri_edge(verts: PackedVector3Array, a: Vector3, b: Vector3, t: float, side: float) -> Vector3:
	var ab := b - a
	var along := ab.normalized()
	var c := pc_a.lerp(pc_b, t)
	var across := along.cross(Vector3.UP).normalized() * side
	var best := c + across * PERI_W - Vector3.UP * 0.006
	var best_y := -INF
	for v in verts:
		var k := clampf((v - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := v.distance_to(a + ab * k)
		if absf(d - PERI_W) > 0.003 or (v - c).dot(across) < 0.0 or absf((v - c).dot(along)) > 0.006:
			continue
		if v.y > best_y:
			best_y = v.y
			best = v
	return best


# ---------------------------------------------------------------- CEC

func _aorta_axis() -> Vector3:
	return Vector3(0.35, -0.93, 0.1).normalized()


func _ao_done(hand: SurgeonHand, instant: bool) -> void:
	_park_cannula("canule_aortique", hand, instant)


func _vei_done(hand: SurgeonHand, instant: bool) -> void:
	_park_cannula("canule_veineuse", hand, instant)
	_start_bypass(instant)


## La canule reste en place (tenue par un garrot) ; sa ligne part vers la machine.
func _park_cannula(inst_id: String, hand: SurgeonHand, _instant: bool) -> void:
	# Le bout de la canule reste dans le vaisseau, dans l'axe de son trajet (pose toujours
	# identique : la tubulure qui en part est calculée une seule fois, cache des câbles). La partie
	# souple sort du thorax, se couche sur les champs et pend jusqu'à la machine : c'est la ligne.
	var inst := instrument(inst_id)
	var s := _insert_step(inst_id)
	var tgt: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var xf := inst.tip_transform(tgt + axis * float(s["depth"]), axis, Vector3(0, 0, -1))
	if hand and hand.held == inst:
		hand.release_parked()
	park(inst, xf, true)
	_show_cannula_body(inst, false)
	_add_line(inst_id, inst_id == "canule_aortique")


func _insert_step(inst_id: String) -> Dictionary:
	for st in steps:
		if st.get("inst", "") == inst_id and st["kind"] == "insert":
			return st
	return {}


## Corps rigide de la canule (long tube transparent) : caché tant que la ligne souple le remplace.
func _show_cannula_body(inst: Instrument, on: bool) -> void:
	for n in ["Tube", "Raccord", "Spirale", "Repere"]:
		var c := inst.model.find_child(n, false, false)
		if c:
			(c as Node3D).visible = on


## Point où l'on saisit la canule pour la retirer (à sa sortie du vaisseau).
func _cannula_grip(inst_id: String) -> Vector3:
	var s := _insert_step(inst_id)
	return (s["target"].call() as Vector3) - (s["axis"] as Vector3) * 0.01


func _add_line(inst_id: String, arterial: bool) -> void:
	var s := _insert_step(inst_id)
	var tgt: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var port := _cec.art_port_global() if arterial else _cec.ven_port_global()
	# Du vaisseau, la tubulure remonte hors du thorax, file sur le drap du côté gauche, passe le
	# bord de la table et pend jusqu'à la machine
	var inside := tgt + axis * float(s["depth"]) * 0.6
	var exit := tgt - axis * 0.012
	var out := exit - axis * 0.03 + Vector3.UP * 0.012
	# Elles partent vers le haut du champ (la face avant du cœur reste libre pour le pontage), puis
	# passent sur l'épaule gauche
	var cran := Cable.on_surface(0.11, 0.03 if arterial else 0.012, 0.01)
	var side := Cable.on_surface(0.1, 0.2, 0.01)
	var edge := Vector3(0.09, Patient.TABLE_TOP + 0.12, Patient.TABLE_MAX.y + 0.04)
	var path := PackedVector3Array([inside, exit, out, cran, side, edge, port])
	var pts := Cable.smooth(Cable.lay(path, 0.08, 0.006, 0.025, 2, 1, []))
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.0055 if arterial else 0.0075)
	var line := MeshInstance3D.new()
	line.name = "LigneArterielle" if arterial else "LigneVeineuse"
	line.mesh = MeshUtil.tube(pts, rr, 12)
	# PVC transparent plein de sang : rouge vif (artériel) ou sombre (veineux), brillant
	var m := MeshUtil.mat(Color(0.68, 0.05, 0.05) if arterial else Color(0.3, 0.02, 0.04), 0.1)
	m.clearcoat_enabled = true
	m.clearcoat = 0.8
	m.clearcoat_roughness = 0.05
	line.material_override = m
	root.add_child(line)
	_lines.append(line)
	Cable.save_cache()  # lignes livrées avec le jeu (calculées une fois, hors export)


func _start_bypass(_instant: bool) -> void:
	on_bypass = true
	_cec.flow = 4.8
	_cec.temp = 32.0
	monitor.bypass = true
	monitor.map_bypass = 64
	patient.beat_gain = 0.55  # le cœur, vidé, bat à vide
	patient.breathe_amp = 0.0  # on arrête de ventiler
	Sfx.play("ecarte", _cec.global_position + Vector3.UP, -12.0, 0.6)


func _clamp_xf(inst: Instrument) -> Transform3D:
	# En travers de l'aorte, venant de la droite du patient (côté du chirurgien)
	var z := Vector3(0.0, -0.3, 1.0).normalized()
	var x := Vector3(1, 0, 0)
	var y := z.cross(x).normalized()
	x = y.cross(z).normalized()
	var tip := aorta_clamp + z * (aorta_r + 0.012)
	return Transform3D(Basis(x, y, z), tip) * Transform3D(Basis.IDENTITY, -inst.tip_local)


func _clamp_seat(hand: SurgeonHand) -> void:
	var inst := instrument("clamp_aortique")
	if inst.parked:
		return
	hand.release_parked()
	park(inst, _clamp_xf(inst), false)
	inst.set_squeeze(1.0)
	Sfx.play("clic", aorta_clamp, -4.0)


func _clamp_done(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("clamp_aortique")
	if not inst.parked:
		if hand and hand.held == inst:
			hand.release_parked()
		park(inst, _clamp_xf(inst), instant)
		inst.set_squeeze(1.0)
	# Cardioplégie : le cœur ralentit et s'arrête, se refroidit
	if instant:
		_arrest_heart(1.0)
	else:
		var tw := root.create_tween()
		tw.tween_method(_arrest_heart, 0.0, 1.0, 6.0)


func _arrest_heart(v: float) -> void:
	cold = v
	patient.beat_gain = lerpf(0.55, 0.0, smoothstep(0.0, 0.8, v))
	patient.heart_rate = lerpf(72.0, 30.0, v)
	patient.set_heart_cold(v)
	monitor.target_rate = lerpf(72.0, 20.0, v)
	monitor.asystole = v > 0.8
	_cec.temp = lerpf(32.0, 28.0, v)


# ---------------------------------------------------------------- IVA, anastomose

func _lad_path() -> PackedVector3Array:
	var c := _heart_follow.transform * lad_c if _heart_follow else lad_c
	return PackedVector3Array([c - lad_dir * 0.003, c + lad_dir * 0.003])


func _lad_progress(t0: float, t1: float) -> void:
	patient.set_heart_wound(lad_c, lad_dir, 0.003 * maxf(t1 - t0, 0.2), 0.0)


func _lad_done(_h: SurgeonHand, _instant: bool) -> void:
	patient.set_heart_wound(lad_c, lad_dir, 0.003, 0.0)


func _graft_bring() -> void:
	# L'aide amène le bout du greffon sur l'IVA
	var tw := root.create_tween()
	tw.tween_method(func(v: float) -> void:
		graft_on = v
		_update_graft(), 0.0, 1.0, 1.5).set_trans(Tween.TRANS_SINE)


func _anast_pairs() -> Array:
	var across := lad_n.cross(lad_dir).normalized()
	var out := []
	var pos := [[-1.0, -1.0], [-1.0, 1.0], [0.0, 1.0], [1.0, 1.0], [1.0, -1.0], [0.0, -1.0]]
	for q in pos:
		var c: Vector3 = lad_c + lad_dir * 0.0032 * float(q[0])
		var side: float = q[1]
		out.append([c + across * 0.0042 * side + lad_n * 0.0015, c + across * 0.0012 * side])
	return out


func _anast_point(i: int, instant: bool) -> void:
	var pair: Array = _anast_pairs()[i]
	var a: Vector3 = pair[0]
	var b: Vector3 = pair[1]
	var st := MeshInstance3D.new()
	st.name = "PointAnastomose"
	var mid := (a + b) * 0.5 + lad_n * 0.0012
	st.mesh = MeshUtil.tube(MeshUtil.bezier(a, a.lerp(mid, 0.5) + lad_n * 0.0006, mid, b, 6), PackedFloat32Array([0.0002, 0.0002, 0.0002, 0.0002, 0.0002, 0.0002]), 5)
	st.material_override = _thread_mat
	_heart_follow.add_child(st)
	patient.set_heart_wound(lad_c, lad_dir, 0.003, 0.17 * (i + 1))
	if not instant:
		Sfx.play("fil", a, -8.0)


func _anast_done(instant: bool) -> void:
	graft_on = 1.0
	_update_graft()
	patient.set_heart_wound(lad_c, lad_dir, 0.003, 1.0)
	if not instant:
		for h in proc.hands:
			if h.held and h.held.id == "porte_aiguille":
				h.put_back()


# ---------------------------------------------------------------- Déclampage, choc, sevrage

func _unclamp_done(_hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("clamp_aortique")
	proc.parked.erase(inst)
	if instant:
		inst.parked = false
		inst.global_transform = inst.tray_transform
	else:
		inst.return_to_tray()
	# Reperfusion : le cœur se réchauffe, puis fibrille
	if instant:
		_reperfuse(1.0)
		_start_vf()
	else:
		var tw := root.create_tween()
		tw.tween_method(_reperfuse, 0.0, 1.0, 4.0)
		_vf_at = _t + 2.5


func _reperfuse(v: float) -> void:
	cold = 1.0 - v
	patient.set_heart_cold(1.0 - v)
	_cec.temp = lerpf(28.0, 36.5, v)


func _start_vf() -> void:
	_vf_at = -1.0
	patient.beat_gain = 0.0
	patient.set_fibrillation(1.0)
	monitor.asystole = false
	monitor.vf = true


func _shock_done(_h: SurgeonHand, instant: bool) -> void:
	_vf_at = -1.0
	patient.set_fibrillation(0.0)
	patient.heart_rate = 88.0
	patient.beat_gain = 0.8
	monitor.vf = false
	monitor.asystole = false
	monitor.heart_rate = 88.0
	monitor.target_rate = 88.0
	if not instant:
		Sfx.play("plop", Patient.HEART_C, 0.0, 0.6)
		Sfx.play("bip_alarme", monitor.global_position, -4.0, 0.7)
		_flash()
		for h in proc.hands:
			if h.held and h.held.id == "palettes":
				h.put_back()


## Éclair du choc électrique.
func _flash() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.85, 1.0)
	l.light_energy = 6.0
	l.omni_range = 0.6
	root.add_child(l)
	l.global_position = Patient.HEART_C + Vector3.UP * 0.12
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _wean() -> void:
	# Sevrage : la machine ralentit, le cœur reprend le travail
	var tw := root.create_tween()
	tw.tween_method(func(v: float) -> void:
		_cec.flow = lerpf(4.8, 1.2, v)
		patient.beat_gain = lerpf(0.8, 1.0, v), 0.0, 1.0, 3.0)


func _decan_done(_h: SurgeonHand, instant: bool) -> void:
	for inst_id in ["canule_aortique", "canule_veineuse"]:
		var inst := instrument(inst_id)
		_show_cannula_body(inst, true)
		proc.parked.erase(inst)
		if instant:
			inst.parked = false
			inst.global_transform = inst.tray_transform
		else:
			inst.return_to_tray()
	for l in _lines:
		l.queue_free()
	_lines.clear()
	on_bypass = false
	_cec.flow = 0.0
	_cec.temp = 36.6
	monitor.bypass = false
	monitor.sys = 112
	monitor.dia = 66
	monitor.target_spo2 = 99.0
	patient.beat_gain = 1.0
	patient.breathe_amp = 0.003


# ---------------------------------------------------------------- Fermeture

func _close_enter() -> void:
	# L'écarteur est retiré, l'aide rapproche les deux moitiés du sternum ; la peau revient sur le
	# sternum (on voit ses deux moitiés et la fente entre elles)
	_remove_retractor(false)
	var from := spread
	var tw := root.create_tween()
	tw.tween_method(func(v: float) -> void:
		patient.set_aperture(sternum, sternum_h, 0.0, 1.0, CUT_W, SPREAD * lerpf(from, CLOSE_SPREAD, v), 0.045, FALL, DEEP)
		patient.opening = lerpf(1.0, CLOSE_OPEN, v), 0.0, 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	spread = CLOSE_SPREAD


## Écarteur rendu à la table (bras refermés) ; les fils de suspension du péricarde sont coupés.
func _remove_retractor(instant: bool) -> void:
	for st in _stays:
		st.queue_free()
	_stays.clear()
	var ret := instrument("ecarteur_sternal")
	if ret.parked:
		proc.parked.erase(ret)
		if instant:
			ret.parked = false
			ret.global_transform = ret.tray_transform
		else:
			ret.return_to_tray()
	if ret.model is FinochiettoModel:
		var fm := ret.model as FinochiettoModel
		fm.set_lift(0.0)
		if instant:
			fm.set_spread(0.012)
		else:
			var tw0 := root.create_tween()
			tw0.tween_method(fm.set_spread, fm.spread, 0.012, 0.8)


func _wire_pairs() -> Array:
	var out := []
	for x in [0.074, 0.046, 0.018, -0.01, -0.038]:
		var top := Patient.body_height(x, 0.0)
		var y := top - 0.014
		var half := CUT_W + SPREAD * spread * _h_at(x) + 0.011
		out.append([Vector3(x, y, -half), Vector3(x, y, half)])
	return out


func _h_at(x: float) -> float:
	var t := clampf((STERNUM[0].x - x) / (STERNUM[0].x - STERNUM[STERNUM.size() - 1].x), 0.0, 1.0)
	var f := t * (STERNUM_H.size() - 1)
	var i := mini(int(f), STERNUM_H.size() - 2)
	return lerpf(STERNUM_H[i], STERNUM_H[i + 1], f - i)


func _wire_point(i: int, _instant: bool) -> void:
	var pair: Array = _wire_pairs()[i]
	var w := Node3D.new()
	w.name = "FilAcier"
	w.set_meta("x", (pair[0] as Vector3).x)
	root.add_child(w)
	_wires.append(w)
	_rebuild_wire(w)


## Un fil d'acier : boucle autour des deux berges, torsadé au milieu.
func _rebuild_wire(w: Node3D) -> void:
	for c in w.get_children():
		c.queue_free()
	var x: float = w.get_meta("x")
	var top := Patient.body_height(x, 0.0)
	var bone := top - WOUND_DEPTH  # face avant du sternum, sous la peau et la graisse
	var half := CUT_W + SPREAD * spread * _h_at(x) + 0.011
	# Le fil passe derrière chaque moitié du sternum, remonte sur son bord externe et revient sur
	# sa face avant jusqu'à la torsade, au milieu
	var pts := PackedVector3Array()
	for sd in [-1.0, 1.0]:
		var side := PackedVector3Array([Vector3(x, bone - 0.018, sd * half), Vector3(x, bone - 0.009, sd * (half + 0.0028)),
			Vector3(x, bone - 0.0008, sd * (half - 0.0012)), Vector3(x, bone + 0.0006, sd * half * 0.55), Vector3(x, bone + 0.0008, sd * 0.0022)])
		if sd < 0.0:
			pts.append_array(side)
		else:
			side.reverse()
			pts.append_array(side)
	var loop := MeshInstance3D.new()
	var sm := Cable.smooth(pts)
	loop.mesh = MeshUtil.tube(sm, _radii(sm.size(), 0.0006), 6)
	loop.material_override = _wire_mat
	w.add_child(loop)
	# Torsade (5 mm), puis les bouts coupés couchés vers les pieds
	var twist := MeshInstance3D.new()
	var tp := PackedVector3Array()
	for k in 10:
		var a := k * 1.4
		tp.append(Vector3(x + 0.0008 * cos(a), bone + 0.001 + k * 0.00045, 0.0008 * sin(a)))
	for j in range(1, 4):
		tp.append(Vector3(x - 0.0016 * j, bone + 0.0052 - 0.0006 * j, 0.0))
	twist.mesh = MeshUtil.tube(tp, _radii(tp.size(), 0.0007), 6)
	twist.material_override = _wire_mat
	w.add_child(twist)


static func _radii(n: int, r: float) -> PackedFloat32Array:
	var rr := PackedFloat32Array()
	rr.resize(n)
	rr.fill(r)
	return rr


func _close_done(instant: bool) -> void:
	# Les fils serrés rapprochent les berges : sternum fermé ; la peau est refermée aux agrafes
	if instant:
		_remove_retractor(true)
		_close_to(0.0)
		_staples()
	else:
		var tw := root.create_tween()
		tw.tween_method(_close_to, spread, 0.0, 1.5).set_trans(Tween.TRANS_SINE)
		tw.tween_callback(_staples)
		for h in proc.hands:
			if h.held and h.held.id == "porte_aiguille":
				h.put_back()


## Agrafes cutanées en travers de l'incision refermée.
func _staples() -> void:
	var n := 12
	for i in n:
		var p := Procedure.path_point(sternum, (i + 0.5) / n)
		var y := Patient.body_height(p.x, p.z) + 0.0012
		var nrm := Patient.skin_normal(p.x, p.z)
		var pts := PackedVector3Array([Vector3(p.x, y - 0.0018, -0.0032), Vector3(p.x, y - 0.0002, -0.0033), Vector3(p.x, y + 0.0003, -0.0022),
			Vector3(p.x, y + 0.0004, 0.0), Vector3(p.x, y + 0.0003, 0.0022), Vector3(p.x, y - 0.0002, 0.0033), Vector3(p.x, y - 0.0018, 0.0032)])
		var st := MeshInstance3D.new()
		st.name = "Agrafe"
		var sm := Cable.smooth(pts)
		st.mesh = MeshUtil.tube(sm, _radii(sm.size(), 0.00032), 5)
		st.material_override = _wire_mat
		root.add_child(st)
		# Couchée sur la peau (la peau monte vers l'abdomen) : tournée autour de son milieu
		var b := Basis(Quaternion(Vector3.UP, nrm))
		var c := Vector3(p.x, y, 0.0)
		st.global_transform = Transform3D(b, c - b * c)
		st.set_meta("base", st.global_transform)
		_staple_nodes.append(st)


func _close_to(v: float) -> void:
	spread = v
	patient.set_aperture(sternum, sternum_h, 0.0, 1.0, CUT_W * minf(v * 8.0, 1.0), SPREAD * v, 0.045, FALL, DEEP)
	patient.opening = lerpf(0.0, CLOSE_OPEN, v / CLOSE_SPREAD)
	for w in _wires:
		_rebuild_wire(w)


# ---------------------------------------------------------------- Animation

func process(delta: float) -> void:
	_t += delta
	if _heart_follow:
		var sq := patient.heart_squeeze
		var hb := Basis.from_scale(Vector3(1.0 + 0.08 * sq, 1.0 - 0.32 * sq, 1.0 + 0.1 * sq) * (1.0 + patient.beat_now))
		_heart_follow.transform = Transform3D(hb, Patient.HEART_C - hb * Patient.HEART_C)
	if _vf_at > 0.0 and _t >= _vf_at:
		_start_vf()
	# Les agrafes montent et descendent avec la peau (respiration)
	for st in _staple_nodes:
		var base: Transform3D = st.get_meta("base")
		var c := base * Vector3.ZERO
		st.global_transform = base.translated(Vector3.UP * patient.breath_offset(c.x, c.z))
	# Le bout du greffon suit les battements une fois cousu
	if _graft and graft_on > 0.99 and patient.beat_gain > 0.0:
		_graft_t += delta
		if _graft_t > 0.05:
			_graft_t = 0.0
			_update_graft()
