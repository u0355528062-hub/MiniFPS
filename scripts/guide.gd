class_name Guide
extends Node
## Accompagnement du mode histoire pendant la prise en charge :
##  - TUTORIEL (premier patient) : une suite d'étapes, chacune avec une consigne claire, les touches
##    à utiliser, une flèche vers l'endroit où agir (dans la salle, sur le patient, ou sur un bouton
##    de l'interface) et un dialogue de Sophie quand c'est utile. Une étape est validée dès que sa
##    condition est vraie (elle reste validée) ; les étapes « de manipulation » (regarder, marcher,
##    ouvrir une vue) sont validées d'office quand une étape suivante l'est ;
##  - CONSEILS (patients suivants) : le chef ou l'infirmière parle quand on traîne ;
##  - Sophie peut poser la voie veineuse à la place du joueur.

var game: ERGame
var steps: Array = []
var rules: Array = []
var current := -1
var _latched: Array = []
var _rule_t := {}  ## index de règle -> instant du dernier déclenchement
var _bark_cool := 0.0
var _look_acc := 0.0
var _last_yaw := 0.0
var _walk_acc := 0.0
var _last_pos := Vector3.ZERO
var _iv_self := false
var _iv_steps_t := 0.0
var _busy := false  ## un dialogue bloquant est en cours
var _overlay: Overlay
var _tick := 0.0
var _focus_ui := ""  ## surbrillance demandée par un dialogue


func setup(g: ERGame) -> void:
	game = g
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	_overlay = Overlay.new()
	_overlay.guide = self
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)
	if Story.is_tutorial():
		steps = _tutorial_steps()
		_latched.resize(steps.size())
		_latched.fill(false)
	else:
		rules = Story.coach_rules(Story.chapter)
	_last_yaw = g.player.rotation.y
	_last_pos = g.player.global_position


func is_tutorial() -> bool:
	return not steps.is_empty()


## Ce que montre la liste « À faire » du HUD.
func tasks() -> Dictionary:
	if steps.is_empty() or current < 0 or current >= steps.size():
		return {}
	var s: Dictionary = steps[current]
	var nxt := ""
	for i in range(current + 1, steps.size()):
		if not _latched[i] and not steps[i].get("hidden", false):
			nxt = steps[i]["title"]
			break
	return {"mode": "tutorial", "index": current, "count": steps.size(), "title": s["title"], "text": s["text"], "keys": s.get("keys", []), "next": nxt}


func _process(delta: float) -> void:
	if game.state != "play" or _busy:
		return
	# Mesures pour les premières étapes (regarder, marcher)
	var yaw := game.player.rotation.y
	_look_acc += absf(angle_difference(yaw, _last_yaw)) + absf(game.player.head.rotation.x - _pitch_last) * 0.5
	_pitch_last = game.player.head.rotation.x
	_last_yaw = yaw
	var pos := game.player.global_position
	_walk_acc += Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length()
	_last_pos = pos
	_bark_cool -= delta
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.15
	if is_tutorial():
		_update_steps(0.15)
	else:
		_update_rules()


var _pitch_last := 0.0


# ---------------------------------------------------------------- Tutoriel

func _update_steps(dt: float) -> void:
	var last_done := -1
	for i in steps.size():
		if not _latched[i]:
			var cond: Callable = steps[i]["done"]
			if cond.call():
				_latched[i] = true
		if _latched[i]:
			last_done = i
	# Les étapes de manipulation et les étapes cachées avant une étape faite sont validées
	for i in last_done:
		if not _latched[i] and (steps[i].get("input", false) or game.args.has("autotest")):
			_latched[i] = true
	var nc := steps.size()
	for i in steps.size():
		if not _latched[i]:
			nc = i
			break
	if nc != current:
		current = nc
		if current < steps.size():
			var s: Dictionary = steps[current]
			if s.has("on_start"):
				_run_start(s["on_start"])
	if current < steps.size() and steps[current].get("iv", false):
		_iv_steps_t += dt
		if _iv_steps_t > 150.0 and not _busy:
			_iv_steps_t = -1e9
			_sophie_takes_over()


