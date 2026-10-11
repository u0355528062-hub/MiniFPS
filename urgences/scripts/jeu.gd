extends Node3D
## Partie (prototype, étape 1) : un box d'examen, un patient, le joueur soignant.
## Boucle : examiner le patient → brancher le scope, prendre les constantes, l'interroger →
## attribuer un niveau de tri. Le temps de jeu avance (1 s réelle = 10 s de jeu).

const ECHELLE_TEMPS := 10.0

var monde: Node3D
var joueur: Joueur
var hud: Hud
var menu_pause: MenuPause
var patient: PatientJeu
var moniteur: Moniteur
var heure := 8.0 * 3600.0 + 12.0 * 60.0   # 08 h 12
var _action := {}                            # action en cours {id, duree, t, fin}
var _menu_cible: Node = null

const SCENARIO := {
	"modele": "patient_gerard", "posture": "semi_assis",
	"prenom": "Gérard", "nom": "MARTIN", "age": 67, "sexe": "M", "iep": "2410-03187", "arrivee": "07 h 58",
	"motif": "Douleur thoracique depuis 45 minutes",
	"antecedents": "HTA, diabète de type 2, tabagisme (40 paquets-années)",
	"traitement": "Metformine 1000 mg ×2, ramipril 5 mg",
	"allergies": "Aucune connue",
	"constantes": {"fc": 96.0, "tas": 158.0, "tad": 92.0, "spo2": 95.0, "fr": 20.0, "temperature": 36.9,
		"glycemie": 1.62, "eva": 7, "sus_st": 0.22},
	"tri_attendu": 2,
	"reponses": {
		"motif": "J'ai une douleur dans la poitrine… comme un étau. Ça serre fort.",
		"debut": "Ça a commencé il y a trois quarts d'heure, en montant les escaliers. Ça ne passe pas au repos.",
		"irradiation": "Ça descend dans le bras gauche… et un peu dans la mâchoire.",
		"signes": "J'ai transpiré d'un coup, et j'ai un peu la nausée.",
		"antecedents": "J'ai de la tension, du diabète… et je fume, je sais, ce n'est pas bien.",
		"traitement": "De la metformine matin et soir, et un comprimé pour la tension, le ramipril.",
		"allergies": "Non, aucune allergie que je sache.",
		"douleur": "Sur dix ? Je dirais sept. C'est vraiment fort.",
	},
}

const QUESTIONS := [
	["q_motif", "« Qu'est-ce qui vous amène ? »", "motif"],
	["q_debut", "« Depuis quand ? Dans quelles circonstances ? »", "debut"],
	["q_irradiation", "« La douleur va-t-elle ailleurs ? »", "irradiation"],
	["q_signes", "« Avez-vous d'autres symptômes ? »", "signes"],
	["q_antecedents", "« Avez-vous des antécédents médicaux ? »", "antecedents"],
	["q_traitement", "« Prenez-vous des médicaments ? »", "traitement"],
	["q_allergies", "« Êtes-vous allergique à quelque chose ? »", "allergies"],
]

## Gestes de mesure : id -> [libellé, durée (s de jeu), constantes obtenues, message].
const GESTES := {
	"scope": ["Brancher le scope (électrodes, capteur SpO₂)", 40.0, ["fc", "spo2", "fr"], "Scope branché : rythme sinusal."],
	"tension": ["Prendre la pression artérielle (brassard)", 45.0, ["ta"], ""],
	"saturation": ["Poser l'oxymètre de pouls", 15.0, ["spo2", "fc"], ""],
	"temperature": ["Prendre la température (tympanique)", 20.0, ["temperature"], ""],
	"glycemie": ["Glycémie capillaire (bout du doigt)", 60.0, ["glycemie"], ""],
	"fr": ["Compter la fréquence respiratoire (30 s)", 30.0, ["fr"], ""],
	"eva": ["Évaluer la douleur (échelle 0 à 10)", 10.0, ["eva"], ""],
}


func _ready() -> void:
	monde = load("res://scenes/box_examen.tscn").instantiate()
	add_child(monde)
	# Patient sur le brancard.
	patient = PatientJeu.new()
	patient.name = "Patient"
	patient.configurer(SCENARIO.duplicate(true))
	monde.add_child(patient)
	var place: Vector3 = monde.points_interet["place_patient"]
	patient.position = place - Vector3(0, patient.personnage.hauteur_bassin(), 0)
	moniteur = monde.points_interet["moniteur"]
	moniteur.connecter(patient.constantes)
	# Joueur à l'entrée du box.
	joueur = Joueur.new()
	joueur.name = "Joueur"
	joueur.position = Vector3(2.65, 0.0, 3.2)
	joueur.rotation_degrees.y = 25.0
	add_child(joueur)
	joueur.rayon.collision_mask = 1 | 2
	joueur.cible_changee.connect(_cible_changee)
	joueur.interaction.connect(_interagir)
	hud = Hud.new()
	add_child(hud)
	hud.action_choisie.connect(_action_menu)
	hud.menu_ferme.connect(func(): joueur.controle = true)
	menu_pause = MenuPause.new()
	add_child(menu_pause)
	menu_pause.quitter_demande.connect(func(): get_tree().quit())
	patient.parle.connect(func(t): hud.dire(patient.dossier["prenom"], t))
	patient.constantes.mesure_prise.connect(func(_n, _v): hud.remplir_dossier(patient))
	hud.remplir_dossier(patient)
	hud.notifier("Box 3 : %s — %s. À vous de l'accueillir." % [patient.titre(), SCENARIO["motif"].to_lower()], ThemeHopital.ORANGE, 8.0)


func heure_texte() -> String:
	var s := int(heure) % 86400
	return "%02d h %02d" % [s / 3600, (s / 60) % 60]


