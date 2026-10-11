class_name Garde
extends Node
## La garde : le temps qui passe, les arrivées de patients (à pied à l'accueil, en ambulance
## au sas), la file d'attente, l'occupation des box et du déchocage, les résultats d'examens
## qui tombent, les aggravations et le score du service.

signal notification(texte: String, couleur: Color, duree: float)
signal patients_changes

const ECHELLE_TEMPS := 10.0                 # 1 s réelle = 10 s de jeu
const MAX_PATIENTS := 12
const PRENOMS_H := ["Gérard", "Thomas", "Karim", "Julien", "Michel", "Nicolas", "Mamadou", "Kevin", "Jean-Pierre",
	"Antoine", "Lucas", "Yanis", "Bernard", "Hugo", "Sébastien", "Wei", "Mehdi", "Patrick", "Christophe", "Alain"]
const PRENOMS_F := ["Sophie", "Isabelle", "Fatou", "Chloé", "Marie", "Nathalie", "Camille", "Léa", "Monique",
	"Aïcha", "Julie", "Sandrine", "Inès", "Jacqueline", "Emma", "Mei", "Nadia", "Françoise", "Manon", "Brigitte"]
const NOMS := ["MARTIN", "BERNARD", "DUBOIS", "THOMAS", "ROBERT", "PETIT", "DURAND", "LEROY", "MOREAU", "SIMON",
	"LAURENT", "LEFEBVRE", "MICHEL", "GARCIA", "DAVID", "BERTRAND", "ROUX", "VINCENT", "FOURNIER", "DIALLO",
	"NGUYEN", "BENALI", "TRAORE", "FAURE", "ANDRÉ", "MERCIER", "BLANC", "GUERIN", "BOYER", "CHEVALIER"]
## Modèles disponibles : [id, sexe, âge approximatif, en blouse ?]
const MODELES := [
	["p_homme_jeune_jean", "M", 30, false], ["p_femme_jeune", "F", 27, false], ["p_homme_age_pull", "M", 78, false],
	["p_femme_agee", "F", 82, false], ["p_homme_africain", "M", 38, false], ["p_femme_africaine", "F", 36, false],
	["p_homme_asiatique", "M", 33, false], ["p_femme_mur", "F", 52, false], ["p_homme_mur_fort", "M", 50, false],
	["p_ado", "M", 17, false], ["p_femme_blouse", "F", 65, true], ["p_homme_blouse", "M", 45, true],
	["patient_gerard", "M", 67, true],
]

static var instance: Garde

var service: Service
var heure := 8.0 * 3600.0 + 12.0 * 60.0
var patients: Array[PatientJeu] = []
var occupation := {}                       # id d'emplacement -> PatientJeu
var score := 0
var reputation := 70.0
var bilans := []                            # résumés des patients orientés
var prochaine_arrivee := 0.0
var arrivees_actives := true
var _accu := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	instance = self
	_rng.randomize()


func _ready() -> void:
	prochaine_arrivee = heure + 4.0 * 60.0


static func heure_texte_de(s: float) -> String:
	var t := int(s) % 86400
	return "%02d h %02d" % [t / 3600, (t / 60) % 60]


func heure_texte() -> String:
	return heure_texte_de(heure)


func _process(delta: float) -> void:
	heure += delta * ECHELLE_TEMPS
	_accu += delta
	if _accu < 1.0:
		return
	_accu = 0.0
	# Arrivées.
	if arrivees_actives and heure >= prochaine_arrivee and patients.size() < MAX_PATIENTS:
		generer_arrivee()
		prochaine_arrivee = heure + _rng.randf_range(10.0, 22.0) * 60.0
	# Résultats d'examens, aggravations, patience en salle d'attente.
	for p in patients:
		for ex in p.examens:
			var e: Dictionary = p.examens[ex]
			if e["resultat"] == "" and heure >= e["pret"]:
				e["resultat"] = p.patho.get("examens", {}).get(ex, "Examen sans anomalie.")
				notification.emit("Résultat disponible : %s — %s" % [Pathologies.EXAMENS[ex][0], p.civilite()], ThemeHopital.BLEU, 6.0)
				patients_changes.emit()
		if p.verifier_aggravation(heure):
			notification.emit("⚠ %s s'aggrave (%s) !" % [p.civilite(), p.lieu], ThemeHopital.ROUGE, 8.0)
			reputation = maxf(reputation - 4.0, 0.0)
			patients_changes.emit()


