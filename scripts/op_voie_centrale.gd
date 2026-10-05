class_name OpVoieCentrale
extends Operation
## Voie veineuse centrale sous-clavière gauche, technique de Seldinger, chez un polytraumatisé en
## choc hémorragique (veines des bras introuvables, collier cervical : pas de jugulaire).
##   1. Repérage : sous le milieu de la clavicule, à 1-2 cm de l'os.
##   2. Désinfection, 3. anesthésie locale (attendre qu'elle agisse).
##   4. Ponction : aiguille sur seringue, sous la clavicule, vers le creux sus-sternal, en aspirant :
##      le sang veineux (sombre, qui ne bat pas) revient quand la pointe entre dans la veine. Plus
##      loin : l'artère sous-clavière et le sommet du poumon.
##   5. Guide : on retire la seringue (l'aide), on pousse le guide métallique dans l'aiguille,
##      15-20 cm ; trop loin, il touche le cœur (extrasystoles). L'aide retire l'aiguille.
##   6. Dilatateur sur le guide, 7. cathéter sur le guide jusqu'à 16-19 cm (l'aide retire le
##      guide), 8. fixation par deux points.
## Le trajet vers la veine est calculé sur la vraie anatomie (veine et artère sous-clavières,
## clavicule) à partir du point marqué.

const VEIN_SCALE := 1.6  ## veine dilatée (patient incliné tête en bas) : cible plus large

var site := Vector3.ZERO  ## point de ponction (peau)
var axis := Vector3.DOWN  ## trajet de l'aiguille
var vein_depth := 0.065  ## distance jusqu'à la veine le long du trajet
var pitch := 30.0
var path := PackedVector3Array()  ## trajet du guide : peau → veine → veine cave supérieure → oreillette
var _path_len := PackedFloat32Array()
var wire_len := 0.0
var cath_len := 0.0
var _V := PackedVector3Array()
var _VR := PackedFloat32Array()
var _A := PackedVector3Array()
var _AR := PackedFloat32Array()
var _cm := Vector3.ZERO
var _cl := Vector3.ZERO
var _wire_in: MeshInstance3D
var _wire_out: MeshInstance3D
var _cath_in: MeshInstance3D
var _cath_out: Node3D
var _wire_mat: StandardMaterial3D
var _cath_mat: StandardMaterial3D
var _needle_left := false  ## l'aide a retiré l'aiguille


func _init() -> void:
	id = "voie_centrale"
	name = "Voie veineuse centrale"
	tagline = "Choc : un cathéter dans la veine sous-clavière (technique de Seldinger)."
	pose = "dos"
	player_spawn = Vector3(0.12, 0.0, 0.66)
	player_look = Vector3(0.09, 1.0, 0.09)
	tray_pos = Vector3(-0.32, 0.0, 0.66)
	patient_line = "Lucas M., 35 ans — chute d'un échafaudage (6 m)"
	urgency = "URGENCE VITALE"
	intro_title = "Salle de déchocage"
	intro_text = "Chute de six mètres : bassin et fémur fracturés, il saigne à l'intérieur. Pâle, glacé, la tension baisse ; les veines des bras sont collabées, impossible d'y mettre un cathéter. Il faut une voie centrale pour transfuser vite.\n\nLe collier cervical empêche d'aller au cou : ce sera la veine sous-clavière gauche, sous la clavicule, par la technique de Seldinger (aiguille, guide, dilatateur, cathéter)."
	imaging_tex = ""
	imaging_text = "Choc hémorragique (fractures du bassin et du fémur). Pas d'accès veineux périphérique.\n\n•  tension 84 / 52, pouls 124\n•  veines des bras collabées\n•  collier cervical : jugulaire impossible\n•  table inclinée tête en bas : la veine se gonfle"
	scan_text = "RADIO DU BASSIN\nFracture du bassin\nfracture du fémur gauche"
	header = "DÉCHOCAGE  ·  VOIE CENTRALE  ·  SOUS-CLAVIÈRE GAUCHE"
	summary = "Le cathéter central est en place, sa pointe dans la veine cave supérieure : la transfusion passe à plein débit, la tension remonte."
	breath_rate = 24.0
	vitals = {"hr": 124.0, "spo2": 95.0, "sys": 84, "dia": 52, "temp": 35.2}
	catalog = [
		["feutre", "Feutre dermographique", "proc:feutre", 0.0, 0.0],
		["mikulicz", "Pince à badigeon (chlorhexidine)", "pince_mikulicz", 0.0, 0.0],
		["seringue", "Seringue de lidocaïne 1 %", "seringue", 0.0, 0.0, Vector3(90, 0, 0)],
		["aiguille", "Aiguille 18G sur seringue", "proc:cathlon", 0.0, 0.0],
		["guide", "Guide métallique à bout en J", "proc:guide", 0.0, 0.0],
		["dilatateur", "Dilatateur", "proc:dilatateur", 0.0, 0.0],
		["kt_central", "Cathéter central 3 voies", "proc:kt_central", 0.0, 0.0],
		["porte_aiguille", "Porte-aiguille + fil 2/0", "porte_aiguille", 0.0, 0.19],
	]


