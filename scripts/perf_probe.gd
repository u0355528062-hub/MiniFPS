class_name PerfProbe
extends Node
## Mesure du temps de calcul par image (option --perf) : moyenne et pire image par étape.

var proc: Procedure
var _step := -99
var _sum := 0.0
var _n := 0
var _worst := 0.0


func _process(_delta: float) -> void:
	var t := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	if proc and proc.step != _step:
		_report()
		_step = proc.step
	_sum += t
	_n += 1
	_worst = maxf(_worst, t)


func _report() -> void:
	if _n > 0:
		print("PERF étape %d : moyenne %.2f ms, pire %.2f ms (%d images)" % [_step, _sum / _n, _worst, _n])
	_sum = 0.0
	_n = 0
	_worst = 0.0


func _exit_tree() -> void:
	_report()
