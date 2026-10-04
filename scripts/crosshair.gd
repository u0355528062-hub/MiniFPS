class_name Crosshair
extends Control
## Viseur contextuel : point discret ; anneau quand on survole un instrument ; croix fine quand
## l'instrument tenu est posé sur le patient (s'élargit en précision) ; repère de profondeur.

var hand: PlayerHand
var _hover_k := 0.0
var _work_k := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if hand == null:
		return
	_hover_k = move_toward(_hover_k, 1.0 if (hand.held == null and hand.hovered) else 0.0, delta * 8.0)
	_work_k = move_toward(_work_k, 1.0 if (hand.held and hand.on_patient) else 0.0, delta * 8.0)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 1, 1, 0.85)
	var shadow := Color(0, 0, 0, 0.5)
	if _work_k < 0.99:
		var a := 1.0 - _work_k
		draw_circle(c, 3.2, Color(shadow, shadow.a * a))
		draw_circle(c, 2.2, Color(col, col.a * a))
	if _hover_k > 0.01:
		var r := lerpf(6.0, 13.0, _hover_k)
		draw_arc(c, r + 1.0, 0, TAU, 40, Color(0, 0, 0, 0.45 * _hover_k), 3.0, true)
		draw_arc(c, r, 0, TAU, 40, Color(UIKit.ACCENT, _hover_k), 2.0, true)
	if _work_k > 0.01:
		var g := 5.0
		var l := 9.0
		var wc := Color(UIKit.ACCENT, 0.9 * _work_k)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * g, c + d * (g + l), Color(0, 0, 0, 0.5 * _work_k), 3.0, true)
			draw_line(c + d * g, c + d * (g + l), wc, 1.6, true)
		# Profondeur sous la peau : petite jauge à droite
		if hand.held and hand.held.tip_depth > 0.0:
			var dmm := hand.held.tip_depth * 1000.0
			var h := clampf(dmm / 45.0, 0.0, 1.0) * 30.0
			draw_rect(Rect2(c + Vector2(22, -15), Vector2(4, 30)), Color(1, 1, 1, 0.15 * _work_k))
			draw_rect(Rect2(c + Vector2(22, -15 + 30 - h), Vector2(4, h)), Color(1.0, 0.45, 0.4, 0.9 * _work_k))
			draw_string(UIKit.font(), c + Vector2(30, 6), "%d mm" % int(dmm), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.8 * _work_k))
