class_name Procedure
extends Node
## Moteur de l'opération guidée : menu de choix, une étape à la fois, instrument en surbrillance,
## repère lumineux, progression, messages, chrono et erreurs. Les étapes viennent de l'Operation
## et sont jouées selon leur type de geste (paint, trace, place, hold, push, lift, carry, points).

signal finished(seconds: float, errors: int)

const MENU := -2
const INTRO := -1

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
var is_vr := false

var step := MENU
var elapsed := 0.0
var errors := 0
var running := false
var show_markers := true  ## faux pour les captures « propres »
var menu_index := 0
var parked: Array[Instrument] = []  ## instruments posés hors de la main (écarteurs, drain...)

var marker: TargetMarker
var marker2: TargetMarker
var _wrong_counted := false
var _sound_cd := 0.0
var _hint_cd := 0.0
# État de l'étape en cours
var _trace := 0.0
var _hold_t := 0.0
var _point_i := 0
var _push := 0.0
var _push_hand: SurgeonHand
var _grab_hand: SurgeonHand
var _carry_home := Vector3.ZERO
var _carry_offset := Vector3.ZERO
var _anim: Tween


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
	if start_at_intro:
		start_at_intro = false
		_show_intro()
	else:
		_show_menu()


func _hint() -> String:
	if is_vr:
		return "GRIP : prendre / reposer un instrument (ou vise-le de loin)   ·   GÂCHETTE : agir   ·   B/Y : recentrer"
	return "Clic : prendre   ·   Clic maintenu : agir   ·   Molette : lever / baisser   ·   R : reposer   ·   1-8 : choisir un instrument"


func _ui_step(title: String, text: String, inst_label: String) -> void:
	for ui in uis:
		ui.show_step(step, steps.size(), title, text, inst_label, _hint())


func _ui_progress(v: float, caption: String) -> void:
	for ui in uis:
		ui.set_progress(v, caption)


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
	lines += "Stick haut / bas pour choisir, A pour valider." if is_vr else "Flèches haut / bas (ou 1-%d) pour choisir, ESPACE pour valider." % entries.size()
	for ui in uis:
		ui.set_steps([])
		ui.show_step(-2, 0, "Choisis ton opération", lines, "", _hint())


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


func _show_intro() -> void:
	step = INTRO
	var titles := []
	for s in steps:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	var go := "Appuie sur A (manette droite) pour commencer." if is_vr else "Appuie sur ESPACE pour commencer."
	_ui_step(op.name, op.intro_text + "\n" + go, "")


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
	_trace = 0.0
	_hold_t = 0.0
	_point_i = 0
	_push = 0.0
	_push_hand = null
	_grab_hand = null
	_carry_home = Vector3.ZERO
	if step >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[step]
	var inst: Instrument = tray.instruments[s["inst"]]
	_ui_step(s["title"], s["text"], inst.label)
	if hud:
		hud.mark_required(s["inst"])
	match s["kind"]:
		"paint":
			_ui_progress(0.0, "Zone désinfectée : 0 %")
		"trace":
			_ui_progress(0.0, "Incision : 0 %")
		"points":
			_ui_progress(0.0, "Points : 0 / %d" % s["points"].call().size())
		_:
			_ui_progress(0.0, "")
	if s.has("enter"):
		s["enter"].call()


func _complete_step() -> void:
	_toast(current().get("done_msg", "Bien joué !"), true)
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
	var again := "Appuie sur A pour revenir au menu." if is_vr else "Appuie sur ESPACE pour revenir au menu."
	for ui in uis:
		ui.show_end(elapsed, errors, stars, op.name + " réussie.\n" + again)
	finished.emit(elapsed, errors)


# ---------------------------------------------------------------- Prendre / reposer

