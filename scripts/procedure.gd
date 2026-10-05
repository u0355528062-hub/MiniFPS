class_name Procedure
extends Node
## Moteur de l'opération guidée : une étape à la fois, instrument demandé en surbrillance, repère
## lumineux, messages, chrono, erreurs et bilan. Les gestes sont physiques et continus : rien ne se
## déclenche en remplissant une barre, l'effet suit la main en direct :
##   mark    : le feutre dessine le point d'entrée (5e espace intercostal, triangle de sécurité)
##   paint   : la compresse badigeonne là où elle touche la peau
##   inject  : l'aiguille pique, on pousse le piston, le liquide baisse, un bouton gonfle
##   incise  : la lame coupe là où elle entre dans la peau, le long du tracé
##   spread  : la pince entre, ouvre ses mors pour écarter les tissus, va plus profond
##   insert  : le drain glisse dans le trajet jusqu'à la bonne profondeur
##   suture  : l'aiguille entre d'un côté, ressort de l'autre, le point se noue
##   needle  : l'aiguille avance en aspirant (clic maintenu) jusqu'au retour (air, sang, liquide)
##   withdraw: on retire l'aiguille, le cathéter souple reste en place

signal finished(seconds: float, errors: int)
signal step_changed(index: int)

const INTRO := -1
const GRAVITY := 9.8

static var restarts := 0

var op: Operation
var patient: Patient
var tray: InstrumentTray
var monitor: VitalMonitor
var hands: Array[SurgeonHand] = []
var uis: Array = []  ## interfaces : show_step, set_progress, toast, set_status, set_steps, show_end

var step := INTRO
var elapsed := 0.0
var errors := 0
var error_log: Array[String] = []
var running := false
var show_markers := true
var parked: Array[Instrument] = []
var anesthesia_ready_at := 0
## Notes de qualité du geste (précision du repère, de l'incision…), pour le bilan
var quality := {}

var marker: TargetMarker
var marker2: TargetMarker
var st := {}
var _wrong_counted := false
var _hint_cd := 0.0
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
	Contact.patient = patient
	Contact.clear_zones()
	_show_intro()


func _exit_tree() -> void:
	# Les étapes tiennent des lambdas qui référencent l'opération : on casse le cycle pour que
	# l'opération soit libérée quand on change d'opération ou qu'on quitte.
	if op:
		op.steps = []
		op.catalog = []


func _ui_step(title: String, text: String, inst_label: String) -> void:
	for ui in uis:
		ui.show_step(step, steps.size(), title, text, inst_label, "")


func _caption(text: String) -> void:
	for ui in uis:
		ui.set_progress(0.0, text)


func _toast(text: String, ok := true) -> void:
	for ui in uis:
		ui.toast(text, ok)


# ---------------------------------------------------------------- Accueil, fin

func _show_intro() -> void:
	step = INTRO
	running = false
	var titles := []
	for s in steps:
		titles.append(s["list"])
	for ui in uis:
		ui.set_steps(titles)
	_ui_step(op.name, op.intro_text, "")


## Démarrer (après le briefing) ou, à la fin, rejouer.
func on_continue() -> void:
	if step == INTRO:
		running = true
		op.on_start()
		_enter_step(0)
	elif step >= steps.size():
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
	step_changed.emit(step)
	if step >= steps.size():
		_finish()
		return
	var s: Dictionary = steps[step]
	var inst: Instrument = tray.instruments[s["inst"]]
	_ui_step(s["title"], s["text"], inst.label)
	_caption("")
	if s["kind"] == "inject":
		inst.set_volume(1.0)
	if s.has("enter"):
		s["enter"].call()


func _complete_step(msg := "") -> void:
	_toast(msg if msg != "" else current().get("done_msg", "Bien joué !"), true)
	Sfx.play("etape", Vector3.INF, -6.0)
	for h in hands:
		h.pulse(0.6, 0.12)
	_enter_step(step + 1)


## Note finale : S (parfait), A, B, C, D.
func grade() -> String:
	var pts := 100.0 - errors * 12.0
	pts -= maxf(0.0, elapsed - 240.0) / 12.0
	pts += quality.get("bonus", 0.0)
	if errors == 0 and pts >= 95.0:
		return "S"
	if pts >= 85.0:
		return "A"
	if pts >= 70.0:
		return "B"
	if pts >= 50.0:
		return "C"
	return "D"