func _ideal() -> Vector2:
	var cm := Patient.lm("clavicle_medial_L")
	var cl := Patient.lm("clavicle_lateral_L")
	var z := 0.1
	var x := lerpf(cm.x, cl.x, (z - cm.z) / (cl.z - cm.z)) - 0.02
	return Vector2(x, z)


func configure_patient(p: Patient) -> void:
	p.init_lung(0.0)  # pas de pneumothorax : poumons bien gonflés
	p.WINDOW_MIN = Vector2(-0.2, -0.22)
	p.WINDOW_MAX = Vector2(0.2, 0.22)
	var c := _ideal() if not Patient.landmarks.is_empty() else Vector2(0.092, 0.1)
	p.PATCH_MIN = c - Vector2(0.1, 0.1)
	p.PATCH_SIZE = Vector2(0.2, 0.2)
	p.INC_A = c - Vector2(0.0, 0.003)
	p.INC_B = c + Vector2(0.0, 0.003)
	p.paint_r = Vector2(0.06, 0.055)
	p.wound_w = 0.004
	p.WOUND_DEPTH = 0.01
	p.breathe_amp = 0.005
	p.hole_limit = 0.003
	p.antiseptic = "chlorhexidine"
	p.props_options = {"ecg_lateral": true}


func build_extras() -> void:
	patient.heart_rate = vitals["hr"]
	var vd: Dictionary = Patient.landmarks.get("subclavian_vein_L", {})
	for q in vd.get("points", []):
		_V.append(Vector3(q[0], q[1], q[2]))
	for r in vd.get("radius", []):
		_VR.append(float(r) * VEIN_SCALE)
	var ad: Dictionary = Patient.landmarks.get("subclavian_artery_L", {})
	for q in ad.get("points", []):
		_A.append(Vector3(q[0], q[1], q[2]))
	for r in ad.get("radius", []):
		_AR.append(float(r))
	_cm = Patient.lm("clavicle_medial_L")
	_cl = Patient.lm("clavicle_lateral_L")
	var c := _ideal()
	_set_site(patient.on_skin(Vector3(c.x, 0, c.y)))
	var needle := instrument("aiguille")
	if needle and needle.model is CathlonModel:
		var m := needle.model as CathlonModel
		m.with_catheter = false
		m.draws_blood = true
	_wire_mat = MeshUtil.mat(Color(0.82, 0.84, 0.87), 0.18, 1.0)
	_cath_mat = MeshUtil.mat(Color(0.95, 0.94, 0.9), 0.35)


func on_start() -> void:
	monitor.target_rate = vitals["hr"]
	monitor.target_spo2 = vitals["spo2"]


