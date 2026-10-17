class_name Gestures
extends Node3D
## Les gestes en vue rapprochée, avec l'objet sélectionné, là où pointe la souris :
##  - mains : pouls (carotidien, radial), stimulation (épaule, visage), libération des voies
##    aériennes et contrôle de la respiration (front / menton), palpation de l'abdomen, temps de
##    recoloration (ongle), massage cardiaque (talon de la main sur la moitié inférieure du
##    sternum : clic maintenu, la souris pousse le thorax vers le bas et le relâche) ;
##  - stéthoscope (cœur, poumons), lampe (pupilles), thermomètre (oreille), glycémie (doigt) ;
##  - électrodes du scope, de l'ECG 12 dérivations, de défibrillation ; oxymètre, brassard ;
##  - garrot, antiseptique, cathéter (sur la veine visible), tubes, perfusion, seringues (IV sur
##    le robinet du cathéter, IM dans le deltoïde ou la cuisse) ;
##  - oxygène (lunettes, masque, nébulisation), BAVU (masque sur le visage, clic sur le ballon),
##    LUCAS (massage automatique) ;
##  - boutons des appareils (défibrillateur, scope, électrocardiographe, débitmètre).

const SCOPE_LEADS := ["RA", "LA", "LL"]
const ECG12_LEADS := ["RA", "LA", "RL", "LL", "V1", "V2", "V3", "V4", "V5", "V6"]
const LEAD_NAMES := {"RA": "bras droit (rouge/blanc : sous la clavicule droite)", "LA": "bras gauche (sous la clavicule gauche)",
	"LL": "jambe gauche (flanc gauche)", "RL": "jambe droite (flanc droit)", "V1": "V1 : 4e espace, bord droit du sternum",
	"V2": "V2 : 4e espace, bord gauche du sternum", "V3": "V3 : entre V2 et V4", "V4": "V4 : 5e espace, ligne médio-claviculaire",
	"V5": "V5 : ligne axillaire antérieure, niveau de V4", "V6": "V6 : ligne axillaire moyenne, niveau de V4"}
const O2_STEPS := [0.0, 1.0, 2.0, 3.0, 4.0, 6.0, 9.0, 12.0, 15.0]
const PUSH_PER_PX := 0.00026

var game: Node
var zv: ZoneView
var patient: Patient
var gear: PatientGear
var physio: Physio
var inv: Inventory
var hint := ""  ## ligne d'aide (ce que fait le clic ici)
var hover_label := ""
var airway_open := false
var bavu_on_face := false
var lucas_on := false

var _ghost: Node3D
var _ghost_id := ""
var _hold := {}  ## geste en cours (maintien) : {"kind", "t", "need", ...}
var _models := {}
# Massage
var cpr := false
var _push := 0.0
var _depth := 0.0
var _down := false
var _cycle_max := 0.0
var _cycle_min := 0.0
var _last_comp := -10.0
var _rate := 0.0
var _hands: Node3D
var _cpr_point := Vector2.ZERO
var _cpr_ok_spot := true
var comp_count := 0
var _since_vent := 0
# Ballon
var _bavu: Node3D
var _bag: Node3D
var _squeeze := 0.0
# LUCAS
var _lucas: Node3D
var _lucas_piston: Node3D
var _lucas_t := 0.0
# Voie veineuse (séquence complète : IVProcedure)
var iv_proc: IVProcedure
var veins := {"L": PackedVector3Array(), "R": PackedVector3Array()}
var _iv_misses := 0
var _disinfected := {}
var _stetho_beat := 0.0
var _neb_pending := []


func setup(p_game: Node) -> void:
	game = p_game
	zv = game.get("zone_view")
	patient = game.get("patient")
	gear = patient.gear
	physio = game.get("physio")
	inv = game.get("inv")
	iv_proc = IVProcedure.new()
	iv_proc.name = "VoieVeineuse"
	add_child(iv_proc)
	iv_proc.setup(self)
	iv_proc.build_veins()


func _model(file: String) -> Node3D:
	var sc: PackedScene = load("res://assets/models/%s.glb" % file)
	var n: Node3D = sc.instantiate()
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


func ev(kind: String, text := "", data := {}) -> void:
	game.call("event", kind, text, data)


func toast(text: String, ok := true) -> void:
	game.call("toast", text, ok)


func say(text: String) -> void:
	game.call("say", text, "patient")


# ---------------------------------------------------------------- Repères

func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _region(p: Vector3) -> String:
	var nk: Dictionary = Patient.landmarks.get("neck", {"x": 0.18})
	var nkx := float(nk["x"])
	var head_top := float(Patient.landmarks.get("head_top_x", 0.41))
	if p.x > nkx + 0.035 and p.x < head_top + 0.02 and absf(p.z) < 0.09:
		return "tete"
	if absf(p.x - nkx) <= 0.035 and absf(p.z) < 0.08:
		return "cou"
	for side in ["L", "R"]:
		var tip := Patient.arm_point(side, 1.0)
		var wr := Patient.arm_point(side, 0.8)
		if _flat(p, tip) < 0.06 or (_seg_dist(p, wr, tip) < 0.035):
			return "main_" + side
		var sh := Patient.arm_point(side, 0.0)
		if _seg_dist(p, sh, wr) < 0.05 and absf(p.z) > 0.17:
			return "bras_" + side
	if p.x > -0.12 and p.x <= nkx - 0.035 and absf(p.z) < 0.2:
		return "thorax"
	if p.x <= -0.12 and p.x > -0.45 and absf(p.z) < 0.17:
		return "abdomen"
	if p.x <= -0.45:
		return "jambes"
	return ""


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var k := clampf(ap.dot(ab) / maxf(ab.length_squared(), 1e-9), 0.0, 1.0)
	return (ap - ab * k).length()


## Moitié inférieure du sternum : point idéal pour le massage.
func cpr_ideal() -> Vector3:
	var a := Patient.lm("mid_sternum")
	var b := Patient.lm("xiphoid_tip")
	var p := a.lerp(b, 0.45)
	return Vector3(p.x, Patient.body_height(p.x, 0.0), 0.0)


