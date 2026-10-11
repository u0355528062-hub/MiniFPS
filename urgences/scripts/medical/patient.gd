class_name PatientJeu
extends Node3D
## Un patient en jeu : son corps (Personnage), son dossier (identité, motif, antécédents),
## ses constantes vitales et ses réponses à l'interrogatoire. Cliquable (groupe « interactif »).

signal parle(texte: String)

var personnage: Personnage
var constantes: Constantes
var dossier := {}
var reponses := {}
var tri := 0
var _parole := 0.0


func configurer(d: Dictionary) -> void:
	dossier = d
	reponses = d.get("reponses", {})
	constantes = Constantes.new(d.get("constantes", {}))


func _ready() -> void:
	add_to_group("interactif")
	personnage = Personnage.new()
	personnage.modele = dossier.get("modele", "patient_gerard")
	personnage.animation_initiale = dossier.get("posture", "semi_assis")
	add_child(personnage)
	# Volume cliquable autour du corps (allongé ou assis).
	var corps := StaticBody3D.new()
	corps.collision_layer = 2
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.55, 0.45, 1.7)
	cs.shape = b
	cs.position = Vector3(0, personnage.hauteur_bassin() + 0.05, -0.25)
	corps.add_child(cs)
	add_child(corps)


func nom_complet() -> String:
	return "%s %s" % [dossier.get("prenom", ""), dossier.get("nom", "")]


func titre() -> String:
	return "%s, %d ans" % [nom_complet(), dossier.get("age", 0)]


func repondre(question: String) -> String:
	var r: String = reponses.get(question, "Je ne sais pas trop, docteur…")
	_parole = clampf(r.length() * 0.06, 1.0, 5.0)
	parle.emit(r)
	return r


func _process(delta: float) -> void:
	var _t_prof := Profileur.debut()
	if constantes:
		constantes.avancer(delta)
	if personnage == null or personnage.corps == null:
		Profileur.fin("patients", _t_prof)
		return
	# Expression de douleur selon l'EVA, mouvements de lèvres quand il parle.
	personnage.expression("douleur", clampf(constantes.eva / 10.0, 0.0, 1.0) * 0.9)
	if _parole > 0.0:
		_parole -= delta
		personnage.expression("bouche_ouverte", absf(sin(Time.get_ticks_msec() * 0.012)) * 0.5)
	else:
		personnage.expression("bouche_ouverte", 0.0)
	Profileur.fin("patients", _t_prof)
