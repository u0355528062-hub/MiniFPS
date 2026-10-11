class_name PatientJeu
extends Node3D
## Un patient en jeu : corps (Personnage), dossier (identité, pathologie, mesures, examens,
## traitements), constantes vitales, déplacements dans le service et postures.
## États : arrivee → accueil → attente → installe → oriente (départ).

signal parle(texte: String)
signal arrive                      # fin d'un déplacement
signal etat_change

const VITESSE := 1.05

var personnage: Personnage
var constantes: Constantes
var dossier := {}
var reponses := {}
var patho := {}
var tri := 0
var etat := "arrivee"
var lieu := "Entrée"
var place := ""                    # id de l'emplacement occupé (siège, box…)
var arrivee_jeu := 0.0             # heure de jeu d'arrivée (s)
var installe_jeu := -1.0
var traitements := []
var examens := {}                  # id -> {demande: s, resultat: texte|""}
var diagnostic := ""
var orientation := ""
var aggrave := false
var arret := false
var arret_heure := 0.0
var decede := false
var qualite_gestes := []
var service: Service

var _parole := 0.0
var _chemin := PackedVector3Array()
var _i_chemin := 0
var _corps_clic: StaticBody3D
var _forme: CollisionShape3D
var _posture := ""


func configurer(d: Dictionary) -> void:
	dossier = d
	reponses = d.get("reponses", {})
	patho = Pathologies.par_id(d.get("pathologie", ""))
	constantes = Constantes.new(d.get("constantes", {}))


func _ready() -> void:
	add_to_group("interactif")
	add_to_group("patients")
	personnage = Personnage.new()
	personnage.modele = dossier.get("modele", "patient_gerard")
	personnage.animation_initiale = dossier.get("posture", "attente")
	add_child(personnage)
	_corps_clic = StaticBody3D.new()
	_corps_clic.collision_layer = 2
	_corps_clic.collision_mask = 0
	_forme = CollisionShape3D.new()
	_forme.shape = BoxShape3D.new()
	_corps_clic.add_child(_forme)
	add_child(_corps_clic)
	poser_posture(dossier.get("posture", "attente"))


func nom_complet() -> String:
	return "%s %s" % [dossier.get("prenom", ""), dossier.get("nom", "")]


func titre() -> String:
	return "%s, %d ans" % [nom_complet(), dossier.get("age", 0)]


func civilite() -> String:
	return ("M. " if dossier.get("sexe", "M") == "M" else "Mme ") + dossier.get("nom", "")


func repondre(question: String) -> String:
	var r: String = reponses.get(question, Repliques.NE_SAIS_PAS)
	_parole = clampf(r.length() * 0.06, 1.0, 5.0)
	_voix(r)
	parle.emit(r)
	return r


func dire_eva() -> void:
	var t := Repliques.eva(int(constantes.eva))
	_parole = 2.0
	_voix(t)
	parle.emit(t)


## Voix synthétisée de la réplique (si elle existe) ; la bouche bouge pendant sa durée.
func _voix(t: String) -> void:
	var age: int = dossier.get("age", 45)
	var hauteur := 0.94 if age >= 70 else (1.05 if age < 25 else 1.0)
	var d := Sons.voix(self, t, dossier.get("sexe", "M") == "M", hauteur)
	if d > 0.0:
		_parole = d


func changer_etat(e: String, l := "") -> void:
	etat = e
	if l != "":
		lieu = l
	etat_change.emit()


## Posture : « attente » (debout), « assis », « semi_assis », « allonge », « marche ».
func poser_posture(p: String) -> void:
	_posture = p
	var b: BoxShape3D = _forme.shape
	match p:
		"semi_assis", "allonge":
			b.size = Vector3(0.6, 0.5, 1.7)
			_forme.position = Vector3(0, personnage.hauteur_bassin() + 0.05, -0.25 if p == "semi_assis" else 0.0)
			personnage.jouer(p)
		"assis":
			b.size = Vector3(0.6, 1.3, 0.7)
			_forme.position = Vector3(0, 0.65, 0.1)
			personnage.jouer("assis" if randf() < 0.6 else "assis_tete_mains")
		_:
			b.size = Vector3(0.55, 1.7, 0.45)
			_forme.position = Vector3(0, 0.85, 0)
			personnage.jouer(p if p != "" else "attente")