func _process(delta: float) -> void:
	heure += delta * ECHELLE_TEMPS
	hud.horloge.text = "Urgences adultes · Box 3 · " + heure_texte()
	if not _action.is_empty():
		_action["t"] += delta * ECHELLE_TEMPS
		var f: float = _action["t"] / _action["duree"]
		hud.progression(_action["libelle"], f)
		if f >= 1.0:
			_finir_action()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dossier"):
		hud.dossier.visible = not hud.dossier.visible
		hud.remplir_dossier(patient)
	elif event.is_action_pressed("pause") and hud.menu.visible:
		hud.fermer_menu()
		get_viewport().set_input_as_handled()


func _cible_changee(c: Node) -> void:
	if c == patient:
		hud.montrer_invite("[E] Examiner %s" % patient.titre())
	elif c is Moniteur:
		hud.montrer_invite("[E] Moniteur")
	else:
		hud.montrer_invite("")


func _interagir(c: Node) -> void:
	if c == patient and _action.is_empty():
		_menu_cible = patient
		joueur.controle = false
		hud.montrer_invite("")
		_menu_principal()


func _menu_principal() -> void:
	var opts := [["questions", "Interroger le patient…"]]
	for id in GESTES:
		opts.append([id, GESTES[id][0]])
	opts.append(["tri", "Attribuer un niveau de tri…"])
	opts.append(["fermer", "Fermer"])
	hud.ouvrir_menu(patient.titre(), opts)


func _action_menu(id: String) -> void:
	if id == "fermer":
		hud.fermer_menu()
	elif id == "questions":
		var opts := []
		for q in QUESTIONS:
			opts.append([q[0], q[1]])
		opts.append(["retour", "← Retour"])
		hud.ouvrir_menu("Interrogatoire", opts)
	elif id == "retour":
		_menu_principal()
	elif id.begins_with("q_"):
		for q in QUESTIONS:
			if q[0] == id:
				hud.dire("Vous", q[1].trim_prefix("« ").trim_suffix(" »"))
				await get_tree().create_timer(1.6).timeout
				patient.repondre(q[2])
				if q[2] in ["antecedents", "traitement", "allergies"]:
					patient.dossier["connu_" + q[2]] = true
					hud.remplir_dossier(patient)
	elif id == "tri":
		var opts := [["", "Échelle FRENCH (Fédération française de médecine d'urgence)"]]
		var noms := {1: "Tri 1 — urgence vitale immédiate", 2: "Tri 2 — urgence vraie, < 20 min",
			3: "Tri 3 — urgence relative, < 60 min", 4: "Tri 4 — sans gravité, < 120 min", 5: "Tri 5 — non urgent"}
		for n in range(1, 6):
			opts.append(["tri_%d" % n, noms[n], ThemeHopital.TRI[n].darkened(0.15 if n != 3 else 0.35)])
		opts.append(["retour", "← Retour"])
		hud.ouvrir_menu("Niveau de tri", opts)
	elif id.begins_with("tri_"):
		_attribuer_tri(int(id.substr(4)))
	elif GESTES.has(id):
		hud.fermer_menu()
		joueur.controle = false
		var g: Array = GESTES[id]
		_action = {"id": id, "libelle": g[0], "duree": g[1], "t": 0.0}


func _finir_action() -> void:
	var id: String = _action["id"]
	var g: Array = GESTES[id]
	hud.progression("", 1.0)
	_action = {}
	joueur.controle = true
	var c := patient.constantes
	var res := []
	for k in g[2]:
		c.mesurer(k, heure_texte())
		res.append("%s : %s" % [Constantes.NOMS[k], Constantes.texte(k, c.mesures[k]["valeur"])])
	if id == "scope":
		moniteur.brancher(true)
	if id == "eva":
		patient.repondre("douleur")
	if g[3] != "":
		hud.notifier(g[3], ThemeHopital.VERT)
	hud.notifier("\n".join(res), ThemeHopital.BLEU, 7.0)


func _attribuer_tri(n: int) -> void:
	hud.fermer_menu()
	patient.tri = n
	hud.remplir_dossier(patient)
	var manquantes := []
	for k in ["fc", "ta", "spo2"]:
		if not patient.constantes.mesures.has(k):
			manquantes.append(Constantes.NOMS[k].to_lower())
	var attendu: int = SCENARIO["tri_attendu"]
	if n == attendu:
		hud.notifier("Tri %d : correct. Douleur thoracique typique chez un patient à risque : ECG 12 dérivations dans les 10 minutes et avis médical immédiat." % n, ThemeHopital.VERT, 10.0)
	elif n < attendu:
		hud.notifier("Tri %d : sur-triage. Le patient est stable mais nécessite une prise en charge rapide (tri %d attendu)." % [n, attendu], ThemeHopital.ORANGE, 10.0)
	else:
		hud.notifier("Tri %d : sous-triage dangereux ! Douleur thoracique typique avec facteurs de risque → tri %d." % [n, attendu], ThemeHopital.ROUGE, 10.0)
	if not manquantes.is_empty():
		hud.notifier("Attention : tri attribué sans " + ", ".join(manquantes) + ".", ThemeHopital.ORANGE, 8.0)


# --- Captures ---------------------------------------------------------------------------------
func poses_capture() -> Array:
	return monde.poses_capture() + [
		{"nom": "jeu_scope", "position": Vector3(2.1, 1.55, 2.2), "cible": Vector3(0.6, 1.4, 0.7), "fov": 60.0, "avant": "brancher_pour_capture"},
	]


func brancher_pour_capture() -> void:
	moniteur.brancher(true)
	hud.remplir_dossier(patient)
	hud.dossier.visible = true