func eye_point(side: float) -> Vector3:
	var x := 1.5895 - 1.29927
	var z := 0.0312 * side
	return Vector3(x, Patient.body_height(x, z), z)


func _carotid(p: Vector3) -> bool:
	var nk: Dictionary = Patient.landmarks.get("neck", {"x": 0.18, "half_width": 0.06})
	return absf(p.x - float(nk["x"])) < 0.035 and absf(p.z) > 0.012 and absf(p.z) < float(nk["half_width"]) + 0.01


func _radial(p: Vector3) -> String:
	for side in ["L", "R"]:
		if _flat(p, Patient.arm_point(side, 0.83)) < 0.035:
			return side
	return ""


func _fingertip(p: Vector3) -> String:
	for side in ["L", "R"]:
		if _flat(p, Patient.lm("fingertip_" + side)) < 0.045:
			return side
	return ""


# ---------------------------------------------------------------- Veines (voie veineuse)

## Veines (pli du coude, avant-bras, poignet, dos de la main) : construites et animées par
## IVProcedure (gonflées sous garrot, plates en cas de choc).
func _update_vein_vis() -> void:
	iv_proc.update_vis()


# ---------------------------------------------------------------- Survol (aperçu sous la souris)

func _set_ghost(id: String) -> void:
	if id == _ghost_id:
		return
	if _ghost:
		_ghost.queue_free()
		_ghost = null
	_ghost_id = id
	var file := ""
	match id:
		"main":
			file = "main_pouls"
		"stetho":
			file = "stethoscope"
		"lampe", "glucometre", "thermometre", "seringue":
			file = id
		"pads":
			file = "electrode_defib"
	if file != "":
		_ghost = _model(file)
		add_child(_ghost)
		_ghost.visible = false


func _place_ghost(h: Dictionary) -> void:
	if _ghost == null:
		return
	if h.is_empty() or h.get("device", false) or cpr:
		_ghost.visible = false
		return
	var p: Vector3 = h["pos"]
	var n: Vector3 = h["normal"]
	var cam := zv.camera.global_position
	var to := (p - cam)
	var fwd := (to - n * to.dot(n)).normalized()
	if fwd.length() < 0.1:
		fwd = Vector3(0, 0, -1)
	var right := n.cross(-fwd).normalized()
	var b := Basis(right, n, -fwd).orthonormalized()
	_ghost.visible = true
	match _ghost_id:
		"main":
			# Bout de l'index et du majeur sur le point visé, poignet vers le soignant
			_ghost.global_transform = Transform3D(b, p + n * 0.012 - fwd * 0.17)
		"stetho":
			_ghost.global_transform = Transform3D(b, p + n * 0.002)
		"lampe", "thermometre":
			var axis := (to.normalized() * 0.6 - n * 0.4).normalized()
			_ghost.global_transform = Transform3D(Basis(Quaternion(Vector3(0, 0, 1), axis)), p - axis * 0.07)
		"seringue":
			# Seringue tenue de profil, inclinée vers le point visé (embout à 1,5 cm de la peau). Avant,
			# elle était alignée sur le regard : on voyait le poussoir blanc de face, avec toutes les
			# parois transparentes empilées, comme une tache lumineuse sur la peau.
			var route: String = inv.current()["data"].get("route", "IV")
			(_ghost.find_child("Aiguille", true, false) as Node3D).visible = route == "IM"
			var side_dir := fwd.cross(n).normalized()
			var axis2 := (-n * 0.75 + fwd * 0.45 + side_dir * 0.3).normalized()
			var x := axis2.cross(n).normalized()
			_ghost.global_transform = Transform3D(Basis(x, axis2.cross(x), axis2).orthonormalized(), p + n * 0.015 - axis2 * 0.004)
		"pads":
			_ghost.global_transform = Transform3D(Basis(n.cross(Vector3(1, 0, 0)).normalized(), n, Vector3(1, 0, 0)).orthonormalized(), p + n * 0.003)
		_:
			_ghost.global_transform = Transform3D(b, p + n * 0.01)


# ---------------------------------------------------------------- Boucle

func _process(delta: float) -> void:
	iv_proc.tick(delta, zv.hit if zv.active else {})
	if not zv.active:
		if _ghost:
			_ghost.visible = false
		hint = ""
		return
	var id := inv.current_id()
	_set_ghost(id)
	var h := zv.hit
	_place_ghost(h)
	hover_label = ""
	hint = _hint_for(id, h)
	# Pose de voie veineuse en cours : l'étape guide l'aide ; seule la main qui palpe reste visible
	if iv_proc.active and iv_proc.wants(id, h) and not h.get("device", false):
		hint = iv_proc.hint(h)
		if _ghost and not (id == "main" and IVProcedure.STEPS[iv_proc.step] == "veine"):
			_ghost.visible = false
	if _ghost and id == "seringue" and not _hold.is_empty():
		_ghost.visible = false
	if not _hold.is_empty():
		_tick_hold(delta, h)
	_tick_cpr(delta)
	_tick_bavu(delta)


func _process_always(delta: float) -> void:
	_tick_lucas(delta)


func _physics_process(delta: float) -> void:
	_process_always(delta)


