class_name Procedure
extends Node
## Déroulé guidé de l'appendicectomie : une étape à la fois, instrument en surbrillance,
## repère lumineux, progression, messages, chrono et erreurs.

signal finished(seconds: float, errors: int)

const STEPS := [
	{"id": "badigeon", "list": "Désinfection", "inst": "mikulicz",
		"title": "Désinfecte la peau",
		"text": "Prends la pince à badigeon et frotte toute la zone de peau en gardant la gâchette appuyée, jusqu'à 100 %."},
	{"id": "incision", "list": "Incision", "inst": "bistouri",
		"title": "Incise la peau",
		"text": "Pose la lame sur le point « DÉPART » et suis le pointillé violet, gâchette appuyée, d'un seul geste."},
	{"id": "ecarteur1", "list": "Écarteur 1", "inst": "langenbeck",
		"title": "Écarte le premier bord",
		"text": "Amène l'écarteur de Langenbeck sur le repère, au bord de la plaie, puis appuie sur la gâchette pour le poser."},
	{"id": "ecarteur2", "list": "Écarteur 2", "inst": "roux",
		"title": "Écarte l'autre bord",
		"text": "Pose l'écarteur de Roux sur le repère de l'autre bord. La plaie s'ouvre : on voit le cæcum et l'appendice."},
	{"id": "saisie", "list": "Sortir l'appendice", "inst": "debakey",
		"title": "Sors l'appendice",
		"text": "Avec la pince De Bakey, attrape la pointe de l'appendice (gâchette) et soulève-la hors de la plaie sans lâcher."},
	{"id": "ligature", "list": "Ligature", "inst": "overholt",
		"title": "Ligature la base",
		"text": "Amène le fil sur le repère à la base de l'appendice et appuie sur la gâchette pour serrer le nœud."},
	{"id": "section", "list": "Section", "inst": "ciseaux",
		"title": "Coupe l'appendice",
		"text": "Place les ciseaux sur le repère, juste au-dessus de la ligature, et appuie sur la gâchette."},
	{"id": "retrait", "list": "Retrait", "inst": "debakey",
		"title": "Dépose l'appendice",
		"text": "Attrape l'appendice coupé avec la pince (gâchette maintenue) et lâche-le au-dessus du haricot métallique."},
	{"id": "suture", "list": "Suture", "inst": "porte_aiguille",
		"title": "Referme la peau",
		"text": "Les écarteurs sont retirés. Avec le porte-aiguille, touche les 4 points de suture un par un (gâchette)."},
]
const STITCH_T := [0.15, 0.38, 0.62, 0.85]

var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var hands: Array[SurgeonHand] = []
var uis: Array[GuideUI] = []
var hud: DesktopHUD
var is_vr := false

var step := -1  # -1 = accueil, STEPS.size() = terminé
var elapsed := 0.0
var errors := 0
var running := false

var marker: TargetMarker
var marker2: TargetMarker
var _wrong_counted := false
var _sound_cd := 0.0
var _incision := 0.0
var _grab_hand: SurgeonHand
var _piece: Node3D
var _piece_home: Vector3
var _piece_offset := Vector3.ZERO
var _stitch_i := 0
var _parked: Array[Instrument] = []


func setup() -> void:
	marker = TargetMarker.new()
	marker2 = TargetMarker.new()
	add_child(marker)
	add_child(marker2)
	var titles := []
	for s in STEPS:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	for h in hands:
		h.instruments = tray.ordered
		h.take_requested.connect(_on_take)
		h.put_back_requested.connect(_on_put_back)
	_show_intro()


func _hint() -> String:
	if is_vr:
		return "GRIP : prendre / reposer un instrument (ou vise-le de loin)   ·   GÂCHETTE : agir   ·   B/Y : recentrer"
	return "Clic : prendre   ·   Clic maintenu : agir   ·   Molette : lever / baisser   ·   R : reposer   ·   1-8 : choisir un instrument"


func _ui_step(title: String, text: String, inst_label: String) -> void:
	for ui in uis:
		ui.show_step(step, STEPS.size(), title, text, inst_label, _hint())


func _ui_progress(v: float, caption: String) -> void:
	for ui in uis:
		ui.set_progress(v, caption)


