class_name VitalMonitor
extends Node3D
## Scope de surveillance sur le bras plafonnier. Il n'affiche que ce que mesurent les capteurs posés :
## ECG (3 électrodes), SpO2 (pince au doigt), pression non invasive (brassard : mesure toutes les
## 3 minutes ou à la demande), fréquence respiratoire (impédance des électrodes). Tracés : rythme
## sinusal, bradycardie, tachycardie ventriculaire, fibrillation, asystolie, activité sans pouls,
## sus-décalage du segment ST, artefacts du massage cardiaque. Alarmes sonores.

var physio: Physio
var gear: PatientGear
var screen: MonitorScreen
var _viewport: SubViewport
var _draw_t := 0.0
var _beat_t := 0.0
var _alarm_t := 0.0
var beat_count := 0
var pvc := false
var _pvc_queue := 0
var _art := 0.0
var _art_t := 10.0
## Dernière PNI mesurée
var nibp := Vector2.ZERO
var nibp_t := -1000.0
var _nibp_running := 0.0
var auto_nibp := 180.0
var time := 0.0


func build(scope_model: Node3D) -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 500)
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	screen = MonitorScreen.new()
	screen.monitor = self
	screen.size = Vector2(800, 500)
	_viewport.add_child(screen)
	if scope_model:
		add_child(scope_model)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.31, 0.195)
	quad.mesh = qm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _viewport.get_texture()
	quad.material_override = m
	quad.position = Vector3(0, 0.006, 0.0115)
	add_child(quad)


func texture() -> Texture2D:
	return _viewport.get_texture()


func has_ecg() -> bool:
	return gear != null and gear.scope_leads() >= 3


func has_spo2() -> bool:
	return gear != null and gear.spo2_side != ""


func has_cuff() -> bool:
	return gear != null and gear.cuff_side != ""


## Lance une mesure de pression (brassard) : le résultat arrive après 25 s.
func measure_nibp() -> void:
	if not has_cuff() or _nibp_running > 0.0:
		return
	_nibp_running = 25.0 if physio.pulse() else 40.0
	Sfx.play("clic", global_position, -10.0, 0.8)


func _process(delta: float) -> void:
	time += delta
	_draw_t += delta
	if _draw_t >= 1.0 / 30.0:
		_draw_t = 0.0
		screen.queue_redraw()
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_art_t += delta
	_art = maxf(0.0, _art - delta * 2.2)
	if has_cuff():
		if _nibp_running > 0.0:
			_nibp_running -= delta
			if _nibp_running <= 0.0:
				nibp = Vector2(physio.sys, physio.dia) if physio.pulse() and physio.sys > 50.0 else Vector2.ZERO
				nibp_t = time
				Sfx.play("bip", global_position, -12.0, 1.3)
		elif time - nibp_t > auto_nibp:
			measure_nibp()
	# Alarmes
	var alarm := 0.0
	if has_ecg() and physio.in_arrest():
		alarm = 0.7
	elif has_spo2() and physio.spo2 < 90.0 and physio.pulse():
		alarm = 1.4
	elif has_ecg() and (physio.hr > 140.0 or physio.hr < 45.0):
		alarm = 1.6
	if alarm > 0.0:
		_alarm_t -= delta
		if _alarm_t <= 0.0:
			_alarm_t = alarm
			Sfx.play("bip_alarme", global_position, -7.0, 1.25 if physio.in_arrest() else 1.0)
	_beat_t += delta
	if physio.rhythm in ["fv", "asystolie"] or physio.hr < 1.0:
		_beat_t = 0.0
		return
	var period := 60.0 / maxf(physio.hr, 1.0)
	if _beat_t >= period:
		_beat_t -= period
		beat_count += 1
		pvc = _pvc_queue > 0 and randf() < 0.75
		if pvc:
			_pvc_queue -= 1
		screen.beat()
		if (has_spo2() and physio.pulse()) or (has_ecg() and not has_spo2() and not physio.in_arrest()):
			var p := clampf(1.0 - (97.0 - physio.spo2) * 0.012, 0.72, 1.02) if has_spo2() else 1.0
			Sfx.play("bip", global_position, -16.0, p)


## Une compression du massage : artefact sur l'ECG et onde de pression.
func compression() -> void:
	_art = 1.0
	_art_t = 0.0


func ectopic(n := 3) -> void:
	_pvc_queue = maxi(_pvc_queue, n)


func art_wave() -> float:
	var t := _art_t
	return 0.9 * exp(-pow((t - 0.12) / 0.07, 2.0)) + 0.25 * exp(-pow((t - 0.3) / 0.06, 2.0))