## Ligne d'aide selon l'objet en main et ce qu'il y a sous la souris.
func _hint_for(id: String, h: Dictionary) -> String:
	if cpr:
		return "Massage : pousse la souris vers le bas pour enfoncer le thorax, remonte pour relâcher · relâche le clic pour arrêter"
	if h.is_empty():
		return "Pointe le patient (ou un bouton de l'appareil) · clic droit maintenu : tourner · molette : zoom"
	if h.get("device", false):
		var it: Interactable = h["collider"]
		hover_label = it.label
		return "Clic : %s" % it.label
	var p: Vector3 = h["pos"]
	var reg := _region(p)
	match id:
		"main":
			if reg == "thorax" and _flat(p, cpr_ideal()) < 0.06:
				return "Clic maintenu : massage cardiaque (talon de la main sur le sternum)"
			if _carotid(p):
				return "Clic maintenu : prendre le pouls carotidien"
			if _radial(p) != "":
				return "Clic maintenu : prendre le pouls radial"
			if _fingertip(p) != "":
				return "Clic maintenu : temps de recoloration cutanée"
			if reg == "tete":
				return "Clic : appeler et stimuler · clic maintenu sur le menton : libérer les voies aériennes et regarder s'il respire"
			if reg == "abdomen":
				return "Clic : palper l'abdomen"
			if gear.tourniquet.size() > 0 and reg.begins_with("bras"):
				return "Clic : desserrer le garrot"
			return "Clic : stimuler"
		"stetho":
			return "Clic maintenu : ausculter ici"
		"lampe":
			return "Clic : examiner les pupilles" if reg == "tete" else "Vise un œil"
		"thermometre":
			return "Clic : température tympanique (oreille)" if reg == "tete" else "Vise l'oreille"
		"glucometre":
			return "Clic : glycémie capillaire au bout du doigt" if _fingertip(p) != "" else "Vise le bout d'un doigt"
		"electrodes":
			var lead := _next_lead(SCOPE_LEADS, gear.electrodes)
			return "Clic : coller l'électrode %s" % LEAD_NAMES.get(lead, lead)
		"ecg12":
			var lead2 := _next_lead(ECG12_LEADS, gear.ecg12)
			return "Clic : électrode %s" % LEAD_NAMES.get(lead2, lead2)
		"pads":
			return "Clic : coller l'électrode %s" % ("sous la clavicule droite" if gear.pads.size() == 0 else "sous l'aisselle gauche (pointe du cœur)")
		"spo2":
			return "Clic : pince au bout du doigt" if _fingertip(p) != "" else "Vise le bout d'un doigt"
		"brassard":
			return "Clic : brassard au bras" if reg.begins_with("bras") else "Vise le haut d'un bras"
		"garrot", "antiseptique", "catheter18", "catheter20":
			if gear.has_iv():
				return "Il a déjà une voie veineuse"
			return "Clic sur le bras : commencer la pose de la voie veineuse (7 étapes)" if reg.begins_with("bras") or reg.begins_with("main") else "Vise un bras"
		"tubes":
			return "Clic sur le robinet du cathéter : prélever les tubes" if gear.has_iv() else "Il faut d'abord un cathéter veineux"
		"perfuseur":
			return "Clic sur le robinet du cathéter : brancher la perfusion" if gear.has_iv() else "Il faut d'abord un cathéter veineux"
		"seringue":
			var d: Dictionary = inv.current()["data"]
			if d.get("route", "") == "IM":
				return "Clic maintenu sur le deltoïde ou la cuisse : injection IM (%s)" % inv.current()["name"]
			return "Clic maintenu sur le robinet du cathéter : injecter (%s)" % inv.current()["name"]
		"bavu":
			if bavu_on_face:
				return "Clic sur le ballon : insuffler (1 s, le thorax doit se soulever)"
			return "Clic sur le visage : appliquer le masque (tête basculée en arrière)"
		"masque_o2", "lunettes_o2", "nebuliseur":
			return "Clic sur le visage : mettre en place (puis régler le débit d'O2 au mur)"
		"lucas":
			return "Clic sur le thorax : installer le LUCAS (massage automatique)"
	return ""


func _next_lead(order: Array, placed: Dictionary) -> String:
	for l in order:
		if not placed.has(l):
			return l
	return ""


# ---------------------------------------------------------------- Clic

func press(h: Dictionary) -> void:
	var id := inv.current_id()
	if not h.is_empty() and h.get("device", false):
		_device((h["collider"] as Interactable).id)
		return
	if id == "bavu" and bavu_on_face and _bag_hit():
		_insufflate()
		return
	if iv_proc.wants(id, h):
		iv_proc.press(h)
		return
	if h.is_empty():
		return
	var p: Vector3 = h["pos"]
	var reg := _region(p)
	match id:
		"main":
			_hand_press(p, reg)
		"stetho":
			_hold = {"kind": "stetho", "t": 0.0, "need": 2.5, "p": p}
		"lampe":
			if reg == "tete":
				_pupils()
		"thermometre":
			if reg == "tete":
				_hold = {"kind": "thermo", "t": 0.0, "need": 1.5, "p": p}
		"glucometre":
			if _fingertip(p) != "":
				_hold = {"kind": "glyc", "t": 0.0, "need": 4.0, "p": p}
				_gloves_check("glycémie capillaire")
				Sfx.play("pique", p, -10.0)
		"electrodes":
			_scope_electrode(p)
		"ecg12":
			_ecg12_electrode(p)
		"pads":
			_pad(p)
		"spo2":
			var s := _fingertip(p)
			if s != "":
				gear.place_spo2(s)
				inv.use_current()
				ev("spo2", "Capteur de SpO2 posé (main %s)" % ("gauche" if s == "L" else "droite"))
		"brassard":
			if reg.begins_with("bras"):
				var side := reg.substr(5)
				gear.place_cuff(side)
				inv.use_current()
				game.get("monitor").call("measure_nibp")
				ev("brassard", "Brassard posé au bras %s" % ("gauche" if side == "L" else "droit"))
		"tubes":
			if _near_port(p):
				_gloves_check("prélèvement")
				inv.use_current()
				ev("prelevement", "Tubes prélevés et envoyés au laboratoire (pneumatique)")
				toast("Tubes partis au labo : prescris les analyses sur l'ordinateur")
				Sfx.play("plop", p, -8.0)
		"perfuseur":
			if _near_port(p):
				iv_proc.connect_perfusion()
		"seringue":
			_syringe_press(p, reg)
		"bavu":
			if reg == "tete" or reg == "cou":
				_bavu_on()
		"masque_o2", "lunettes_o2", "nebuliseur":
			if reg == "tete":
				_o2_device(id)
		"lucas":
			if reg == "thorax":
				_install_lucas()


