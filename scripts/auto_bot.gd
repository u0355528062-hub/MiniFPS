class_name AutoBot
extends SurgeonHand
## Main abstraite pilotée par le robot de test AutoDriver (pointe et serrage imposés).

var bot_tip := Vector3(0.4, 1.3, 0.4)
var bot_squeeze := 0.0
var patient: Patient


func squeeze_value() -> float:
	return bot_squeeze


func raw_tip() -> Vector3:
	return bot_tip if held else global_position


func _process(_delta: float) -> void:
	_update_edges()
	if held:
		var axis := Vector3(0.2, -0.85, 0.45).normalized()
		# Au fond de la plaie : l'instrument passe par l'ouverture (vise depuis au-dessus du centre)
		if patient and Vector2(bot_tip.x - patient.center.x, bot_tip.z - patient.center.z).length() < 0.06 and bot_tip.y < patient.center.y - 0.008:
			axis = (bot_tip - (patient.center + Vector3(0.05, 0.3, 0.12))).normalized()
		# Près de l'orifice, l'instrument suit le trajet (pince, drain)
		var wa := tract_weight(bot_tip)
		if wa > 0.0:
			axis = axis.slerp(assist_axis, wa).normalized()
		held.pose_tip(bot_tip, axis, Vector3.UP)
		held.set_squeeze(bot_squeeze)
		_after_place(patient)