func _on_take(hand: SurgeonHand, inst: Instrument) -> void:
	if step == MENU:
		return
	# Passer un instrument d'une main à l'autre
	for h in hands:
		if h != hand and h.held == inst:
			if _grab_hand == h:
				_release_grab()
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
	if _grab_hand == hand:
		_release_grab()
	Sfx.play("pose", hand.held.global_position, -8.0)
	hand.put_back()


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if running:
		elapsed += delta
	_sound_cd -= delta
	_hint_cd -= delta
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

	if not running or step < 0 or step >= steps.size():
		marker.visible = false
		marker2.visible = false
		return

	var target := _target()
	# L'étiquette s'efface quand la pointe arrive sur le repère (elle gênerait la vue)
	var closest := 1.0
	for h in hands:
		if h.held:
			closest = minf(closest, h.tip().distance_to(marker.global_position))
	marker.label.visible = closest > 0.07
	if not show_markers:
		marker.visible = false
		marker2.visible = false
	for h in hands:
		var ok := h.held != null and h.held.id == req
		h.assist_target = target if ok else Vector3.INF
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = 0.0
	match current()["kind"]:
		"paint": _tick_paint()
		"trace": _tick_trace()
		"place": _tick_place()
		"hold": _tick_hold(delta)
		"push": _tick_push()
		"lift": _tick_lift(delta)
		"carry": _tick_carry(delta)
		"points": _tick_points()


## Cible de l'étape en cours (repère lumineux + aide au placement à la souris).
func _target() -> Vector3:
	marker2.visible = false
	var s := current()
	match s["kind"]:
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			marker.show_at(c + Vector3.UP * 0.003, s.get("label", "Zone à désinfecter"), s.get("ring", 3.5))
			return Vector3.INF
		"trace":
			var p := patient.incision_point(maxf(_trace, 0.0))
			marker.show_at(p + Vector3.UP * 0.002, "DÉPART" if _trace < 0.02 else "", 0.8)
			marker2.show_at(patient.incision_point(1.0) + Vector3.UP * 0.002, "ARRIVÉE", 0.6)
			return Vector3.INF
		"place", "hold", "push":
			var p: Vector3 = s["target"].call()
			marker.show_at(p, s.get("label", ""), s.get("ring", 1.0))
			return p
		"lift":
			var p: Vector3 = s["target"].call()
			marker.show_at(p, s.get("label", "") if _grab_hand == null else "Soulève !", 0.9)
			return p
		"carry":
			if _grab_hand:
				var d: Vector3 = s["dest"].call()
				marker.show_at(d, s.get("dest_label", "Lâche ici"), 2.5)
				return d
			var obj: Node3D = s["object"].call()
			var p := obj.global_position if obj else patient.center
			marker.show_at(p, s.get("label", ""), 0.9)
			return p
		"points":
			var pts: Array = s["points"].call()
			if _point_i < pts.size():
				var p: Vector3 = pts[_point_i]
				marker.show_at(p, "%s %d" % [s.get("label", "Point"), _point_i + 1], s.get("ring", 0.6))
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


func _done(hand: SurgeonHand, instant: bool) -> void:
	var s := current()
	if not s.has("done"):
		return
	var cb: Callable = s["done"]
	if cb.get_argument_count() >= 2:
		cb.call(hand, instant)
	else:
		cb.call(instant)


# ---------------------------------------------------------------- Types de gestes

func _tick_paint() -> void:
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
				_done(h, false)
				_complete_step()
				return


