class_name SurgeonHand
extends Node3D
## Main du chirurgien (mains nues, manette ou souris). Tient au plus un instrument. La procédure lit
## la pointe de l'instrument (et sa profondeur sous la peau) et le serrage des doigts (0..1) qui
## ferme les mâchoires, pousse le piston...

signal take_requested(hand: SurgeonHand, inst: Instrument)
signal put_back_requested(hand: SurgeonHand)

var held: Instrument
var hovered: Instrument
## Aide au placement (souris) : la procédure indique la cible de l'étape en cours
var assist_target := Vector3.INF
## Axe du trajet à suivre près de la cible (pince, drain) : l'instrument s'y aligne
var assist_axis := Vector3.ZERO
var instruments: Array[Instrument] = []
var slot := 0  ## 0 ou 1 : pour la peau enfoncée sous chaque main

var _trigger_was := false
var _trigger_edge := false
var _release_edge := false


## Serrage des doigts (pouce contre index, gâchette, clic) : 0 = ouvert, 1 = serré.
func squeeze_value() -> float:
	return 0.0


## Clic (ou serrage) main vide : massage cardiaque, manivelle d'un écarteur posé.
func pressing() -> bool:
	return false


func trigger_value() -> float:
	return squeeze_value()


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


## Pointe voulue par la main avant la correction des contacts (pour les robots de test).
func raw_tip() -> Vector3:
	return tip()


## Bout de l'index (boutons à toucher), INF si la main n'en a pas.
func fingertip() -> Vector3:
	return Vector3.INF


## Poids d'alignement sur le trajet (1 = l'instrument suit l'axe) : selon la distance de la pointe
## à la ligne du trajet, de 3 cm avant l'entrée jusqu'au fond.
func tract_weight(p: Vector3) -> float:
	if assist_axis == Vector3.ZERO or assist_target == Vector3.INF:
		return 0.0
	var d := p - assist_target
	var along := d.dot(assist_axis)
	if along < -0.04 or along > 0.16:
		return 0.0
	var lat := (d - assist_axis * along).length()
	return 1.0 - smoothstep(0.012, 0.035, lat)


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


## L'instrument quitte la main sans retourner au plateau (écarteur tenu par l'aide, drain posé).
func release_parked() -> void:
	held = null


func set_hover(inst: Instrument) -> void:
	hovered = inst


## Instrument tenu : met à jour ses mâchoires et la peau enfoncée sous la pointe.
func _after_place(patient: Patient) -> void:
	if held == null:
		return
	if patient and held.tip_depth > 0.0 and held.tip_depth < 0.012 and patient.hole_depth(held.tip_global()) <= 0.0:
		patient.set_press(slot, held.tip_global(), minf(held.tip_depth, Contact.SOFT) * 1.3)