func define_steps() -> void:
	steps = [
		{"id": "repere", "kind": "mark", "list": "Repérage", "inst": "feutre",
			"title": "Repère le point de ponction",
			"text": "Côté gauche, sous la clavicule. Suis la clavicule du sternum vers l'épaule : à son milieu, descends de 1 à 2 cm. L'aiguille passera sous l'os vers le creux au-dessus du sternum. Marque le point au feutre (V : vue anatomique, la veine passe sous la clavicule).",
			"label": "Sous la clavicule gauche", "ring": 3.6,
			"area": func() -> Vector3: return patient.on_skin(Vector3(_ideal().x + 0.005, 0, 0.085)),
			"ideal": func() -> Vector3: return patient.on_skin(Vector3(_ideal().x, 0, _ideal().y)),
			"judge": _judge_site, "done": _marked},
		{"id": "badigeon", "kind": "paint", "list": "Désinfection", "inst": "mikulicz",
			"title": "Désinfecte largement",
			"text": "Chlorhexidine alcoolique en partant du point marqué vers l'extérieur, sous la clavicule et jusqu'à l'épaule : le guide et le cathéter passeront par là.",
			"label": "Désinfecte ici", "ring": 2.0,
			"area": func() -> Vector3: return site,
			"done_msg": "Désinfecté"},
		{"id": "anesthesie", "kind": "inject", "list": "Anesthésie locale", "inst": "seringue",
			"title": "Anesthésie locale",
			"text": "Pique sur le repère et pousse le piston (clic maintenu) : un bouton gonfle sous la peau. Puis attends quelques secondes que la lidocaïne agisse.",
			"label": "Pique ici", "wait": 8.0, "what": "Lidocaïne",
			"target": func() -> Vector3: return site + Vector3.UP * 0.0005,
			"done_msg": "Lidocaïne injectée : attends qu'elle agisse"},
		{"id": "ponction", "kind": "needle", "list": "Ponction de la veine", "inst": "aiguille",
			"title": "Pique sous la clavicule",
			"text": "Sur le repère, l'aiguille à %d° de la peau, vers le creux au-dessus du sternum : elle glisse sous la clavicule. Maintiens le clic : elle avance en aspirant. Dès que du sang sombre revient dans la seringue, arrête : tu es dans la veine." % int(pitch),
			"label": "Pique ici", "ring": 0.7,
			"target": func() -> Vector3: return patient.live(site),
			"axis": axis, "flash_depth": vein_depth + 0.0015, "max_depth": vein_depth + 0.018, "flash": "blood",
			"aspiration_max": 0.08, "speed": 0.012,
			"deep_msg": "Trop profond : derrière la veine, il y a l'artère et le sommet du poumon !",
			"on_too_deep": _too_deep, "on_flash": _venous_flash,
			"done": _needle_in, "done_msg": "Sang sombre, qui ne bat pas : tu es dans la veine"},
		{"id": "guide", "kind": "thread", "list": "Guide", "inst": "guide",
			"title": "Passe le guide dans l'aiguille",
			"text": "L'aide a retiré la seringue. Présente le bout en J du guide à l'embase de l'aiguille et pousse-le (clic maintenu) : 15 à 20 cm. Surveille le scope : s'il s'affole, le guide touche le cœur.",
			"label": "Embase de l'aiguille", "ring": 0.6,
			"target": _hub, "axis": axis, "near": 0.03,
			"ok": Vector2(0.15, 0.2), "max": 0.215, "speed": 0.04, "what": "Guide",
			"on_length": _wire_length, "on_too_far": _touch_heart,
			"far_msg": "Le guide est entré dans le cœur : extrasystoles ! Il ne faut pas dépasser 20 cm.",
			"done": _wire_done, "done_msg": "Guide en place : l'aide retire l'aiguille en le tenant"},
		{"id": "dilatation", "kind": "insert", "list": "Dilatation", "inst": "dilatateur",
			"title": "Dilate le trajet",
			"text": "Enfile le dilatateur sur le guide et pousse-le de 4 cm, dans l'axe de l'aiguille, en tournant légèrement : il élargit le passage jusqu'à la veine. Puis retire-le en laissant le guide.",
			"label": "Sur le guide", "depth": 0.04, "axis": axis, "what": "Dilatateur",
			"target": func() -> Vector3: return patient.live(site),
			"zone_r": 0.01, "zone_depth": 0.06,
			"done": _dilated, "done_msg": "Trajet dilaté"},
		{"id": "catheter", "kind": "thread", "list": "Cathéter", "inst": "kt_central",
			"title": "Glisse le cathéter sur le guide",
			"text": "Enfile le cathéter sur le guide et pousse-le (clic maintenu) jusqu'à 16-19 cm à la peau : sa pointe arrive dans la veine cave supérieure, juste au-dessus du cœur. L'aide retirera le guide.",
			"label": "Sur le guide", "ring": 0.6,
			"target": func() -> Vector3: return patient.live(site), "axis": axis, "near": 0.03,
			"ok": Vector2(0.16, 0.19), "max": 0.205, "speed": 0.035, "what": "Cathéter",
			"on_length": _cath_length, "on_too_far": _touch_heart,
			"far_msg": "Le cathéter est dans l'oreillette : extrasystoles ! Il faut rester sous 19 cm.",
			"done": _cath_done, "done_msg": "Cathéter en place, le sang revient sur chaque voie"},
		{"id": "fixation", "kind": "suture", "list": "Fixation", "inst": "porte_aiguille",
			"title": "Fixe le cathéter",
			"text": "Deux points au porte-aiguille, un dans chaque trou de l'ailette : pique d'un côté, ressors de l'autre.",
			"label": "Point", "radius": 0.006,
			"pairs": _fix_pairs, "point": _fix_point, "done": _fixed,
			"done_msg": "Cathéter fixé : la transfusion passe à plein débit"},
	]


