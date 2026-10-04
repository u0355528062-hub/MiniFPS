class_name OneEuro
extends RefCounted
## Filtre « One Euro » (Casiez et al.) : supprime le tremblement du suivi des mains à l'arrêt,
## sans retard quand la main bouge vite.

var min_cutoff := 1.4
var beta := 14.0
var d_cutoff := 1.0
var _x := Vector3.ZERO
var _dx := Vector3.ZERO
var _ready := false


func _init(p_min_cutoff := 1.4, p_beta := 14.0) -> void:
	min_cutoff = p_min_cutoff
	beta = p_beta


static func _alpha(cutoff: float, dt: float) -> float:
	var tau := 1.0 / (TAU * cutoff)
	return 1.0 / (1.0 + tau / dt)


func reset() -> void:
	_ready = false


func filter(x: Vector3, dt: float) -> Vector3:
	if not _ready or dt <= 0.0:
		_x = x
		_dx = Vector3.ZERO
		_ready = true
		return x
	var dx := (x - _x) / dt
	_dx = _dx.lerp(dx, _alpha(d_cutoff, dt))
	_x = _x.lerp(x, _alpha(min_cutoff + beta * _dx.length(), dt))
	return _x
