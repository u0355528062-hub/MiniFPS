class_name UIIcon
extends Control
## Petites icônes vectorielles dessinées (pas d'image à charger) : cœur, goutte d'oxygène, jauge
## de tension, poumons, horloge, coche, croix, alerte, info, lecture, livre, réglages, sortie,
## flèche, étoile, cadenas, éclair, seringue, flacon, tracé ECG, liste, personne.

var kind := "heart":
	set(v):
		kind = v
		queue_redraw()
var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var pulse := 0.0  ## battement (0..1) pour le cœur


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s < 4.0:
		return
	var o := (size - Vector2(s, s)) * 0.5
	var c := color
	var w := maxf(1.5, s * 0.09)
	var P := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match kind:
		"heart":
			var k := 1.0 + pulse * 0.12
			var pts := PackedVector2Array()
			for i in 48:
				var t := TAU * i / 48.0
				var x := 16.0 * pow(sin(t), 3)
				var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
				pts.append(P.call(0.5 + x / 38.0 * k, 0.52 + y / 38.0 * k))
			draw_colored_polygon(pts, c)
		"drop":
			var pts2 := PackedVector2Array()
			pts2.append(P.call(0.5, 0.06))
			for i in 25:
				var a := PI - 0.35 + (PI + 0.7) * i / 24.0
				pts2.append(P.call(0.5 + cos(a) * 0.3, 0.62 - sin(a) * 0.3))
			draw_colored_polygon(pts2, c)
			draw_string(UIKit.bold(), P.call(0.36, 0.76), "O₂", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.26), Color(0, 0, 0, 0.55))
		"gauge":
			draw_arc(P.call(0.5, 0.58), s * 0.38, PI * 0.95, PI * 2.05, 24, c, w, true)
			var a2 := PI * 1.7
			draw_line(P.call(0.5, 0.58), P.call(0.5, 0.58) + Vector2(cos(a2), sin(a2)) * s * 0.3, c, w, true)
			draw_circle(P.call(0.5, 0.58), s * 0.08, c)
		"lungs":
			draw_line(P.call(0.5, 0.1), P.call(0.5, 0.45), c, w, true)
			draw_line(P.call(0.5, 0.45), P.call(0.38, 0.55), c, w, true)
			draw_line(P.call(0.5, 0.45), P.call(0.62, 0.55), c, w, true)
			for sd in [-1.0, 1.0]:
				var pts3 := PackedVector2Array()
				for i in 20:
					var t2 := PI * i / 19.0
					pts3.append(P.call(0.5 + sd * (0.1 + 0.3 * sin(t2) * (0.6 + 0.4 * t2 / PI)), 0.3 + 0.62 * (1.0 - cos(t2)) * 0.5))
				pts3.append(P.call(0.5 + sd * 0.08, 0.9))
				draw_colored_polygon(pts3, Color(c, 0.85))
		"clock":
			draw_arc(P.call(0.5, 0.5), s * 0.4, 0, TAU, 32, c, w, true)
			draw_line(P.call(0.5, 0.5), P.call(0.5, 0.24), c, w, true)
			draw_line(P.call(0.5, 0.5), P.call(0.68, 0.58), c, w, true)
		"check":
			draw_polyline(PackedVector2Array([P.call(0.2, 0.52), P.call(0.42, 0.74), P.call(0.8, 0.28)]), c, w * 1.3, true)
		"cross":
			draw_line(P.call(0.25, 0.25), P.call(0.75, 0.75), c, w * 1.3, true)
			draw_line(P.call(0.75, 0.25), P.call(0.25, 0.75), c, w * 1.3, true)
		"plus":
			draw_rect(Rect2(P.call(0.38, 0.12), Vector2(0.24, 0.76) * s), c)
			draw_rect(Rect2(P.call(0.12, 0.38), Vector2(0.76, 0.24) * s), c)
		"warn":
			draw_colored_polygon(PackedVector2Array([P.call(0.5, 0.08), P.call(0.95, 0.88), P.call(0.05, 0.88)]), c)
			draw_line(P.call(0.5, 0.36), P.call(0.5, 0.62), Color(0, 0, 0, 0.8), w * 1.2)
			draw_circle(P.call(0.5, 0.75), s * 0.05, Color(0, 0, 0, 0.8))
		"info":
			draw_circle(P.call(0.5, 0.5), s * 0.45, c)
			draw_line(P.call(0.5, 0.44), P.call(0.5, 0.76), Color(0, 0, 0, 0.75), w * 1.2)
			draw_circle(P.call(0.5, 0.28), s * 0.06, Color(0, 0, 0, 0.75))
		"play":
			draw_colored_polygon(PackedVector2Array([P.call(0.28, 0.15), P.call(0.85, 0.5), P.call(0.28, 0.85)]), c)
		"pause":
			draw_rect(Rect2(P.call(0.24, 0.15), Vector2(0.18, 0.7) * s), c)
			draw_rect(Rect2(P.call(0.58, 0.15), Vector2(0.18, 0.7) * s), c)
		"book":
			draw_colored_polygon(PackedVector2Array([P.call(0.08, 0.2), P.call(0.47, 0.28), P.call(0.47, 0.88), P.call(0.08, 0.8)]), c)
			draw_colored_polygon(PackedVector2Array([P.call(0.53, 0.28), P.call(0.92, 0.2), P.call(0.92, 0.8), P.call(0.53, 0.88)]), c)
		"gear":
			for i in 8:
				var a3 := TAU * i / 8.0
				draw_line(P.call(0.5, 0.5) + Vector2(cos(a3), sin(a3)) * s * 0.28, P.call(0.5, 0.5) + Vector2(cos(a3), sin(a3)) * s * 0.44, c, s * 0.14)
			draw_circle(P.call(0.5, 0.5), s * 0.3, c)
			draw_circle(P.call(0.5, 0.5), s * 0.12, Color(0, 0, 0, 0.6))
		"exit":
			draw_polyline(PackedVector2Array([P.call(0.55, 0.15), P.call(0.15, 0.15), P.call(0.15, 0.85), P.call(0.55, 0.85)]), c, w, true)
			draw_line(P.call(0.38, 0.5), P.call(0.88, 0.5), c, w, true)
			draw_polyline(PackedVector2Array([P.call(0.72, 0.32), P.call(0.9, 0.5), P.call(0.72, 0.68)]), c, w, true)
		"arrow":
			draw_line(P.call(0.12, 0.5), P.call(0.82, 0.5), c, w * 1.2, true)
			draw_polyline(PackedVector2Array([P.call(0.55, 0.22), P.call(0.86, 0.5), P.call(0.55, 0.78)]), c, w * 1.2, true)
		"back":
			draw_line(P.call(0.88, 0.5), P.call(0.18, 0.5), c, w * 1.2, true)
			draw_polyline(PackedVector2Array([P.call(0.45, 0.22), P.call(0.14, 0.5), P.call(0.45, 0.78)]), c, w * 1.2, true)
		"star":
			var pts4 := PackedVector2Array()
			for i in 10:
				var a4 := -PI * 0.5 + TAU * i / 10.0
				var r := 0.46 if i % 2 == 0 else 0.2
				pts4.append(P.call(0.5 + cos(a4) * r, 0.53 + sin(a4) * r))
			draw_colored_polygon(pts4, c)
		"lock":
			draw_arc(P.call(0.5, 0.42), s * 0.2, PI, TAU, 16, c, w, true)
			draw_line(P.call(0.3, 0.42), P.call(0.3, 0.5), c, w)
			draw_line(P.call(0.7, 0.42), P.call(0.7, 0.5), c, w)
			draw_rect(Rect2(P.call(0.2, 0.5), Vector2(0.6, 0.4) * s), c)
		"bolt":
			draw_colored_polygon(PackedVector2Array([P.call(0.58, 0.04), P.call(0.2, 0.56), P.call(0.47, 0.56), P.call(0.38, 0.96), P.call(0.8, 0.42), P.call(0.53, 0.42)]), c)
		"syringe":
			draw_line(P.call(0.2, 0.8), P.call(0.68, 0.32), c, s * 0.18)
			draw_line(P.call(0.68, 0.32), P.call(0.88, 0.12), c, w * 0.7)
			draw_line(P.call(0.12, 0.66), P.call(0.34, 0.88), c, w)
		"flask":
			draw_colored_polygon(PackedVector2Array([P.call(0.4, 0.1), P.call(0.6, 0.1), P.call(0.6, 0.4), P.call(0.86, 0.88), P.call(0.14, 0.88), P.call(0.4, 0.4)]), c)
		"ecg":
			draw_polyline(PackedVector2Array([P.call(0.04, 0.55), P.call(0.3, 0.55), P.call(0.38, 0.4), P.call(0.46, 0.85), P.call(0.56, 0.12), P.call(0.64, 0.55), P.call(0.96, 0.55)]), c, w, true)
		"list":
			for i in 3:
				var y := 0.22 + i * 0.28
				draw_circle(P.call(0.16, y), s * 0.07, c)
				draw_line(P.call(0.32, y), P.call(0.9, y), c, w)
		"user":
			draw_circle(P.call(0.5, 0.32), s * 0.2, c)
			var pts5 := PackedVector2Array()
			for i in 17:
				var a5 := PI + PI * i / 16.0
				pts5.append(P.call(0.5 + cos(a5) * 0.36, 0.92 + sin(a5) * 0.36))
			draw_colored_polygon(pts5, c)
		"chat":
			draw_rect(Rect2(P.call(0.08, 0.16), Vector2(0.84, 0.54) * s), c)
			draw_colored_polygon(PackedVector2Array([P.call(0.25, 0.68), P.call(0.45, 0.68), P.call(0.25, 0.88)]), c)
		"ring":
			draw_arc(P.call(0.5, 0.5), s * 0.36, 0, TAU, 32, c, maxf(1.5, s * 0.08), true)
		"target":
			draw_arc(P.call(0.5, 0.5), s * 0.4, 0, TAU, 32, c, w, true)
			draw_circle(P.call(0.5, 0.5), s * 0.14, c)
		_:
			draw_circle(P.call(0.5, 0.5), s * 0.3, c)
