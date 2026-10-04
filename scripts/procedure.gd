class_name Procedure
extends Node
## Moteur de l'opération guidée : menu de choix, une étape à la fois, instrument en surbrillance,
## repère lumineux, messages, chrono et erreurs. Les gestes sont physiques et continus : rien ne se
## déclenche en remplissant une barre. L'effet suit la main en direct :
##   paint   : la compresse badigeonne là où elle touche la peau
##   incise  : la lame coupe là où elle entre dans la peau, le long du tracé
##   inject  : l'aiguille pique, le pouce pousse le piston, le liquide baisse, un bouton gonfle
##   retract : l'écarteur accroche un bord et l'étire ; relâché, le bord se détend
##   spread  : la pince entre et ouvre ses mors pour écarter les tissus, puis va plus profond
##   lift    : la pince saisit (mors serrés) et soulève ; lâchée, la pièce retombe
##   ligate  : l'Overholt passe le fil (mors serrés) puis on tire pour serrer le nœud
##   cut     : les ciseaux s'ouvrent autour de la cible et coupent en se fermant
##   carry   : la pince saisit un objet et le lâche ; il tombe pour de vrai
##   suture  : l'aiguille entre d'un côté, ressort de l'autre, le point se noue
##   insert  : le drain glisse dans l'orifice jusqu'à la bonne profondeur
##   hold    : la pointe reste sur la cible (aspiration)        place : toucher la cible et serrer

signal finished(seconds: float, errors: int)

const MENU := -2
const INTRO := -1
const GRAVITY := 9.8

## Opération choisie (garde sa valeur quand la scène est rechargée)
static var op_id := "appendicectomie"
static var start_at_intro := false
static var restarts := 0

var op: Operation
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var hands: Array[SurgeonHand] = []
var uis: Array[GuideUI] = []
var hud: DesktopHUD
var touch_menu: TouchMenu
var is_vr := false

var step := MENU
var elapsed := 0.0
var errors := 0
var running := false
var show_markers := true  ## faux pour les captures « propres »
var menu_index := 0
var parked: Array[Instrument] = []  ## instruments posés hors de la main (écarteurs, drain...)
## Anesthésie locale : instant (ms) où elle fait effet (0 = pas d'anesthésie locale en cours)
var anesthesia_ready_at := 0

var marker: TargetMarker
var marker2: TargetMarker
var st := {}  ## état de l'étape en cours
var _wrong_counted := false
var _hint_cd := 0.0
var _finished_at := 0
var _thread: MeshInstance3D
var _hover_label: Label3D
var _drops: Array[Dictionary] = []


var steps: Array:
	get:
		return op.steps


func setup() -> void:
	marker = TargetMarker.new()
	marker2 = TargetMarker.new()
	add_child(marker)
	add_child(marker2)
	for h in hands:
		h.instruments = tray.ordered
		h.take_requested.connect(_on_take)
		h.put_back_requested.connect(_on_put_back)
	menu_index = Operation.ALL.find(op.id)
	Contact.patient = patient
	Contact.clear_zones()
	# Nom de l'instrument que la main s'apprête à prendre (casque)
	_hover_label = Label3D.new()
	_hover_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hover_label.no_depth_test = true
	_hover_label.render_priority = 12
	_hover_label.font = load("res://assets/fonts/Inter.ttf")
	_hover_label.font_size = 36
	_hover_label.outline_size = 8
	_hover_label.pixel_size = 0.00045
	_hover_label.outline_modulate = Color(0, 0, 0, 0.75)
	_hover_label.visible = false
	add_child(_hover_label)
	if start_at_intro:
		start_at_intro = false
		_show_intro()
	else:
		_show_menu()


func _hint() -> String:
	if is_vr:
		return "Mains nues : PINCE pour prendre · serre / desserre le pouce pour fermer / ouvrir · OUVRE GRAND la main pour lâcher\nManettes : GRIP prendre / reposer · GÂCHETTE serrer · B recentrer"
	return "Clic : prendre   ·   Clic maintenu : appuyer / serrer   ·   Molette : lever / baisser   ·   R : reposer   ·   1-8 : choisir un instrument"


func _ui_step(title: String, text: String, inst_label: String) -> void:
	for ui in uis:
		ui.show_step(step, steps.size(), title, text, inst_label, _hint())


func _caption(text: String) -> void:
	for ui in uis:
		ui.set_progress(0.0, text)


func _toast(text: String, ok := true) -> void:
	for ui in uis:
		ui.toast(text, ok)


# ---------------------------------------------------------------- Menu, accueil, fin

func _show_menu() -> void:
	step = MENU
	running = false
	var entries := Operation.menu_entries()
	var lines := ""
	for i in entries.size():
		lines += ("▶  " if i == menu_index else "     ") + "%d.  %s\n" % [i + 1, entries[i][0]]
	lines += "\n" + entries[menu_index][1] + "\n\n"
	lines += "Touche une opération du bout du doigt." if is_vr else "Flèches haut / bas (ou 1-%d) pour choisir, ESPACE pour valider." % entries.size()
	for ui in uis:
		ui.set_steps([])
		ui.show_step(-2, 0, "Choisis ton opération", lines, "", _hint())
	if touch_menu:
		var labels := []
		for e in entries:
			labels.append(e[0])
		touch_menu.show_menu(labels, menu_index)


## Stick / flèches dans le menu.
func menu_move(delta_i: int) -> void:
	if step != MENU:
		return
	menu_index = wrapi(menu_index + delta_i, 0, Operation.ALL.size())
	Sfx.play("pose", Vector3.INF, -12.0, 1.4)
	_show_menu()


func menu_select(i: int) -> void:
	if step != MENU or i < 0 or i >= Operation.ALL.size():
		return
	menu_index = i
	_show_menu()