func _tick_trace() -> void:
	for h in _active_hands():
		var p := h.tip()
		var proj := patient.incision_project(p)
		var t := proj.x
		var on_line := proj.y < (0.012 if is_vr else 0.009)
		var dt := 0.12 * clampf(0.07 / maxf(patient.INC_A.distance_to(patient.INC_B), 0.01), 0.15, 1.0)
		if h.trigger_down() and on_line and _skin_contact(p, 0.014) and t <= _trace + maxf(dt, 0.03) and t > _trace:
			_trace = t
			patient.incision_progress = _trace
			monitor.stress(14.0)
			_ui_progress(_trace, "Incision : %d %%" % int(_trace * 100))
			if _sound_cd <= 0.0:
				Sfx.play("incision", p, -6.0, randf_range(0.9, 1.15))
				_sound_cd = 0.12
			h.pulse(0.25, 0.02)
			if _trace >= 0.96:
				_trace = 1.0
				patient.incision_progress = 1.0
				monitor.stress(4.0)
				_done(h, false)
				_complete_step()
				return
		elif h.trigger_down() and on_line and _skin_contact(p, 0.014) and _trace < 0.03 and t > 0.25 and _hint_cd <= 0.0:
			_toast("Commence au point « DÉPART », puis va vers « ARRIVÉE ».", false)
			_hint_cd = 3.0


func _tick_place() -> void:
	var s := current()
	for h in _active_hands():
		if not h.trigger_just_pressed():
			continue
		var p: Vector3 = s["target"].call()
		if _near(h, p, s.get("radius", 0.03)):
			Sfx.play(s.get("sound", "pose"), p, -4.0)
			_done(h, false)
			_complete_step()
			return
		elif s.has("near_miss") and _near(h, p, s["near_miss"]):
			_toast("Vise bien le repère lumineux.", false)
			Sfx.play("erreur", Vector3.INF, -8.0)


func _tick_hold(delta: float) -> void:
	var s := current()
	var p: Vector3 = s["target"].call()
	for h in _active_hands():
		if h.trigger_down() and _near(h, p, s.get("radius", 0.025)):
			_hold_t += delta
			var v := clampf(_hold_t / s.get("duration", 1.5), 0.0, 1.0)
			_ui_progress(v, s.get("progress_label", "Maintiens…"))
			if s.has("progress"):
				s["progress"].call(v)
			if _sound_cd <= 0.0 and s.has("hold_sound"):
				Sfx.play(s["hold_sound"], p, -10.0)
				_sound_cd = 0.3
			h.pulse(0.08, 0.02)
			if v >= 1.0:
				_done(h, false)
				_complete_step()
			return


func _tick_push() -> void:
	var s := current()
	var entry: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var depth: float = s["depth"]
	for h in _active_hands():
		var tip := h.tip()
		var d := tip - entry
		var along := d.dot(axis)
		var off := (d - axis * along).length()
		var inside: bool = off < s.get("radius", 0.015) * (1.4 if is_vr else 1.0) and along > -0.02
		if h.trigger_down() and inside:
			_push_hand = h
			if h is DesktopHand:
				# À la souris, la gâchette maintenue enfonce l'instrument tout seul
				(h as DesktopHand).auto_lift = -(depth + 0.01) / maxf(-axis.y, 0.3)
			var v := clampf(along / depth, 0.0, 1.0)
			if v > _push:
				_push = v
				if s.has("progress"):
					s["progress"].call(v)
				h.pulse(0.12, 0.02)
			_ui_progress(_push, s.get("progress_label", "Enfonce…"))
			if _push >= 1.0:
				_done(h, false)
				_complete_step()
			return