func _run_start(f: Callable) -> void:
	f.call()


## Dialogue bloquant (le jeu est en pause pendant qu'on lit).
func _talk(lines: Array, focus := "") -> Array:
	_busy = true
	_focus_ui = focus
	var testing := game.args.has("autotest")
	var was_captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if not testing:
		game.get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var picked: Array = await game.dialogue.play(lines)
	if not testing:
		game.get_tree().paused = false
		if was_captured and game.state == "play" and not game.zone_view.active and not game.hud.any_panel_open():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_focus_ui = ""
	_busy = false
	return picked


func _did(kind: String) -> bool:
	return game.journal.has(kind)


func _has(id: String) -> bool:
	return game.inv.has(id)


func _syringe(drug: String) -> bool:
	return Story._has_syringe(game, drug)


func _skin(x: float, z: float) -> Vector3:
	return Vector3(x, Patient.body_height(x, z), z)


func _zone_pos(id: String) -> Vector3:
	var zs: Dictionary = game.patient.get("zones")
	if zs and zs.has(id):
		return (zs[id] as Node3D).global_position
	return Vector3(0.2, 1.0, 0.0)


func _interactable(id: String) -> Vector3:
	for n in game.room.find_children("*", "Interactable", true, false):
		if (n as Interactable).id == id:
			return (n as Node3D).global_position
	return Vector3.INF


func _neck() -> Vector3:
	var nk: Dictionary = Patient.landmarks.get("neck", {"x": 0.18, "half_width": 0.06})
	return _skin(float(nk["x"]), -float(nk.get("half_width", 0.06)) * 0.7)


func _finger(side := "R") -> Vector3:
	var p := Patient.lm("fingertip_" + side)
	return p if p != Vector3.ZERO else Patient.arm_point(side, 1.0)


func _next_electrode() -> Vector3:
	var placed: Dictionary = game.patient.gear.electrodes
	if not placed.has("RA"):
		return _skin(0.09, -0.12)
	if not placed.has("LA"):
		return _skin(0.09, 0.12)
	return _skin(-0.22, 0.1)