# ---------------------------------------------------------------- Trajet

func _set_site(p: Vector3) -> void:
	site = p
	var best := _path_from(p)
	if best.is_empty():
		# Repli (point mal choisi) : droit vers le milieu de la veine
		var t := _V[_V.size() * 2 / 3] if _V.size() > 0 else p + Vector3(0.02, -0.05, -0.04)
		axis = (t - p).normalized()
		vein_depth = p.distance_to(t)
	else:
		axis = best["axis"]
		vein_depth = best["depth"]
	pitch = snappedf(rad_to_deg(asin(clampf(-axis.y, -1.0, 1.0))), 5.0)
	_build_path()


## Meilleur trajet depuis le point E : vers un point de la veine (moitié interne), angle proche de
## 30°, sans traverser l'artère ni toucher la clavicule.
func _path_from(e: Vector3) -> Dictionary:
	var best := {}
	for i in _V.size():
		var t := _V[i]
		if t.z < 0.025 or t.z > 0.085:
			continue
		var a := (t - e).normalized()
		var p_deg := rad_to_deg(asin(clampf(-a.y, -1.0, 1.0)))
		if p_deg < 12.0 or p_deg > 55.0:
			continue
		var hit := -1.0
		var bad := false
		for n in range(1, 200):
			var s := n * 0.0005
			var q := e + a * s
			if _in_tube(q, _A, _AR, 0.001):
				bad = true
				break
			if s > 0.005 and _seg_dist(q, _cm, _cl) < 0.007:
				bad = true
				break
			if _in_tube(q, _V, _VR, 0.0):
				hit = s
				break
		if bad or hit < 0.0:
			continue
		var score := -absf(p_deg - 30.0)
		if best.is_empty() or score > float(best["score"]):
			best = {"score": score, "axis": a, "depth": hit}
	return best