func _tick_lift(delta: float) -> void:
	var s := current()
	if _grab_hand:
		var h := _grab_hand
		if h.held == null or not h.trigger_down():
			_release_grab()
			_toast("Ça a glissé : garde la gâchette appuyée.", false)
			return
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = s.get("auto_lift", 0.07)
		var cur: Vector3 = s["target"].call()
		s["move"].call(cur.lerp(h.tip(), 1.0 - exp(-delta * 18.0)))
		var v: float = s["goal"].call()
		_ui_progress(v, "Soulève encore…" if v < 1.0 else "")
		h.pulse(0.1, 0.02)
		if v >= 1.0:
			_grab_hand = null
			_done(h, false)
			_complete_step()
		return
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, s["target"].call(), s.get("radius", 0.03)):
			if s.has("grab"):
				s["grab"].call()
			_grab_hand = h
			Sfx.play("prise", h.tip(), -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


func _tick_carry(delta: float) -> void:
	var s := current()
	var obj: Node3D = s["object"].call()
	if obj == null:
		return
	if _grab_hand:
		var h := _grab_hand
		if h.held == null or not h.trigger_down():
			_release_grab()
			return
		if h is DesktopHand:
			(h as DesktopHand).auto_lift = 0.05
		obj.global_position = obj.global_position.lerp(h.tip() + _carry_offset, 1.0 - exp(-delta * 20.0))
		var dest: Vector3 = s["dest"].call()
		var flat := Vector2(obj.global_position.x - dest.x, obj.global_position.z - dest.z).length()
		_ui_progress(1.0 - clampf(flat / 0.5, 0.0, 1.0), "Direction : " + String(s.get("dest_label", "la cible")).to_lower())
		return
	for h in _active_hands():
		if h.trigger_just_pressed() and _near(h, obj.global_position, 0.04):
			_kill_anim()
			_grab_hand = h
			if _carry_home == Vector3.ZERO:
				_carry_home = obj.global_position
			_carry_offset = (obj.global_position - h.tip()).limit_length(0.02)
			Sfx.play("prise", obj.global_position, -12.0, 0.6)
			h.pulse(0.4, 0.05)
			return


func _tick_points() -> void:
	var s := current()
	var pts: Array = s["points"].call()
	for h in _active_hands():
		if _point_i >= pts.size():
			return
		if h.trigger_just_pressed() and _near(h, pts[_point_i], s.get("radius", 0.022)):
			s["point"].call(_point_i, false)
			Sfx.play(s.get("sound", "fil"), pts[_point_i], -6.0)
			_point_i += 1
			h.pulse(0.3, 0.05)
			_ui_progress(float(_point_i) / pts.size(), "Points : %d / %d" % [_point_i, pts.size()])
			if _point_i >= pts.size():
				_done(h, false)
				_complete_step()
			return


func _kill_anim() -> void:
	if _anim and _anim.is_valid():
		_anim.kill()
	_anim = null


## Lâcher : l'objet soulevé retombe ; l'objet transporté est jugé là où la pince le lâche.
func _release_grab() -> void:
	var h := _grab_hand
	_grab_hand = null
	if h is DesktopHand:
		(h as DesktopHand).auto_lift = 0.0
	var s := current()
	if s.is_empty():
		return
	if s["kind"] == "lift" and s.has("release"):
		s["release"].call()
	elif s["kind"] == "carry":
		var obj: Node3D = s["object"].call()
		if obj == null:
			return
		if h and h.held:
			obj.global_position = h.tip() + _carry_offset
		var dest: Vector3 = s["dest"].call()
		var flat := Vector2(obj.global_position.x - dest.x, obj.global_position.z - dest.z).length()
		_kill_anim()
		_anim = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if flat < (0.11 if is_vr else 0.09):
			_anim.tween_property(obj, "global_position", dest + Vector3.UP * 0.008, 0.35)
			_anim.tween_callback(func() -> void: Sfx.play("pose", dest, -6.0, 0.7))
			_done(h, false)
			_complete_step()
		else:
			_anim.tween_property(obj, "global_position", _carry_home, 0.4)
			_toast("Lâche-le au-dessus de la cible.", false)


## Saute directement à l'étape n (tests, captures) en appliquant les étapes précédentes.
func skip_to(n: int) -> void:
	running = true
	var titles := []
	for s in steps:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	op.on_start()
	for i in mini(n, steps.size()):
		step = i
		var s: Dictionary = steps[i]
		match s["kind"]:
			"paint":
				patient.fill_iodine()
			"trace":
				_trace = 1.0
				patient.incision_progress = 1.0
			"points":
				var pts: Array = s["points"].call()
				for k in pts.size():
					s["point"].call(k, true)
		_done(null, true)
	_enter_step(n)