func _finish() -> void:
	running = false
	marker.visible = false
	marker2.visible = false
	Contact.clear_zones()
	for inst in tray.ordered:
		inst.set_highlight(0)
	Sfx.play("fin", Vector3.INF, -2.0)
	for ui in uis:
		ui.show_end(elapsed, errors, grade(), op.summary, error_log, quality)
	finished.emit(elapsed, errors)


func _error(msg: String, once_key := "") -> void:
	if once_key != "":
		if st.has("err_" + once_key):
			return
		st["err_" + once_key] = true
	errors += 1
	error_log.append(msg)
	_toast(msg, false)
	Sfx.play("erreur", Vector3.INF, -6.0)


# ---------------------------------------------------------------- Prendre / reposer

func _on_take(hand: SurgeonHand, inst: Instrument) -> void:
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
			error_log.append("Mauvais instrument pris : %s (au lieu de %s)" % [inst.label, good.label])
			_wrong_counted = true


func _on_put_back(hand: SurgeonHand) -> void:
	if hand.held == null:
		return
	Sfx.play("pose", hand.held.global_position, -8.0)
	hand.put_back()


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	if running:
		elapsed += delta
	_hint_cd -= delta
	op.process(delta)
	_update_drops(delta)
	for ui in uis:
		ui.set_status(elapsed, errors)
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
	if not running or step < 0 or step >= steps.size():
		marker.visible = false
		marker2.visible = false
		return
	st["t"] = st.get("t", 0.0) + delta
	var s := current()
	_setup_hands(s)
	_update_zones(s)
	match s["kind"]:
		"mark": _tick_mark(s, delta)
		"paint": _tick_paint(s, delta)
		"incise": _tick_incise(s, delta)
		"inject": _tick_inject(s, delta)
		"spread": _tick_spread(s, delta)
		"suture": _tick_suture(s, delta)
		"insert": _tick_insert(s, delta)
		"needle": _tick_needle(s, delta)
		"withdraw": _tick_withdraw(s, delta)
	if step >= 0 and step < steps.size() and current() == s:
		_update_markers(s)
	if not show_markers:
		marker.visible = false
		marker2.visible = false


## Réglages de la main (effet du clic) et aide au placement selon le geste.
func _setup_hands(s: Dictionary) -> void:
	var target := Vector3.INF
	var mode := "press"
	var pmax := 0.005
	var speed := 0.045
	var axis := Vector3.ZERO
	match s["kind"]:
		"mark":
			pmax = 0.004
		"paint":
			pmax = 0.0055
		"incise":
			pmax = 0.0065
		"inject":
			pmax = 0.0085
			target = s["target"].call()
		"spread":
			mode = "hold"
			pmax = s["depth"] + 0.012
			target = s["target"].call()
			axis = s["axis"]
		"insert":
			mode = "hold"
			pmax = s["depth"] + 0.03
			target = s["target"].call()
			axis = s["axis"]
		"suture":
			pmax = 0.0065
			var pair := _suture_pair(s)
			if not pair.is_empty():
				target = pair[1] if st.get("phase", 0) == 1 else pair[0]
		"needle", "withdraw":
			mode = "hold"
			pmax = s["max_depth"] + 0.01
			speed = s.get("speed", 0.016)
			target = s["target"].call()
			axis = s["axis"]
	for h in hands:
		var ok: bool = h.held != null and h.held.id == s["inst"]
		h.assist_target = target if ok else Vector3.INF
		h.assist_axis = axis if ok else Vector3.ZERO
		if h.has_method("set_press_mode"):
			h.call("set_press_mode", mode, pmax, speed)


## Zones où les instruments peuvent entrer pour ce geste.
func _update_zones(s: Dictionary) -> void:
	Contact.clear_zones()
	match s["kind"]:
		"incise":
			var a := patient.incision_point(-0.08)
			var b := patient.incision_point(1.08)
			Contact.add_zone(a, b, 0.005, 0.007, ["blade"])
		"inject":
			var p: Vector3 = s["target"].call()
			Contact.add_zone(p, p, 0.02, 0.03, ["needle"])
		"spread":
			var p: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			var dz: float = st.get("dissect", 0.008)
			Contact.add_zone(p, p + axis * dz, 0.011, (dz + 0.004) / maxf(absf(axis.y), 0.3), ["tip", "body"])
		"insert":
			var p: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			Contact.add_zone(p, p + axis * (s["depth"] + 0.03), s.get("zone_r", 0.014), s.get("zone_depth", s["depth"] + 0.04), ["tube", "tip", "body"])
		"suture":
			var pair := _suture_pair(s)
			if not pair.is_empty():
				for p in pair:
					Contact.add_zone(p, p, 0.01, 0.007, ["needle"])
		"needle", "withdraw":
			var p: Vector3 = s["target"].call()
			var axis: Vector3 = s["axis"]
			var dmax: float = s["max_depth"] + 0.012
			Contact.add_zone(p, p + axis * dmax, 0.009, dmax, ["needle"])