func _tutorial_steps() -> Array:
	var g := game
	return [
		{"title": "Regarde autour de toi", "text": "Bouge la souris pour tourner la tête. Repère le patient sur le brancard, le chariot d'urgence rouge et le scope au-dessus du lit.",
			"keys": ["Souris"], "input": true, "done": func() -> bool: return _look_acc > 1.2},
		{"title": "Déplace-toi", "text": "Marche avec Z Q S D (ou W A S D, ou les flèches). Fais quelques pas autour du brancard.",
			"keys": ["Z", "Q", "S", "D"], "input": true, "done": func() -> bool: return _walk_acc > 1.0},
		{"title": "Mets des gants", "text": "Vise la boîte de gants au mur avec le point au centre de l'écran, puis clique. On se protège toujours avant de toucher un patient.",
			"keys": ["Clic", "E"], "target": func() -> Vector3: return _interactable("gants"), "done": func() -> bool: return bool(g.flags.get("gants", false))},
		{"title": "Approche-toi de sa tête", "text": "Vise la tête du patient et clique : la vue rapprochée s'ouvre. La souris devient libre pour viser précisément ; clic droit maintenu pour tourner autour.",
			"keys": ["Clic"], "input": true, "target": func() -> Vector3: return _zone_pos("tete"), "done": func() -> bool: return g.zone_view.zone in ["tete", "cou"]},
		{"title": "Appelle-le", "text": "Avec les Mains (touche 1), clique sur son front : tu l'appelles fort et tu le secoues. Est-ce qu'il répond ?",
			"keys": ["1", "Clic"], "ui": ["hotbar:main"], "target": func() -> Vector3: return _skin(Patient.lm("nose_tip").x + 0.07, 0.0), "done": func() -> bool: return _did("stimulation")},
		{"title": "Vérifie qu'il respire", "text": "Maintiens le clic sur son menton : tu bascules sa tête en arrière et tu regardes si sa poitrine se soulève (5 secondes).",
			"keys": ["Clic maintenu"], "target": func() -> Vector3: return _skin(Patient.lm("nose_tip").x - 0.06, 0.0), "done": func() -> bool: return _did("respiration")},
		{"title": "Prends son pouls", "text": "Maintiens le clic sur le côté du cou, 3 secondes : c'est le pouls au cou (carotidien). Son cœur bat-il ?",
			"keys": ["Clic maintenu"], "target": func() -> Vector3: return _neck(), "done": func() -> bool: return _did("pouls")},
		{"title": "Reviens à la vue normale", "text": "Appuie sur Échap (ou sur « Revenir » en haut de l'écran) pour te relever.", "keys": ["Échap"], "input": true,
			"on_start": _start_sucre,
			"done": func() -> bool: return not g.zone_view.active},
		{"title": "Prends le lecteur de sucre", "text": "Va au chariot d'urgence (le meuble rouge à tiroirs), vise-le et clique. Onglet « Examen », puis « Lecteur de sucre (glycémie) ».",
			"keys": ["Clic"], "target": func() -> Vector3: return _interactable("chariot"), "ui": ["cart:tab:Examen", "cart:item:glucometre"],
			"done": func() -> bool: return _has("glucometre") or _did("glycemie")},
		{"title": "Mesure son sucre", "text": "Ferme le chariot (Échap). Vise sa main droite et clique, prends le lecteur (barre du bas), puis clique au bout d'un doigt.",
			"keys": ["Échap", "Clic"], "target": func() -> Vector3: return _finger("R"), "ui": ["hotbar:glucometre"], "done": func() -> bool: return _did("glycemie")},
		{"title": "Prends le matériel du scope", "text": "Au chariot, onglet « Surveillance » : prends les « Électrodes du scope » et la « Pince à oxygène ».",
			"target": func() -> Vector3: return _interactable("chariot"), "ui": ["cart:tab:Surveillance", "cart:item:electrodes", "cart:item:spo2"],
			"on_start": _start_scope,
			"done": func() -> bool: return (_has("electrodes") or _did("scope")) and (_has("spo2") or _did("spo2"))},
		{"title": "Colle les 3 électrodes", "text": "Vue rapprochée sur sa poitrine (thorax), électrodes en main : clique sous la clavicule droite, sous la clavicule gauche, puis en bas des côtes à gauche.",
			"keys": ["Clic"], "target": func() -> Vector3: return _next_electrode(), "ui": ["hotbar:electrodes"], "done": func() -> bool: return _did("scope")},
		{"title": "Pose la pince à oxygène", "text": "Pince en main (barre du bas), clique au bout d'un doigt (vue rapprochée sur une main).",
			"keys": ["Clic"], "target": func() -> Vector3: return _finger("L") if _did("glycemie") else _finger("R"), "ui": ["hotbar:spo2"], "done": func() -> bool: return _did("spo2")},
		{"title": "Pose la voie veineuse", "text": "Un petit tuyau souple dans une veine du bras, pour injecter les médicaments.",
			"on_start": _start_iv,
			"done": func() -> bool: return _did("vvp") or _iv_self},
		{"title": "Prends le matériel de perfusion", "text": "Au chariot, onglet « Perfusion » : garrot, désinfectant et cathéter 18G (vert).", "iv": true,
			"target": func() -> Vector3: return _interactable("chariot"), "ui": ["cart:tab:Perfusion", "cart:item:garrot", "cart:item:antiseptique", "cart:item:catheter18"],
			"done": func() -> bool: return _did("vvp") or (_has("garrot") and _has("antiseptique") and (_has("catheter18") or _has("catheter20")))},
		{"title": "Serre le garrot", "text": "Vue rapprochée sur son bras droit, garrot en main : clique au-dessus du coude. Les veines vont gonfler.", "iv": true,
			"keys": ["Clic"], "target": func() -> Vector3: return Patient.arm_point("R", 0.42), "ui": ["hotbar:garrot"], "done": func() -> bool: return _did("vvp") or _did("garrot")},
		{"title": "Désinfecte la peau", "text": "Désinfectant en main : maintiens le clic en frottant sur la veine gonflée de l'avant-bras.", "iv": true,
			"keys": ["Clic maintenu"], "target": func() -> Vector3: return Patient.arm_point("R", 0.62), "ui": ["hotbar:antiseptique"], "done": func() -> bool: return _did("vvp") or _did("desinfection")},
		{"title": "Pique la veine", "text": "Cathéter en main : clique sur la veine bleue gonflée, puis glisse vers le coude en gardant le clic enfoncé.", "iv": true,
			"keys": ["Clic", "Glisser"], "target": func() -> Vector3: return Patient.arm_point("R", 0.62), "ui": ["hotbar:catheter18", "hotbar:catheter20"], "done": func() -> bool: return _did("vvp")},
		{"title": "Desserre le garrot", "text": "Les Mains (touche 1) : clique sur le bras pour desserrer le garrot, sinon rien ne passera dans la veine.", "iv": true,
			"keys": ["1", "Clic"], "target": func() -> Vector3: return Patient.arm_point("R", 0.42), "ui": ["hotbar:main"],
			"done": func() -> bool: return _did("vvp") and g.patient.gear.tourniquet.is_empty()},
		{"title": "Prépare le sucre", "text": "Au chariot, onglet « Médicaments » : « Glucosé 30 % », dose 9 g, « Dans la veine (IV) », puis « Préparer la seringue ».",
			"target": func() -> Vector3: return _interactable("chariot"), "ui": ["cart:tab:Médicaments", "cart:drug:glucose30", "cart:dose:9 g", "cart:route:IV", "cart:prep"],
			"done": func() -> bool: return _syringe("glucose30") or _did("drug:glucose30") or _did("drug:glucagon")},
		{"title": "Injecte le sucre", "text": "Vue rapprochée sur son bras droit, seringue en main : maintiens le clic sur le robinet du cathéter (le bouchon coloré) jusqu'au bout de l'injection.",
			"keys": ["Clic maintenu"], "target": func() -> Vector3: return g.patient.gear.iv.get("port", Patient.arm_point("R", 0.6)) if g.patient.gear.has_iv() else Patient.arm_point("R", 0.6),
			"ui": ["hotbar:seringue"], "done": func() -> bool: return _did("drug:glucose30") or _did("drug:glucagon")},
		{"title": "Observe-le", "text": "Le sucre agit en quelques secondes… regarde son visage.", "done": func() -> bool: return _did("reveil")},
		{"title": "Recontrôle son sucre", "text": "Il se réveille ! Lecteur en main, mesure de nouveau le sucre au bout d'un doigt pour vérifier qu'il est bien remonté.",
			"keys": ["Clic"], "target": func() -> Vector3: return _finger("R"), "ui": ["hotbar:glucometre"],
			"on_start": _start_reveil,
			"done": func() -> bool: return bool(g.case.get("_rechecked"))},
		{"title": "Parle-lui", "text": "Approche-toi du lit et appuie sur T : pose-lui au moins 2 questions pour comprendre ce qui s'est passé.",
			"keys": ["T"], "ui": ["question:0", "question:1"], "done": func() -> bool: return g.journal.count("question") >= 2},
		{"title": "Conclus dans le dossier", "text": "Appuie sur Tab (dossier), onglet « Conclusion » : ce qu'il a (manque de sucre grave) et où il va (surveillance quelques heures). Puis valide.",
			"keys": ["Tab"], "ui": ["comp:tab:Conclusion", "comp:diag", "comp:orient", "comp:ok"],
			"on_start": _start_conclusion,
			"done": func() -> bool: return g._ended},
	]


