class_name Collegue
extends Node3D
## Collègue PNJ (infirmier·ère, brancardier, interne) : exécute les tâches de la garde
## (soins, prélèvements, ECG, transferts de patients), puis retourne au poste de soins.
## Logique événementielle (pas de calcul à chaque image) : un déplacement, une attente, un rappel.

signal libre

var role := "ide"
var nom := ""
var modele := "infirmiere_claire"
var service: Service
var personnage: Personnage
var marcheur: Marcheur
var poste := Vector3.ZERO
var tache := {}


func _ready() -> void:
	personnage = Personnage.new()
	personnage.modele = modele
	personnage.animation_initiale = "attente"
	add_child(personnage)
	marcheur = Marcheur.new()
	marcheur.service = service
	marcheur.personnage = personnage
	marcheur.vitesse = 1.35
	add_child(marcheur)


func occupe() -> bool:
	return not tache.is_empty()


func titre() -> String:
	return "%s (%s)" % [nom, {"ide": "IDE", "brancardier": "brancardier", "interne": "interne"}.get(role, role)]


## Va en `lieu`, travaille `duree` secondes de jeu, puis appelle `fin`.
func executer(t: Dictionary, lieu: Vector3, duree: float, fin: Callable, regarder := Vector3.INF) -> void:
	tache = t
	marcheur.aller(lieu)
	await marcheur.arrive
	if regarder != Vector3.INF:
		var d := regarder - global_position
		rotation.y = atan2(d.x, d.z)
	personnage.jouer("parler", 0.3)
	await get_tree().create_timer(duree / Garde.ECHELLE_TEMPS).timeout
	fin.call()
	tache = {}
	personnage.jouer("attente", 0.3)
	libre.emit()
	retour_poste()


func retour_poste() -> void:
	if occupe():
		return
	marcheur.aller(poste + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.4, 0.4)))
