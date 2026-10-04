class_name OpLaparo
extends Operation
## Laparotomie médiane exploratrice pour plaie abdominale par arme blanche : grande incision,
## écarteur autostatique, aspiration de l'hémopéritoine, anse grêle perforée sortie, clampée,
## réparée, lavage, puis fermeture de l'aponévrose et de la peau.

const APO_T := [0.12, 0.31, 0.5, 0.69, 0.88]
const SKIN_T := [0.08, 0.22, 0.36, 0.5, 0.64, 0.78, 0.92]

var gosset_open: Node3D
var pool: MeshInstance3D
var loop_mesh := ArrayMesh.new()
var loop_node: MeshInstance3D
var anchor: Node3D  ## suit le sommet de l'anse (perforation, points, saignement)
var bleed: MeshInstance3D
var loop_a: Vector3
var loop_b: Vector3
var apex_rest: Vector3
var apex: Vector3
var _anim: Tween
var _loop_stitches := 0


func _init() -> void:
	id = "laparotomie"
	name = "Laparotomie"
	tagline = "Plaie au couteau dans le ventre : grande incision du haut au bas du ventre, aspiration du sang, réparation de l'intestin perforé, puis fermeture en deux plans."
	intro_text = "Hugo, 27 ans, coup de couteau dans le ventre. Il saigne à l'intérieur : tension basse, cœur rapide. Il est endormi. Tu vas ouvrir tout le ventre, trouver l'intestin perforé, le réparer et refermer."
	summary = "Hémorragie aspirée, intestin réparé, ventre refermé en deux plans (aponévrose puis peau)."
	header = "URGENCES  ·  LAPAROTOMIE MÉDIANE  ·  PLAIE PAR ARME BLANCHE"
	scan_text = "ÉCHOGRAPHIE (FAST)\nÉpanchement intra-abdominal\nabondant : hémopéritoine"
	breath_rate = 20.0
	surgeon_spot = Vector3(-0.12, 0.0, 0.62)
	tray_pos = Vector3(0.42, 0.0, 0.6)
	vitals = {"hr": 118.0, "spo2": 96.0, "sys": 86, "dia": 50}
	catalog = [
		["mikulicz", "Pince à badigeon", "pince_mikulicz", 0.0, 0.0],
		["bistouri", "Bistouri lame 23", "manche_bistouri", 90.0, 0.0],
		["gosset", "Écarteur autostatique de Gosset", "proc:gosset", 0.0, 0.0],
		["aspirateur", "Canule d'aspiration", "proc:aspirateur", 0.0, 0.0],
		["debakey", "Pince De Bakey", "pince_debakey", 90.0, 0.0],
		["kelly", "Clamp intestinal", "clamp_ligature", 0.0, 0.2],
		["porte_aiguille", "Porte-aiguille + fil", "porte_aiguille", 0.0, 0.19],
	]


func configure_patient(p: Patient) -> void:
	p.op = "laparotomie"
	p.INC_A = Vector2(-0.28, 0.0)
	p.INC_B = Vector2(0.04, 0.0)
	p.PATCH_MIN = Vector2(-0.4, -0.17)
	p.PATCH_SIZE = Vector2(0.56, 0.34)
	p.WINDOW_MIN = Vector2(-0.34, -0.11)
	p.WINDOW_MAX = Vector2(0.1, 0.11)
	p.paint_r = Vector2(0.17, 0.075)
	p.wound_w = 0.06
	p.WOUND_DEPTH = 0.05
	p.bowl_radii = Vector3(0.19, 0.09, 0.1)
	p.bowl_color = Color(0.5, 0.16, 0.13)