func _sophie_takes_over() -> void:
	await _talk([Story.L("sophie", "Pas facile, hein ? Laisse, je m'en occupe. Regarde bien comment je fais : garrot, désinfection, et je pique là où la veine gonfle.")])
	nurse_iv()


func _start_sucre() -> void:
	await _talk([Story.L("sophie", "Il respire, son cœur bat… mais il ne se réveille pas, et il est trempé de sueur."),
		Story.L("sophie", "Chez un diabétique, il y a un réflexe à avoir : mesurer le sucre dans le sang. C'est la glycémie. Allons chercher le lecteur.")])


func _start_scope() -> void:
	var gl := ("%.2f" % game.physio.glyc).replace(".", ",") if game.physio.glyc < 0.6 else "0,32"
	await _talk([Story.L("sophie", "%s g/L ! Normalement, c'est autour de 1. Son cerveau manque de sucre : c'est une hypoglycémie sévère. Bien vu !" % gl),
		Story.L("sophie", "On va lui donner du sucre directement dans la veine. Mais d'abord, on le branche au scope pour surveiller son cœur et son oxygène.")])


func _start_iv() -> void:
	var ch := await _talk([Story.L("sophie", "Regarde en haut à droite : ses constantes. Le cœur, l'oxygène dans le sang, la tension, la respiration. Vert c'est normal, orange à surveiller, rouge danger."),
		{"who": "sophie", "text": "Pour le sucre, il faut une voie veineuse : un petit tuyau dans une veine du bras. C'est un geste délicat. Tu veux essayer ?", "choices": [
			Story.C("Je veux essayer !", [Story.L("sophie", "D'accord ! Je te guide.")], "iv_self"),
			Story.C("Montre-moi d'abord.", [Story.L("sophie", "Regarde bien : garrot, désinfection, et je pique là où la veine gonfle. Tu le feras au prochain patient.")], "iv_sophie"),
		]}], "vitals")
	_iv_self = "iv_self" in ch
	if not _iv_self:
		nurse_iv()