## Déplacement à pied le long du maillage de navigation.
func aller(cible: Vector3) -> void:
	if service == null:
		global_position = cible
		arrive.emit()
		return
	_chemin = service.chemin(global_position, cible)
	_i_chemin = 1
	if _chemin.size() < 2:
		global_position = cible
		_chemin = PackedVector3Array()
		arrive.emit()
		return
	poser_posture("boiter" if patho.get("id", "") in ["entorse", "fracture_poignet"] and randf() < 0.5 else "marche")


func en_marche() -> bool:
	return not _chemin.is_empty()


func _physics_process(delta: float) -> void:
	if _chemin.is_empty():
		return
	var cible := _chemin[_i_chemin]
	var pos := global_position
	var d := Vector3(cible.x - pos.x, 0, cible.z - pos.z)
	var pas := VITESSE * (0.75 if _posture == "boiter" else 1.0) * delta
	if d.length() <= pas:
		global_position = Vector3(cible.x, 0.0, cible.z)
		_i_chemin += 1
		if _i_chemin >= _chemin.size():
			_chemin = PackedVector3Array()
			poser_posture("attente")
			arrive.emit()
		return
	var dir := d.normalized()
	global_position = Vector3(pos.x, 0.0, pos.z) + dir * pas
	# Le modèle regarde +Z : on oriente le nœud vers la direction de marche (rotation lissée).
	var lacet := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, lacet, clampf(delta * 8.0, 0.0, 1.0))


func _process(delta: float) -> void:
	var _t_prof := Profileur.debut()
	if constantes:
		constantes.avancer(delta * Garde.ECHELLE_TEMPS)
	if personnage == null or personnage.corps == null:
		Profileur.fin("patients", _t_prof)
		return
	personnage.expression("douleur", clampf(constantes.eva / 10.0, 0.0, 1.0) * 0.9)
	if _parole > 0.0:
		_parole -= delta
		personnage.expression("bouche_ouverte", absf(sin(Time.get_ticks_msec() * 0.012)) * 0.5)
	else:
		personnage.expression("bouche_ouverte", 0.0)
	Profileur.fin("patients", _t_prof)


func declencher_arret(heure: float) -> void:
	arret = true
	arret_heure = heure
	constantes.rythme = "fv"
	constantes.fc = 0.0
	constantes.cibles["fc"] = 0.0
	constantes.tas = 0.0
	constantes.cibles["tas"] = 0.0
	constantes.spo2 = 60.0
	constantes.cibles["spo2"] = 40.0
	constantes.glasgow = 3
	poser_posture("allonge")


func deceder() -> void:
	decede = true
	arret = false
	constantes.rythme = "asystolie"
	poser_posture("allonge")


## Vérifie l'aggravation (appelé par la garde, une fois par seconde de jeu réel).
func verifier_aggravation(heure: float) -> bool:
	var ag: Dictionary = patho.get("aggravation", {})
	if aggrave or ag.is_empty() or orientation != "":
		return false
	var delai: float = ag.get("delai", 999.0) * 60.0
	var traite := false
	for t in patho.get("traitements", []):
		if t in traitements:
			traite = true
	if traite or heure - arrivee_jeu < delai:
		return false
	aggrave = true
	for k in ag:
		if k in ["fc", "tas", "tad", "spo2", "fr", "temperature", "glycemie"]:
			constantes.cibles[k] = ag[k]
		elif k == "glasgow":
			constantes.glasgow = ag[k]
		elif k == "rythme":
			constantes.rythme = ag[k]
	return true