func build_extras() -> void:
	var c := patient.center
	var skin_y := c.y
	# Organes réels (Z-Anatomy) : origine du fichier = milieu, face antérieure
	var scene: PackedScene = load("res://assets/models/anatomie_abdomen.glb")
	var anat: Node3D = scene.instantiate()
	anat.name = "Abdomen"
	patient.add_child(anat)
	anat.global_position = Vector3(-0.1, skin_y - 0.016, 0.0)
	var looks := {
		"Liver": tissue(Color(0.45, 0.14, 0.12), 0.0, 0.4, 0.0, 10.0),
		"Gallbladder": tissue(Color(0.35, 0.5, 0.3), 0.0, 0.3, 0.0, 20.0),
		"Stomach": tissue(Color(0.85, 0.58, 0.52), 0.0, 0.8, 0.0, 12.0),
		"Transverse_colon": tissue(Color(0.86, 0.62, 0.5), 0.0, 0.7, 0.0, 12.0),
		"Ascending_colon": tissue(Color(0.86, 0.62, 0.5), 0.0, 0.7, 0.0, 12.0),
		"Descending_colon": tissue(Color(0.86, 0.62, 0.5), 0.0, 0.7, 0.0, 12.0),
		"Sigmoid_colon": tissue(Color(0.86, 0.62, 0.5), 0.0, 0.7, 0.0, 12.0),
		"Jejunum": tissue(Color(0.9, 0.56, 0.5), 0.05, 0.85, 0.0, 16.0),
		"Spleen": tissue(Color(0.42, 0.12, 0.2), 0.0, 0.3, 0.0, 12.0),
		"Vermiform_appendix": tissue(Color(0.86, 0.56, 0.5), 0.0, 0.6, 0.0, 20.0),
	}
	for mi in patient._meshes_in(anat):
		var m: ShaderMaterial = looks.get(String(mi.name), tissue(Color(0.85, 0.55, 0.48)))
		m.set_shader_parameter("clip_y", skin_y - 0.012)
		mi.material_override = m

	# Anse grêle perforée, posée sur les autres organes
	apex_rest = c + Vector3(0.0, -0.022, 0.035)
	apex = apex_rest
	loop_a = apex_rest + Vector3(-0.06, -0.022, -0.02)
	loop_b = apex_rest + Vector3(0.06, -0.022, -0.012)
	loop_node = MeshInstance3D.new()
	loop_node.name = "AnsePerforee"
	loop_node.mesh = loop_mesh
	loop_node.material_override = tissue(Color(0.9, 0.52, 0.47), 0.2, 0.9, 0.0, 18.0)
	patient.add_child(loop_node)
	anchor = Node3D.new()
	anchor.name = "Perforation"
	patient.add_child(anchor)
	var hole := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.0045
	hs.height = 0.004
	hole.mesh = hs
	hole.material_override = MeshUtil.mat(Color(0.25, 0.01, 0.02), 0.15)
	hole.position = Vector3(0, 0.0115, 0)
	anchor.add_child(hole)
	bleed = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.012
	bs.height = 0.003
	bleed.mesh = bs
	var blood := MeshUtil.mat(Color(0.32, 0.01, 0.02), 0.06)
	blood.clearcoat_enabled = true
	blood.clearcoat = 1.0
	bleed.material_override = blood
	bleed.position = Vector3(0.006, 0.009, 0.004)
	anchor.add_child(bleed)
	_update_loop()

	# Hémopéritoine : flaque de sang qui recouvre les organes
	pool = MeshInstance3D.new()
	pool.name = "Hemoperitoine"
	var ps := SphereMesh.new()
	ps.radius = 1.0
	ps.height = 2.0
	pool.mesh = ps
	var pm := MeshUtil.mat(Color(0.28, 0.01, 0.02), 0.04)
	pm.clearcoat_enabled = true
	pm.clearcoat = 1.0
	pool.material_override = pm
	pool.scale = Vector3(0.14, 0.006, 0.07)
	pool.position = c + Vector3(-0.02, -0.03, 0.0)
	patient.add_child(pool)


func on_start() -> void:
	monitor.target_rate = 118.0


func _loop_points() -> PackedVector3Array:
	# Courbe passant par le sommet : point de contrôle quadratique 2m - (a+b)/2
	var ctrl := apex * 2.0 - (loop_a + loop_b) * 0.5
	var pts := PackedVector3Array()
	for i in 24:
		var t := float(i) / 23.0
		var u := 1.0 - t
		pts.append(loop_a * u * u + ctrl * 2.0 * u * t + loop_b * t * t)
	return pts


func _update_loop() -> void:
	var pts := _loop_points()
	var rr := PackedFloat32Array()
	for i in pts.size():
		rr.append(0.0115 * (1.0 + 0.05 * sin(i * 1.7)))
	MeshUtil.tube(pts, rr, 16, true, true, loop_mesh)
	anchor.global_position = apex