## Bouton touché du doigt (menu tactile en VR).
func on_touch_button(action: String) -> void:
	if action.begins_with("op:"):
		menu_select(int(action.substr(3)))
		on_continue()
	elif action == "start" or action == "again":
		on_continue()
	elif action == "menu":
		restarts += 1
		get_tree().reload_current_scene()


func _show_intro() -> void:
	step = INTRO
	var titles := []
	for s in steps:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	var go := "Touche « Commencer » (ou pince pouce-index, ou A)." if is_vr else "Appuie sur ESPACE pour commencer."
	_ui_step(op.name, op.intro_text + "\n" + go, "")
	if touch_menu:
		touch_menu.show_buttons([["Commencer", "start"], ["Changer d'opération", "menu"]])


## Pincement main nue : navigation sans manettes.
func on_hand_pinch(left: bool) -> void:
	match step:
		MENU:
			if left:
				on_continue()
			else:
				menu_move(1)
		INTRO:
			on_continue()
		_:
			if step >= steps.size() and left and Time.get_ticks_msec() - _finished_at > 1500:
				on_continue()


## Bouton A / Espace
func on_continue() -> void:
	match step:
		MENU:
			var chosen: String = Operation.ALL[menu_index]
			if chosen != op.id:
				op_id = chosen
				start_at_intro = true
				get_tree().reload_current_scene()
			else:
				_show_intro()
		INTRO:
			running = true
			op.on_start()
			if touch_menu:
				touch_menu.show_buttons([])
			_enter_step(0)
		_:
			if step >= steps.size():
				restarts += 1
				get_tree().reload_current_scene()


func required_id() -> String:
	return steps[step]["inst"] if step >= 0 and step < steps.size() else ""


func current() -> Dictionary:
	return steps[step] if step >= 0 and step < steps.size() else {}


func _enter_step(i: int) -> void:
	step = i
	_wrong_counted = false
	st = {"t": 0.0}
	_set_thread(false)
	if step >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[step]
	var inst: Instrument = tray.instruments[s["inst"]]
	_ui_step(s["title"], s["text"], inst.label)
	_caption("")
	if hud:
		hud.mark_required(s["inst"])
	if s["kind"] == "inject":
		# Seringue pleine pour chaque injection (anesthésie, puis sérum de lavage)
		inst.set_volume(1.0)
	if s.has("enter"):
		s["enter"].call()


func _complete_step(msg := "") -> void:
	_toast(msg if msg != "" else current().get("done_msg", "Bien joué !"), true)
	Sfx.play("etape", Vector3.INF, -6.0)
	for h in hands:
		h.pulse(0.6, 0.12)
	_enter_step(step + 1)


func _finish() -> void:
	running = false
	marker.visible = false
	marker2.visible = false
	Contact.clear_zones()
	for inst in tray.ordered:
		inst.set_highlight(0)
	var stars := 3 if errors == 0 else (2 if errors <= 2 else 1)
	if elapsed > 600.0:
		stars = maxi(1, stars - 1)
	Sfx.play("fin", Vector3.INF, -2.0)
	var again := "Touche « Recommencer » ou pince main gauche (ou A)." if is_vr else "Appuie sur ESPACE pour revenir au menu."
	_finished_at = Time.get_ticks_msec()
	for ui in uis:
		ui.show_end(elapsed, errors, stars, op.summary + "\n" + again)
	if touch_menu:
		touch_menu.show_buttons([["Recommencer", "again"]])
	finished.emit(elapsed, errors)


func _error(msg: String, once_key := "") -> void:
	if once_key != "":
		if st.has("err_" + once_key):
			return
		st["err_" + once_key] = true
	errors += 1
	_toast(msg, false)
	Sfx.play("erreur", Vector3.INF, -6.0)


# ---------------------------------------------------------------- Prendre / reposer

func _on_take(hand: SurgeonHand, inst: Instrument) -> void:
	if step == MENU:
		return
	# Passer un instrument d'une main à l'autre
	for h in hands:
		if h != hand and h.held == inst:
			h.release_parked()
	if inst in parked:
		_toast("Cet instrument est en place : laisse-le.", false)
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
	_release_hand(hand)
	Sfx.play("pose", hand.held.global_position, -8.0)
	hand.put_back()


## La main lâche son instrument : tout ce qu'elle tenait avec (appendice, écarteur...) est relâché.
func _release_hand(hand: SurgeonHand) -> void:
	if st.get("grab") == hand:
		st.erase("grab")
	if st.get("hook") == hand:
		st.erase("hook")


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if running:
		elapsed += delta
	_hint_cd -= delta
	op.process(delta)
	_update_drops(delta)
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
		if mode == 0 and inst.id == req and not is_held and running and not inst.parked:
			mode = 1
		inst.set_highlight(0 if is_held else mode)
	if is_vr and _hover_label:
		var shown: Instrument = null
		for h in hands:
			if h.hovered and h.held == null:
				shown = h.hovered
		_hover_label.visible = shown != null
		if shown:
			_hover_label.text = shown.label
			_hover_label.modulate = GuideUI.ACCENT if shown.id == req else Color(0.92, 0.96, 1.0)
			_hover_label.global_position = shown.grip_global() + Vector3.UP * 0.05

	_update_falling(delta)
	if not running or step < 0 or step >= steps.size():
		marker.visible = false
		marker2.visible = false
		return
	st["t"] = st.get("t", 0.0) + delta
	var s := current()
	_setup_hands(s)
	_update_zones(s)
	match s["kind"]:
		"paint": _tick_paint(s, delta)
		"incise": _tick_incise(s, delta)
		"inject": _tick_inject(s, delta)
		"retract": _tick_retract(s, delta)
		"spread": _tick_spread(s, delta)
		"lift": _tick_lift(s, delta)
		"ligate": _tick_ligate(s, delta)
		"cut": _tick_cut(s, delta)
		"carry": _tick_carry(s, delta)
		"suture": _tick_suture(s, delta)
		"insert": _tick_insert(s, delta)
		"hold": _tick_hold(s, delta)
		"place": _tick_place(s, delta)
		"selfretract": _tick_selfretract(s, delta)
	if step >= 0 and step < steps.size() and current() == s:
		_update_markers(s)
	if not show_markers:
		marker.visible = false
		marker2.visible = false