## Forme de l'ECG (dérivation II), t secondes après le début du battement.
func ecg_shape(t: float) -> float:
	var g := time
	var art := 0.0
	if _art_t < 0.5:
		art = 1.6 * exp(-pow((_art_t - 0.1) / 0.08, 2.0)) - 0.4 * exp(-pow((_art_t - 0.3) / 0.08, 2.0))
	match physio.rhythm:
		"fv":
			return art + 0.32 * sin(TAU * 5.3 * g) + 0.22 * sin(TAU * 7.7 * g + 1.3) + 0.14 * sin(TAU * 11.1 * g + 0.4)
		"asystolie":
			return art + 0.03 * sin(TAU * 0.3 * g)
		"tvsp", "tv":
			var ph := fmod(t, 60.0 / maxf(physio.hr, 1.0))
			return art + 1.1 * sin(TAU * ph / (60.0 / maxf(physio.hr, 1.0)))
		"aesp":
			return art + 0.42 * exp(-pow((t - 0.12) / 0.05, 2.0)) - 0.16 * exp(-pow((t - 0.34) / 0.09, 2.0))
	if pvc:
		return 1.15 * exp(-pow((t - 0.14) / 0.045, 2.0)) - 0.35 * exp(-pow((t - 0.21) / 0.03, 2.0)) - 0.5 * exp(-pow((t - 0.36) / 0.07, 2.0))
	var v := 0.0
	v += 0.12 * exp(-pow((t - 0.06) / 0.025, 2.0))  # P
	v -= 0.12 * exp(-pow((t - 0.15) / 0.008, 2.0))  # Q
	v += 1.0 * exp(-pow((t - 0.17) / 0.011, 2.0))  # R
	v -= 0.25 * exp(-pow((t - 0.19) / 0.01, 2.0))  # S
	var st := 0.0
	if physio.stemi == "inferieur":
		st = 0.28
	elif physio.stemi == "anterieur":
		st = -0.08  # miroir en II
	v += st * smoothstep(0.19, 0.21, t) * (1.0 - smoothstep(0.34, 0.42, t))
	v += (0.22 + st * 0.5) * exp(-pow((t - 0.38) / 0.05, 2.0))  # T
	return v + art


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
		var ph := monitor.physio
		var n := maxi(1, int(round(delta * 100.0)))
		for i in n:
			_since_beat += 0.01
			_resp += 0.01
			ecg[head] = (monitor.ecg_shape(_since_beat) + randf_range(-0.015, 0.015)) if monitor.has_ecg() else 0.0
			var pt := _since_beat - 0.22
			if not monitor.has_spo2():
				pleth[head] = 0.0
			elif ph.in_arrest():
				pleth[head] = monitor.art_wave() * (0.3 + 0.7 * ph.cpr_quality)
			else:
				var amp := clampf((ph.sys - 50.0) / 70.0, 0.15, 1.0)
				pleth[head] = ((0.85 * exp(-pow((pt - 0.12) / 0.09, 2.0)) + 0.3 * exp(-pow((pt - 0.36) / 0.08, 2.0))) if pt > 0.0 else 0.0) * amp
			head = (head + 1) % ecg.size()

	func _draw() -> void:
		var ph := monitor.physio
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03))
		var w := 560.0
		var green := Color(0.25, 1.0, 0.4)
		var cyan := Color(0.3, 0.85, 1.0)
		var red := Color(1, 0.4, 0.4)
		var yellow := Color(1.0, 0.85, 0.2)
		if monitor.has_ecg():
			_trace(ecg, Rect2(16, 40, w, 150), green, 0.9)
		else:
			draw_string(font, Vector2(150, 125), "ÉLECTRODES ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.9, 0.9, 0.9, 0.7))
		if monitor.has_spo2():
			_trace(pleth, Rect2(16, 230, w, 110), cyan, 1.0)
		else:
			draw_string(font, Vector2(150, 300), "CAPTEUR SpO2 ?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.9, 0.9, 0.9, 0.6))
		draw_string(font, Vector2(16, 28), "II", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, green)
		draw_string(font, Vector2(16, 222), "Pleth", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, cyan)
		var x0 := 600.0
		draw_string(font, Vector2(x0, 34), "FC", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, green)
		var hr_txt := "--"
		if monitor.has_ecg():
			hr_txt = "---" if ph.rhythm == "fv" else str(int(round(ph.hr)))
		elif monitor.has_spo2() and ph.pulse():
			hr_txt = str(int(round(ph.hr)))
		draw_string(font, Vector2(x0, 120), hr_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, red if ph.in_arrest() else green)
		draw_string(font, Vector2(x0, 226), "SpO2 %", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, cyan)
		var sp := "--"
		if monitor.has_spo2() and ph.pulse() and ph.spo2 > 30.0:
			sp = str(int(ph.spo2))
		draw_string(font, Vector2(x0, 300), sp, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, cyan)
		draw_string(font, Vector2(x0, 344), "PNI mmHg", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, red)
		var bp := "--/--"
		if monitor.has_cuff():
			if monitor._nibp_running > 0.0:
				bp = "mesure…"
			elif monitor.nibp != Vector2.ZERO:
				bp = "%d/%d" % [int(monitor.nibp.x), int(monitor.nibp.y)]
			elif monitor.nibp_t > -1000.0:
				bp = "échec"
		draw_string(font, Vector2(x0, 384), bp, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, red)
		var fr_txt := str(int(round(ph.rr))) if monitor.has_ecg() and not ph.in_arrest() else "--"
		draw_string(font, Vector2(x0, 440), "FR %s" % fr_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, yellow)
		draw_string(font, Vector2(16, 400), "T° %s" % ("%.1f" % ph.temp).replace(".", ",") if monitor.has_ecg() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.8, 0.85))
		var blink := fmod(monitor.time, 1.0) < 0.6
		if monitor.has_ecg() and blink:
			var msg := ""
			match ph.rhythm:
				"fv":
					msg = "FIBRILLATION VENTRICULAIRE"
				"tvsp", "tv":
					msg = "TACHYCARDIE VENTRICULAIRE"
				"asystolie":
					msg = "ASYSTOLIE"
			if msg == "" and monitor.has_spo2() and ph.spo2 < 90.0 and ph.pulse():
				msg = "DÉSATURATION"
			if msg != "":
				draw_string(font, Vector2(150, 30), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.25, 0.25))
		if ph.cpr_running() and monitor.has_ecg():
			draw_string(font, Vector2(16, 470), "RCP en cours", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, yellow)

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
