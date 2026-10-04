class_name OpAppendix
extends Operation
## Appendicectomie par voie de McBurney.

const STITCH_T := [0.15, 0.38, 0.62, 0.85]

var piece: Node3D


func _init() -> void:
	id = "appendicectomie"
	name = "Appendicectomie"
	tagline = "Appendicite aiguë : incision de McBurney, ligature et ablation de l'appendice."
	intro_text = "Lucas, 24 ans : appendicite aiguë confirmée au scanner. Il est endormi et installé. Tu vas faire l'appendicectomie, étape par étape. Tout se fait avec de vrais gestes : la lame coupe quand elle touche la peau, la pince serre quand tu serres les doigts."
	with_dish = true
	summary = "Appendice retiré, ligature en place, peau suturée."
	header = "BLOC 2  ·  APPENDICECTOMIE  ·  VOIE DE McBURNEY"
	scan_text = "SCANNER ABDOMINAL\nAppendice épaissi (11 mm)\ninfiltration de la graisse"
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 90.0, 0.0],
		["langenbeck", "Écarteur de Langenbeck", "ecarteur_langenbeck", 0.0, 0.0],
		["roux", "Écarteur de Roux", "ecarteur_roux", 0.0, 0.0],
		["debakey", "Pince De Bakey", "pince_debakey", 90.0, 0.0],
		["overholt", "Overholt + fil de ligature", "clamp_overholt", 0.0, 0.0],
		["ciseaux", "Ciseaux de Metzenbaum", "ciseaux_metzenbaum", 0.0, 0.19],
		["porte_aiguille", "Porte-aiguille + fil", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	p.op = "appendicectomie"


func define_steps() -> void:
	steps = [
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte la peau",
			"text": "Prends la pince à badigeon et frotte la compresse sur toute la zone de peau, comme avec une éponge, jusqu'à ce qu'elle soit toute brune.",
			"label": "Zone à désinfecter", "ring": 3.5, "done_msg": "Peau désinfectée !"},
		{"id": "incision", "kind": "incise", "list": "Incision", "inst": "bistouri",
			"title": "Incise la peau",
			"text": "Pose la lame sur « DÉPART » et appuie un peu : elle entre dans la peau. Glisse-la le long du pointillé jusqu'à « ARRIVÉE », d'un geste continu.",
			"done": _incision_done, "done_msg": "Belle incision !"},
		{"id": "ecarteur1", "kind": "retract", "list": "Écarteur 1", "inst": "langenbeck",
			"title": "Écarte un bord",
			"text": "Glisse le bout recourbé de l'écarteur de Langenbeck dans la plaie, contre un bord, puis tire ce bord vers l'extérieur. Si tu lâches, il se referme. Tiens-le bien ouvert : l'aide prendra l'écarteur.",
			"label": "Accroche le bord", "done": _retractor_done, "done_msg": "L'aide tient l'écarteur"},
		{"id": "ecarteur2", "kind": "retract", "list": "Écarteur 2", "inst": "roux",
			"title": "Écarte l'autre bord",
			"text": "Même geste avec l'écarteur de Roux sur l'autre bord. La plaie s'ouvre : on voit le cæcum et l'appendice rouge et gonflé.",
			"label": "Accroche ce bord", "done": _retractor_done, "done_msg": "La plaie est ouverte"},
		{"id": "saisie", "kind": "lift", "list": "Sortir l'appendice", "inst": "debakey",
			"title": "Sors l'appendice",
			"text": "Mets les mors de la pince De Bakey autour de la pointe de l'appendice et serre les doigts pour la saisir. Garde serré et soulève-la hors de la plaie.",
			"label": "Pointe de l'appendice", "radius": 0.018,
			"target": func() -> Vector3: return patient.appendix_tip,
			"move": patient.set_appendix_tip, "goal": _lift_goal,
			"rest": func() -> Vector3: return patient.appendix_rest_tip,
			"done": _lift_done, "done_msg": "Appendice extériorisé — l'aide le maintient"},
		{"id": "ligature", "kind": "ligate", "list": "Ligature", "inst": "overholt",
			"title": "Ligature la base",
			"text": "Amène les mors de l'Overholt contre la base de l'appendice et serre : le fil passe autour. Garde serré et tire doucement vers toi pour serrer le nœud.",
			"label": "Base de l'appendice", "radius": 0.016,
			"target": func() -> Vector3: return patient.appendix_point(0.18),
			"done": func(_hand: SurgeonHand, _instant: bool) -> void: patient.ligate(),
			"done_msg": "Nœud serré"},
		{"id": "section", "kind": "cut", "list": "Section", "inst": "ciseaux",
			"title": "Coupe l'appendice",
			"text": "Ouvre les ciseaux (écarte le pouce), place les lames de part et d'autre de l'appendice, juste au-dessus du nœud, puis referme-les d'un coup.",
			"label": "Couper ici", "radius": 0.01,
			"target": func() -> Vector3: return patient.appendix_point(0.32),
			"done": _cut_done, "done_msg": "Appendice sectionné"},
		{"id": "retrait", "kind": "carry", "list": "Retrait", "inst": "debakey",
			"title": "Dépose l'appendice",
			"text": "Saisis l'appendice coupé avec la pince (serre), emmène-le au-dessus du haricot sur le guéridon à ta gauche, et desserre : il tombe dedans.",
			"label": "Attrape l'appendice", "dest_label": "Lâche ici",
			"object": func() -> Node3D: return piece,
			"dest": func() -> Vector3: return tray.dish_center,
			"done": _carry_done, "done_msg": "Appendice dans le haricot"},
		{"id": "suture", "kind": "suture", "list": "Suture", "inst": "porte_aiguille",
			"title": "Referme la peau",
			"text": "Les écarteurs sont retirés, la plaie se détend. Pour chaque point : pique l'aiguille à l'entrée (repère), fais-la ressortir sur l'autre bord. Le nœud se fait tout seul. 4 points.",
			"label": "Point", "radius": 0.008,
			"pairs": _stitch_pairs, "point": _stitch, "done": _closed,
			"done_msg": "Peau refermée !"},
	]


