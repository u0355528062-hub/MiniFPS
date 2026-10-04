class_name AutoBot
extends SurgeonHand
## Main abstraite pilotée par le robot de test AutoDriver (pointe et gâchette imposées).

var bot_tip := Vector3(0.4, 1.3, 0.4)
var bot_trigger := false


func trigger_value() -> float:
	return 1.0 if bot_trigger else 0.0


func tip() -> Vector3:
	return bot_tip if held else global_position


func _process(_delta: float) -> void:
	_update_edges()
	if held:
		held.pose_tip(bot_tip, Vector3(0.2, -0.85, 0.45).normalized(), Vector3.UP)
