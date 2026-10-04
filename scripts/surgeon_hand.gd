class_name SurgeonHand
extends Node3D
## Main du chirurgien (VR ou souris). Tient au plus un instrument ; la procédure lit
## la pointe de l'instrument et la gâchette.

signal take_requested(hand: SurgeonHand, inst: Instrument)
signal put_back_requested(hand: SurgeonHand)

var held: Instrument
var hovered: Instrument
## Aide au placement (souris) : la procédure indique la cible de l'étape en cours
var assist_target := Vector3.INF
var instruments: Array[Instrument] = []

var _trigger_was := false
var _trigger_edge := false
var _release_edge := false


func trigger_value() -> float:
	return 0.0


func trigger_down() -> bool:
	return trigger_value() > 0.55


func trigger_just_pressed() -> bool:
	return _trigger_edge


func trigger_just_released() -> bool:
	return _release_edge


## À appeler en début de _process par les sous-classes.
func _update_edges() -> void:
	var now := trigger_down()
	_trigger_edge = now and not _trigger_was
	_release_edge = (not now) and _trigger_was
	_trigger_was = now


func tip() -> Vector3:
	return held.tip_global() if held else global_position


func pulse(_amplitude := 0.5, _duration := 0.05) -> void:
	pass


## Prendre un instrument (le précédent retourne sur le plateau).
func take(inst: Instrument) -> void:
	if inst == held:
		return
	if held:
		held.return_to_tray()
	held = inst
	inst.take()
	pulse(0.4, 0.06)


func put_back() -> void:
	if held:
		held.return_to_tray()
		held = null
		pulse(0.2, 0.04)


## L'instrument quitte la main sans retourner au plateau (écarteur posé dans la plaie).
func release_parked() -> void:
	held = null


func set_hover(inst: Instrument) -> void:
	hovered = inst
