class_name Defibrillator
extends Node
## Défibrillateur moniteur posé sur le chariot d'urgence. Mode semi-automatique (DSA : l'appareil
## analyse le rythme et recommande ou non le choc) ou manuel (énergie choisie à la molette).
## Il lit le rythme par les électrodes de défibrillation collées sur le patient, guide le massage
## (profondeur, fréquence) et délivre le choc si personne ne touche le patient.

signal shocked(energy: int)
signal analysed(shock_advised: bool)

const ENERGIES := [0, 150, 200, 360]  ## 0 : mode DSA (énergie automatique 200 J)

var model: Node3D
var physio: Physio
var gear: PatientGear
var on := false
var energy_i := 0
var charged := false
var charging := 0.0
var analysing := 0.0
var advice := ""  ## dernier message
var advice_t := 0.0
var shocks := 0
var last_analysis := -1000.0
var cpr_depth := 0.0  ## dernière compression (m)
var cpr_rate := 0.0
var cpr_recoil := true
var _vp: SubViewport
var _screen: DefibScreen
var _t := 0.0
var _hold_hands := false  ## quelqu'un touche le patient (massage en cours)
var buttons := {}  ## nom -> Interactable (zone rapprochée)


func setup(p_model: Node3D, p_physio: Physio, p_gear: PatientGear) -> void:
	model = p_model
	physio = p_physio
	gear = p_gear
	_vp = SubViewport.new()
	_vp.size = Vector2i(560, 390)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_vp)
	_screen = DefibScreen.new()
	_screen.defib = self
	_screen.size = Vector2(560, 390)
	_vp.add_child(_screen)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.17, 0.118)
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _vp.get_texture()
	quad.material_override = m
	quad.position = Vector3(-0.06, 0.16, 0.1385)
	model.add_child(quad)
	# Boutons cliquables en vue rapprochée
	var specs := {"Bouton_Marche": [Vector3(-0.135, 0.06, 0.135), "Marche / arrêt"], "Bouton_Analyse": [Vector3(0.065, 0.11, 0.135), "Analyse"],
		"Bouton_Charge": [Vector3(0.11, 0.11, 0.135), "Charge"], "Bouton_Choc": [Vector3(0.11, 0.055, 0.135), "CHOC"],
		"Molette": [Vector3(0.11, 0.19, 0.135), "Énergie"]}
	for k in specs:
		var p: Vector3 = specs[k][0]
		var it := Interactable.make(model, "defib:" + k, specs[k][1], "Appuyer", Vector3(0.045, 0.045, 0.03), model.global_transform * p, Patient.LAYER_DEVICE)
		buttons[k] = it


func press(button: String) -> void:
	Sfx.play("clic", model.global_position, -8.0, 1.2)
	match button:
		"Bouton_Marche":
			on = not on
			charged = false
			_say("Appareil allumé · mode %s" % ("DSA" if energy_i == 0 else "manuel") if on else "")
		"Molette":
			if not on:
				return
			energy_i = (energy_i + 1) % ENERGIES.size()
			charged = false
			_say("Mode DSA (analyse automatique)" if energy_i == 0 else "Mode manuel : %d J" % ENERGIES[energy_i])
		"Bouton_Analyse":
			if not on:
				return
			if gear.pads.size() < 2:
				_say("CONNECTEZ LES ÉLECTRODES")
				Sfx.play("bip_alarme", model.global_position, -6.0, 0.9)
				return
			analysing = 5.0
			charged = false
			_say("ANALYSE EN COURS · NE TOUCHEZ PAS LE PATIENT")
		"Bouton_Charge":
			if not on or gear.pads.size() < 2:
				return
			if energy_i == 0 and advice != "CHOC RECOMMANDÉ · CHARGEZ":
				_say("Mode DSA : lancez d'abord l'analyse")
				return
			charging = 4.0
			_say("CHARGE EN COURS…")
		"Bouton_Choc":
			if not on:
				return
			if not charged:
				_say("Appareil non chargé")
				return
			var g: Node = get_meta("gestures", null)
			if g and g.get("cpr"):
				_say("ÉCARTEZ-VOUS DU PATIENT !")
				Sfx.play("bip_alarme", model.global_position, -4.0, 1.4)
				return
			charged = false
			shocks += 1
			var e := energy()
			Sfx.play("choc", model.global_position, 0.0)
			_say("CHOC DÉLIVRÉ (%d J) · REPRENEZ LE MASSAGE" % e)
			shocked.emit(e)


func energy() -> int:
	return 200 if energy_i == 0 else ENERGIES[energy_i]


func _say(t: String) -> void:
	advice = t
	advice_t = _t


## Massage en cours : profondeur et fréquence (retour sur l'écran, comme les vrais appareils).
func cpr_feedback(depth: float, rate: float, recoil: bool) -> void:
	cpr_depth = depth
	cpr_rate = rate
	cpr_recoil = recoil
	if analysing > 0.0:
		_say("MOUVEMENT DÉTECTÉ · ARRÊTEZ LE MASSAGE")
		analysing = 5.0