func set_apex(p: Vector3) -> void:
	var off := p - apex_rest
	if off.length() > 0.12:
		off = off.normalized() * 0.12
	apex = apex_rest + off
	_update_loop()


func _lifted_apex() -> Vector3:
	return apex_rest + Vector3(0.0, 0.07, 0.01)


func _kill_anim() -> void:
	if _anim and _anim.is_valid():
		_anim.kill()
	_anim = null


func _move_apex_to(target: Vector3, dur: float, trans := Tween.TRANS_SINE) -> void:
	var from := apex
	_kill_anim()
	_anim = proc.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	_anim.tween_method(func(k: float) -> void: set_apex(from.lerp(target, k)), 0.0, 1.0, dur)


func define_steps() -> void:
	var c := patient.center
	steps = [
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte tout le ventre",
			"text": "Frotte la compresse de la pince à badigeon sur toute la peau du ventre, du bas des côtes jusqu'au pubis, jusqu'à ce qu'elle soit toute brune.",
			"label": "Zone à désinfecter", "ring": 6.0, "done_msg": "Ventre désinfecté"},
		{"id": "incision", "kind": "incise", "list": "Incision médiane", "inst": "bistouri",
			"title": "Ouvre le ventre sur la ligne médiane",
			"text": "Grande incision du haut du ventre jusque sous le nombril : pose la lame sur « DÉPART », appuie, et suis le pointillé d'un long geste.",
			"done": _incision_done, "done_msg": "Ventre ouvert : du sang remonte"},
		{"id": "gosset", "kind": "selfretract", "list": "Écarteur de Gosset", "inst": "gosset",
			"title": "Ouvre grand le ventre",
			"text": "Enfonce l'écarteur de Gosset fermé au milieu de la plaie, puis écarte le pouce de l'index : ses deux valves s'ouvrent et écartent les bords. Grand ouvert, il se bloque tout seul.",
			"label": "Écarteur ici", "done": _gosset_done, "done_msg": "Le ventre est plein de sang !"},
		{"id": "aspiration", "kind": "hold", "list": "Aspirer le sang", "inst": "aspirateur",
			"title": "Aspire le sang",
			"text": "Plonge le bout de la canule d'aspiration dans le sang et promène-la dans la flaque : elle aspire tant qu'elle y trempe.",
			"label": "Aspire ici", "radius": 0.06, "duration": 4.0, "hold_sound": "aspiration",
			"target": func() -> Vector3: return pool.global_position,
			"progress": _aspirate, "done_msg": "Sang aspiré : on voit l'intestin qui saigne"},
		{"id": "exploration", "kind": "lift", "list": "Sortir l'anse", "inst": "debakey",
			"title": "Sors l'anse qui saigne",
			"text": "Mets les mors de la pince sur l'anse d'intestin qui saigne, serre les doigts pour la saisir et sors-la doucement du ventre.",
			"label": "Anse perforée", "radius": 0.025, "auto_lift": 0.08,
			"target": func() -> Vector3: return apex,
			"move": set_apex, "goal": _lift_goal,
			"rest": func() -> Vector3: return apex_rest,
			"done": _lift_done, "done_msg": "Perforation trouvée"},
		{"id": "clamp", "kind": "place", "list": "Clamper", "inst": "kelly",
			"title": "Clampe la perforation",
			"text": "Ouvre le clamp, place ses mors sur l'anse à côté du trou, puis serre : le saignement s'arrête.",
			"label": "Clamp ici", "radius": 0.022, "sound": "pose",
			"target": func() -> Vector3: return apex + Vector3.UP * 0.011,
			"done": _clamp_done, "done_msg": "Saignement arrêté"},
		{"id": "reparation", "kind": "suture", "list": "Réparer l'intestin", "inst": "porte_aiguille",
			"title": "Recouds la perforation",
			"text": "Avec le porte-aiguille, 3 points autour du trou de l'intestin : pique d'un côté du trou (repère), ressors de l'autre.",
			"label": "Point", "radius": 0.008, "free": true,
			"pairs": func() -> Array: return _pairs_around(_repair_points(), patient.perp3 * 0.004), "point": _repair_point, "done": _repaired,
			"done_msg": "Intestin réparé, remis dans le ventre"},
		{"id": "lavage", "kind": "hold", "list": "Lavage", "inst": "aspirateur",
			"title": "Lave le ventre",
			"text": "L'aide verse du sérum chaud dans le ventre. Aspire-le avec la canule, au fond, jusqu'à ce que tout soit propre.",
			"label": "Aspire ici", "radius": 0.06, "duration": 3.0, "hold_sound": "aspiration",
			"enter": _pour_saline,
			"target": func() -> Vector3: return pool.global_position,
			"progress": _wash, "done": _washed, "done_msg": "Ventre propre, écarteur retiré"},
		{"id": "aponevrose", "kind": "suture", "list": "Fermer l'aponévrose", "inst": "porte_aiguille",
			"title": "Ferme le plan profond",
			"text": "Referme l'aponévrose (le tissu blanc et solide au fond de la plaie) : 5 points. Pique d'un côté, ressors de l'autre.",
			"label": "Point", "radius": 0.009,
			"pairs": func() -> Array: return _pairs_around(_apo_points(), patient.perp3 * 0.006), "point": _apo_point, "done_msg": "Paroi solide refermée"},
		{"id": "peau", "kind": "suture", "list": "Fermer la peau", "inst": "porte_aiguille",
			"title": "Ferme la peau",
			"text": "Dernière étape : 7 points sur la peau, le long de la cicatrice. Pique à l'entrée, ressors sur l'autre bord.",
			"label": "Point", "radius": 0.008,
			"pairs": _skin_pairs, "point": _skin_point, "done": _closed,
			"done_msg": "Ventre refermé !"},
	]