# ---------------------------------------------------------------- Effets des étapes

func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	if instant:
		patient.opening = 0.25
	else:
		tween_opening(0.25)


## Pose de l'écarteur tenu par l'aide (sauts d'étape) : crochet dans la plaie, manche vers l'extérieur.
func _retractor_pose(inst: Instrument, side: float) -> Transform3D:
	var edge := patient.edge_point(0.0, side)
	var tip := edge - Vector3.UP * 0.008
	var axis := (-patient.perp3 * side * 0.6 + Vector3.DOWN).normalized()
	return inst.tip_transform(tip, axis, patient.perp3 * side)


func _retractor_done(hand: SurgeonHand, instant: bool, side: float) -> void:
	var inst := instrument(proc.current()["inst"]) if proc.current().size() > 0 else null
	if instant:
		# Saut d'étape : l'écarteur est posé, le bord tenu
		var id2: String = "langenbeck" if patient.held_l < 0.0 and patient.held_r < 0.0 else "roux"
		inst = instrument(id2)
		if side < 0.0:
			patient.held_l = 1.0
			patient.open_l = 1.0
		else:
			patient.held_r = 1.0
			patient.open_r = 1.0
		park(inst, _retractor_pose(inst, side), true)
	elif hand:
		hand.release_parked()


func _lift_goal() -> float:
	var goal := patient.center.y + 0.012
	var rest := patient.appendix_rest_tip.y
	return clampf((patient.appendix_tip.y - rest) / (goal - rest), 0.0, 1.0)


func _lifted_tip() -> Vector3:
	return patient.center + Vector3.UP * 0.035 - patient.dir3 * 0.012 + patient.perp3 * 0.004


func _lift_done(instant: bool) -> void:
	if instant:
		patient.set_appendix_tip(_lifted_tip())
		return
	# L'aide le maintient là où on l'a sorti (un peu recentré)
	var from := patient.appendix_tip
	var tw := proc.create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(k: float) -> void: patient.set_appendix_tip(from.lerp(_lifted_tip(), k * 0.6)), 0.0, 1.0, 0.6)


func _cut_done(_hand: SurgeonHand, _instant: bool) -> void:
	piece = patient.cut()


func _carry_done(instant: bool) -> void:
	if instant and piece:
		piece.global_position = tray.dish_center + Vector3.UP * 0.008
	unpark_all(instant)
	if instant:
		patient.opening = 0.3
	else:
		tween_opening(0.3)


func _stitch_pairs() -> Array:
	var out := []
	for t in STITCH_T:
		out.append(patient.stitch_pair(t))
	return out


func _stitch(i: int, instant: bool) -> void:
	patient.add_stitch(STITCH_T[i])
	var left := 0.3 * (1.0 - float(i + 1) / STITCH_T.size())
	if instant:
		patient.opening = left
	else:
		tween_opening(left)


func _closed(_instant: bool) -> void:
	patient.set_stitched(1.0)