func release(_h: Dictionary) -> void:
	if cpr:
		_stop_cpr()
	if not _hold.is_empty():
		var k: String = _hold["kind"]
		if k in ["stetho", "pulse", "radial", "airway", "desinf", "crt", "syringe"] and _hold["t"] < _hold["need"]:
			if k == "syringe":
				toast("Injection interrompue : maintiens le clic jusqu'au bout", false)
				iv_proc.hide_syringe()
			_hold = {}
		else:
			_hold = {}
	iv_proc.release(_h)


func drag(_h: Dictionary, rel: Vector2) -> void:
	if cpr:
		_push = clampf(_push + rel.y * PUSH_PER_PX * Settings.sensitivity, 0.0, 0.08)
		return
	if iv_proc.busy():
		iv_proc.drag(_h, rel)


## Échap en vue rapprochée : arrête ce qui est en cours (vrai si quelque chose a été annulé).
func cancel_current() -> bool:
	if cpr:
		_stop_cpr()
		return true
	if iv_proc.cancel():
		return true
	return false


# ---------------------------------------------------------------- Maintiens (pouls, auscultation...)

func _tick_hold(delta: float, h: Dictionary) -> void:
	var k: String = _hold["kind"]
	if not zv.mouse_left and k != "glyc" and k != "thermo":
		_hold = {}
		if k == "syringe":
			iv_proc.hide_syringe()
		return
	_hold["t"] = float(_hold["t"]) + delta
	var tt: float = _hold["t"]
	var need: float = _hold["need"]
	game.call("set_progress", tt / need, _hold_label(k))
	if k == "syringe":
		iv_proc.syringe_progress(clampf(tt / need, 0.0, 1.0))
	if k == "stetho":
		_stetho_sound(delta)
	if k == "desinf" and not h.is_empty():
		_hold["p"] = h["pos"]
	if tt < need:
		return
	_hold = {}
	game.call("set_progress", 0.0, "")
	match k:
		"pulse":
			_pulse_result("carotidien")
		"radial":
			_pulse_result("radial")
		"airway":
			_airway_result()
		"stetho":
			_ausc_result(_hold_p_or(h))
		"thermo":
			var tx := ("Température tympanique : %.1f °C" % physio.temp).replace(".", ",")
			toast(tx)
			ev("temperature", tx)
		"glyc":
			var g := physio.glyc
			var tx2 := ("Glycémie capillaire : %.2f g/L" % g).replace(".", ",") if g >= 0.2 else "Glycémie capillaire : LO (< 0,20 g/L)"
			toast(tx2, g >= 0.7 and g <= 1.8)
			ev("glycemie", tx2, {"value": g})
		"crt":
			var crt := 2 if physio.sys > 95.0 and physio.signs["mottling"] < 0.2 else (4 if physio.sys > 70.0 else 6)
			var tx3 := "Temps de recoloration cutanée : %d s%s" % [crt, " (allongé)" if crt > 3 else ""]
			toast(tx3, crt <= 3)
			ev("trc", tx3)
		"desinf":
			var reg: String = _hold.get("reg", "")
			_disinfected[reg.substr(reg.length() - 1)] = true
			toast("Peau désinfectée")
			ev("desinfection", "Désinfection cutanée")
		"syringe":
			_inject_done()


var _last_hold_p := Vector3.ZERO


func _hold_p_or(h: Dictionary) -> Vector3:
	return h["pos"] if not h.is_empty() else _last_hold_p


func _hold_label(k: String) -> String:
	return {"pulse": "Pouls carotidien…", "radial": "Pouls radial…", "airway": "Tête basculée : regarder, écouter, sentir…",
		"stetho": "Auscultation…", "thermo": "Température…", "glyc": "Lecture de la glycémie…", "crt": "Pression sur l'ongle…",
		"desinf": "Désinfection…", "syringe": "Injection…"}.get(k, "")


func _gloves_check(what: String) -> void:
	if not game.get("flags").get("gants", false):
		game.call("case_fault", "Geste invasif sans gants (%s)" % what, 2.0)


# ---------------------------------------------------------------- Mains

func _hand_press(p: Vector3, reg: String) -> void:
	_last_hold_p = p
	if reg == "thorax" and _flat(p, cpr_ideal()) < 0.07:
		_start_cpr(p)
		return
	if _carotid(p):
		_hold = {"kind": "pulse", "t": 0.0, "need": 3.0, "p": p}
		return
	if _radial(p) != "":
		_hold = {"kind": "radial", "t": 0.0, "need": 3.0, "p": p}
		return
	if _fingertip(p) != "":
		_hold = {"kind": "crt", "t": 0.0, "need": 2.0, "p": p}
		return
	if not gear.tourniquet.is_empty() and (reg.begins_with("bras") or reg.begins_with("main")):
		gear.remove_tourniquet()
		_update_vein_vis()
		toast("Garrot desserré")
		ev("garrot_retire", "")
		return
	if reg == "tete":
		var nose := Patient.lm("nose_tip")
		if p.x < nose.x + 0.01:
			# Menton / bouche : bascule de la tête, menton soulevé ; on regarde la respiration
			_hold = {"kind": "airway", "t": 0.0, "need": 5.0, "p": p}
			airway_open = true
			return
		_stimulate()
		return
	if reg == "abdomen":
		_palpate(p)
		return
	if reg in ["thorax", "cou", "bras_L", "bras_R", "jambes"]:
		_stimulate()


func _stimulate() -> void:
	var r: String = game.get("case").call("stimulation_response")
	toast("Vous l'appelez fort et le stimulez : " + r)
	ev("stimulation", "Réactivité : " + r)
	if physio.speaks:
		var ans: String = game.get("case").get("profile").get("reply", "Oui… docteur…")
		say(ans)
	if physio.gcs >= 9 and not physio.in_arrest():
		patient.set_eyes_open(0.8)
		get_tree().create_timer(2.5).timeout.connect(func() -> void:
			if physio.gcs < 13:
				patient.set_eyes_open(0.0))