func _toast(text: String, ok := true) -> void:
	for ui in uis:
		ui.toast(text, ok)


func _show_intro() -> void:
	step = -1
	var go := "Appuie sur A (manette droite) pour commencer." if is_vr else "Appuie sur ESPACE pour commencer."
	_ui_step("Bienvenue au bloc",
		"Léa, 24 ans : appendicite aiguë confirmée au scanner. Elle est endormie et installée. Tu vas faire l'appendicectomie, étape par étape. Suis les consignes et les repères lumineux.\n" + go, "")


## Bouton A / Espace
func on_continue() -> void:
	if step == -1:
		running = true
		_enter_step(0)
	elif step >= STEPS.size():
		get_tree().reload_current_scene()


func required_id() -> String:
	return STEPS[step]["inst"] if step >= 0 and step < STEPS.size() else ""


func _enter_step(i: int) -> void:
	step = i
	_wrong_counted = false
	if step >= STEPS.size():
		_finish()
		return
	var s: Dictionary = STEPS[step]
	var inst: Instrument = tray.instruments[s["inst"]]
	_ui_step(s["title"], s["text"], inst.label)
	if hud:
		hud.mark_required(s["inst"])
	match s["id"]:
		"badigeon":
			_ui_progress(0.0, "Zone désinfectée : 0 %")
		"incision":
			_ui_progress(0.0, "Incision : 0 %")
		"suture":
			_stitch_i = 0
			_ui_progress(0.0, "Points : 0 / 4")
		_:
			_ui_progress(0.0, "")


func _complete_step(msg: String) -> void:
	_toast(msg, true)
	Sfx.play("etape", Vector3.INF, -4.0)
	for h in hands:
		h.pulse(0.6, 0.12)
	_enter_step(step + 1)


func _finish() -> void:
	running = false
	marker.visible = false
	marker2.visible = false
	for inst in tray.ordered:
		inst.set_highlight(0)
	var stars := 3 if errors == 0 else (2 if errors <= 2 else 1)
	if elapsed > 480.0:
		stars = maxi(1, stars - 1)
	Sfx.play("fin", Vector3.INF, -2.0)
	var again := "Appuie sur A pour recommencer." if is_vr else "Appuie sur ESPACE pour recommencer."
	for ui in uis:
		ui.show_end(elapsed, errors, stars, again)
	finished.emit(elapsed, errors)


# ---------------------------------------------------------------- Prendre / reposer

func _on_take(hand: SurgeonHand, inst: Instrument) -> void:
	for h in hands:
		if h != hand and h.held == inst:
			return
	if inst in _parked:
		_toast("Cet écarteur tient la plaie ouverte : laisse-le en place.", false)
		return
	hand.take(inst)
	Sfx.play("prise", inst.global_position, -6.0)
	var req := required_id()
	if running and req != "" and inst.id != req:
		var good: Instrument = tray.instruments[req]
		_toast("Pas celui-là : prends « %s »" % good.label, false)
		Sfx.play("erreur", Vector3.INF, -6.0)
		if not _wrong_counted:
			errors += 1
			_wrong_counted = true


func _on_put_back(hand: SurgeonHand) -> void:
	if hand.held == null:
		return
	if _grab_hand == hand:
		_release_grab(false)
	Sfx.play("pose", hand.held.global_position, -8.0)
	hand.put_back()


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if running:
		elapsed += delta
	_sound_cd -= delta
	for ui in uis:
		ui.set_status(elapsed, errors)

	# Surbrillances : instrument demandé (cyan) et instrument survolé (blanc)
	var req := required_id()
	for inst in tray.ordered:
		var mode := 0
		var is_held := false
		for h in hands:
			if h.held == inst:
				is_held = true
			elif h.hovered == inst:
				mode = 2
		if mode == 0 and inst.id == req and not is_held and running:
			mode = 1
		inst.set_highlight(0 if is_held else mode)

	if not running or step < 0 or step >= STEPS.size():
		marker.visible = false
		marker2.visible = false
		return

	var target := _target()
	for h in hands:
		var ok := h.held != null and h.held.id == req
		h.assist_target = target if ok else Vector3.INF
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = 0.0
	match STEPS[step]["id"]:
		"badigeon": _tick_badigeon(delta)
		"incision": _tick_incision(delta)
		"ecarteur1": _tick_retractor(-1.0)
		"ecarteur2": _tick_retractor(1.0)
		"saisie": _tick_saisie(delta)
		"ligature": _tick_ligature()
		"section": _tick_section()
		"retrait": _tick_retrait(delta)
		"suture": _tick_suture()