static func _in_tube(q: Vector3, pts: PackedVector3Array, radii: PackedFloat32Array, margin: float) -> bool:
	for i in pts.size():
		var r := radii[i] + margin
		if q.distance_squared_to(pts[i]) < r * r:
			return true
	return false


static func _seg_dist(q: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return q.distance_to(a + ab * t)


## Trajet du guide : la peau, le long de l'aiguille jusqu'à la veine, puis la veine vers le milieu,
## le tronc veineux brachio-céphalique, la veine cave supérieure et l'entrée de l'oreillette.
func _build_path() -> void:
	path = PackedVector3Array()
	var h := site + axis * (vein_depth + 0.002)
	path.append(site)
	path.append(h)
	var k := 0
	var best := 1e9
	for i in _V.size():
		var d := _V[i].distance_to(h)
		if d < best:
			best = d
			k = i
	for i in range(k + 1, _V.size()):
		path.append(_V[i])
	var svc: Dictionary = Patient.landmarks.get("svc", {})
	var sp: Array = svc.get("points", [])
	if not sp.is_empty():
		var top := Vector3(sp[0][0], sp[0][1], sp[0][2])
		var last := path[path.size() - 1]
		path.append(last.lerp(top, 0.5) + Vector3(0.006, -0.004, 0.0))
		for q in sp:
			path.append(Vector3(q[0], q[1], q[2]))
		var bottom := path[path.size() - 1]
		path.append(bottom + (bottom - top).normalized() * 0.04)
	_path_len = PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		_path_len.append(_path_len[i - 1] + path[i].distance_to(path[i - 1]))


## Points du trajet jusqu'à la longueur l (depuis la peau).
func _path_upto(l: float) -> PackedVector3Array:
	var out := PackedVector3Array([path[0]])
	for i in range(1, path.size()):
		if _path_len[i] >= l:
			var seg := _path_len[i] - _path_len[i - 1]
			var t := (l - _path_len[i - 1]) / maxf(seg, 1e-6)
			out.append(path[i - 1].lerp(path[i], t))
			return out
		out.append(path[i])
	return out


func _hub() -> Vector3:
	var needle := instrument("aiguille")
	return needle.model.global_transform * Vector3(0, 0, CathlonModel.BARREL_Z1 + 0.004)


# ---------------------------------------------------------------- Repérage

func _clav_x(z: float) -> float:
	return lerpf(_cm.x, _cl.x, (z - _cm.z) / (_cl.z - _cm.z))


func _judge_site(p: Vector3) -> Dictionary:
	var ideal := _ideal()
	var mm := Vector2(p.x - ideal.x, p.z - ideal.y).length() * 1000.0
	if p.z < 0.0:
		return {"ok": false, "mm": mm, "msg": "Côté droit : on pose la voie à gauche (sous la clavicule gauche)."}
	if p.z < _cm.z + 0.02:
		return {"ok": false, "mm": mm, "msg": "Sur le sternum : va sous la clavicule, vers l'épaule."}
	var below := _clav_x(p.z) - p.x
	if below < 0.006:
		return {"ok": false, "mm": mm, "msg": "Sur la clavicule : pique 1 à 2 cm sous l'os."}
	if below > 0.034:
		return {"ok": false, "mm": mm, "msg": "Trop bas : reste à 1-2 cm sous la clavicule, sinon l'aiguille n'arrive pas sous l'os."}
	var f := (p.z - _cm.z) / (_cl.z - _cm.z)
	if f > 0.82:
		return {"ok": false, "mm": mm, "msg": "Trop en dehors, vers l'épaule : la veine y est profonde et l'artère proche."}
	var best := _path_from(p)
	if best.is_empty():
		if f < 0.5:
			return {"ok": false, "mm": mm, "msg": "Trop en dedans : la veine est juste dessous, l'aiguille plongerait à pic vers le poumon. Décale-toi vers le milieu de la clavicule."}
		return {"ok": false, "mm": mm, "msg": "De là, l'aiguille croiserait l'artère sous-clavière. Décale-toi un peu."}
	return {"ok": true, "mm": mm, "msg": "Bon repère : sous le milieu de la clavicule, à %d cm de l'os" % int(round(below * 100.0))}


func _marked(_hand: SurgeonHand, _instant: bool, p: Variant) -> void:
	var c := _ideal()
	var q: Vector3 = p if p is Vector3 else patient.on_skin(Vector3(c.x, 0, c.y))
	_set_site(patient.on_skin(Vector3(q.x, 0, q.z)))
	for m in [patient.skin_mat, patient.zone_mat]:
		m.set_shader_parameter("pen_mark", Vector3(site.x, site.z, 1.0))
	patient.set_paint_center(Vector2(site.x, site.z))
	for s in steps:
		if s.has("axis"):
			s["axis"] = axis
		if s["kind"] == "needle":
			s["flash_depth"] = vein_depth + 0.0015
			s["max_depth"] = vein_depth + 0.018
			s["text"] = "Sur le repère, l'aiguille à %d° de la peau, vers le creux au-dessus du sternum : elle glisse sous la clavicule. Maintiens le clic : elle avance en aspirant. Dès que du sang sombre revient dans la seringue, arrête : tu es dans la veine." % int(pitch)


func anesthesia_started(wait: float) -> void:
	var b := patient.bleb
	if wait <= 0.0:
		patient.bleb_pale = 1.0
		patient.set_bleb(Vector3(b.x, 0, b.y), 0.014, 0.0011)
		return
	var tw := proc.create_tween().set_parallel(true)
	tw.tween_property(patient, "bleb_pale", 1.0, wait).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(k: float) -> void: patient.set_bleb(Vector3(b.x, 0, b.y), lerpf(b.z, 0.014, k), lerpf(b.w, 0.0011, k)), 0.0, 1.0, wait)