func _pulse_result(where: String) -> void:
	var txt := ""
	var present := physio.pulse() and (physio.sys > (60.0 if where == "carotidien" else 80.0))
	if not present:
		txt = "Pas de pouls %s." % where
	else:
		var q := "bien frappé" if physio.sys > 100.0 else ("filant" if physio.sys < 85.0 else "")
		var reg_txt := "régulier" if physio.rhythm in ["sinus", "brady"] else "rapide"
		txt = "Pouls %s %s, %s, environ %d par minute." % [where, reg_txt, q, int(round(physio.hr / 5.0) * 5.0)]
	toast(txt, present)
	ev("pouls", txt, {"present": present})


func _airway_result() -> void:
	var txt := ""
	if physio.in_arrest():
		txt = "Voies aériennes libérées. Pas de respiration normale (quelques gasps)." if randf() < 0.5 else "Voies aériennes libérées. Il ne respire pas."
	elif physio.rr < 1.0:
		txt = "Voies aériennes libérées. Il ne respire pas."
	elif physio.rr < 9.0:
		txt = "Voies aériennes libérées. Respiration très lente et superficielle (%d/min), ronflante." % int(physio.rr)
	elif physio.rr > 24.0:
		txt = "Voies aériennes libres. Respiration rapide (%d/min)%s." % [int(physio.rr), ", avec tirage" if physio.breath_noise == "tirage" else ""]
	else:
		txt = "Voies aériennes libres. Respiration normale (%d/min)." % int(physio.rr)
	toast(txt, not physio.in_arrest() and physio.rr >= 9.0)
	ev("respiration", txt)


func _palpate(_p: Vector3) -> void:
	var txt := "Abdomen souple, dépressible, indolore."
	match physio.abdomen:
		"douloureux":
			txt = "Abdomen douloureux à la palpation."
			if physio.speaks:
				say("Aïe ! Là, ça fait mal…")
		"defense":
			txt = "Défense abdominale."
	toast(txt)
	ev("abdomen", txt)


func _pupils() -> void:
	patient.set_eyes_open(0.7)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if not physio.conscious:
			patient.set_eyes_open(0.0))
	var size := float(physio.pupils["size"])
	var desc := "%d mm" % int(round(size))
	if size <= 2.0:
		desc += ", en myosis serré (« en tête d'épingle »)"
	elif size >= 5.5:
		desc += ", en mydriase"
	var txt := "Pupilles %s, %s, symétriques." % [desc, "réactives" if physio.pupils["reactive"] else "aréactives"]
	toast(txt)
	ev("pupilles", txt)


# ---------------------------------------------------------------- Auscultation

func _stetho_sound(delta: float) -> void:
	var p: Vector3 = _hold.get("p", Vector3.ZERO)
	if zv.hit.has("pos"):
		p = zv.hit["pos"]
		_hold["p"] = p
	var heart := _heart_spot(p) != ""
	if heart and physio.pulse():
		_stetho_beat += delta
		var period := 60.0 / maxf(physio.hr, 20.0)
		if _stetho_beat >= period:
			_stetho_beat -= period
			var vol := -8.0 if physio.heart_sound != "assourdi" else -18.0
			Sfx.play("coeur", Vector3.INF, vol, 1.0)
	else:
		var lung := _lung_spot(p)
		var s: String = physio.lungs.get(lung, "normal")
		var lvl := 0.0 if s == "absent" or physio.rr < 1.0 else (0.35 if s == "diminue" else 0.8)
		var ph := fmod(physio.time * maxf(physio.rr, 1.0) / 60.0, 1.0)
		lvl *= 0.4 + 0.6 * sin(clampf(ph / 0.4, 0.0, 1.0) * PI) if ph < 0.4 else 0.25
		Sfx.loop("respi", zv.camera.global_position, lvl)
		if s == "sibilants":
			Sfx.loop("sibilant", zv.camera.global_position, lvl * 0.9 if ph > 0.3 else 0.0)
		if s == "crepitants":
			Sfx.loop("crepitant", zv.camera.global_position, lvl)


func _heart_spot(p: Vector3) -> String:
	var apex := Patient.lm("heart_apex")
	if _flat(p, Vector3(0.055, 0, -0.03)) < 0.025:
		return "aortique"
	if _flat(p, Vector3(0.055, 0, 0.03)) < 0.025:
		return "pulmonaire"
	if _flat(p, Vector3(-0.03, 0, 0.025)) < 0.025:
		return "tricuspide"
	if _flat(p, apex) < 0.03:
		return "mitral"
	return ""


func _lung_spot(p: Vector3) -> String:
	var side := "g" if p.z > 0.0 else "d"
	return ("apex_" if p.x > -0.03 else "base_") + side


func _ausc_result(p: Vector3) -> void:
	var hs := _heart_spot(p)
	var txt := ""
	if hs != "":
		if not physio.pulse():
			txt = "Foyer %s : aucun bruit du cœur." % hs
		else:
			var d := {"normal": "bruits du cœur réguliers, pas de souffle", "assourdi": "bruits du cœur assourdis, lointains",
				"galop": "bruits du cœur rapides, galop", "souffle": "souffle systolique"}
			txt = "Foyer %s : %s (%d/min)." % [hs, d.get(physio.heart_sound, "bruits normaux"), int(physio.hr)]
	else:
		var lung := _lung_spot(p)
		var s: String = physio.lungs.get(lung, "normal")
		if physio.rr < 1.0 or physio.in_arrest():
			s = "absent"
		var names := {"apex_d": "sommet droit", "apex_g": "sommet gauche", "base_d": "base droite", "base_g": "base gauche"}
		var d2 := {"normal": "murmure vésiculaire normal", "sibilants": "sibilants (sifflements expiratoires)", "crepitants": "crépitants",
			"diminue": "murmure vésiculaire très diminué", "absent": "silence auscultatoire (pas de murmure)"}
		txt = "Poumon, %s : %s." % [names[lung], d2.get(s, s)]
	toast(txt)
	ev("auscultation", txt)


