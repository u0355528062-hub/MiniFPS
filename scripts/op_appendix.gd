class_name OpAppendix
extends Operation
## Appendicectomie par voie de McBurney.

const STITCH_T := [0.15, 0.38, 0.62, 0.85]

var piece: Node3D
var _anim: Tween


func _init() -> void:
	id = "appendicectomie"
	name = "Appendicectomie"
	tagline = "Appendicite aiguë : incision de McBurney, ligature et ablation de l'appendice."
	intro_text = "Lucas, 24 ans : appendicite aiguë confirmée au scanner. Il est endormi et installé. Tu vas faire l'appendicectomie, étape par étape. Suis les consignes et les repères lumineux."
	with_dish = true
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["bistouri", "Bistouri lame 15", "manche_bistouri", 0.0, 0.0],
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
			"text": "Prends la pince à badigeon et frotte toute la zone de peau en gardant la gâchette appuyée, jusqu'à 100 %.",
			"label": "Zone à désinfecter", "ring": 3.5, "done_msg": "Peau désinfectée !"},
		{"id": "incision", "kind": "trace", "list": "Incision", "inst": "bistouri",
			"title": "Incise la peau",
			"text": "Pose la lame sur le point « DÉPART » et suis le pointillé violet, gâchette appuyée, d'un seul geste.",
			"done": _incision_done, "done_msg": "Belle incision !"},
		{"id": "ecarteur1", "kind": "place", "list": "Écarteur 1", "inst": "langenbeck",
			"title": "Écarte le premier bord",
			"text": "Amène l'écarteur de Langenbeck sur le repère, au bord de la plaie, puis appuie sur la gâchette pour le poser.",
			"label": "Écarteur ici", "radius": 0.035, "sound": "pose",
			"target": func() -> Vector3: return patient.retractor_slot(-1.0),
			"done": _retractor1_done, "done_msg": "Écarteur en place"},
		{"id": "ecarteur2", "kind": "place", "list": "Écarteur 2", "inst": "roux",
			"title": "Écarte l'autre bord",
			"text": "Pose l'écarteur de Roux sur le repère de l'autre bord. La plaie s'ouvre : on voit le cæcum et l'appendice.",
			"label": "Écarteur ici", "radius": 0.035, "sound": "pose",
			"target": func() -> Vector3: return patient.retractor_slot(1.0),
			"done": _retractor2_done, "done_msg": "Écarteur en place"},
		{"id": "saisie", "kind": "lift", "list": "Sortir l'appendice", "inst": "debakey",
			"title": "Sors l'appendice",
			"text": "Avec la pince De Bakey, attrape la pointe de l'appendice (gâchette) et soulève-la hors de la plaie sans lâcher.",
			"label": "Pointe de l'appendice", "radius": 0.03,
			"target": func() -> Vector3: return patient.appendix_tip,
			"grab": _kill_anim, "move": patient.set_appendix_tip, "goal": _lift_goal,
			"release": _appendix_fall, "done": _lift_done,
			"done_msg": "Appendice extériorisé — l'aide le maintient"},
		{"id": "ligature", "kind": "place", "list": "Ligature", "inst": "overholt",
			"title": "Ligature la base",
			"text": "Amène le fil sur le repère à la base de l'appendice et appuie sur la gâchette pour serrer le nœud.",
			"label": "Ligature ici", "radius": 0.03, "sound": "fil",
			"target": func() -> Vector3: return patient.appendix_point(0.18),
			"done": func(_hand: SurgeonHand, _instant: bool) -> void: patient.ligate(),
			"done_msg": "Nœud serré"},
		{"id": "section", "kind": "place", "list": "Section", "inst": "ciseaux",
			"title": "Coupe l'appendice",
			"text": "Place les ciseaux sur le repère, juste au-dessus de la ligature, et appuie sur la gâchette.",
			"label": "Couper ici", "radius": 0.03, "sound": "ciseaux", "near_miss": 0.08,
			"target": func() -> Vector3: return patient.appendix_point(0.32),
			"done": _cut_done, "done_msg": "Appendice sectionné"},
		{"id": "retrait", "kind": "carry", "list": "Retrait", "inst": "debakey",
			"title": "Dépose l'appendice",
			"text": "Attrape l'appendice coupé avec la pince (gâchette maintenue) et lâche-le dans le haricot, sur le guéridon à ta gauche.",
			"label": "Attrape l'appendice", "dest_label": "Lâche ici",
			"object": func() -> Node3D: return piece,
			"dest": func() -> Vector3: return tray.dish_center,
			"done": _carry_done, "done_msg": "Appendice dans le haricot"},
		{"id": "suture", "kind": "points", "list": "Suture", "inst": "porte_aiguille",
			"title": "Referme la peau",
			"text": "Les écarteurs sont retirés. Avec le porte-aiguille, touche les 4 points de suture un par un (gâchette).",
			"label": "Point", "radius": 0.022,
			"points": _stitch_points, "point": _stitch, "done": _closed,
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
		tween_opening(0.25, 0.6)


func _retractor_pose(inst: Instrument, side: float) -> Transform3D:
	# Manche relevé vers l'extérieur, lame recourbée (+Y du modèle) plongée dans la plaie
	var edge := patient.center + patient.perp3 * side * 0.02
	var tip := Vector3(edge.x, Patient.body_height(edge.x, edge.z) + 0.004, edge.z)
	var axis := (-patient.perp3 * side + Vector3.UP * 0.6).normalized()
	return inst.tip_transform(tip, axis, Vector3.DOWN)


func _place_retractor(inst_id: String, side: float, hand: SurgeonHand, instant: bool, open_to: float) -> void:
	var inst := instrument(inst_id)
	if hand:
		hand.release_parked()
	park(inst, _retractor_pose(inst, side), instant)
	if instant:
		patient.opening = open_to
	else:
		tween_opening(open_to, 0.8)


func _retractor1_done(hand: SurgeonHand, instant: bool) -> void:
	_place_retractor("langenbeck", -1.0, hand, instant, 0.6)


func _retractor2_done(hand: SurgeonHand, instant: bool) -> void:
	_place_retractor("roux", 1.0, hand, instant, 1.0)


func _kill_anim() -> void:
	if _anim and _anim.is_valid():
		_anim.kill()
	_anim = null


func _lift_goal() -> float:
	var goal := patient.center.y + 0.012
	var rest := patient.appendix_rest_tip.y
	return clampf((patient.appendix_tip.y - rest) / (goal - rest), 0.0, 1.0)


func _appendix_fall() -> void:
	var from := patient.appendix_tip
	_kill_anim()
	_anim = proc.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_anim.tween_method(func(k: float) -> void: patient.set_appendix_tip(from.lerp(patient.appendix_rest_tip, k)), 0.0, 1.0, 0.7)


func _lifted_tip() -> Vector3:
	return patient.center + Vector3.UP * 0.035 - patient.dir3 * 0.012 + patient.perp3 * 0.004


func _lift_done(instant: bool) -> void:
	if instant:
		patient.set_appendix_tip(_lifted_tip())
		return
	var from := patient.appendix_tip
	_kill_anim()
	_anim = proc.create_tween().set_trans(Tween.TRANS_SINE)
	_anim.tween_method(func(k: float) -> void: patient.set_appendix_tip(from.lerp(_lifted_tip(), k)), 0.0, 1.0, 0.5)


func _cut_done(_hand: SurgeonHand, _instant: bool) -> void:
	piece = patient.cut()


func _carry_done(instant: bool) -> void:
	if instant and piece:
		piece.global_position = tray.dish_center + Vector3.UP * 0.008
	unpark_all(instant)
	if instant:
		patient.opening = 0.3
	else:
		tween_opening(0.3, 0.8)


func _stitch_points() -> Array:
	var out := []
	for t in STITCH_T:
		out.append(patient.incision_point(t) + Vector3.UP * 0.001)
	return out


func _stitch(i: int, instant: bool) -> void:
	patient.add_stitch(STITCH_T[i])
	var left := 0.3 * (1.0 - float(i + 1) / STITCH_T.size())
	if instant:
		patient.opening = left
	else:
		tween_opening(left, 0.4)


func _closed(_instant: bool) -> void:
	patient.set_stitched(1.0)
