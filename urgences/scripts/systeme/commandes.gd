extends Node
## Déclare les actions clavier/souris (autoload « Commandes »).
## Les touches de déplacement utilisent les codes PHYSIQUES : la rangée W-A-S-D d'un clavier
## QWERTY correspond à Z-Q-S-D sur un AZERTY, sans rien configurer.

const ACTIONS := {
	"avancer": [KEY_W, KEY_UP],
	"reculer": [KEY_S, KEY_DOWN],
	"gauche": [KEY_A, KEY_LEFT],
	"droite": [KEY_D, KEY_RIGHT],
	"courir": [KEY_SHIFT],
	"accroupir": [KEY_CTRL],
	"interagir": [KEY_E],
	"camera": [KEY_V],
	"dossier": [KEY_TAB],
	"pause": [KEY_ESCAPE],
	"aide": [KEY_F1],
	"fps": [KEY_F3],
}


func _ready() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	_souris("clic", MOUSE_BUTTON_LEFT)
	_souris("clic_droit", MOUSE_BUTTON_RIGHT)
	var ev_e := InputEventMouseButton.new()
	ev_e.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interagir", ev_e)


func _souris(action: String, bouton: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = bouton
	InputMap.action_add_event(action, ev)