func _process(delta: float) -> void:
	_t += delta
	if analysing > 0.0:
		analysing -= delta
		if analysing <= 0.0:
			last_analysis = _t
			var shock := physio.shockable()
			_say("CHOC RECOMMANDÉ · CHARGEZ" if shock else "CHOC NON RECOMMANDÉ · REPRENEZ LE MASSAGE")
			if energy_i == 0 and shock:
				charging = 4.0
				_say("CHOC RECOMMANDÉ · CHARGE EN COURS")
			analysed.emit(shock)
	if charging > 0.0:
		charging -= delta
		Sfx.loop("charge", model.global_position, 0.6)
		if charging <= 0.0:
			charged = true
			_say("CHARGÉ %d J · APPUYEZ SUR CHOC" % energy())
			Sfx.play("bip_alarme", model.global_position, -4.0, 1.6)
	elif charged and fmod(_t, 0.8) < delta:
		Sfx.play("bip", model.global_position, -8.0, 1.8)
	if on and fmod(_t, 1.0 / 30.0) < delta:
		_screen.queue_redraw()
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


class DefibScreen:
	extends Control
	var defib: Defibrillator
	var trace := PackedFloat32Array()
	var head := 0
	var _since := 0.0
	var font: Font

	func _ready() -> void:
		trace.resize(300)
		font = load("res://assets/fonts/Inter.ttf")

	func _process(delta: float) -> void:
		var ph := defib.physio
		var n := maxi(1, int(round(delta * 75.0)))
		var period := 60.0 / maxf(ph.hr, 1.0)
		for i in n:
			_since += 1.0 / 75.0
			if _since > period and ph.hr > 1.0:
				_since -= period
			var v := 0.0
			if defib.gear.pads.size() >= 2 and defib.on:
				var mon: VitalMonitor = defib.get_meta("monitor", null)
				v = mon.ecg_shape(_since) if mon else 0.0
			trace[head] = v
			head = (head + 1) % trace.size()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0) if defib.on else Color(0.03, 0.035, 0.04))
		if not defib.on:
			return
		var ph := defib.physio
		var g := Color(0.3, 1.0, 0.45)
		draw_string(font, Vector2(12, 28), "PALETTES" if defib.gear.pads.size() >= 2 else "PALETTES -- ÉLECTRODES ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, g)
		var mode := "DSA" if defib.energy_i == 0 else "MANUEL %d J" % defib.energy()
		draw_string(font, Vector2(380, 28), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.2))
		var pts := PackedVector2Array()
		var n := trace.size()
		for i in n - 6:
			var idx := (head + i) % n
			pts.append(Vector2(12 + 536.0 * i / n, 120 - trace[idx] * 55.0))
		draw_polyline(pts, g, 2.0, true)
		var hr_txt := "---" if ph.rhythm == "fv" or defib.gear.pads.size() < 2 else str(int(round(ph.hr)))
		draw_string(font, Vector2(12, 215), "FC %s" % hr_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, g)
		draw_string(font, Vector2(260, 215), "Chocs : %d" % defib.shocks, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.9, 0.9))
		# Aide au massage : profondeur et fréquence
		if ph.cpr_running():
			var d := defib.cpr_depth * 100.0
			var dc := Color(0.3, 1.0, 0.45) if d >= 5.0 and d <= 6.0 else Color(1.0, 0.6, 0.2)
			var rc := Color(0.3, 1.0, 0.45) if defib.cpr_rate >= 100.0 and defib.cpr_rate <= 120.0 else Color(1.0, 0.6, 0.2)
			draw_string(font, Vector2(12, 258), ("Profondeur %.1f cm" % d).replace(".", ","), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, dc)
			draw_string(font, Vector2(290, 258), "%d / min" % int(defib.cpr_rate), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, rc)
			var tip := ""
			if d < 5.0:
				tip = "APPUYEZ PLUS FORT"
			elif d > 6.2:
				tip = "MOINS FORT"
			elif defib.cpr_rate < 100.0:
				tip = "PLUS VITE"
			elif defib.cpr_rate > 120.0:
				tip = "MOINS VITE"
			elif not defib.cpr_recoil:
				tip = "RELÂCHEZ COMPLÈTEMENT"
			else:
				tip = "BON MASSAGE"
			draw_string(font, Vector2(12, 290), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, dc if tip != "BON MASSAGE" else g)
		if defib.advice != "":
			var col := Color(1, 0.3, 0.25) if "CHOC" in defib.advice or "ÉCARTEZ" in defib.advice else Color(1.0, 0.85, 0.2)
			draw_rect(Rect2(0, 320, 560, 70), Color(0.08, 0.08, 0.09))
			draw_string(font, Vector2(12, 362), defib.advice, HORIZONTAL_ALIGNMENT_LEFT, 536, 22, col)
		if defib.charging > 0.0:
			draw_rect(Rect2(380, 190, 160 * (1.0 - defib.charging / 4.0), 16), Color(1.0, 0.6, 0.1))