## Réglages des mains souris (effet du clic) et aide au placement selon le geste.
func _setup_hands(s: Dictionary) -> void:
	var target := Vector3.INF
	var mode := "press"
	var pmax := 0.005
	var lift := 0.0
	match s["kind"]:
		"paint":
			pmax = 0.0055
		"incise":
			pmax = 0.0065
		"inject":
			pmax = 0.0085
			target = s["target"].call()
		"retract":
			pmax = 0.0165
			if not st.has("hook"):
				target = _retract_marker(s)
		"spread":
			mode = "hold"
			pmax = s["depth"] + 0.012
			target = s["target"].call()
		"insert":
			mode = "hold"
			pmax = s["depth"] + 0.03
			target = s["target"].call()
		"lift", "carry":
			mode = "none"
			if st.has("grab"):
				lift = s.get("auto_lift", 0.07)
			else:
				target = s["target"].call() if s["kind"] == "lift" else (s["object"].call() as Node3D).global_position
		"ligate":
			mode = "none"
			if st.get("phase", 0) != 1:
				target = s["target"].call()
		"cut", "place":
			mode = "none"
			target = s["target"].call()
		"suture":
			pmax = 0.0065
			var pair := _suture_pair(s)
			if not pair.is_empty():
				target = pair[1] if st.get("phase", 0) == 1 else pair[0]
		"hold":
			mode = "none"
			target = s["target"].call()
		"selfretract":
			mode = "hold"
			pmax = 0.025
			target = patient.center
	for h in hands:
		var ok: bool = h.held != null and h.held.id == s["inst"]
		h.assist_target = target if ok else Vector3.INF
		if h is DesktopHand:
			var dh := h as DesktopHand
			dh.press_mode = mode
			dh.press_max = pmax
			dh.auto_lift = lift if ok else 0.0


## Zones où les instruments peuvent entrer pour ce geste.
func _update_zones(s: Dictionary) -> void:
	Contact.clear_zones()
	match s["kind"]:
		"incise":
			var a := patient.incision_point(-0.06)
			var b := patient.incision_point(1.06)
			Contact.add_zone(a, b, 0.006 if is_vr else 0.005, 0.007, ["blade"])
		"inject":
			var p: Vector3 = s["target"].call()
			Contact.add_zone(p, p, 0.022, 0.03, ["needle"])
		"retract":
			if st.has("hook"):
				Contact.add_zone(patient.incision_point(0.0), patient.incision_point(1.0), 0.07, 0.03, ["hook"])
		"spread":
			var p: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			# Profondeur comptée le long du trajet (perpendiculaire à la peau), convertie à la verticale
			var dz: float = st.get("dissect", 0.008)
			Contact.add_zone(p, p + axis * dz, 0.011, (dz + 0.004) / maxf(absf(axis.y), 0.3), ["tip", "body"])
		"insert":
			var p: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			Contact.add_zone(p, p + axis * (s["depth"] + 0.03), 0.014, s["depth"] + 0.04, ["tube", "tip", "body"])
		"suture":
			var pair := _suture_pair(s)
			if not pair.is_empty():
				for p in pair:
					Contact.add_zone(p, p, 0.01, 0.007, ["needle"])


func _active_hands() -> Array[SurgeonHand]:
	var out: Array[SurgeonHand] = []
	var req := required_id()
	for h in hands:
		if h.held and h.held.id == req:
			out.append(h)
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tol(r: float) -> float:
	return r * (1.25 if is_vr else 1.0)


func _done(hand: SurgeonHand, instant: bool, extra: Variant = null) -> void:
	var s := current()
	if not s.has("done"):
		return
	var cb: Callable = s["done"]
	match cb.get_argument_count():
		3:
			cb.call(hand, instant, extra)
		2:
			cb.call(hand, instant)
		_:
			cb.call(instant)


# ---------------------------------------------------------------- Repères

func _update_markers(s: Dictionary) -> void:
	marker2.visible = false
	match s["kind"]:
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			marker.show_at(c + Vector3.UP * 0.003, s.get("label", "Zone à désinfecter"), s.get("ring", 3.5))
		"incise":
			if not patient.has_cut():
				marker.show_at(patient.incision_point(0.0) + Vector3.UP * 0.002, "DÉPART", 0.8)
			else:
				marker.show_at(patient.incision_point(patient.cut1) + Vector3.UP * 0.002, "", 0.6)
			marker2.show_at(patient.incision_point(1.0) + Vector3.UP * 0.002, "ARRIVÉE", 0.6)
		"inject":
			marker.show_at(s["target"].call(), s.get("label", "Pique ici"), 0.9)
		"retract":
			if st.has("hook"):
				var side: float = st["side"]
				var goal := patient.center + patient.perp3 * side * patient.wound_w * 0.95
				goal.y = Patient.body_height(goal.x, goal.z) + 0.002
				marker.show_at(goal, "Tire jusqu'ici", 0.7)
			else:
				marker.show_at(_retract_marker(s), s.get("label", "Accroche le bord"), 0.8)
		"selfretract":
			marker.show_at(patient.center - Vector3.UP * 0.004, s.get("label", ""), 1.2)
		"spread", "insert", "hold", "place", "cut", "ligate":
			marker.show_at(s["target"].call(), s.get("label", ""), s.get("ring", 0.9))
		"lift":
			marker.show_at(s["target"].call(), s.get("label", "") if not st.has("grab") else "Soulève !", 0.9)
		"carry":
			if st.has("grab") or st.has("fall"):
				marker.show_at(s["dest"].call(), s.get("dest_label", "Lâche ici"), 2.5)
			else:
				var obj: Node3D = s["object"].call()
				marker.show_at(obj.global_position if obj else patient.center, s.get("label", ""), 0.9)
		"suture":
			var pair := _suture_pair(s)
			if not pair.is_empty():
				var n: int = st.get("k", 0) + 1
				if st.get("phase", 0) == 1:
					marker.show_at(pair[1], "Ressors ici", 0.5)
				else:
					marker.show_at(pair[0], "%s %d : pique ici" % [s.get("label", "Point"), n], 0.5)
					marker2.show_at(pair[1], "", 0.4)
	# L'étiquette s'efface quand la pointe arrive sur le repère (elle gênerait la vue)
	var closest := 1.0
	for h in hands:
		if h.held:
			closest = minf(closest, h.tip().distance_to(marker.global_position))
	marker.label.visible = closest > 0.06


