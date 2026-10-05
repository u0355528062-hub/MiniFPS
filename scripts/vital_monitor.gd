class_name VitalMonitor
extends Node3D
## Moniteur de surveillance (scope) sur bras articulé : ECG défilant, SpO2 pléthysmo,
## pression artérielle, fréquence respiratoire, température. Bip à chaque QRS.

var heart_rate := 84.0
var resp_rate := 14.0
var target_rate := 84.0
var spo2 := 99.0
var target_spo2 := -1.0  ## si >= 0, la SpO2 évolue doucement vers cette valeur
var _alarm_t := 0.0
var sys := 124
var dia := 76
var screen: MonitorScreen
var _beat_t := 0.0
var _viewport: SubViewport
var _draw_t := 0.0
var _react_t := 0.0
var ecg_voltage := 1.0  ## amplitude des QRS (épanchement péricardique : microvoltage)
var alternans := 0.0  ## alternance électrique : un QRS sur deux plus petit (tamponnade)
var beat_count := 0
var pvc := false  ## battement en cours : extrasystole ventriculaire (QRS large, sans onde P)
var _pvc_queue := 0
## Arrêt cardiaque : activité électrique lente sans pouls (ni saturation ni tension mesurables) ;
## chaque compression du massage crée une onde de pression
var arrest := false
var bypass := false  ## circulation extracorporelle : pression non pulsée, pas de saturation lue
var asystole := false  ## cœur arrêté par la cardioplégie : tracé plat, pas d'alarme sous CEC
var vf := false  ## fibrillation ventriculaire : tracé anarchique, pas de pouls
var map_bypass := 64  ## pression artérielle moyenne sous CEC
var ventilated := true  ## respirateur en marche (arrêté pendant la sternotomie et sous CEC)
var temp := 37.0  ## température centrale (°C)
var _art := 0.0
var _art_t := 10.0


func build() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 500)
	_viewport.transparent_bg = false
	# L'écran est redessiné 30 fois par seconde seulement (économise la carte graphique)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	screen = MonitorScreen.new()
	screen.monitor = self
	screen.size = Vector2(800, 500)
	_viewport.add_child(screen)

	var body := MeshUtil.mat(Color(0.86, 0.87, 0.88), 0.4, 0.1)
	var dark := MeshUtil.mat(Color(0.08, 0.09, 0.1), 0.3)
	MeshUtil.box_instance(self, Vector3(0.46, 0.32, 0.07), Vector3(0, 0, -0.035), body, "Boitier")
	MeshUtil.box_instance(self, Vector3(0.43, 0.27, 0.005), Vector3(0, 0.005, 0.002), dark, "Cadre")
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 0.25)
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _viewport.get_texture()
	m.emission_enabled = true
	m.emission_texture = _viewport.get_texture()
	m.emission_energy_multiplier = 0.4
	quad.material_override = m
	quad.position = Vector3(0, 0.005, 0.006)
	add_child(quad)
	# Bras au plafond
	var steel := MeshUtil.mat(Color(0.8, 0.82, 0.84), 0.3, 0.8)
	var pole := MeshUtil.cylinder_instance(self, 0.018, 1.3, Vector3(0, 0.82, -0.08), steel, "Bras")
	pole.rotation_degrees.x = -4
	MeshUtil.box_instance(self, Vector3(0.08, 0.06, 0.06), Vector3(0, 0.18, -0.07), dark, "Rotule")


func _process(delta: float) -> void:
	_draw_t += delta
	if _draw_t >= 1.0 / 30.0:
		_draw_t = 0.0
		screen.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _react_t > 0.0:
		_react_t -= delta
		if _react_t <= 0.0:
			target_rate = maxf(target_rate - 30.0, 70.0)
	heart_rate = lerpf(heart_rate, target_rate, delta * (1.5 if _react_t > 0.0 else 0.3))
	if target_spo2 >= 0.0:
		spo2 = move_toward(spo2, target_spo2, delta * 1.2)
	_art_t += delta
	_art = maxf(0.0, _art - delta * 2.2)
	# Alarme de désaturation (ou d'arrêt cardiaque, de fibrillation)
	if vf:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 0.6
			Sfx.play("bip_alarme", global_position, -5.0, 1.3)
	elif bypass:
		pass
	elif arrest:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 0.9
			Sfx.play("bip_alarme", global_position, -6.0, 1.15)
	elif spo2 < 90.0:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = 1.4
			Sfx.play("bip_alarme", global_position, -8.0)
	_beat_t += delta
	if asystole or vf:
		_beat_t = 0.0
		return
	var period := 60.0 / maxf(heart_rate, 1.0)
	if _beat_t >= period:
		_beat_t -= period
		beat_count += 1
		pvc = _pvc_queue > 0 and randf() < 0.75
		if pvc:
			_pvc_queue -= 1
		screen.beat()
		Sfx.play("bip", global_position, -16.0, 1.0 if spo2 > 96 else 0.92)