# ---------------------------------------------------------------------------------------------
func _choisir_modele(sexe: String, age: int, blouse: bool, exclus: Array) -> String:
	var meilleur := ""
	var ecart := 999.0
	for m in MODELES:
		if m[1] != sexe or (m[3] != blouse) or m[0] in exclus:
			continue
		var e := absf(m[2] - age) + _rng.randf() * 12.0
		if e < ecart:
			ecart = e
			meilleur = m[0]
	if meilleur == "":
		for m in MODELES:
			if m[1] == sexe and m[0] not in exclus:
				return m[0]
		return "p_homme_jeune_jean"
	return meilleur


func creer_dossier(patho_id := "", force := {}) -> Dictionary:
	var pa: Dictionary = Pathologies.par_id(patho_id) if patho_id != "" else _tirer_pathologie()
	var homme: bool = _rng.randf() < pa.get("homme", 0.5)
	var age := _rng.randi_range(pa["age"][0], pa["age"][1])
	var en_cours := []
	for p in patients:
		en_cours.append(p.dossier.get("modele", ""))
	var ambulance: bool = pa.get("arrivee", "pied") == "ambulance"
	var d := {
		"pathologie": pa["id"], "prenom": (PRENOMS_H if homme else PRENOMS_F)[_rng.randi() % 20],
		"nom": NOMS[_rng.randi() % NOMS.size()], "age": age, "sexe": "M" if homme else "F",
		"iep": "2410-%05d" % _rng.randi_range(1000, 99999), "arrivee": heure_texte(),
		"motif": pa["motif"], "constantes": pa["constantes"].duplicate(), "reponses": pa["reponses"].duplicate(),
		"antecedents": "", "traitement": "", "allergies": "", "mode": "ambulance" if ambulance else "pied",
		"modele": _choisir_modele("M" if homme else "F", age, ambulance, en_cours),
	}
	# Petite variabilité des constantes.
	var c: Dictionary = d["constantes"]
	for k in ["fc", "tas", "tad", "fr"]:
		if c.has(k):
			c[k] = c[k] * _rng.randf_range(0.94, 1.06)
	d.merge(force, true)
	return d


func _tirer_pathologie() -> Dictionary:
	# Plus de patients peu graves que d'urgences vitales (comme dans un vrai service).
	var poids := {1: 0.5, 2: 1.4, 3: 2.2, 4: 2.4, 5: 1.4}
	var total := 0.0
	for p in Pathologies.LISTE:
		total += poids[p["tri"]]
	var r := _rng.randf() * total
	for p in Pathologies.LISTE:
		r -= poids[p["tri"]]
		if r <= 0.0:
			return p
	return Pathologies.LISTE[0]


## Crée un patient et l'ajoute au service.
func ajouter_patient(d: Dictionary) -> PatientJeu:
	var p := PatientJeu.new()
	p.name = "Patient_%s" % d["iep"]
	p.configurer(d)
	p.service = service
	p.arrivee_jeu = heure
	service.add_child(p)
	patients.append(p)
	patients_changes.emit()
	return p