func _active_hands() -> Array[SurgeonHand]:
	var out: Array[SurgeonHand] = []
	var req := required_id()
	for h in hands:
		if h.held and h.held.id == req:
			out.append(h)
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


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
		"mark":
			# Pas de repère précis : c'est au joueur de trouver le bon espace (zone large)
			marker.show_at(s["area"].call(), s.get("label", ""), s.get("ring", 3.2))
		"paint":
			var c: Vector3 = s["area"].call() if s.has("area") else patient.center
			marker.show_at(c + Vector3.UP * 0.003, s.get("label", "Zone à désinfecter"), s.get("ring", 2.6))
		"incise":
			if not patient.has_cut():
				marker.show_at(patient.incision_point(0.0) + Vector3.UP * 0.002, "DÉPART", 0.7)
			else:
				marker.show_at(patient.incision_point(patient.cut1) + Vector3.UP * 0.002, "", 0.5)
			marker2.show_at(patient.incision_point(1.0) + Vector3.UP * 0.002, "ARRIVÉE", 0.55)
		"inject":
			marker.show_at(s["target"].call(), s.get("label", "Pique ici"), 0.8)
		"spread", "insert", "needle", "withdraw":
			marker.show_at(s["target"].call(), s.get("label", ""), s.get("ring", 0.8))
		"suture":
			var pair := _suture_pair(s)
			if not pair.is_empty():
				var n: int = st.get("k", 0) + 1
				if st.get("phase", 0) == 1:
					marker.show_at(pair[1], "Ressors ici", 0.45)
				else:
					marker.show_at(pair[0], "%s %d : pique ici" % [s.get("label", "Point"), n], 0.45)
					marker2.show_at(pair[1], "", 0.35)
	var closest := 1.0
	for h in hands:
		if h.held:
			closest = minf(closest, h.tip().distance_to(marker.global_position))
	marker.label.visible = closest > 0.05


# ---------------------------------------------------------------- Gestes

## Repérage : le feutre touche la peau là où le joueur pense que se trouve le 5e espace intercostal
## (ligne axillaire moyenne). Le point est jugé par rapport à l'anatomie réelle.
func _tick_mark(s: Dictionary, _delta: float) -> void:
	for h in _active_hands():
		var p := h.tip()
		var depth := h.held.tip_depth
		if depth < 0.0008 or not Contact.is_skin(p):
			st.erase("touch_%d" % h.slot)
			continue
		if st.has("touch_%d" % h.slot):
			continue
		st["touch_%d" % h.slot] = true
		var verdict: Dictionary = s["judge"].call(p)
		Sfx.play("pose", p, -14.0, 1.6)
		if verdict["ok"]:
			quality["mark_mm"] = verdict["mm"]
			if verdict["mm"] < 6.0:
				quality["bonus"] = quality.get("bonus", 0.0) + 4.0
			_done(h, false, p)
			_complete_step(verdict["msg"])
			return
		_error(verdict["msg"])


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
		var cov := patient.paint_iodine(p, 0.013 + 0.004 * pressure, pressure * clampf(0.35 + speed * 4.0, 0.35, 1.0))
		_caption("Désinfecté : %d %%" % int(minf(cov / 0.85, 1.0) * 100))
		h.pulse(0.08, 0.02)
		if cov >= 0.85:
			patient.fill_iodine()
			_done(h, false)
			_complete_step()
			return
	Sfx.loop("badigeon", patient.center, clampf(rubbing * 3.0, 0.0, 1.0))