# ---------------------------------------------------------------- Gestes

## Badigeon : la compresse imbibée peint là où elle frotte la peau.
func _tick_paint(s: Dictionary, delta: float) -> void:
	var rubbing := 0.0
	for h in _active_hands():
		var p := h.tip()
		var depth := h.held.tip_depth
		var last: Vector3 = st.get("last_%d" % h.slot, p)
		st["last_%d" % h.slot] = p
		if depth < -0.003 or not Contact.is_skin(p):
			continue
		var pressure := clampf(0.55 + depth / 0.003, 0.4, 1.2)
		var speed := last.distance_to(p) / maxf(delta, 0.001)
		rubbing = maxf(rubbing, speed)
		var cov := patient.paint_iodine(p, 0.015 + 0.005 * pressure, pressure * clampf(0.35 + speed * 4.0, 0.35, 1.0))
		_caption("Désinfecté : %d %%" % int(minf(cov / 0.85, 1.0) * 100))
		h.pulse(0.08, 0.02)
		if cov >= 0.85:
			patient.fill_iodine()
			_done(h, false)
			_complete_step()
			return
	Sfx.loop("badigeon", patient.center, clampf(rubbing * 3.0, 0.0, 1.0))


## Incision : la lame coupe là où elle entre dans la peau sur le tracé, sans bouton.
func _tick_incise(s: Dictionary, _delta: float) -> void:
	var speed := 0.0
	var len := patient.half_len * 2.0
	var jump := clampf(0.008 / len, 0.03, 0.3)
	for h in _active_hands():
		var p := h.tip()
		var depth := h.held.tip_depth
		var proj := patient.incision_project(p)
		var last: Vector3 = st.get("last_%d" % h.slot, p)
		st["last_%d" % h.slot] = p
		if depth < 0.0008 or not Contact.is_skin(p):
			continue
		# Anesthésie locale pas encore efficace : le patient sent la lame
		if anesthesia_ready_at > 0 and Time.get_ticks_msec() < anesthesia_ready_at:
			if _hint_cd <= 0.0:
				_hint_cd = 2.5
				monitor.react()
				_error("Il a senti la lame ! Attends que l'anesthésie agisse.", "early")
			continue
		var along := (Vector2(p.x, p.z) - patient.INC_A).dot(patient.INC_B - patient.INC_A) / (len * len)
		if proj.y > _tol(0.0045) or along < -0.05 or along > 1.05:
			if depth > 0.002 and _hint_cd <= 0.0:
				_hint_cd = 2.5
				_toast("Reste sur le pointillé violet.", false)
			continue
		var t := clampf(along, 0.0, 1.0)
		if patient.has_cut() and (t < patient.cut0 - jump or t > patient.cut1 + jump):
			continue
		var before := patient.incision_progress
		if not st.has("bloody"):
			st["bloody"] = true
			var bm: StandardMaterial3D = h.held.get_meta("blade_mat", null)
			if bm:
				var tw := create_tween()
				tw.tween_property(bm, "albedo_color", Color(0.62, 0.22, 0.2), 2.0)
		patient.extend_cut(t)
		speed = maxf(speed, last.distance_to(p) / maxf(_delta, 0.001))
		patient.rest_open = 0.14 * patient.incision_progress
		if patient.incision_progress > before:
			monitor.stress(12.0)
			h.pulse(0.2, 0.02)
		var tol_t := clampf(0.003 / len, 0.02, 0.08)
		if patient.cut0 <= tol_t and patient.cut1 >= 1.0 - tol_t:
			patient.extend_cut(0.0)
			patient.extend_cut(1.0)
			monitor.stress(4.0)
			_done(h, false)
			_complete_step()
			return
	Sfx.loop("incision", patient.center, clampf(speed * 6.0, 0.0, 1.0))
	if anesthesia_ready_at > 0:
		var left := (anesthesia_ready_at - Time.get_ticks_msec()) / 1000.0
		_caption("L'anesthésie agit… encore %d s" % ceili(left) if left > 0.0 else "C'est endormi : tu peux inciser.")


