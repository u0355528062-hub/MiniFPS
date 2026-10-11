class_name Marcheur
extends Node
## Composant de déplacement : fait marcher son parent (Node3D) le long du maillage de
## navigation, l'oriente dans le sens de la marche et joue l'animation de marche du Personnage.
## Mise à jour dans _physics_process (60 Hz, positions interpolées par le moteur).

signal arrive

var vitesse := 1.25
var anim_marche := "marche"
var anim_arret := "attente"
var service: Service
var personnage: Personnage
var _chemin := PackedVector3Array()
var _i := 0
var _corps: Node3D


func _ready() -> void:
	_corps = get_parent()


func aller(cible: Vector3) -> void:
	_chemin = service.chemin(_corps.global_position, cible) if service else PackedVector3Array()
	_i = 1
	if _chemin.size() < 2:
		_corps.global_position = Vector3(cible.x, 0.0, cible.z)
		_chemin = PackedVector3Array()
		arrive.emit()
		return
	if personnage:
		personnage.jouer(anim_marche, 0.25, vitesse / 1.25)


func en_marche() -> bool:
	return not _chemin.is_empty()


func arreter() -> void:
	_chemin = PackedVector3Array()


func _physics_process(delta: float) -> void:
	if _chemin.is_empty():
		return
	var cible := _chemin[_i]
	var pos := _corps.global_position
	var d := Vector3(cible.x - pos.x, 0, cible.z - pos.z)
	var pas := vitesse * delta
	if d.length() <= pas:
		_corps.global_position = Vector3(cible.x, 0.0, cible.z)
		_i += 1
		if _i >= _chemin.size():
			_chemin = PackedVector3Array()
			if personnage:
				personnage.jouer(anim_arret, 0.3)
			arrive.emit()
		return
	var dir := d.normalized()
	_corps.global_position = Vector3(pos.x, 0.0, pos.z) + dir * pas
	_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(dir.x, dir.z), clampf(delta * 8.0, 0.0, 1.0))