func generer_arrivee(patho_id := "") -> PatientJeu:
	var d := creer_dossier(patho_id)
	if d["mode"] == "ambulance":
		d["posture"] = "allonge"
		var p := ajouter_patient(d)
		var a: Vector3 = service.points["sas"]["arrivee"]
		p.global_position = a + Vector3(0, 0.80 - p.personnage.hauteur_bassin(), 0)
		p.rotation.y = PI
		var br := Bibliotheque.meuble("brancard")
		br.position = a + Vector3(0, 0, 0.05)
		br.rotation_degrees.y = 90.0
		br.name = "Brancard_" + d["iep"]
		service.add_child(br)
		p.set_meta("brancard", br)
		p.changer_etat("accueil", "Sas ambulances")
		notification.emit("🚑 Arrivée %s au sas : %s, %s — %s" % ["SAMU" if _rng.randf() < 0.5 else "des pompiers",
			p.civilite(), str(d["age"]) + " ans", d["motif"].to_lower()], ThemeHopital.ROUGE, 9.0)
		return p
	d["posture"] = "attente"
	var p := ajouter_patient(d)
	p.global_position = service.points["entree"]
	p.changer_etat("arrivee", "Entrée")
	var file := 0
	for q in patients:
		if q != p and q.etat in ["arrivee", "accueil"] and q.lieu == "Accueil":
			file += 1
	var cible: Vector3 = service.points["accueil"] + Vector3(0.0, 0, 0.75 * file)
	p.aller(cible)
	p.arrive.connect(func():
		p.rotation.y = PI
		p.changer_etat("accueil", "Accueil")
		patients_changes.emit(), CONNECT_ONE_SHOT)
	notification.emit("Nouveau patient à l'accueil : %s, %d ans — %s" % [p.civilite(), d["age"], d["motif"].to_lower()],
		ThemeHopital.ORANGE, 6.0)
	return p


# ---------------------------------------------------------------------------------------------
func box_libres() -> Array:
	var l := []
	for id in ["box_1", "box_2", "box_3", "box_4", "box_5", "box_6", "dechoc_1", "dechoc_2"]:
		if not occupation.has(id):
			l.append(id)
	return l


static func nom_place(id: String) -> String:
	if id.begins_with("box_"):
		return "Box " + id.substr(4)
	if id.begins_with("dechoc_"):
		return "Déchocage " + id.substr(7)
	return id


func liberer(p: PatientJeu) -> void:
	if p.place != "" and occupation.get(p.place) == p:
		occupation.erase(p.place)
	p.place = ""


## Envoie un patient s'asseoir en salle d'attente.
func envoyer_attente(p: PatientJeu) -> void:
	var sieges: Array = service.points["sieges"]
	for i in sieges.size():
		var id := "siege_%d" % i
		if occupation.has(id):
			continue
		liberer(p)
		occupation[id] = p
		p.place = id
		var s: Dictionary = sieges[i]
		p.changer_etat("attente", "Salle d'attente")
		p.aller(s["pos"])
		p.arrive.connect(func():
			p.rotation.y = s["rot"]
			p.global_position = s["pos"]
			p.poser_posture("assis"), CONNECT_ONE_SHOT)
		patients_changes.emit()
		return
	notification.emit("Plus de siège libre en salle d'attente !", ThemeHopital.ORANGE, 5.0)


## Installe un patient sur le brancard d'un box ou du déchocage (pris en charge par l'équipe).
func installer(p: PatientJeu, id: String) -> void:
	if occupation.has(id):
		return
	liberer(p)
	occupation[id] = p
	p.place = id
	var info: Dictionary = service.points[id]
	if p.has_meta("brancard"):
		(p.get_meta("brancard") as Node).queue_free()
		p.remove_meta("brancard")
	# Le transfert est assuré par l'équipe (brancardier) : le patient est réinstallé dans le box.
	var pl: Vector3 = info["place_patient"]
	p.global_position = pl - Vector3(0, p.personnage.hauteur_bassin(), 0)
	p.rotation.y = 0.0
	p.poser_posture("semi_assis")
	p.installe_jeu = heure
	p.changer_etat("installe", nom_place(id))
	(info["moniteur"] as Moniteur).connecter(p.constantes)
	(info["moniteur"] as Moniteur).brancher(false)
	patients_changes.emit()


func moniteur_de(p: PatientJeu) -> Moniteur:
	if p.place.begins_with("box_") or p.place.begins_with("dechoc_"):
		return service.points[p.place]["moniteur"]
	return null