# ---------------------------------------------------------------- Électrodes

func _scope_electrode(p: Vector3) -> void:
	var lead := _next_lead(SCOPE_LEADS, gear.electrodes)
	if lead == "":
		return
	var ok := true
	match lead:
		"RA":
			ok = p.z < 0.0 and p.x > -0.05
		"LA":
			ok = p.z > 0.0 and p.x > -0.05
		"LL":
			ok = p.z > 0.0 and p.x < -0.04
	gear.place_electrode(lead, p)
	inv.use_current()
	if not ok:
		toast("Électrode %s mal placée : le tracé sera faux (inversion)" % lead, false)
		game.call("case_fault", "Électrodes du scope mal placées", 2.0)
	if gear.scope_leads() >= 3:
		ev("scope", "Scope branché (3 électrodes)")
		toast("Scope branché : regarde le moniteur")


func _ecg12_electrode(p: Vector3) -> void:
	var lead := _next_lead(ECG12_LEADS, gear.ecg12)
	if lead == "":
		return
	var err := _ecg12_error(lead, p)
	gear.place_electrode(lead, p, true)
	inv.use_current()
	if err != "":
		toast("%s : %s" % [lead, err], false)
		var bad: Array = game.get("flags").get("ecg12_bad", [])
		bad.append(lead)
		game.get("flags")["ecg12_bad"] = bad
	if gear.ecg12.size() >= 10:
		ev("ecg12_pose", "10 électrodes de l'ECG posées")
		toast("Électrodes posées : lance l'enregistrement sur l'électrocardiographe")


## Erreur de position d'une électrode de l'ECG (vide si bien placée), jugée sur les vraies côtes.
func _ecg12_error(lead: String, p: Vector3) -> String:
	var code := Patient.rib_code(p.x, p.z)
	var mcl := float(Patient.landmarks.get("mcl_z_L", 0.083))
	match lead:
		"RA":
			return "" if p.z < -0.05 and p.x > -0.1 else "doit être sur l'épaule ou le bras droit"
		"LA":
			return "" if p.z > 0.05 and p.x > -0.1 else "doit être sur l'épaule ou le bras gauche"
		"RL":
			return "" if p.z < 0.0 and p.x < -0.2 else "doit être sur le flanc ou la jambe droite"
		"LL":
			return "" if p.z > 0.0 and p.x < -0.2 else "doit être sur le flanc ou la jambe gauche"
		"V1":
			return "" if code == -4 and p.z < -0.005 and p.z > -0.045 else "4e espace intercostal, juste à droite du sternum"
		"V2":
			return "" if code == -4 and p.z > 0.005 and p.z < 0.045 else "4e espace intercostal, juste à gauche du sternum"
		"V3":
			return "" if p.z > 0.03 and p.z < mcl and p.x < 0.02 and p.x > -0.07 else "entre V2 et V4"
		"V4":
			return "" if code == -5 and absf(p.z - mcl) < 0.025 else "5e espace intercostal, ligne médio-claviculaire"
		"V5":
			return "" if p.z > mcl + 0.015 and p.z < 0.14 and p.x < 0.0 and p.x > -0.08 else "ligne axillaire antérieure, au niveau de V4"
		"V6":
			return "" if p.z >= 0.13 and p.x < 0.0 and p.x > -0.09 else "ligne axillaire moyenne, au niveau de V4"
	return ""


func _pad(p: Vector3) -> void:
	if gear.pads.size() >= 2:
		return
	var first := gear.pads.size() == 0
	var ok := true
	if first:
		ok = p.z < -0.02 and p.x > 0.0 and p.x < 0.11
	else:
		var mal := Patient.lm_skin("ics5_mal_L")
		ok = p.z > 0.08 and p.x < 0.04 and p.x > -0.11
		var _m := mal
	gear.place_pad(p)
	inv.use_current()
	if not ok:
		toast("Électrode mal placée : le courant ne traversera pas bien le cœur", false)
		game.get("flags")["pads_bad"] = true
		game.call("case_fault", "Électrodes de défibrillation mal placées", 4.0)
	if gear.pads.size() >= 2:
		ev("pads", "Électrodes de défibrillation collées")
		toast("Électrodes collées : allume le défibrillateur")


# ---------------------------------------------------------------- Voie veineuse

## Garrot, désinfection, choix de la veine, ponction, pansement, branchement : IVProcedure.

func _near_port(p: Vector3) -> bool:
	if not gear.has_iv():
		toast("Il n'a pas de voie veineuse", false)
		return false
	var port: Vector3 = gear.iv["port"]
	if p.distance_to(port) > 0.04:
		toast("Vise le bouchon du cathéter (site d'injection)", false)
		return false
	return true


# ---------------------------------------------------------------- Seringues

func _syringe_press(p: Vector3, reg: String) -> void:
	var data: Dictionary = inv.current()["data"]
	var route: String = data.get("route", "IV")
	if route == "IV":
		if not _near_port(p):
			return
		if not gear.tourniquet.is_empty():
			game.call("case_fault", "Injection avec le garrot encore serré", 3.0)
			toast("Le garrot est encore serré : desserre-le d'abord", false)
			return
	elif route == "IM":
		var deltoid := false
		for side in ["L", "R"]:
			if _flat(p, Patient.arm_point(side, 0.12)) < 0.05:
				deltoid = true
		var thigh := reg == "jambes" and p.x > -0.85 and p.x < -0.45
		if not deltoid and not thigh:
			toast("Injection IM : face externe de la cuisse ou deltoïde", false)
			return
	else:
		toast("Ce produit ne s'injecte pas", false)
		return
	_gloves_check("injection")
	_hold = {"kind": "syringe", "t": 0.0, "need": 2.0 if route == "IV" else 1.2, "p": p}
	iv_proc.show_syringe(p, route)
	Sfx.play("pique", p, -10.0)