func _start_reveil() -> void:
	await _talk([Story.L("sophie", "Il ouvre les yeux ! Bravo, tu viens de lui éviter de graves séquelles au cerveau."),
		Story.L("sophie", "Le sucre peut redescendre : l'insuline agit encore. Contrôle sa glycémie, puis discute avec lui.")])


func _start_conclusion() -> void:
	await _talk([Story.L("patient", "Je suis désolé… j'ai fait mon insuline à midi par habitude, mais je n'ai pas mangé."),
		Story.L("sophie", "Dernière étape : on écrit dans le dossier ce qu'il a et où il va. Le Dr Marchand relira.")])


# ---------------------------------------------------------------- Conseils

func _update_rules() -> void:
	if _bark_cool > 0.0 or game._ended:
		return
	for i in rules.size():
		var r: Dictionary = rules[i]
		var last: float = _rule_t.get(i, -INF)
		if last > -INF:
			var rep: float = r.get("repeat", 0.0)
			if rep <= 0.0 or game.physio.time - last < rep:
				continue
		var cond: Callable = r["when"]
		if not cond.call(game):
			continue
		_rule_t[i] = game.physio.time
		_bark_cool = 7.0
		if r.get("offer_iv", false):
			if game.args.has("autotest"):
				return
			_offer_iv(r)
		else:
			game.dialogue.bark(r["who"], r["text"])
		return


func _offer_iv(r: Dictionary) -> void:
	var ch := await _talk([{"who": r["who"], "text": r["text"], "choices": [
		Story.C("Oui, merci Sophie !", [Story.L("sophie", "C'est parti. Continue, je m'occupe du bras.")], "oui"),
		Story.C("Non, je m'en occupe.", [Story.L("sophie", "D'accord, le matériel est dans le chariot, onglet Perfusion.")], "non"),
	]}])
	if "oui" in ch:
		await get_tree().create_timer(3.0, false).timeout
		nurse_iv()


## Sophie pose la voie veineuse (et fait la prise de sang).
func nurse_iv() -> void:
	var gear: PatientGear = game.patient.gear
	if gear.has_iv():
		return
	var side := "R"
	var p := Patient.arm_point(side, 0.62)
	var vv = game.gestures.get("veins")
	if vv is Dictionary and (vv as Dictionary).has(side) and (vv[side] as PackedVector3Array).size() > 3:
		p = (vv[side] as PackedVector3Array)[3]
	var toward := (Patient.arm_point(side, 0.0) - Patient.arm_point(side, 1.0)).normalized()
	if gear.has_method("place_iv"):
		gear.call("place_iv", side, p, toward, Color(0.2, 0.7, 0.3))
	game.event("vvp", "Voie veineuse posée par Sophie (infirmière)")
	game.event("prelevement", "Prise de sang faite par Sophie et envoyée au laboratoire")
	game.toast("Sophie a posé la voie veineuse au bras droit")
	Sfx.play("succes", Vector3.INF, -16.0)