func demander_examen(p: PatientJeu, ex: String) -> void:
	if p.examens.has(ex):
		return
	var duree: float = Pathologies.EXAMENS[ex][1] * _rng.randf_range(0.8, 1.2)
	p.examens[ex] = {"demande": heure, "pret": heure + duree, "resultat": ""}
	patients_changes.emit()


## Oriente le patient (fin de prise en charge) et calcule son bilan.
func orienter(p: PatientJeu, o: String) -> Dictionary:
	p.orientation = o
	var pa := p.patho
	var b := {"patient": p.titre(), "points": 0, "details": []}
	var pts := 0
	# Tri.
	if p.tri == pa.get("tri", 3):
		pts += 30
		b["details"].append("Tri juste (%d) : +30" % p.tri)
	elif p.tri > 0:
		var e: int = absi(p.tri - pa["tri"])
		pts += 30 - e * 15
		b["details"].append("Tri %d au lieu de %d : %+d" % [p.tri, pa["tri"], 30 - e * 15])
	else:
		pts -= 20
		b["details"].append("Pas de tri : -20")
	# Diagnostic.
	if p.diagnostic == pa.get("id", ""):
		pts += 40
		b["details"].append("Diagnostic exact : +40")
	else:
		pts -= 20
		b["details"].append("Diagnostic erroné ou absent : -20")
	# Examens utiles / inutiles.
	for ex in pa.get("utiles", []):
		if p.examens.has(ex):
			pts += 5
	var inutiles := 0
	for ex in p.examens:
		if ex not in pa.get("utiles", []):
			inutiles += 1
	if inutiles > 0:
		pts -= inutiles * 5
		b["details"].append("%d examen(s) non indiqué(s) : -%d" % [inutiles, inutiles * 5])
	# Traitements.
	var bons := 0
	for t in pa.get("traitements", []):
		if t in p.traitements:
			bons += 1
	if pa.get("traitements", []).size() > 0:
		var bonus := int(20.0 * bons / pa["traitements"].size())
		pts += bonus
		b["details"].append("Traitements adaptés : %d/%d (+%d)" % [bons, pa["traitements"].size(), bonus])
	# Orientation.
	if o == pa.get("orientation", ""):
		pts += 25
		b["details"].append("Orientation correcte : +25")
	else:
		pts -= 15
		b["details"].append("Orientation discutable (attendu : %s) : -15" % Pathologies.ORIENTATIONS[pa["orientation"]])
	# Délai de prise en charge selon la gravité.
	var attente := (p.installe_jeu if p.installe_jeu >= 0.0 else heure) - p.arrivee_jeu
	var delai_max: float = {1: 5.0, 2: 20.0, 3: 60.0, 4: 120.0, 5: 240.0}[pa.get("tri", 3)] * 60.0
	if attente > delai_max:
		pts -= 15
		b["details"].append("Prise en charge trop tardive (%d min) : -15" % int(attente / 60.0))
	if p.aggrave:
		pts -= 20
		b["details"].append("Aggravation pendant la prise en charge : -20")
	b["points"] = pts
	score += pts
	reputation = clampf(reputation + pts / 25.0, 0.0, 100.0)
	bilans.append(b)
	# Départ : le patient quitte le service.
	liberer(p)
	var mon := moniteur_de(p)
	if mon:
		mon.brancher(false)
	p.changer_etat("oriente", Pathologies.ORIENTATIONS[o])
	_depart(p, o)
	patients_changes.emit()
	return b


func _depart(p: PatientJeu, o: String) -> void:
	if o == "sortie" and p.dossier.get("mode", "pied") == "pied":
		p.poser_posture("attente")
		p.global_position.y = 0.0
		p.aller(service.points["entree"])
		p.arrive.connect(func(): _retirer(p), CONNECT_ONE_SHOT)
	else:
		# Transfert par l'équipe : le patient disparaît après un court délai (fondu à venir).
		get_tree().create_timer(6.0).timeout.connect(func(): _retirer(p))


func _retirer(p: PatientJeu) -> void:
	patients.erase(p)
	if p.has_meta("brancard"):
		(p.get_meta("brancard") as Node).queue_free()
	p.queue_free()
	patients_changes.emit()