## Une compression du massage cardiaque : onde de pression sur la courbe de pouls.
func compression() -> void:
	_art = 1.0
	_art_t = 0.0


## Valeur de l'onde de pression créée par le massage (0..1), t secondes après la compression.
func art_wave() -> float:
	var t := _art_t
	return 0.9 * exp(-pow((t - 0.12) / 0.07, 2.0)) + 0.25 * exp(-pow((t - 0.3) / 0.06, 2.0))


## Quelques extrasystoles ventriculaires (myocarde irrité, par exemple touché par une aiguille).
func ectopic(n := 3) -> void:
	_pvc_queue = maxi(_pvc_queue, n)
	Sfx.play("bip_alarme", global_position, -8.0, 1.3)


## Amplitude du battement en cours (microvoltage, alternance électrique).
func beat_amp() -> float:
	return ecg_voltage * (1.0 - alternans * float(beat_count % 2))


## Forme de l'ECG, t secondes après le début du battement.
func ecg_shape(t: float) -> float:
	var v := 0.0
	if vf:
		# Fibrillation : ondulations rapides, irrégulières, sans complexe
		var g := Time.get_ticks_msec() / 1000.0
		return 0.32 * sin(TAU * 5.3 * g) + 0.22 * sin(TAU * 7.7 * g + 1.3) + 0.14 * sin(TAU * 11.1 * g + 0.4)
	if asystole:
		return 0.0
	if arrest:
		# Activité électrique sans pouls : complexes larges, lents, de faible amplitude
		v += 0.42 * exp(-pow((t - 0.12) / 0.05, 2.0)) - 0.16 * exp(-pow((t - 0.34) / 0.09, 2.0))
		return v
	if pvc:
		v += 1.15 * exp(-pow((t - 0.14) / 0.045, 2.0)) - 0.35 * exp(-pow((t - 0.21) / 0.03, 2.0))
		v -= 0.5 * exp(-pow((t - 0.36) / 0.07, 2.0))
		return v * maxf(ecg_voltage, 0.7)
	v += 0.12 * exp(-pow((t - 0.06) / 0.025, 2.0))  # P
	v -= 0.12 * exp(-pow((t - 0.15) / 0.008, 2.0))  # Q
	v += 1.0 * exp(-pow((t - 0.17) / 0.011, 2.0))  # R
	v -= 0.25 * exp(-pow((t - 0.19) / 0.01, 2.0))  # S
	v += 0.22 * exp(-pow((t - 0.38) / 0.05, 2.0))  # T
	return v * beat_amp()


## Petite tachycardie quand on incise, retour au calme ensuite.
func stress(amount: float) -> void:
	target_rate = clampf(84.0 + amount, 70.0, 125.0)


## Le patient a mal (anesthésie pas encore efficace) : le cœur s'emballe quelques secondes.
func react() -> void:
	target_rate = clampf(heart_rate + 30.0, 70.0, 150.0)
	_react_t = 4.0
	Sfx.play("bip_alarme", global_position, -6.0, 1.2)