# ---------------------------------------------------------------- Ponction, guide, cathéter

func _venous_flash() -> void:
	var needle := instrument("aiguille")
	if needle.model is CathlonModel:
		(needle.model as CathlonModel).set_aspiration(0.12)


func _too_deep() -> void:
	# Artère piquée ou plèvre : la saturation baisse un peu (pneumothorax débutant)
	monitor.target_spo2 = maxf(monitor.target_spo2 - 3.0, 88.0)


## L'aiguille reste dans la veine, la seringue est retirée : on garde l'aiguille en place.
func _needle_in(hand: SurgeonHand, instant: bool) -> void:
	var needle := instrument("aiguille")
	var xf := needle.global_transform
	if instant:
		# Aiguille dans l'axe, la pointe juste dans la veine
		var b := Basis.looking_at(-axis, Vector3.UP if absf(axis.y) < 0.95 else Vector3.FORWARD)
		var tip := site + axis * (vein_depth + 0.002)
		xf = Transform3D(b, tip) * Transform3D(Basis.IDENTITY, -needle.tip_local)
	if hand and hand.held == needle:
		hand.release_parked()
	park(needle, xf, true)
	if needle.model is CathlonModel:
		(needle.model as CathlonModel).show_syringe(false)


func _wire_length(l: float) -> void:
	wire_len = l
	_draw_wire()


func _touch_heart() -> void:
	monitor.ectopic(4)


## L'aide retire l'aiguille en tenant le guide.
func _wire_done(hand: SurgeonHand, instant: bool) -> void:
	if instant:
		wire_len = 0.175
	var needle := instrument("aiguille")
	proc.parked.erase(needle)
	needle.parked = false
	if needle.model is CathlonModel:
		(needle.model as CathlonModel).show_syringe(true)
	needle.return_to_tray()
	_needle_left = true
	_draw_wire()
	var g := instrument("guide")
	if hand and hand.held == g:
		hand.put_back()


