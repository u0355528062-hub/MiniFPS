class_name VitalsWidget
extends Control
## Constantes vitales en surimpression (haut droite) : fréquence cardiaque avec tracé ECG
## défilant, SpO2 avec courbe de pouls, tension, fréquence respiratoire. Couleurs d'alarme.

var monitor: VitalMonitor
var _ecg := PackedFloat32Array()
var _pleth := PackedFloat32Array()
var _phase := 0.0
var _t := 0.0
const N := 160


func _ready() -> void:
	_ecg.resize(N)
	_pleth.resize(N)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if monitor == null:
		return
	_t += delta
	var hr := maxf(monitor.heart_rate, 30.0)
	_phase += delta * hr / 60.0
	var p := fmod(_phase, 1.0)
	# Tracé ECG : même forme que le scope (microvoltage, alternance, extrasystoles)
	var v := monitor.ecg_shape(p * 60.0 / hr * 0.85 + 0.03)
	var pl := maxf(0.0, sin(TAU * (p - 0.35))) * (0.6 + 0.4 * exp(-pow((p - 0.55) / 0.06, 2.0)))
	if monitor.bypass:
		pl = 0.35
	elif monitor.vf or monitor.asystole:
		pl = 0.0
	elif monitor.arrest:
		pl = monitor.art_wave()
	for k in 2:
		_ecg.remove_at(0)
		_ecg.append(v)
		_pleth.remove_at(0)
		_pleth.append(pl)
	queue_redraw()


func _draw() -> void:
	if monitor == null:
		return
	var sb := UIKit.box(UIKit.PANEL, 14, Color(1, 1, 1, 0.06), 1, 0)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var f := UIKit.bold()
	var fr := UIKit.font()
	var hr := int(round(monitor.heart_rate))
	var spo := int(round(monitor.spo2))
	var hr_col := Color(0.3, 1.0, 0.45) if hr <= 110 else (UIKit.WARN if hr <= 130 else UIKit.BAD)
	var sp_col := Color(0.35, 0.85, 1.0) if spo >= 94 else (UIKit.WARN if spo >= 90 else UIKit.BAD)
	var no_pulse := monitor.arrest or monitor.vf or monitor.bypass
	var blink := ((spo < 90 and not monitor.bypass) or monitor.arrest or monitor.vf) and fmod(_t, 1.0) < 0.5
	if monitor.arrest or monitor.vf:
		hr_col = UIKit.BAD
	# ECG
	var r := Rect2(14, 14, 190, 52)
	_trace(_ecg, r, hr_col, 0.5, 0.45)
	draw_string(fr, Vector2(214, 26), "FC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	draw_string(f, Vector2(214, 64), "---" if monitor.vf else ("0" if monitor.asystole else str(hr)), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, hr_col)
	# SpO2
	var r2 := Rect2(14, 78, 190, 40)
	_trace(_pleth, r2, sp_col, 0.9, 0.0)
	draw_string(fr, Vector2(214, 90), "SpO₂", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	draw_string(f, Vector2(214, 126), "-- %" if no_pulse else "%d %%" % spo, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.BAD if blink else sp_col)
	# Tension et respiration
	draw_string(fr, Vector2(14, 150), "PAM" if monitor.bypass else "PA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	var bp := "%d  CEC" % monitor.map_bypass if monitor.bypass else ("--/--" if monitor.arrest or monitor.vf else "%d/%d" % [monitor.sys, monitor.dia])
	draw_string(f, Vector2(48 if monitor.bypass else 40, 152), bp, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.7, 0.3) if monitor.bypass else Color(1, 0.55, 0.55))
	draw_string(fr, Vector2(150, 150), "FR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	var rr := int(round(monitor.resp_rate))
	var rr_txt := ("%d /min" % rr) if monitor.ventilated else "-- /min"
	draw_string(f, Vector2(176, 152), rr_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 0.5) if rr <= 22 or not monitor.ventilated else UIKit.WARN)


func _trace(data: PackedFloat32Array, r: Rect2, c: Color, scale_y: float, offset: float) -> void:
	var pts := PackedVector2Array()
	for i in data.size():
		var x := r.position.x + r.size.x * i / float(data.size() - 1)
		var y := r.position.y + r.size.y * (1.0 - (data[i] * scale_y + offset))
		pts.append(Vector2(x, clampf(y, r.position.y - 4, r.end.y + 4)))
	var cols := PackedColorArray()
	for i in pts.size():
		var a := float(i) / pts.size()
		cols.append(Color(c.r, c.g, c.b, 0.15 + 0.85 * a * a))
	draw_polyline_colors(pts, cols, 2.0, true)