class MonitorScreen:
	extends Control
	var monitor: VitalMonitor
	var ecg := PackedFloat32Array()
	var pleth := PackedFloat32Array()
	var head := 0
	var _since_beat := 10.0
	var _resp := 0.0
	var font: Font

	func _ready() -> void:
		ecg.resize(400)
		pleth.resize(400)
		font = load("res://assets/fonts/Inter.ttf")

	func beat() -> void:
		_since_beat = 0.0

	func _process(delta: float) -> void:
		# Deux échantillons par image environ : balayage de 4 s sur l'écran
		var n := maxi(1, int(round(delta * 100.0)))
		for i in n:
			_since_beat += 0.01
			_resp += 0.01
			var t := _since_beat
			ecg[head] = monitor.ecg_shape(t) + randf_range(-0.015, 0.015)
			var pt := t - 0.22
			if monitor.bypass:
				pleth[head] = 0.35 + 0.012 * sin(_resp * 9.0)
			elif monitor.vf or monitor.asystole:
				pleth[head] = 0.0
			elif monitor.arrest:
				pleth[head] = monitor.art_wave()
			else:
				pleth[head] = (0.85 * exp(-pow((pt - 0.12) / 0.09, 2.0)) + 0.3 * exp(-pow((pt - 0.36) / 0.08, 2.0))) if pt > 0.0 else 0.0
			head = (head + 1) % ecg.size()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03))
		var w := 560.0
		_trace(ecg, Rect2(16, 40, w, 150), Color(0.25, 1.0, 0.4), 0.9)
		_trace(pleth, Rect2(16, 230, w, 110), Color(0.3, 0.85, 1.0), 1.0)
		# Respiration (capnographie simplifiée)
		var cap := PackedVector2Array()
		for i in 120:
			var x := 16.0 + i * w / 120.0
			var period := 60.0 / maxf(monitor.resp_rate, 4.0)
			var ph := fmod(_resp - (120 - i) * 0.033 + 100.0, period) / period * 4.0
			# Plateau du CO2 expiré : bas en arrêt cardiaque (peu de sang aux poumons), plat sans ventilation
			var plateau := 0.0 if not monitor.ventilated else (20.0 if monitor.arrest or monitor.vf else 60.0)
			var y := 470.0 - (plateau if ph > 1.6 and ph < 3.4 else 0.0) * clampf(minf(ph - 1.6, 3.4 - ph) * 8.0, 0.0, 1.0)
			cap.append(Vector2(x, y))
		draw_polyline(cap, Color(1.0, 0.85, 0.2), 2.0, true)
		draw_string(font, Vector2(16, 28), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 1.0, 0.4))
		draw_string(font, Vector2(16, 222), "Pleth", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.3, 0.85, 1.0))
		draw_string(font, Vector2(16, 395), "CO2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.85, 0.2))
		var x0 := 600.0
		draw_string(font, Vector2(x0, 34), "FC", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.25, 1.0, 0.4))
		var hr_txt := "---" if monitor.vf else ("0" if monitor.asystole else str(int(round(monitor.heart_rate))))
		draw_string(font, Vector2(x0, 120), hr_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, Color(1, 0.3, 0.3) if monitor.vf else Color(0.25, 1.0, 0.4))
		draw_string(font, Vector2(x0, 226), "SpO2 %", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 0.85, 1.0))
		var no_pulse := monitor.arrest or monitor.vf or monitor.bypass
		draw_string(font, Vector2(x0, 300), "--" if no_pulse else str(int(monitor.spo2)), HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.3, 0.85, 1.0))
		draw_string(font, Vector2(x0, 344), "PAM mmHg" if monitor.bypass else "PNI mmHg", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.4, 0.4))
		var bp := str(monitor.map_bypass) if monitor.bypass else ("--/--" if monitor.arrest or monitor.vf else "%d/%d" % [monitor.sys, monitor.dia])
		draw_string(font, Vector2(x0, 384), bp, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 0.4, 0.4))
		if monitor.bypass:
			draw_string(font, Vector2(170, 30), "CEC  ·  %s" % ("CŒUR ARRÊTÉ" if monitor.asystole else "EN MARCHE"), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.7, 0.2))
		elif monitor.vf and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6:
			draw_string(font, Vector2(170, 30), "FIBRILLATION VENTRICULAIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.25, 0.25))
		if monitor.arrest and fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6:
			draw_string(font, Vector2(170, 30), "PAS DE POULS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.25, 0.25))
		var fr_txt := str(int(round(monitor.resp_rate))) if monitor.ventilated else "--"
		draw_string(font, Vector2(x0, 430), "FR %s   T° %s" % [fr_txt, ("%.1f" % monitor.temp).replace(".", ",")], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.2))
		var etco2 := "--" if not monitor.ventilated else ("12" if monitor.arrest or monitor.vf else "36")
		draw_string(font, Vector2(x0, 478), "EtCO2 %s" % etco2, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.2))

	func _trace(buf: PackedFloat32Array, r: Rect2, c: Color, amp: float) -> void:
		var pts := PackedVector2Array()
		var n := buf.size()
		var gap := 8
		for i in n:
			var idx := (head + i) % n
			if i > n - gap:
				continue
			pts.append(Vector2(r.position.x + r.size.x * i / n, r.position.y + r.size.y * (0.7 - buf[idx] * amp * 0.6)))
		draw_polyline(pts, c, 2.5, true)