func _inject_done() -> void:
	var it := inv.current()
	var data: Dictionary = it["data"]
	var drug: String = data["drug"]
	var dose: float = data["dose"]
	var route: String = data["route"]
	inv.use_current()
	iv_proc.syringe_progress(1.0)
	get_tree().create_timer(0.6).timeout.connect(iv_proc.hide_syringe)
	game.call("drug_given", drug, dose, route)
	if route == "IV":
		iv_proc.line_or_injection()


# ---------------------------------------------------------------- Oxygène

func _o2_device(id: String) -> void:
	var kind: String = {"masque_o2": "masque", "lunettes_o2": "lunettes", "nebuliseur": "nebu"}[id]
	if bavu_on_face:
		_bavu_off()
	var data: Dictionary = inv.current()["data"]
	gear.set_o2(kind)
	physio.o2_device = kind
	inv.use_current()
	var names := {"masque": "Masque à haute concentration posé", "lunettes": "Lunettes à oxygène posées", "nebu": "Nébulisation installée"}
	ev("o2_" + kind, names[kind])
	if kind == "nebu":
		_neb_pending = data.get("drugs", [])
		_check_neb()
	if physio.o2_flow <= 0.0:
		toast("Pense à ouvrir l'oxygène au débitmètre mural", false)


func _check_neb() -> void:
	if _neb_pending.is_empty() or physio.o2_device != "nebu":
		return
	if physio.o2_flow >= 6.0:
		for dd in _neb_pending:
			game.call("drug_given", dd[0], dd[1], "NEB")
		_neb_pending = []
	else:
		toast("Nébulisation : il faut 6 à 8 L/min d'O2 au débitmètre", false)


func set_o2_flow(v: float) -> void:
	physio.o2_flow = v
	ev("o2_debit", "Débit d'oxygène : %d L/min" % int(v), {"flow": v})
	_check_neb()


# ---------------------------------------------------------------- Appareils (boutons)

func _device(id: String) -> void:
	var parts := id.split(":")
	match parts[0]:
		"defib":
			(game.get("defib") as Defibrillator).press(parts[1])
		"scope":
			game.get("monitor").call("measure_nibp")
			toast("Mesure de la pression lancée")
		"ecg":
			if parts[1] == "electrodes":
				if inv.add("ecg12"):
					toast("Électrodes de l'ECG prises : pose-les sur le patient (vue Thorax)")
				else:
					toast("Tu as déjà les électrodes (ou les mains pleines)", false)
			else:
				game.call("record_ecg12")
		"rampe":
			var i := O2_STEPS.find(physio.o2_flow)
			if i < 0:
				i = 0
			i = clampi(i + (1 if parts[1] == "plus" else -1), 0, O2_STEPS.size() - 1)
			set_o2_flow(O2_STEPS[i])
			toast("Oxygène : %d L/min" % int(O2_STEPS[i]))
			Sfx.play("souffle", Vector3.INF, -20.0 + i, 1.0)


# ---------------------------------------------------------------- Massage cardiaque

func _start_cpr(p: Vector3) -> void:
	if lucas_on:
		toast("Le LUCAS masse déjà", false)
		return
	cpr = true
	zv.locked = true
	_push = 0.0
	_depth = 0.0
	_down = false
	_cycle_max = 0.0
	_cycle_min = 0.0
	var ideal := cpr_ideal()
	_cpr_ok_spot = _flat(p, ideal) < 0.03
	_cpr_point = Vector2(p.x, p.z)
	if not _cpr_ok_spot:
		toast("Mains mal placées : le talon de la main sur la moitié inférieure du sternum", false)
	if _hands == null:
		_hands = _model("mains_rcp")
		add_child(_hands)
	_hands.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not game.get("journal").has("rcp"):
		ev("rcp", "Massage cardiaque externe débuté")