func _dilated(hand: SurgeonHand, _instant: bool) -> void:
	var d := instrument("dilatateur")
	if hand and hand.held == d:
		hand.put_back()


func _cath_length(l: float) -> void:
	cath_len = l
	_draw_catheter()


## Le cathéter est en place : l'aide retire le guide, la partie externe est posée sur la peau.
func _cath_done(hand: SurgeonHand, instant: bool) -> void:
	if instant:
		cath_len = 0.175
	wire_len = 0.0
	_draw_wire()
	var k := instrument("kt_central")
	if hand and hand.held == k:
		hand.release_parked()
	park(k, k.global_transform, true)
	k.visible = false
	_draw_catheter()
	_build_cath_out()
	monitor.sys = 92
	monitor.dia = 56
	monitor.target_rate = 116.0


func _fix_pairs() -> Array:
	var out_dir := Vector3(-axis.x, 0.0, -axis.z).normalized()
	var perp := out_dir.cross(Vector3.UP).normalized()
	var wing := site + out_dir * 0.03
	var res := []
	for sgn in [-1.0, 1.0]:
		var c: Vector3 = wing + perp * 0.009 * sgn
		var a := c - out_dir * 0.004
		var b := c + out_dir * 0.004
		res.append([patient.on_skin(a), patient.on_skin(b)])
	return res


func _fix_point(i: int, instant: bool) -> void:
	var pair: Array = _fix_pairs()[i]
	var p: Vector3 = (pair[0] + pair[1]) * 0.5
	patient.add_stitch_at(p, (pair[1] - pair[0]).normalized(), 0.01)
	if not instant:
		Sfx.play("fil", p, -6.0)


func _fixed(_instant: bool) -> void:
	monitor.sys = 102
	monitor.dia = 62
	monitor.target_rate = 104.0
	monitor.target_spo2 = 97.0
	patient.heart_rate = 104.0


# ---------------------------------------------------------------- Dessin du guide et du cathéter

## Partie interne : visible seulement en vue anatomique (comme sous radioscopie, par-dessus les
## organes) ; partie externe : sort de l'aiguille (ou de la peau) et retombe sur le thorax.
func _draw_wire() -> void:
	if _wire_in == null:
		_wire_in = MeshInstance3D.new()
		_wire_in.name = "GuideInterne"
		var m := _wire_mat.duplicate() as StandardMaterial3D
		m.no_depth_test = true
		m.render_priority = 2
		m.emission_enabled = true
		m.emission = Color(0.75, 0.8, 0.9)
		m.emission_energy_multiplier = 1.2
		_wire_in.material_override = m
		root.add_child(_wire_in)
		_wire_out = MeshInstance3D.new()
		_wire_out.name = "GuideExterne"
		_wire_out.material_override = _wire_mat
		root.add_child(_wire_out)
	if wire_len <= 0.0:
		_wire_in.visible = false
		_wire_out.visible = false
		return
	# Tant que l'aiguille est en place, le guide entre par son embase
	var start := site if _needle_left else _hub()
	var inside := _path_upto(wire_len + (0.0 if _needle_left else start.distance_to(site)))
	if not _needle_left:
		inside[0] = start
	# (affiché plus épais qu'en vrai : visible en vue anatomique, comme sous radioscopie)
	_wire_in.mesh = _tube_mesh(inside, 0.0009)
	_wire_in.visible = patient.view_mode != 0
	# Dehors : 30 cm de guide qui retombent sur le thorax vers l'épaule
	var out_dir := Vector3(-axis.x, 0.0, -axis.z).normalized()
	var a := start - axis * 0.004
	var b := a - axis * 0.05 + Vector3.UP * 0.02
	var c := Cable.on_surface(site.x + out_dir.x * 0.16 - 0.02, site.z + out_dir.z * 0.16, 0.001)
	var d := Cable.on_surface(site.x + out_dir.x * 0.22 - 0.07, site.z + out_dir.z * 0.2, 0.001)
	_wire_out.mesh = _tube_mesh(MeshUtil.bezier(a, b, c, d, 24), 0.00045)
	_wire_out.visible = true