## Seringue : piquer, pousser le piston (pouce contre l'index / gâchette / clic), retirer l'aiguille.
func _tick_inject(s: Dictionary, delta: float) -> void:
	var target: Vector3 = s["target"].call()
	var inj: float = st.get("inj", 0.0)
	var pushing := 0.0
	for h in _active_hands():
		var inst := h.held
		var tipp := h.tip()
		var depth := inst.tip_depth
		# Une aiguille piquée reste dans la peau même quand le thorax respire (hystérésis)
		var was_in: bool = st.get("in", false)
		var inside := _flat(tipp, target) < _tol(0.02) and (depth > 0.002 or (was_in and depth > -0.003))
		var sq := h.squeeze_value()
		# Le pouce qui vient de pincer la seringue pour la prendre ne pousse pas le piston :
		# il faut d'abord relâcher, puis serrer
		if sq < 0.3:
			st["armed_%d" % h.slot] = true
		var rate := clampf((sq - 0.35) / 0.65, 0.0, 1.0) * 0.24 if st.get("armed_%d" % h.slot, false) else 0.0
		if inside and not st.get("in", false):
			Sfx.play("pique", tipp, -10.0)
			h.pulse(0.3, 0.03)
		st["in"] = inside
		if inst.volume <= 0.001:
			rate = 0.0
		if inside and rate > 0.0:
			inj = minf(1.0, inj + rate * delta)
			inst.set_volume(maxf(inst.volume - rate * delta, 0.0))
			pushing = rate
			if s.get("bleb", true):
				patient.set_bleb(target, 0.005 + 0.009 * inj, 0.001 + 0.0026 * inj)
			if s.has("progress"):
				s["progress"].call(inj)
			h.pulse(0.06, 0.02)
		elif rate > 0.0 and not inside and h is VRHand and inst.volume > 0.92:
			# Hors de la peau, le produit gicle par l'aiguille (on peut purger un peu, pas plus)
			inst.set_volume(inst.volume - rate * delta * 0.5)
			_spawn_drop(tipp, inst.axis_global())
			if _hint_cd <= 0.0:
				_hint_cd = 3.0
				_toast("Le produit coule dans le vide : pique d'abord la peau.", false)
		# Seringue vide (un peu de produit a pu être purgé dans l'air) ou tout injecté
		var full := inj >= 0.97 or (inst.volume <= 0.01 and inj >= 0.5)
		if full and depth < 0.0:
			# Aiguille retirée : l'anesthésie commence à agir
			st["inj"] = inj
			var wait: float = s.get("wait", 10.0)
			if wait > 0.0:
				anesthesia_ready_at = Time.get_ticks_msec() + int(wait * 1000.0)
				op.anesthesia_started(wait)
			_done(h, false)
			_complete_step()
			return
	st["inj"] = inj
	Sfx.loop("piston", target, 1.0 if pushing > 0.0 else 0.0)
	var any_empty := false
	for h in _active_hands():
		any_empty = any_empty or h.held.volume <= 0.01
	if inj < 0.97 and not (any_empty and inj >= 0.5):
		_caption("%s injecté : %d %%" % [s.get("what", "Produit"), int(inj * 100)] if inj > 0.0 else "")
	else:
		_caption("Tout est injecté : retire l'aiguille.")


func _spawn_drop(at: Vector3, dir: Vector3) -> void:
	if _drops.size() > 24 or randf() > 0.5:
		return
	var m := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.0012
	sp.height = 0.0024
	sp.radial_segments = 8
	sp.rings = 4
	m.mesh = sp
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.9, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	m.material_override = mat
	add_child(m)
	m.global_position = at
	_drops.append({"node": m, "vel": dir * randf_range(0.2, 0.5) + Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03)), "life": 1.2})


func _update_drops(delta: float) -> void:
	for d in _drops.duplicate():
		var n: MeshInstance3D = d["node"]
		d["vel"] += Vector3.DOWN * GRAVITY * delta
		n.global_position += d["vel"] * delta
		d["life"] -= delta
		var top := Contact.surface(n.global_position)
		if d["life"] <= 0.0 or n.global_position.y < maxf(top, 0.0):
			n.queue_free()
			_drops.erase(d)


## Écarteur : accroche un bord dans la plaie et tire. Le bord suit (ressort), se détend si on
## relâche. Tenu bien écarté un instant, l'aide prend l'écarteur.
func _retract_marker(s: Dictionary) -> Vector3:
	return patient.retractor_slot(_free_side(s))


func _free_side(s: Dictionary) -> float:
	var want: float = s.get("side", 0.0)
	if want != 0.0:
		return want
	if patient.held_l < 0.0:
		return -1.0
	return 1.0


func _tick_retract(s: Dictionary, delta: float) -> void:
	var free := _free_side(s)
	for h in _active_hands():
		var tipp := h.tip()
		var depth := h.held.tip_depth
		var q := patient.uv_of(tipp)
		if st.get("hook") == null or st.get("hook") != h:
			if st.has("hook"):
				continue
			var side := -1.0 if q.y < 0.0 else 1.0
			var near_edge := absf(q.x) < patient.half_len and absf(absf(q.y) - patient.edge_open(q.x, side)) < _tol(0.012)
			if depth > 0.002 and (patient.hole_depth(tipp) > 0.0 or near_edge) and (s.get("side", 0.0) == 0.0 or side == free):
				var held_side := patient.held_l if side < 0.0 else patient.held_r
				if held_side < 0.0:
					st["hook"] = h
					st["side"] = side
					st["hold"] = 0.0
					Sfx.play("ecarte", tipp, -8.0)
					h.pulse(0.4, 0.05)
			continue
		var side2: float = st["side"]
		if depth < 0.0012:
			# Ressorti de la plaie : le bord se détend
			st.erase("hook")
			Sfx.play("ecarte", tipp, -14.0, 1.3)
			_toast("Le bord s'est détendu : accroche-le et tire.", false)
			continue
		var g := maxf(patient.gap_profile(q.x), 0.4)
		var want := clampf(absf(q.y) * (1.0 if signf(q.y) == side2 else -1.0) / (patient.wound_w * g), 0.0, 1.25)
		if side2 < 0.0:
			patient.drive_l = want
		else:
			patient.drive_r = want
		var cur := patient.open_l if side2 < 0.0 else patient.open_r
		Sfx.loop("ecarte", tipp, clampf((want - cur) * 3.0, 0.0, 0.8))
		if cur >= 0.82:
			st["hold"] = st.get("hold", 0.0) + delta
			_caption("Tiens bien… l'aide va prendre l'écarteur")
			if st["hold"] >= 0.6:
				if side2 < 0.0:
					patient.held_l = maxf(cur, 0.92)
				else:
					patient.held_r = maxf(cur, 0.92)
				var inst := h.held
				st.erase("hook")
				h.release_parked()
				op.park(inst, inst.global_transform, true)
				Sfx.play("pose", tipp, -6.0)
				_done(h, false, side2)
				_complete_step("L'aide tient l'écarteur")
				return
		else:
			st["hold"] = 0.0
			_caption("Tire le bord vers l'extérieur" if cur < 0.6 else "Encore un peu…")


