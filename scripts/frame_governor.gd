class_name FrameGovernor
extends Node
## Résolution dynamique (casque) : si la carte graphique ne tient pas la cadence du casque, la
## résolution de rendu baisse un peu ; elle remonte dès qu'il y a de la marge. Une image fluide
## vaut mieux qu'une image nette qui saccade (dans le casque, ça fait trembler toute la vue).

const MIN_SCALE := 0.65
const MAX_SCALE := 1.0

var xr: XRInterface
var scale := 1.0
var _rid: RID
var _sum := 0.0
var _late := 0
var _n := 0
var _calm := 0.0


func _ready() -> void:
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)


func _budget_ms() -> float:
	var hz := 90.0
	if xr is OpenXRInterface:
		var r := (xr as OpenXRInterface).display_refresh_rate
		if r > 30.0:
			hz = r
	return 1000.0 / hz


func _process(delta: float) -> void:
	var budget := _budget_ms()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_rid)
	_sum += gpu
	_n += 1
	if delta * 1000.0 > budget * 1.5:
		_late += 1
	if _n < 45:
		return
	var avg := _sum / _n
	var late := _late
	_sum = 0.0
	_n = 0
	_late = 0
	var before := scale
	if avg > budget * 0.86 or late > 4:
		scale = maxf(MIN_SCALE, scale - 0.07)
		_calm = 0.0
	elif avg < budget * 0.62 and late == 0:
		_calm += 1.0
		if _calm >= 4.0:
			scale = minf(MAX_SCALE, scale + 0.05)
			_calm = 0.0
	else:
		_calm = 0.0
	if scale != before:
		get_viewport().scaling_3d_scale = scale
		print("Résolution du casque : %d %% (carte graphique %.1f ms pour %.1f ms)" % [int(scale * 100.0), avg, budget])