## Cible de l'étape en cours (pour le repère et l'aide au placement).
func _target() -> Vector3:
	marker2.visible = false
	match STEPS[step]["id"]:
		"badigeon":
			marker.show_at(patient.center + Vector3.UP * 0.003, "Zone à désinfecter", 3.5)
			return Vector3.INF
		"incision":
			var p := patient.incision_point(maxf(_incision, 0.0))
			marker.show_at(p + Vector3.UP * 0.002, "DÉPART" if _incision < 0.02 else "", 0.8)
			marker2.show_at(patient.incision_point(1.0) + Vector3.UP * 0.002, "ARRIVÉE", 0.6)
			return Vector3.INF
		"ecarteur1":
			var p := patient.retractor_slot(-1.0)
			marker.show_at(p, "Écarteur ici")
			return p
		"ecarteur2":
			var p := patient.retractor_slot(1.0)
			marker.show_at(p, "Écarteur ici")
			return p
		"saisie":
			var p := patient.appendix_tip
			marker.show_at(p, "Pointe de l'appendice" if _grab_hand == null else "Soulève !", 0.9)
			return p
		"ligature":
			var p := patient.appendix_point(0.18)
			marker.show_at(p, "Ligature ici", 0.8)
			return p
		"section":
			var p := patient.appendix_point(0.32)
			marker.show_at(p, "Couper ici", 0.8)
			return p
		"retrait":
			if _grab_hand:
				marker.show_at(tray.dish_center, "Lâche ici", 2.5)
				return tray.dish_center
			var p := _piece.global_position if _piece else patient.center
			marker.show_at(p, "Attrape l'appendice", 0.9)
			return p
		"suture":
			if _stitch_i < STITCH_T.size():
				var p := patient.incision_point(STITCH_T[_stitch_i]) + Vector3.UP * 0.001
				marker.show_at(p, "Point %d" % (_stitch_i + 1), 0.6)
				return p
	marker.visible = false
	return Vector3.INF


func _active_hands() -> Array[SurgeonHand]:
	var out: Array[SurgeonHand] = []
	var req := required_id()
	for h in hands:
		if h.held and h.held.id == req:
			out.append(h)
	return out


func _near(h: SurgeonHand, p: Vector3, radius: float) -> bool:
	return h.tip().distance_to(p) < radius * (1.25 if is_vr else 1.0)


func _skin_contact(p: Vector3, above := 0.018) -> bool:
	var skin := Patient.body_height(p.x, p.z)
	return p.y < skin + above and p.y > skin - 0.03


# ---------------------------------------------------------------- Étapes

func _tick_badigeon(_delta: float) -> void:
	for h in _active_hands():
		var p := h.tip()
		if h.trigger_down() and _skin_contact(p, 0.022):
			var cov := patient.paint_iodine(p)
			_ui_progress(cov / 0.85, "Zone désinfectée : %d %%" % int(minf(cov / 0.85, 1.0) * 100))
			if _sound_cd <= 0.0:
				Sfx.play("badigeon", p, -10.0, randf_range(0.9, 1.1))
				_sound_cd = 0.18
				h.pulse(0.15, 0.03)
			if cov >= 0.85:
				patient.fill_iodine()
				_complete_step("Peau désinfectée !")
				return


func _tick_incision(_delta: float) -> void:
	for h in _active_hands():
		var p := h.tip()
		var proj := patient.incision_project(p)
		var t := proj.x
		var on_line := proj.y < (0.012 if is_vr else 0.009)
		if h.trigger_down() and on_line and _skin_contact(p, 0.014) and t <= _incision + 0.12 and t > _incision:
			_incision = t
			patient.incision_progress = _incision
			monitor.stress(14.0)
			_ui_progress(_incision, "Incision : %d %%" % int(_incision * 100))
			if _sound_cd <= 0.0:
				Sfx.play("incision", p, -6.0, randf_range(0.9, 1.15))
				_sound_cd = 0.12
			h.pulse(0.25, 0.02)
			if _incision >= 0.96:
				_finish_incision()
				_complete_step("Belle incision !")
				return