func _draw_catheter() -> void:
	if _cath_in == null:
		_cath_in = MeshInstance3D.new()
		_cath_in.name = "CatheterInterne"
		var m := _cath_mat.duplicate() as StandardMaterial3D
		m.no_depth_test = true
		m.render_priority = 1
		_cath_in.material_override = m
		root.add_child(_cath_in)
	if cath_len <= 0.0:
		_cath_in.visible = false
		return
	_cath_in.mesh = _tube_mesh(_path_upto(cath_len), 0.0012)
	_cath_in.visible = patient.view_mode != 0


## Embase, ailette et trois voies colorées posées sur la peau.
func _build_cath_out() -> void:
	if _cath_out:
		_cath_out.queue_free()
	_cath_out = Node3D.new()
	_cath_out.name = "CatheterExterne"
	root.add_child(_cath_out)
	var out_dir := Vector3(-axis.x, 0.0, -axis.z).normalized()
	var perp := out_dir.cross(Vector3.UP).normalized()
	var wing := patient.on_skin(site + out_dir * 0.03) + Vector3.UP * 0.002
	var body := MeshInstance3D.new()
	body.mesh = _tube_mesh(PackedVector3Array([site - axis * 0.002, site + Vector3.UP * 0.003 + out_dir * 0.01, wing]), 0.0013)
	body.material_override = _cath_mat
	_cath_out.add_child(body)
	var w := MeshUtil.box_instance(_cath_out, Vector3(0.022, 0.003, 0.012), wing, _cath_mat, "Ailette")
	w.look_at_from_position(wing, wing + out_dir, Vector3.UP)
	var cols := [Color(0.15, 0.35, 0.8), Color(0.55, 0.35, 0.2), Color(0.95, 0.95, 0.95)]
	for i in 3:
		var side: Vector3 = perp * (i - 1) * 0.012
		var p0 := wing + out_dir * 0.012
		var p1 := Cable.on_surface(p0.x + out_dir.x * 0.05 + side.x, p0.z + out_dir.z * 0.05 + side.z, 0.0015)
		var p2 := Cable.on_surface(p0.x + out_dir.x * 0.1 + side.x * 2.0 + 0.01, p0.z + out_dir.z * 0.1 + side.z * 2.0, 0.0015)
		var ext := MeshInstance3D.new()
		ext.mesh = _tube_mesh(MeshUtil.bezier(p0, p0.lerp(p1, 0.5) + Vector3.UP * 0.004, p1, p2, 12), 0.0012)
		ext.material_override = _cath_mat
		_cath_out.add_child(ext)
		var hub := MeshUtil.mat(cols[i], 0.4)
		var cap := MeshUtil.cylinder_instance(_cath_out, 0.0035, 0.016, p2, hub, "Raccord")
		var dirv := (p2 - p1).normalized()
		cap.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, dirv)), p2 + dirv * 0.008)
		MeshUtil.box_instance(_cath_out, Vector3(0.006, 0.005, 0.008), p1 + Vector3.UP * 0.002, hub, "Clamp")


func _tube_mesh(pts: PackedVector3Array, r: float) -> ArrayMesh:
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(r)
	return MeshUtil.tube(pts, rr, 8, true, true)


func process(_delta: float) -> void:
	# Parties internes visibles en vue anatomique seulement
	if _wire_in:
		_wire_in.visible = wire_len > 0.0 and patient.view_mode != 0
	if _cath_in:
		_cath_in.visible = cath_len > 0.0 and patient.view_mode != 0
	# Le guide suit l'aiguille tant qu'elle est en place
	if _wire_out and wire_len > 0.0 and not _needle_left:
		_draw_wire()