# ---------------------------------------------------------------- Surbrillance

## Ce qui est montré du doigt : endroit dans la salle et boutons de l'interface.
func highlight() -> Dictionary:
	var out := {"world": Vector3.INF, "ui": []}
	if _focus_ui != "":
		out["ui"] = [_focus_ui]
		return out
	if _busy or current < 0 or current >= steps.size():
		return out
	var s: Dictionary = steps[current]
	var ui: Array = s.get("ui", [])
	var shown := []
	for id in ui:
		if game.hud.get_mark(id):
			shown.append(id)
	out["ui"] = shown
	if s.has("target") and not game.hud.any_panel_open():
		var f: Callable = s["target"]
		out["world"] = f.call()
	return out


## Calque de surbrillance : anneau pulsant + flèche sur l'endroit dans la salle (ou flèche au bord
## de l'écran s'il est hors champ) ; cadre lumineux autour des boutons à utiliser.
class Overlay:
	extends Control
	var guide: Guide
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if guide == null or guide.game == null or guide.game.state != "play":
			return
		var h := guide.highlight()
		var col := UIKit.WARN
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		for id in h["ui"]:
			var c: Control = guide.game.hud.get_mark(id)
			if c == null:
				c = guide.game.hud.marks.get(id)
				if c == null or not is_instance_valid(c) or not c.is_visible_in_tree():
					continue
			var r := c.get_global_rect().grow(5.0 + pulse * 4.0)
			draw_rect(r, Color(col, 0.08 + 0.08 * pulse), true)
			_round_rect(r, Color(col, 0.6 + 0.4 * pulse), 3.0)
			# Petite flèche à gauche du bouton
			var tip := Vector2(r.position.x - 6.0 - pulse * 6.0, r.get_center().y)
			_arrow(tip, Vector2.RIGHT, col, 22.0)
		var w: Vector3 = h["world"]
		if w == Vector3.INF:
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var vs := get_viewport_rect().size
		var behind := cam.is_position_behind(w)
		var sp := cam.unproject_position(w)
		var margin := 70.0
		var inside := not behind and sp.x > margin and sp.y > margin and sp.x < vs.x - margin and sp.y < vs.y - margin
		if inside:
			var r2 := 22.0 + pulse * 8.0
			draw_arc(sp, r2, 0, TAU, 40, Color(0, 0, 0, 0.4), 7.0, true)
			draw_arc(sp, r2, 0, TAU, 40, col, 3.5, true)
			draw_arc(sp, r2 + 12.0 + pulse * 6.0, 0, TAU, 40, Color(col, 0.35 * (1.0 - pulse)), 2.0, true)
			var bob := sin(_t * 4.0) * 8.0
			_arrow(sp + Vector2(0, -r2 - 10.0 - bob), Vector2.DOWN, col, 30.0)
		else:
			var c2 := vs * 0.5
			var d := sp - c2
			if behind:
				d = -d
			if d.length() < 1.0:
				d = Vector2.DOWN
			var dir := d.normalized()
			var k := minf((vs.x * 0.5 - margin) / maxf(absf(dir.x), 0.001), (vs.y * 0.5 - margin) / maxf(absf(dir.y), 0.001))
			var p := c2 + dir * k
			draw_circle(p - dir * 12.0, 30.0, Color(0, 0, 0, 0.45))
			_arrow(p + dir * (pulse * 6.0), dir, col, 34.0)

	func _arrow(tip: Vector2, dir: Vector2, col: Color, size: float) -> void:
		var n := Vector2(-dir.y, dir.x)
		var base := tip - dir * size
		var pts := PackedVector2Array([tip, base + n * size * 0.55, base + dir * size * 0.25, base - n * size * 0.55])
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(2, 3))
		draw_colored_polygon(sh, Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, col)

	func _round_rect(r: Rect2, col: Color, w: float) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = col
		sb.set_border_width_all(int(w))
		sb.set_corner_radius_all(12)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