func _finish_incision() -> void:
	_incision = 1.0
	patient.incision_progress = 1.0
	monitor.stress(4.0)
	_tween_opening(0.25, 0.6)


func _tween_opening(v: float, dur: float) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(patient, "opening", v, dur)


func _retractor_pose(inst: Instrument, side: float) -> Transform3D:
	var slot := patient.retractor_slot(side)
	# Lame crochetée sous le bord de la plaie, manche couché vers l'extérieur
	var tip := slot - Vector3.UP * 0.022 - patient.perp3 * side * 0.004
	var axis := (-patient.perp3 * side * 0.93 - Vector3.UP * 0.36).normalized()
	return inst.tip_transform(tip, axis, Vector3.UP)


func _tick_retractor(side: float) -> void:
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, patient.retractor_slot(side), 0.035):
			_place_retractor(h.held, side)
			h.release_parked()
			Sfx.play("pose", patient.center, -4.0)
			_complete_step("Écarteur en place")
			return


func _place_retractor(inst: Instrument, side: float, instant := false) -> void:
	_parked.append(inst)
	var xf := _retractor_pose(inst, side)
	if instant:
		inst.held = false
		inst.parked = true
		inst.global_transform = xf
	else:
		inst.park(xf)
	if instant:
		patient.opening = 0.6 if side < 0 else 1.0
	else:
		_tween_opening(0.6 if side < 0 else 1.0, 0.8)


func lifted_tip() -> Vector3:
	return patient.center + Vector3.UP * 0.035 - patient.dir3 * 0.012 + patient.perp3 * 0.004


func _tick_saisie(delta: float) -> void:
	if _grab_hand:
		var h := _grab_hand
		if h.held == null or not h.trigger_down():
			_release_grab(true)
			_toast("L'appendice a glissé : garde la gâchette appuyée.", false)
			return
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = 0.07
		patient.set_appendix_tip(patient.appendix_tip.lerp(h.tip(), 1.0 - exp(-delta * 18.0)))
		var goal := patient.center.y + 0.012
		var rest := patient.appendix_rest_tip.y
		var v := clampf((patient.appendix_tip.y - rest) / (goal - rest), 0.0, 1.0)
		_ui_progress(v, "Soulève encore…" if v < 1.0 else "")
		h.pulse(0.1, 0.02)
		if v >= 1.0:
			_grab_hand = null
			_finish_saisie(false)
			_complete_step("Appendice extériorisé — l'aide le maintient")
		return
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, patient.appendix_tip, 0.03):
			_grab_hand = h
			Sfx.play("prise", patient.appendix_tip, -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


func _finish_saisie(instant: bool) -> void:
	if instant:
		patient.set_appendix_tip(lifted_tip())
	else:
		var from := patient.appendix_tip
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_method(func(k: float) -> void: patient.set_appendix_tip(from.lerp(lifted_tip(), k)), 0.0, 1.0, 0.5)


func _release_grab(spring_back: bool) -> void:
	var h := _grab_hand
	_grab_hand = null
	if h is DesktopHand:
		(h as DesktopHand).auto_lift = 0.0
	if spring_back and step >= 0 and STEPS[step]["id"] == "saisie":
		var from := patient.appendix_tip
		var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(k: float) -> void: patient.set_appendix_tip(from.lerp(patient.appendix_rest_tip, k)), 0.0, 1.0, 0.7)
	if step >= 0 and step < STEPS.size() and STEPS[step]["id"] == "retrait" and _piece:
		_drop_piece()


func _tick_ligature() -> void:
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, patient.appendix_point(0.18), 0.03):
			patient.ligate()
			Sfx.play("fil", patient.center, -4.0)
			_complete_step("Nœud serré")
			return