## Incision : la lame coupe là où elle entre dans la peau sur le tracé.
func _tick_incise(s: Dictionary, _delta: float) -> void:
	var speed := 0.0
	var len := patient.half_len * 2.0
	var jump := clampf(0.008 / len, 0.03, 0.35)
	for h in _active_hands():
		var p := h.tip()
		var depth := h.held.tip_depth
		var proj := patient.incision_project(p)
		var last: Vector3 = st.get("last_%d" % h.slot, p)
		st["last_%d" % h.slot] = p
		if depth < 0.0008 or not Contact.is_skin(p):
			continue
		if anesthesia_ready_at > 0 and Time.get_ticks_msec() < anesthesia_ready_at:
			if _hint_cd <= 0.0:
				_hint_cd = 2.5
				monitor.react()
				_error("Il a senti la lame ! Attends que l'anesthésie agisse.", "early")
			continue
		var along := (Vector2(p.x, p.z) - patient.INC_A).dot(patient.INC_B - patient.INC_A) / (len * len)
		if proj.y > 0.0045 or along < -0.08 or along > 1.08:
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
		st["dev_sum"] = st.get("dev_sum", 0.0) + proj.y
		st["dev_n"] = st.get("dev_n", 0) + 1
		speed = maxf(speed, last.distance_to(p) / maxf(_delta, 0.001))
		patient.rest_open = 0.14 * patient.incision_progress
		if patient.incision_progress > before:
			monitor.stress(10.0)
			h.pulse(0.2, 0.02)
		var tol_t := clampf(0.003 / len, 0.02, 0.1)
		if patient.cut0 <= tol_t and patient.cut1 >= 1.0 - tol_t:
			patient.extend_cut(0.0)
			patient.extend_cut(1.0)
			quality["incision_dev_mm"] = st["dev_sum"] / maxf(1.0, st["dev_n"]) * 1000.0
			if quality["incision_dev_mm"] < 1.5:
				quality["bonus"] = quality.get("bonus", 0.0) + 3.0
			_done(h, false)
			_complete_step()
			return
	Sfx.loop("incision", patient.center, clampf(speed * 6.0, 0.0, 1.0))
	if anesthesia_ready_at > 0:
		var left := (anesthesia_ready_at - Time.get_ticks_msec()) / 1000.0
		_caption("L'anesthésie agit… encore %d s" % ceili(left) if left > 0.0 else "C'est endormi : tu peux inciser.")


## Seringue : piquer, pousser le piston (clic maintenu), retirer l'aiguille.
func _tick_inject(s: Dictionary, delta: float) -> void:
	var target: Vector3 = s["target"].call()
	var inj: float = st.get("inj", 0.0)
	var pushing := 0.0
	for h in _active_hands():
		var inst := h.held
		var tipp := h.tip()
		var depth := inst.tip_depth
		var was_in: bool = st.get("in", false)
		var inside := _flat(tipp, target) < 0.02 and (depth > 0.002 or (was_in and depth > -0.003))
		var sq := h.squeeze_value()
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
			h.pulse(0.06, 0.02)
		var full := inj >= 0.97 or (inst.volume <= 0.01 and inj >= 0.5)
		if full and depth < 0.0:
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


## Pince de Kelly : pousser, ouvrir les mors pour écarter, pousser plus loin… jusqu'à la plèvre.
func _tick_spread(s: Dictionary, _delta: float) -> void:
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
		var spread := 0.35 + 0.6 * jaw * clampf(along / 0.01, 0.0, 1.0)
		patient.drive_l = spread
		patient.drive_r = spread
		if jaw > last_jaw + 0.002 and along >= dissect - 0.006:
			dissect = minf(depth + 0.003, dissect + (jaw - last_jaw) * 0.016)
			Sfx.loop("ecarte", tipp, 0.7)
			h.pulse(0.15, 0.02)
		if s.has("progress"):
			s["progress"].call(clampf(maxf(along, dissect) / depth, 0.0, 1.0), jaw)
		_caption("Profondeur : %d mm — pousse, ouvre la pince, recommence" % int(along * 1000.0))
		if along >= depth - 0.002:
			st["dissect"] = dissect
			_done(h, false)
			_complete_step()
			return
	st["dissect"] = dissect


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
	var r: float = s.get("radius", 0.008)
	for h in _active_hands():
		var tipp := h.tip()
		var depth := h.held.tip_depth
		if st.get("phase", 0) == 0:
			if _flat(tipp, pair[0]) < r and depth > 0.0015:
				st["phase"] = 1
				Sfx.play("pique", tipp, -10.0)
				h.pulse(0.3, 0.03)
			continue
		if _flat(tipp, pair[1]) < r and depth > -0.004:
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
		if s.has("progress"):
			s["progress"].call(clampf(along / depth, 0.0, 1.0))
		_caption("Drain enfoncé : %d cm sur %d" % [int(along * 100.0), int(depth * 100.0)])
		if along >= depth:
			_done(h, false)
			_complete_step()
			return