## Pince de Kelly : pousser, ouvrir les mors pour écarter, pousser plus loin... jusqu'à la plèvre.
func _tick_spread(s: Dictionary, delta: float) -> void:
	var entry: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var depth: float = s["depth"]
	var dissect: float = st.get("dissect", 0.008)
	for h in _active_hands():
		var tipp := h.tip()
		var d := tipp - entry
		var along := d.dot(axis)
		var lateral := (d - axis * along).length()
		var jaw := 1.0 - h.squeeze_value()
		var last_jaw: float = st.get("jaw_%d" % h.slot, jaw)
		st["jaw_%d" % h.slot] = jaw
		if lateral > 0.022 or along < 0.003:
			continue
		# Les tissus s'écartent avec les mors, et se resserrent quand on les ferme
		var spread := 0.35 + 0.6 * jaw * clampf(along / 0.01, 0.0, 1.0)
		patient.drive_l = spread
		patient.drive_r = spread
		if jaw > last_jaw + 0.002 and along >= dissect - 0.006:
			dissect = minf(depth + 0.003, dissect + (jaw - last_jaw) * 0.016)
			Sfx.loop("ecarte", tipp, 0.7)
			h.pulse(0.15, 0.02)
		if s.has("progress"):
			s["progress"].call(clampf(along / depth, 0.0, 1.0))
		_caption("Profondeur : %d mm — pousse, ouvre la pince, recommence" % int(along * 1000.0))
		if along >= depth - 0.002:
			st["dissect"] = dissect
			_done(h, false)
			_complete_step()
			return
	st["dissect"] = dissect


## Saisir avec la pince (mors serrés près de la cible) et soulever ; lâché, ça retombe.
func _tick_lift(s: Dictionary, delta: float) -> void:
	if st.has("grab"):
		var h: SurgeonHand = st["grab"]
		if h.held == null or h.squeeze_value() < 0.45:
			st.erase("grab")
			st["fall_from"] = s["target"].call()
			_toast("Ça a glissé : garde la pince serrée.", false)
			return
		_follow(s, h.tip() + Vector3.DOWN * 0.002, delta, 700.0, 0.75)
		var v: float = s["goal"].call()
		if v >= 1.0:
			st["ok_t"] = st.get("ok_t", 0.0) + delta
			_caption("Tiens-le là…")
			if st["ok_t"] > 0.35:
				st.erase("grab")
				_done(h, false)
				_complete_step()
			return
		st["ok_t"] = 0.0
		_caption("Soulève-le hors de la plaie")
		return
	# Retombe en douceur (ressort amorti) quand on a lâché
	if st.has("vel"):
		_follow(s, s["rest"].call(), delta, 180.0, 0.3)
	for h in _active_hands():
		var sq := h.squeeze_value()
		var last: float = st.get("sq_%d" % h.slot, sq)
		st["sq_%d" % h.slot] = sq
		if sq > 0.75 and last <= 0.75 and h.tip().distance_to(s["target"].call()) < _tol(s.get("radius", 0.016)):
			st["grab"] = h
			if not st.has("pos"):
				st["pos"] = s["target"].call()
				st["vel"] = Vector3.ZERO
			Sfx.play("prise", h.tip(), -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


## Suivi à ressort de l'objet tenu (appendice, anse) : il traîne un peu, oscille, retombe.
func _follow(s: Dictionary, target: Vector3, delta: float, k: float, zeta: float) -> void:
	var pos: Vector3 = st.get("pos", s["target"].call())
	var vel: Vector3 = st.get("vel", Vector3.ZERO)
	var c := 2.0 * sqrt(k) * zeta
	var h := minf(delta, 0.05) * 0.5
	for i in 2:
		vel += ((target - pos) * k - vel * c) * h
		pos += vel * h
	st["pos"] = pos
	st["vel"] = vel
	s["move"].call(pos)


## Ligature : mors de l'Overholt serrés sur le fil près de la base, puis tirer pour serrer le nœud.
func _tick_ligate(s: Dictionary, _delta: float) -> void:
	var base: Vector3 = s["target"].call()
	var phase: int = st.get("phase", 0)
	for h in _active_hands():
		var sq := h.squeeze_value()
		var last: float = st.get("sq_%d" % h.slot, sq)
		st["sq_%d" % h.slot] = sq
		var tipp := h.tip()
		if phase != 1:
			if sq > 0.75 and last <= 0.75 and tipp.distance_to(base) < _tol(s.get("radius", 0.016)):
				st["phase"] = 1
				st["hand"] = h
				patient.set_ligature(0.0)
				Sfx.play("fil", base, -8.0)
				h.pulse(0.3, 0.04)
				_caption("Le fil passe autour de la base : tire pour serrer le nœud")
			continue
		if st.get("hand") != h:
			continue
		if sq < 0.4:
			st["phase"] = 2
			_set_thread(false)
			_caption("Fil lâché : reprends-le avec l'Overholt (serre près de la base)")
			continue
		var tight := clampf((tipp.distance_to(base) - 0.012) / 0.04, 0.0, 1.0)
		patient.set_ligature(tight)
		_set_thread(true, base, tipp)
		Sfx.loop("fil", base, clampf(tight * 0.8, 0.0, 0.8))
		if tight >= 1.0:
			_set_thread(false)
			_done(h, false)
			_complete_step()
			return


## Fil tendu entre la ligature et la pince.
func _set_thread(on: bool, a := Vector3.ZERO, b := Vector3.ZERO) -> void:
	if not on:
		if _thread:
			_thread.visible = false
		return
	if _thread == null:
		_thread = MeshInstance3D.new()
		_thread.material_override = MeshUtil.mat(Color(0.92, 0.9, 0.82), 0.6)
		_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_thread)
	_thread.visible = true
	var mid := (a + b) * 0.5 + Vector3.DOWN * 0.003
	var pts := MeshUtil.bezier(a, a.lerp(mid, 0.6), b.lerp(mid, 0.4), b, 10)
	var rr := PackedFloat32Array()
	rr.resize(pts.size())
	rr.fill(0.0004)
	_thread.mesh = MeshUtil.tube(pts, rr, 4, false, false, _thread.mesh as ArrayMesh)