func _tick_section() -> void:
	for h in _active_hands():
		if h.trigger_just_pressed():
			if _near(h, patient.appendix_point(0.32), 0.03):
				_do_cut()
				Sfx.play("ciseaux", patient.center, -2.0)
				_complete_step("Appendice sectionné")
				return
			elif _near(h, patient.center, 0.08):
				_toast("Coupe sur le repère, au-dessus de la ligature.", false)
				Sfx.play("erreur", Vector3.INF, -8.0)


func _do_cut() -> void:
	_piece = patient.cut()
	_piece_home = _piece.global_position


func _tick_retrait(delta: float) -> void:
	if _piece == null:
		return
	if _grab_hand:
		var h := _grab_hand
		if h.held == null or not h.trigger_down():
			_release_grab(false)
			return
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = 0.05
		_piece.global_position = _piece.global_position.lerp(h.tip() + _piece_offset, 1.0 - exp(-delta * 20.0))
		var flat := Vector2(_piece.global_position.x - tray.dish_center.x, _piece.global_position.z - tray.dish_center.z).length()
		_ui_progress(1.0 - clampf(flat / 0.5, 0.0, 1.0), "Direction : le haricot")
		return
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, _piece.global_position, 0.04):
			_grab_hand = h
			_piece_offset = (_piece.global_position - h.tip()).limit_length(0.02)
			Sfx.play("prise", _piece.global_position, -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


func _drop_piece() -> void:
	var flat := Vector2(_piece.global_position.x - tray.dish_center.x, _piece.global_position.z - tray.dish_center.z).length()
	var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if flat < (0.11 if is_vr else 0.09):
		tw.tween_property(_piece, "global_position", tray.dish_center + Vector3.UP * 0.008, 0.35)
		tw.tween_callback(func() -> void: Sfx.play("pose", tray.dish_center, -6.0, 0.7))
		_finish_retrait(false)
		_complete_step("Appendice dans le haricot")
	else:
		tw.tween_property(_piece, "global_position", _piece_home, 0.4)
		_toast("Lâche-le au-dessus du haricot.", false)


func _finish_retrait(instant: bool) -> void:
	if instant and _piece:
		_piece.global_position = tray.dish_center + Vector3.UP * 0.008
	# Les écarteurs retournent sur la table, la plaie se referme à moitié
	for inst in _parked:
		if instant:
			inst.parked = false
			inst.global_transform = inst.tray_transform
		else:
			inst.return_to_tray()
	_parked.clear()
	if instant:
		patient.opening = 0.3
	else:
		_tween_opening(0.3, 0.8)


func _tick_suture() -> void:
	for h in _active_hands():
		if _stitch_i >= STITCH_T.size():
			return
		var p := patient.incision_point(STITCH_T[_stitch_i])
		if h.trigger_just_pressed() and _near(h, p, 0.022):
			_stitch(false)
			h.pulse(0.3, 0.05)
			if _stitch_i >= STITCH_T.size():
				_complete_step("Peau refermée !")
			return


func _stitch(instant: bool) -> void:
	patient.add_stitch(STITCH_T[_stitch_i])
	_stitch_i += 1
	var left := 0.3 * (1.0 - float(_stitch_i) / STITCH_T.size())
	if instant:
		patient.opening = left
	else:
		Sfx.play("fil", patient.center, -6.0)
		_tween_opening(left, 0.4)
	_ui_progress(float(_stitch_i) / STITCH_T.size(), "Points : %d / 4" % _stitch_i)
	if _stitch_i >= STITCH_T.size():
		patient.set_stitched(1.0)


## Saute directement à l'étape n (tests, captures) en appliquant les étapes précédentes.
func skip_to(n: int) -> void:
	running = true
	for i in mini(n, STEPS.size()):
		match STEPS[i]["id"]:
			"badigeon":
				patient.fill_iodine()
			"incision":
				_incision = 1.0
				patient.incision_progress = 1.0
				patient.opening = 0.25
			"ecarteur1":
				_place_retractor(tray.instruments["langenbeck"], -1.0, true)
			"ecarteur2":
				_place_retractor(tray.instruments["roux"], 1.0, true)
			"saisie":
				_finish_saisie(true)
			"ligature":
				patient.ligate()
			"section":
				_do_cut()
			"retrait":
				_finish_retrait(true)
			"suture":
				_stitch_i = 0
				for k in STITCH_T.size():
					_stitch(true)
	_enter_step(n)