# ---------------------------------------------------------------- Effets des étapes

func _incision_done(instant: bool) -> void:
	var blade_mat: StandardMaterial3D = instrument("bistouri").get_meta("blade_mat", null)
	if blade_mat:
		blade_mat.albedo_color = Color(0.62, 0.22, 0.2)
		blade_mat.metallic = 0.6
	if instant:
		patient.opening = 0.18
	else:
		tween_opening(0.18, 0.8)


func _gosset_done(hand: SurgeonHand, instant: bool) -> void:
	var inst := instrument("gosset")
	if hand:
		hand.release_parked()
	# L'instrument « replié » disparaît sous le champ ; l'écarteur ouvert apparaît dans la plaie
	park(inst, Transform3D(Basis.IDENTITY, inst.tray_transform.origin - Vector3.UP * 0.3), true)
	inst.visible = false
	patient.held_l = maxf(patient.open_l, 1.0)
	patient.held_r = maxf(patient.open_r, 1.0)
	gosset_open = ProcInstruments.gosset_open(patient.center, patient.dir3, patient.perp3, 0.13, patient.center.y)
	gosset_open.name = "GossetOuvert"
	root.add_child(gosset_open)
	if instant:
		patient.opening = 1.0
	monitor.target_rate = 124.0


## L'aide verse du sérum tiède (rosé par le sang qui reste) : nouvelle flaque à aspirer.
func _pour_saline() -> void:
	var m := pool.material_override as StandardMaterial3D
	m.albedo_color = Color(0.75, 0.42, 0.4, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pool.visible = true
	_wash(0.0)
	Sfx.play("bulles", pool.global_position, -6.0, 0.6)


func _wash(v: float) -> void:
	pool.scale = Vector3(0.13 * (1.0 - 0.6 * v), 0.005 * (1.0 - v) + 0.0005, 0.065 * (1.0 - 0.6 * v))
	pool.position.y = patient.center.y - 0.03 - 0.02 * v
	pool.visible = v < 1.0


func _aspirate(v: float) -> void:
	pool.scale = Vector3(0.14 * (1.0 - 0.6 * v), 0.006 * (1.0 - v) + 0.0005, 0.07 * (1.0 - 0.6 * v))
	pool.position.y = patient.center.y - 0.03 - 0.03 * v
	if v >= 1.0:
		pool.visible = false
		monitor.target_rate = 108.0
		monitor.sys = 98
		monitor.dia = 60


func _lift_goal() -> float:
	var goal := patient.center.y + 0.025
	return clampf((apex.y - apex_rest.y) / (goal - apex_rest.y), 0.0, 1.0)


func _lift_done(instant: bool) -> void:
	# Le cas « instantané » (tests, saut d'étape) applique aussi l'aspiration
	if instant:
		set_apex(_lifted_apex())
	else:
		_move_apex_to(_lifted_apex(), 0.5)


func _clamp_pose() -> Transform3D:
	var inst := instrument("kelly")
	var tip := apex + Vector3.UP * 0.006
	return inst.tip_transform(tip, (Vector3.DOWN * 0.5 + patient.perp3 * 0.86).normalized(), Vector3.UP)


func _clamp_done(hand: SurgeonHand, instant: bool) -> void:
	if instant:
		set_apex(_lifted_apex())
	var inst := instrument("kelly")
	if hand:
		hand.release_parked()
	park(inst, _clamp_pose(), instant)
	bleed.visible = false
	monitor.target_rate = 100.0


func _repair_points() -> Array:
	var d := patient.dir3
	var top := apex + Vector3.UP * 0.0115
	return [top - d * 0.007, top + Vector3.UP * 0.001, top + d * 0.007]


func _repair_point(i: int, _instant: bool) -> void:
	# Petit point noué sur l'intestin, attaché à l'anse
	var p: Vector3 = _repair_points()[i]
	var knot := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.0025
	tm.outer_radius = 0.0033
	knot.mesh = tm
	knot.material_override = MeshUtil.mat(Color(0.12, 0.16, 0.45), 0.4)
	anchor.add_child(knot)
	knot.global_position = p
	knot.rotation_degrees = Vector3(90, 0, 0)
	_loop_stitches += 1


func _repaired(instant: bool) -> void:
	# On retire le clamp et l'anse réparée retourne dans le ventre
	for inst in proc.parked.duplicate():
		if inst.id == "kelly":
			proc.parked.erase(inst)
			if instant:
				inst.parked = false
				inst.global_transform = inst.tray_transform
			else:
				inst.return_to_tray()
	if instant:
		set_apex(apex_rest)
	else:
		_move_apex_to(apex_rest, 1.0)
	monitor.target_rate = 92.0
	monitor.sys = 112
	monitor.dia = 68


func _washed(instant: bool) -> void:
	pool.visible = false
	patient.held_l = -1.0
	patient.held_r = -1.0
	if gosset_open:
		gosset_open.queue_free()
		gosset_open = null
	for inst in proc.parked.duplicate():
		if inst.id == "gosset":
			proc.parked.erase(inst)
			inst.visible = true
			inst.parked = false
			inst.global_transform = inst.tray_transform
	if instant:
		patient.opening = 0.22
	else:
		tween_opening(0.22, 0.8)


func _apo_points() -> Array:
	var out := []
	for t in APO_T:
		out.append(patient.incision_point(t) - Vector3.UP * 0.014)
	return out


func _apo_point(i: int, instant: bool) -> void:
	var p: Vector3 = _apo_points()[i]
	patient.add_stitch_at(p, patient.perp3, 0.02)
	var left := 0.22 - 0.1 * float(i + 1) / APO_T.size()
	if instant:
		patient.opening = left
	else:
		tween_opening(left, 0.3)


func _pairs_around(pts: Array, half: Vector3) -> Array:
	var out := []
	for p in pts:
		out.append([p - half, p + half])
	return out


func _skin_pairs() -> Array:
	var out := []
	for t in SKIN_T:
		out.append(patient.stitch_pair(t))
	return out


func _skin_points() -> Array:
	var out := []
	for t in SKIN_T:
		out.append(patient.incision_point(t) + Vector3.UP * 0.001)
	return out


func _skin_point(i: int, instant: bool) -> void:
	patient.add_stitch(SKIN_T[i])
	var left := 0.12 * (1.0 - float(i + 1) / SKIN_T.size())
	if instant:
		patient.opening = left
	else:
		tween_opening(left, 0.3)


func _closed(_instant: bool) -> void:
	patient.set_stitched(1.0)
	monitor.target_rate = 86.0