## Aiguille montée sur une seringue : piquer sur le repère, avancer en aspirant (clic maintenu :
## l'aiguille avance ET le piston est tiré) ; quand la pointe atteint la cible (plèvre, vaisseau,
## péricarde), ce qu'elle contient remonte dans la seringue. Trop loin : blessure.
func _tick_needle(s: Dictionary, _delta: float) -> void:
	var entry: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var flash_d: float = s["flash_depth"]
	var max_d: float = s["max_depth"]
	for h in _active_hands():
		var inst := h.held
		var tipp := h.tip()
		var d := tipp - entry
		var along := d.dot(axis)
		var lateral := (d - axis * along).length()
		var asp := h.squeeze_value()
		if inst.model.has_method("set_aspiration"):
			inst.model.call("set_aspiration", move_toward(float(inst.model.get("aspiration")), asp, 0.08))
		# Seule compte une aiguille plantée sur le repère, dans l'axe (pas en chemin depuis la table)
		if lateral > 0.009:
			if inst.tip_depth > 0.002 and _hint_cd <= 0.0:
				_hint_cd = 2.5
				_toast("Pique sur le repère.", false)
			continue
		if along < 0.0015 or inst.tip_depth < -0.002:
			continue
		if not st.get("in", false):
			st["in"] = true
			Sfx.play("pique", tipp, -10.0)
			h.pulse(0.3, 0.03)
			if s.has("on_skin"):
				s["on_skin"].call(entry)
		st["max_along"] = maxf(st.get("max_along", 0.0), along)
		if along > max_d and not st.has("err_deep"):
			if OS.get_cmdline_user_args().has("--debug"):
				print("DEBUG trop profond : along=%.4f max=%.4f flash=%.4f tip=%s entry=%s axis=%s" % [along, max_d, flash_d, tipp, entry, axis])
			_error(s.get("deep_msg", "Trop profond !"), "deep")
			if s.has("on_too_deep"):
				s["on_too_deep"].call()
		if along >= flash_d - 0.0015 and asp > 0.5 and not st.get("flash", false):
			st["flash"] = true
			if inst.model.has_method("set_flash"):
				inst.model.call("set_flash", s.get("flash", "air"))
			h.pulse(0.5, 0.06)
			if s.has("on_flash"):
				s["on_flash"].call()
			_done(h, false)
			_complete_step(s.get("done_msg", ""))
			return
		if along >= flash_d + 0.004 and asp < 0.5 and _hint_cd <= 0.0:
			_hint_cd = 3.0
			_toast("Tire le piston en avançant (clic maintenu) : sinon tu ne sais pas où tu es.", false)
		_caption("Profondeur : %d mm%s" % [int(along * 1000.0), "  ·  aspire en avançant" if asp < 0.5 else "  ·  aspiration"])


## Retrait de l'aiguille : le cathéter souple reste en place (glissé sur l'aiguille).
func _tick_withdraw(s: Dictionary, _delta: float) -> void:
	var entry: Vector3 = s["target"].call()
	var axis: Vector3 = s["axis"]
	var any_held := false
	for h in hands:
		if h.held and h.held.id == s["inst"]:
			any_held = true
			var dd := h.tip() - entry
			var along := dd.dot(axis)
			var in_line := (dd - axis * along).length() < 0.012 and h.held.tip_depth > 0.0
			if in_line and along > s["max_depth"] and not st.has("err_deep"):
				if OS.get_cmdline_user_args().has("--debug"):
					print("DEBUG retrait trop profond : along=%.4f max=%.4f tip=%s entry=%s" % [along, s["max_depth"], h.tip(), entry])
				_error(s.get("deep_msg", "Trop profond !"), "deep")
			_caption("Retire l'aiguille (molette vers le haut, ou R) : le cathéter reste en place")
			if along < -0.002 or h.held.tip_depth < -0.001:
				_done(h, false)
				_complete_step()
				return
	if not any_held:
		_done(null, false)
		_complete_step()


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
				patient.set_bleb(s["target"].call(), 0.014, 0.0036)
				if s.get("wait", 10.0) > 0.0:
					op.anesthesia_started(0.0)
				anesthesia_ready_at = 0
			"suture":
				var pairs: Array = s["pairs"].call()
				for k in pairs.size():
					s["point"].call(k, true)
			"mark":
				_done(null, true, s["ideal"].call())
				continue
		_done(null, true)
	_enter_step(n)