func _stop_cpr() -> void:
	cpr = false
	zv.locked = false
	_push = 0.0
	if _hands:
		_hands.visible = false
	patient.set_compression(0.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _tick_cpr(delta: float) -> void:
	if not cpr:
		return
	# Le thorax résiste un peu : sans pousser, il remonte doucement
	_push = maxf(0.0, _push - delta * 0.004)
	_depth = lerpf(_depth, _push, 1.0 - exp(-delta * 30.0))
	var top := Patient.body_height(_cpr_point.x, _cpr_point.y)
	patient.set_compression(_depth, _cpr_point)
	if _hands:
		_hands.global_position = Vector3(_cpr_point.x, top + patient.breath_now - _depth * 0.98 + 0.004, _cpr_point.y)
	if not _down and _depth > 0.02:
		_down = true
		_cycle_max = _depth
	if _down:
		_cycle_max = maxf(_cycle_max, _depth)
		if _depth < 0.008:
			_down = false
			var now := physio.time
			var dt := now - _last_comp
			_last_comp = now
			if dt < 3.0:
				_rate = lerpf(_rate if _rate > 0.0 else 60.0 / dt, 60.0 / maxf(dt, 0.2), 0.4)
			var recoil := _depth < 0.006
			_register_compression(_cycle_max * (1.0 if _cpr_ok_spot else 0.7), _rate, recoil)


func _register_compression(depth: float, rate: float, recoil: bool) -> void:
	comp_count += 1
	_since_vent += 1
	physio.compression(depth, rate, recoil)
	(game.get("defib") as Defibrillator).cpr_feedback(depth, rate, recoil)
	game.get("monitor").call("compression")
	Sfx.play("compression", Vector3.INF, -12.0, randf_range(0.95, 1.05))
	game.call("on_compression", depth, rate)
	if physio.pulse() and physio.gcs >= 8 and comp_count % 5 == 1:
		game.call("case_fault", "Massage cardiaque chez un patient qui a un pouls", 8.0)
		if physio.speaks:
			say("Aïe ! Mais arrêtez !")


# ---------------------------------------------------------------- Ballon (BAVU)

func _bavu_on() -> void:
	if physio.o2_device != "":
		gear.set_o2("")
		physio.o2_device = ""
	if _bavu == null:
		_bavu = _model("bavu")
		add_child(_bavu)
		_bag = _bavu.find_child("Ballon", true, false) as Node3D
	var nose := Patient.lm("nose_tip")
	var mask := Vector3(nose.x - 0.015, Patient.body_height(nose.x - 0.015, 0.0) + 0.04, 0.0)
	var b := Basis(Vector3.UP, deg_to_rad(-90.0))
	_bavu.global_transform = Transform3D(b, mask - b * Vector3(0, -0.035, 0.24))
	_bavu.visible = true
	bavu_on_face = true
	ev("bavu", "Ventilation au masque et au ballon (BAVU)")
	if not airway_open:
		toast("Pense à basculer la tête en arrière (mains, clic maintenu sur le menton)", false)


func _bavu_off() -> void:
	bavu_on_face = false
	if _bavu:
		_bavu.visible = false


func _bag_hit() -> bool:
	if _bag == null:
		return false
	var r := zv.mouse_ray()
	var c := _bag.global_position
	var from: Vector3 = r[0]
	var dir: Vector3 = r[1]
	var k := (c - from).dot(dir)
	return (from + dir * k).distance_to(c) < 0.09


func _insufflate() -> void:
	if _squeeze > 0.3:
		return
	_squeeze = 1.0
	var effective := airway_open and not cpr
	patient.insufflate(effective)
	physio.insufflation(effective)
	Sfx.play("souffle", Patient.lm("nose_tip"), -12.0, 0.8)
	game.call("on_insufflation", effective)
	if not airway_open:
		toast("L'air ne passe pas : bascule la tête en arrière (menton soulevé)", false)
	elif cpr:
		toast("On n'insuffle pas pendant une compression", false)
	_since_vent = 0


func _tick_bavu(delta: float) -> void:
	if _bag == null:
		return
	_squeeze = move_toward(_squeeze, 0.0, delta * 1.6)
	var s := sin(_squeeze * PI * 0.5)
	_bag.scale = Vector3(1.0 - 0.35 * s, 1.0 - 0.3 * s, 1.0)


# ---------------------------------------------------------------- LUCAS (massage automatique)

func _install_lucas() -> void:
	if lucas_on:
		return
	if cpr:
		_stop_cpr()
	var ideal := cpr_ideal()
	_lucas = Node3D.new()
	_lucas.name = "LUCAS"
	add_child(_lucas)
	var shell := MeshUtil.mat(Color(0.88, 0.89, 0.9), 0.35)
	var dark := MeshUtil.mat(Color(0.12, 0.13, 0.15), 0.45)
	var top := Patient.body_height(ideal.x, 0.0) + 0.17
	for s in [-1.0, 1.0]:
		var leg := MeshUtil.box_instance(_lucas, Vector3(0.05, top - Patient.TABLE_TOP + 0.03, 0.06), Vector3(ideal.x, (top + Patient.TABLE_TOP) * 0.5, s * 0.25), shell, "Jambe")
		leg.rotation_degrees.x = -12.0 * s
	MeshUtil.box_instance(_lucas, Vector3(0.12, 0.08, 0.56), Vector3(ideal.x, top, 0.0), shell, "Arche")
	MeshUtil.box_instance(_lucas, Vector3(0.16, 0.1, 0.2), Vector3(ideal.x, top + 0.02, 0.0), dark, "Moteur")
	MeshUtil.box_instance(_lucas, Vector3(0.08, 0.004, 0.06), Vector3(ideal.x, top + 0.072, 0.0), MeshUtil.emissive(Color(0.3, 0.9, 0.5), 1.5), "Voyant")
	MeshUtil.box_instance(_lucas, Vector3(0.5, 0.015, 0.62), Vector3(ideal.x, Patient.TABLE_TOP - 0.005, 0.0), dark, "Planche")
	_lucas_piston = Node3D.new()
	_lucas.add_child(_lucas_piston)
	MeshUtil.cylinder_instance(_lucas_piston, 0.012, 0.12, Vector3(0, 0.06, 0), MeshUtil.mat(Color(0.75, 0.77, 0.8), 0.25, 0.9), "Tige")
	var cup := MeshUtil.cylinder_instance(_lucas_piston, 0.045, 0.02, Vector3(0, 0.0, 0), MeshUtil.mat(Color(0.85, 0.87, 0.9, 1.0), 0.3), "Ventouse")
	(cup.mesh as CylinderMesh).top_radius = 0.025
	_lucas_piston.position = Vector3(ideal.x, top - 0.16, 0.0)
	lucas_on = true
	inv.use_current()
	ev("lucas", "LUCAS installé : massage automatique (102/min, 5,3 cm)")
	toast("LUCAS en marche : tu as les mains libres")


func _tick_lucas(delta: float) -> void:
	if not lucas_on:
		return
	if not physio.in_arrest():
		# Pouls revenu : on arrête la machine
		lucas_on = false
		patient.set_compression(0.0)
		toast("Le LUCAS est arrêté (pouls présent)")
		return
	var defib := game.get("defib") as Defibrillator
	if defib.analysing > 0.0:
		patient.set_compression(0.0)
		return
	_lucas_t += delta * 102.0 / 60.0
	var ph := fmod(_lucas_t, 1.0)
	var d := 0.053 * maxf(0.0, sin(ph * TAU)) if ph < 0.5 else 0.0
	var ideal := cpr_ideal()
	patient.set_compression(d, Vector2(ideal.x, 0.0))
	if _lucas_piston:
		_lucas_piston.position.y = Patient.body_height(ideal.x, 0.0) + 0.01 - d
	if ph < 0.5 and fmod(_lucas_t - delta * 102.0 / 60.0, 1.0) > 0.5:
		physio.compression(0.053, 102.0, true)
		defib.cpr_feedback(0.053, 102.0, true)
		game.get("monitor").call("compression")
		Sfx.play("compression", Vector3.INF, -18.0, 1.1)