## Ciseaux : ouvrir les lames autour de la cible, puis les refermer.
func _tick_cut(s: Dictionary, _delta: float) -> void:
	var target: Vector3 = s["target"].call()
	for h in _active_hands():
		var inst := h.held
		var sq := h.squeeze_value()
		var last: float = st.get("sq_%d" % h.slot, sq)
		st["sq_%d" % h.slot] = sq
		var near := inst.jaw_distance(target) < _tol(s.get("radius", 0.009))
		if sq < 0.5 and near:
			st["open_%d" % h.slot] = true
		if sq > 0.8 and last <= 0.8:
			Sfx.play("ciseaux", inst.tip_global(), -6.0)
			h.pulse(0.5, 0.04)
			if near and st.get("open_%d" % h.slot, false):
				_done(h, false)
				_complete_step()
				return
			elif near:
				_toast("Ouvre d'abord les ciseaux autour, puis referme.", false)
		if not near:
			st.erase("open_%d" % h.slot)
		_caption("Ouvre les ciseaux autour du repère, puis coupe" if not st.has("open_%d" % h.slot) else "Coupe !")


## Transport : saisir l'objet avec la pince, le lâcher au-dessus de la cible ; il tombe vraiment.
func _tick_carry(s: Dictionary, delta: float) -> void:
	var obj: Node3D = s["object"].call()
	if obj == null:
		return
	if st.has("grab"):
		var h: SurgeonHand = st["grab"]
		if h.held == null or h.squeeze_value() < 0.45:
			st.erase("grab")
			st["fall"] = {"node": obj, "vel": st.get("vel", Vector3.ZERO), "rest": 0.0}
			Sfx.play("prise", obj.global_position, -16.0, 1.3)
			return
		var pos: Vector3 = st.get("pos", obj.global_position)
		var vel: Vector3 = st.get("vel", Vector3.ZERO)
		var k := 900.0
		var c := 2.0 * sqrt(k) * 0.7
		var target := h.tip() + Vector3.DOWN * 0.004
		vel += ((target - pos) * k - vel * c) * minf(delta, 0.05)
		pos += vel * minf(delta, 0.05)
		st["pos"] = pos
		st["vel"] = vel
		obj.global_position = pos
		var dest: Vector3 = s["dest"].call()
		_caption("Lâche-le au-dessus du haricot" if _flat(pos, dest) < 0.09 else "Emmène-le jusqu'au haricot (à ta gauche)")
		return
	if st.has("fall"):
		var f: Dictionary = st["fall"]
		if f.get("landed", false):
			st.erase("fall")
			var dest: Vector3 = s["dest"].call()
			if _flat(obj.global_position, dest) < 0.09 and absf(obj.global_position.y - dest.y) < 0.05:
				Sfx.play("plop", dest, -4.0)
				_done(null, false)
				_complete_step()
				return
			if obj.global_position.y < 0.05:
				_error("L'appendice est tombé par terre ! L'infirmière le ramasse.")
				obj.global_position = patient.center + Vector3.UP * 0.01 + patient.perp3 * 0.05
		return
	for h in _active_hands():
		var sq := h.squeeze_value()
		var last: float = st.get("sq_%d" % h.slot, sq)
		st["sq_%d" % h.slot] = sq
		if sq > 0.75 and last <= 0.75 and h.tip().distance_to(obj.global_position) < _tol(0.022):
			st["grab"] = h
			st["pos"] = obj.global_position
			st["vel"] = Vector3.ZERO
			Sfx.play("prise", obj.global_position, -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


## Chute libre de l'objet lâché (rebonds sur le haricot, le guéridon, les champs, le sol).
func _update_falling(delta: float) -> void:
	if not st.has("fall"):
		return
	var f: Dictionary = st["fall"]
	if f.get("landed", false):
		return
	var n: Node3D = f["node"]
	var dt := minf(delta, 0.05)
	f["vel"] += Vector3.DOWN * GRAVITY * dt
	var p: Vector3 = n.global_position + f["vel"] * dt
	var floor_y := 0.004
	if tray.dish:
		var dc := tray.dish_center
		var r := _flat(p, dc)
		if r < 0.1:
			floor_y = dc.y - 0.006 + r * r * 1.2
		elif r < 0.175:
			floor_y = dc.y - 0.01
	var top := Contact.surface(p)
	if top != -INF:
		floor_y = maxf(floor_y, top + 0.004)
	if p.y <= floor_y:
		p.y = floor_y
		var v: Vector3 = f["vel"]
		if absf(v.y) < 0.25:
			f["landed"] = true
			f["vel"] = Vector3.ZERO
		else:
			f["vel"] = Vector3(v.x * 0.4, -v.y * 0.25, v.z * 0.4)
			Sfx.play("plop", p, -12.0, 1.3)
	n.global_position = p


## Suture : piquer à l'entrée, ressortir de l'autre côté de la plaie ; le point se noue.
func _suture_pair(s: Dictionary) -> Array:
	var pairs: Array = s["pairs"].call()
	var k: int = st.get("k", 0)
	return pairs[k] if k < pairs.size() else []


func _tick_suture(s: Dictionary, _delta: float) -> void:
	var pairs: Array = s["pairs"].call()
	var k: int = st.get("k", 0)
	if k >= pairs.size():
		return
	var pair: Array = pairs[k]
	var r := _tol(s.get("radius", 0.008))
	var free: bool = s.get("free", false)  # tissu hors de la peau (intestin) : distance en 3D
	for h in _active_hands():
		var tipp := h.tip()
		var depth := h.held.tip_depth
		if st.get("phase", 0) == 0:
			if (tipp.distance_to(pair[0]) < r) if free else (_flat(tipp, pair[0]) < r and depth > 0.0015):
				st["phase"] = 1
				Sfx.play("pique", tipp, -10.0)
				h.pulse(0.3, 0.03)
			continue
		if (tipp.distance_to(pair[1]) < r) if free else (_flat(tipp, pair[1]) < r and depth > -0.004):
			s["point"].call(k, false)
			Sfx.play(s.get("sound", "fil"), pair[1], -6.0)
			h.pulse(0.3, 0.05)
			k += 1
			st["k"] = k
			st["phase"] = 0
			if k >= pairs.size():
				_done(h, false)
				_complete_step()
			return
	_caption("Point %d / %d — %s" % [k + 1, pairs.size(), "ressors de l'autre côté" if st.get("phase", 0) == 1 else "pique à l'entrée"])


## Drain : il glisse dans l'orifice, le long du trajet, jusqu'à la profondeur voulue.
func _tick_insert(s: Dictionary, _delta: float) -> void:
	var entry: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var depth: float = s["depth"]
	for h in _active_hands():
		var tipp := h.tip()
		var d := tipp - entry
		var along := d.dot(axis)
		if (d - axis * along).length() > 0.02 or along < 0.0:
			continue
		Sfx.loop("ecarte", tipp, 0.4 if along > 0.005 else 0.0)
		_caption("Drain enfoncé : %d cm sur %d" % [int(along * 100.0), int(depth * 100.0)])
		if along >= depth:
			_done(h, false)
			_complete_step()
			return


## Pointe maintenue sur la cible (aspiration) : l'effet progresse tant qu'elle y reste.
func _tick_hold(s: Dictionary, delta: float) -> void:
	var p: Vector3 = s["target"].call()
	for h in _active_hands():
		if h.tip().distance_to(p) < _tol(s.get("radius", 0.03)):
			st["hold"] = st.get("hold", 0.0) + delta
			var v := clampf(st["hold"] / s.get("duration", 2.0), 0.0, 1.0)
			if s.has("progress"):
				s["progress"].call(v)
			Sfx.loop(s.get("hold_sound", "aspiration"), p, 0.8)
			if v >= 1.0:
				_done(h, false)
				_complete_step()
			return


## Écarteur autostatique : on l'enfonce fermé dans la plaie, on écarte les doigts, il s'ouvre et
## écarte les deux bords ; grand ouvert, sa crémaillère se bloque.
func _tick_selfretract(s: Dictionary, delta: float) -> void:
	for h in _active_hands():
		var tipp := h.tip()
		if h.held.tip_depth < 0.006 or patient.hole_depth(tipp) <= 0.0:
			_caption("Enfonce l'écarteur fermé dans la plaie")
			continue
		var spread := 1.0 - h.squeeze_value()
		var want := patient.rest_open + spread * 1.05
		patient.drive_l = want
		patient.drive_r = want
		Sfx.loop("ecarte", tipp, spread * 0.6)
		h.pulse(0.05 * spread, 0.02)
		if minf(patient.open_l, patient.open_r) >= 0.9:
			st["lock"] = st.get("lock", 0.0) + delta
			_caption("Clac ! La crémaillère se bloque")
			if st["lock"] > 0.3:
				_done(h, false)
				_complete_step()
				return
		else:
			st["lock"] = 0.0
			_caption("Écarte les doigts pour ouvrir l'écarteur" if spread < 0.5 else "Encore…")


## Poser / clamper : amener la pointe sur la cible et serrer.
func _tick_place(s: Dictionary, _delta: float) -> void:
	var p: Vector3 = s["target"].call()
	for h in _active_hands():
		var sq := h.squeeze_value()
		var last: float = st.get("sq_%d" % h.slot, sq)
		st["sq_%d" % h.slot] = sq
		if sq > 0.75 and last <= 0.75 and h.tip().distance_to(p) < _tol(s.get("radius", 0.03)):
			Sfx.play(s.get("sound", "pose"), p, -4.0)
			_done(h, false)
			_complete_step()
			return


## Saute directement à l'étape n (tests, captures) en appliquant les étapes précédentes.
func skip_to(n: int) -> void:
	running = true
	var titles := []
	for s in steps:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	op.on_start()
	if touch_menu:
		touch_menu.show_buttons([])
	for i in mini(n, steps.size()):
		step = i
		st = {}
		var s: Dictionary = steps[i]
		match s["kind"]:
			"paint":
				patient.fill_iodine()
			"incise":
				patient.incision_progress = 1.0
				patient.rest_open = 0.14
			"inject":
				var inst: Instrument = tray.instruments[s["inst"]]
				inst.set_volume(0.0)
				if s.get("bleb", true):
					patient.set_bleb(s["target"].call(), 0.014, 0.0036)
				if s.has("progress"):
					s["progress"].call(1.0)
				if s.get("wait", 10.0) > 0.0:
					op.anesthesia_started(0.0)
				anesthesia_ready_at = 0
			"retract":
				_done(null, true, _free_side(s))
				continue
			"hold":
				if s.has("progress"):
					s["progress"].call(1.0)
			"suture":
				var pairs: Array = s["pairs"].call()
				for k in pairs.size():
					s["point"].call(k, true)
		_done(null, true)
	_enter_step(n)
