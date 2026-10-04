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
	# Tracé ECG synthétique (P, QRS, T)
	var v := 0.08 * exp(-pow((p - 0.12) / 0.03, 2.0))
	v += -0.12 * exp(-pow((p - 0.27) / 0.008, 2.0)) + 1.0 * exp(-pow((p - 0.3) / 0.011, 2.0)) - 0.25 * exp(-pow((p - 0.33) / 0.01, 2.0))
	v += 0.22 * exp(-pow((p - 0.55) / 0.05, 2.0))
	var pl := maxf(0.0, sin(TAU * (p - 0.35))) * (0.6 + 0.4 * exp(-pow((p - 0.55) / 0.06, 2.0)))
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
	var blink := spo < 90 and fmod(_t, 1.0) < 0.5
	# ECG
	var r := Rect2(14, 14, 190, 52)
	_trace(_ecg, r, hr_col, 0.5, 0.45)
	draw_string(fr, Vector2(214, 26), "FC", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	draw_string(f, Vector2(214, 64), str(hr), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, hr_col)
	# SpO2
	var r2 := Rect2(14, 78, 190, 40)
	_trace(_pleth, r2, sp_col, 0.9, 0.0)
	draw_string(fr, Vector2(214, 90), "SpO₂", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	draw_string(f, Vector2(214, 126), "%d %%" % spo, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, UIKit.BAD if blink else sp_col)
	# Tension et respiration
	draw_string(fr, Vector2(14, 150), "PA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	draw_string(f, Vector2(40, 152), "%d/%d" % [monitor.sys, monitor.dia], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.55, 0.55))
	draw_string(fr, Vector2(150, 150), "FR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UIKit.TEXT_DIM)
	var rr := int(round(monitor.resp_rate))
	draw_string(f, Vector2(176, 152), "%d /min" % rr, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.95, 0.5) if rr <= 22 else UIKit.WARN)


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
