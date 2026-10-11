extends Node3D
## Partie : le service des urgences complet, une garde avec des arrivées de patients.
## Boucle : accueil et tri (IOA) → installation en box / déchocage ou salle d'attente →
## interrogatoire, examen clinique, constantes, examens complémentaires → traitements →
## diagnostic → orientation (domicile, hospitalisation, bloc, réanimation…). Score et réputation.

var monde: Service
var garde: Garde
var joueur: Joueur
var hud: Hud
var menu_pause: MenuPause
var patient: PatientJeu            # patient du menu ouvert
var _action := {}                  # geste en cours {id, libelle, duree, t, patient}
var _t_ciel := 0.0

const QUESTIONS := [
	["q_motif", "« Qu'est-ce qui vous amène ? »", "motif"],
	["q_debut", "« Depuis quand ? Dans quelles circonstances ? »", "debut"],
	["q_localisation", "« Où avez-vous mal ? Ça va ailleurs ? »", "localisation"],
	["q_signes", "« Avez-vous d'autres symptômes ? »", "signes"],
	["q_antecedents", "« Avez-vous des antécédents médicaux ? »", "antecedents"],
	["q_traitement", "« Prenez-vous des médicaments ? »", "traitement"],
	["q_allergies", "« Êtes-vous allergique à quelque chose ? »", "allergies"],
]

## Gestes de mesure : id -> [libellé, durée (s de jeu), constantes obtenues].
const GESTES := {
	"scope": ["Brancher le scope (ECG, SpO₂, respiration)", 40.0, ["fc", "spo2", "fr"]],
	"tension": ["Pression artérielle (brassard)", 45.0, ["ta"]],
	"saturation": ["Oxymètre de pouls", 15.0, ["spo2", "fc"]],
	"temperature": ["Température (tympanique)", 20.0, ["temperature"]],
	"glycemie": ["Glycémie capillaire", 60.0, ["glycemie"]],
	"fr": ["Fréquence respiratoire (compter 30 s)", 30.0, ["fr"]],
	"eva": ["Douleur (échelle EVA 0 à 10)", 10.0, ["eva"]],
}

## Examen clinique : id -> [libellé, durée].
const CLINIQUE := {
	"aspect": ["Observer le patient (aspect général)", 15.0],
	"auscultation": ["Ausculter (stéthoscope)", 45.0],
	"palpation": ["Palper (abdomen, zone douloureuse)", 40.0],
	"pupilles": ["Examen neurologique et pupilles (lampe)", 40.0],
}


func _ready() -> void:
	monde = load("res://scenes/service.tscn").instantiate()
	add_child(monde)
	garde = Garde.new()
	garde.name = "Garde"
	garde.service = monde
	add_child(garde)
	# Premier patient déjà installé en box 3 : douleur thoracique (le scénario du prototype).
	var d := garde.creer_dossier("sca_st", {"prenom": "Gérard", "nom": "MARTIN", "age": 67, "sexe": "M",
		"modele": "patient_gerard", "posture": "semi_assis", "arrivee": "07 h 58"})
	patient = garde.ajouter_patient(d)
	garde.installer(patient, "box_3")
	patient.arrivee_jeu = garde.heure - 14.0 * 60.0
	var box: Dictionary = monde.points["box_3"]
	joueur = Joueur.new()
	joueur.name = "Joueur"
	joueur.position = box["entree"] + Vector3(0.0, 0.0, 0.6)
	joueur.rotation_degrees.y = 15.0
	add_child(joueur)
	joueur.rayon.collision_mask = 1 | 2
	joueur.cible_changee.connect(_cible_changee)
	joueur.interaction.connect(_interagir)
	hud = Hud.new()
	add_child(hud)
	hud.action_choisie.connect(_action_menu)
	hud.menu_ferme.connect(func(): joueur.controle = true)
	hud.tableau_ferme.connect(func(): joueur.controle = true)
	menu_pause = MenuPause.new()
	add_child(menu_pause)
	menu_pause.quitter_demande.connect(func(): get_tree().quit())
	garde.notification.connect(func(t, c, du): hud.notifier(t, c, du))
	garde.patients_changes.connect(_rafraichir_hud)
	for p in garde.patients:
		_brancher_patient(p)
	garde.patients_changes.connect(func():
		for p in garde.patients:
			if not p.has_meta("branche"):
				_brancher_patient(p))
	hud.remplir_dossier(patient)
	hud.notifier("Prise de garde à 08 h 12. Box 3 : %s — douleur thoracique. Tab : tableau des patients." % patient.titre(),
		ThemeHopital.ORANGE, 9.0)


func _brancher_patient(p: PatientJeu) -> void:
	p.set_meta("branche", true)
	p.parle.connect(func(t): hud.dire(p.dossier["prenom"], t))
	p.constantes.mesure_prise.connect(func(_n, _v): _rafraichir_hud())


func _rafraichir_hud() -> void:
	if hud.dossier.visible and is_instance_valid(patient):
		hud.remplir_dossier(patient)
	if hud.tableau.visible:
		hud.remplir_tableau(garde)


func _process(delta: float) -> void:
	hud.horloge.text = "Urgences adultes · %s · Score %d · Réputation %d %%" % [garde.heure_texte(), garde.score, int(garde.reputation)]
	_t_ciel += delta
	if _t_ciel > 2.0:
		_t_ciel = 0.0
		monde.regler_heure(garde.heure / 3600.0)
	if not _action.is_empty():
		_action["t"] += delta * Garde.ECHELLE_TEMPS
		var f: float = _action["t"] / _action["duree"]
		hud.progression(_action["libelle"], f)
		if f >= 1.0:
			_finir_action()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dossier"):
		if hud.tableau.visible:
			hud.fermer_tableau()
		elif not hud.menu.visible:
			joueur.controle = false
			hud.ouvrir_tableau(garde)
	elif event.is_action_pressed("pause") and (hud.menu.visible or hud.tableau.visible):
		hud.fermer_menu()
		hud.fermer_tableau()
		get_viewport().set_input_as_handled()


func _cible_changee(c: Node) -> void:
	if c is PatientJeu:
		var p: PatientJeu = c
		var tri := "" if p.tri == 0 else "  [tri %d]" % p.tri
		hud.montrer_invite("[E] %s — %s%s" % [p.titre(), p.lieu, tri])
	else:
		hud.montrer_invite("")


func _interagir(c: Node) -> void:
	if c is PatientJeu and _action.is_empty() and (c as PatientJeu).etat != "oriente":
		patient = c
		joueur.controle = false
		hud.montrer_invite("")
		_menu_principal()


# --- Menus ------------------------------------------------------------------------------------
func _menu_principal() -> void:
	var p := patient
	if p.decede:
		hud.ouvrir_menu("%s — décédé(e)" % p.titre(), [["", "Le patient est décédé."], ["fermer", "Fermer"]])
		return
	if p.arret:
		hud.ouvrir_menu("ARRÊT CARDIAQUE — %s" % p.titre(), [["rcp", "Réanimation cardio-pulmonaire (RCP + défibrillateur)", ThemeHopital.ROUGE],
			["fermer", "Fermer"]])
		return
	var opts := [["questions", "Interroger le patient…"], ["mesures", "Constantes…"]]
	if p.etat == "installe":
		opts.append(["clinique", "Examen clinique…"])
		opts.append(["examens", "Examens complémentaires…"])
		opts.append(["traitements", "Traitements…"])
		opts.append(["diagnostic", "Poser le diagnostic…"])
		opts.append(["orientation", "Orienter le patient…"])
	opts.append(["tri", "Niveau de tri (IOA)…" if p.tri == 0 else "Niveau de tri : %d (modifier)…" % p.tri])
	if p.etat in ["accueil", "attente"]:
		opts.append(["installer", "Installer en box / déchocage…"])
		if p.etat == "accueil" and p.dossier.get("mode") == "pied":
			opts.append(["attente", "Envoyer en salle d'attente"])
	opts.append(["dossier", "Ouvrir le dossier"])
	opts.append(["fermer", "Fermer"])
	hud.ouvrir_menu("%s — %s" % [p.titre(), p.lieu], opts)


func _action_menu(id: String) -> void:
	var p := patient
	if not is_instance_valid(p):
		hud.fermer_menu()
		return
	match id:
		"fermer":
			hud.fermer_menu()
		"retour":
			_menu_principal()
		"dossier":
			hud.fermer_menu()
			hud.remplir_dossier(p)
			hud.dossier.visible = true
		"questions":
			var opts := []
			for q in QUESTIONS:
				opts.append([q[0], q[1]])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Interrogatoire — " + p.civilite(), opts)
		"mesures":
			var opts := []
			for g in GESTES:
				if g == "scope" and p.etat != "installe":
					continue
				opts.append(["g_" + g, GESTES[g][0]])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Constantes — " + p.civilite(), opts)
		"clinique":
			var opts := []
			for k in CLINIQUE:
				opts.append(["c_" + k, CLINIQUE[k][0]])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Examen clinique — " + p.civilite(), opts)
		"examens":
			var opts := [["", "Les résultats arrivent après un délai (voir le dossier)."]]
			for ex in Pathologies.EXAMENS:
				var etat := ""
				if p.examens.has(ex):
					etat = "  ✓ résultat" if p.examens[ex]["resultat"] != "" else "  ⏳ en cours"
				opts.append(["e_" + ex, Pathologies.EXAMENS[ex][0] + etat])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Examens — " + p.civilite(), opts)
		"traitements":
			var opts := []
			for t in Pathologies.TRAITEMENTS:
				opts.append(["t_" + t, Pathologies.TRAITEMENTS[t] + ("  ✓" if t in p.traitements else "")])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Prescription — " + p.civilite(), opts)
		"diagnostic":
			var opts := []
			for dg in Pathologies.diagnostics():
				opts.append(["d_" + dg[0], dg[1] + ("  ✓" if p.diagnostic == dg[0] else "")])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Diagnostic — " + p.civilite(), opts)
		"orientation":
			var opts := [["", "Fin de la prise en charge aux urgences."]]
			for o in Pathologies.ORIENTATIONS:
				opts.append(["o_" + o, Pathologies.ORIENTATIONS[o]])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Orientation — " + p.civilite(), opts)
		"tri":
			var opts := [["", "Échelle FRENCH (SFMU)"]]
			var noms := {1: "Tri 1 — détresse vitale, immédiat", 2: "Tri 2 — urgence vraie, < 20 min",
				3: "Tri 3 — urgence relative, < 60 min", 4: "Tri 4 — sans gravité, < 120 min", 5: "Tri 5 — non urgent"}
			for n in range(1, 6):
				opts.append(["tri_%d" % n, noms[n], ThemeHopital.TRI[n].darkened(0.15 if n != 3 else 0.35)])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Niveau de tri — " + p.civilite(), opts)
		"installer":
			var opts := []
			for b in garde.box_libres():
				opts.append(["i_" + b, Garde.nom_place(b)])
			if opts.is_empty():
				opts.append(["", "Aucun box libre : orientez des patients pour libérer de la place."])
			opts.append(["retour", "← Retour"])
			hud.ouvrir_menu("Installer — " + p.civilite(), opts)
		"rcp":
			hud.fermer_menu()
			_lancer_mini(MiniRCP.new(), func(ok, q):
				p.traitements.append("rcp")
				p.qualite_gestes.append(q)
				if ok:
					p.arret = false
					p.poser_posture("semi_assis")
					hud.notifier("RACS : %s a retrouvé un pouls. Orientez-le en réanimation." % p.civilite(), ThemeHopital.VERT, 10.0)
				else:
					p.deceder()
					garde.score -= 60
					hud.notifier("Décès de %s malgré la réanimation." % p.civilite(), ThemeHopital.ROUGE, 10.0)
				garde.patients_changes.emit(), {"constantes": p.constantes})
		"attente":
			hud.fermer_menu()
			if p.tri == 0:
				hud.notifier("Attribuez d'abord un niveau de tri.", ThemeHopital.ORANGE)
				return
			garde.envoyer_attente(p)
		_:
			_action_prefixee(id)


func _action_prefixee(id: String) -> void:
	var p := patient
	if id.begins_with("q_"):
		for q in QUESTIONS:
			if q[0] == id:
				hud.dire("Vous", q[1].trim_prefix("« ").trim_suffix(" »"))
				await get_tree().create_timer(1.4).timeout
				p.repondre(q[2])
				if q[2] in ["antecedents", "traitement", "allergies"]:
					p.dossier[q[2]] = p.reponses.get(q[2], "")
				_rafraichir_hud()
	elif id.begins_with("g_"):
		var g: Array = GESTES[id.substr(2)]
		_commencer_action(id, g[0], g[1])
	elif id.begins_with("c_"):
		var c: Array = CLINIQUE[id.substr(2)]
		_commencer_action(id, c[0], c[1])
	elif id.begins_with("e_"):
		var ex := id.substr(2)
		garde.demander_examen(p, ex)
		hud.notifier("%s demandé pour %s." % [Pathologies.EXAMENS[ex][0], p.civilite()], ThemeHopital.BLEU, 4.0)
		_action_menu("examens")
	elif id.begins_with("t_"):
		var t := id.substr(2)
		if t in p.traitements:
			return
		# Gestes techniques : mini-jeux.
		var mini: Control = null
		match t:
			"suture": mini = MiniSuture.new()
			"vvp": mini = MiniJauge.new()
			"intubation": mini = MiniIntubation.new()
		if mini:
			hud.fermer_menu()
			_lancer_mini(mini, func(ok, q):
				p.qualite_gestes.append(q)
				if ok:
					p.traitements.append(t)
					_effet_traitement(p, t)
					hud.notifier("%s : %s — réussi (qualité %d %%)." % [p.civilite(), Pathologies.TRAITEMENTS[t], int(q * 100)], ThemeHopital.VERT, 6.0)
				else:
					hud.notifier("%s : geste échoué, un collègue s'en charge." % p.civilite(), ThemeHopital.ORANGE, 6.0)
					p.traitements.append(t)
				_rafraichir_hud())
			return
		_commencer_action(id, Pathologies.TRAITEMENTS[t], 120.0)
	elif id.begins_with("d_"):
		p.diagnostic = id.substr(2)
		hud.notifier("Diagnostic retenu : " + Pathologies.par_id(p.diagnostic)["diagnostic"], ThemeHopital.BLEU, 5.0)
		_menu_principal()
	elif id.begins_with("o_"):
		hud.fermer_menu()
		if p.diagnostic == "":
			hud.notifier("Posez d'abord un diagnostic.", ThemeHopital.ORANGE)
			return
		var b := garde.orienter(p, id.substr(2))
		hud.bilan(b)
	elif id.begins_with("tri_"):
		p.tri = int(id.substr(4))
		hud.notifier("%s : tri %d attribué." % [p.civilite(), p.tri], ThemeHopital.TRI[p.tri].darkened(0.2), 4.0)
		_rafraichir_hud()
		_menu_principal()
	elif id.begins_with("i_"):
		hud.fermer_menu()
		if p.tri == 0:
			hud.notifier("Attribuez d'abord un niveau de tri.", ThemeHopital.ORANGE)
			return
		var place := id.substr(2)
		garde.installer(p, place)
		hud.notifier("%s installé(e) en %s." % [p.civilite(), Garde.nom_place(place)], ThemeHopital.VERT, 5.0)


## Lance un mini-jeu plein écran ; le jeu continue derrière (le temps passe !).
func _lancer_mini(mini: Control, fin: Callable, proprietes := {}) -> void:
	for k in proprietes:
		mini.set(k, proprietes[k])
	joueur.controle = false
	hud.racine.add_child(mini)
	mini.termine.connect(func(ok, q):
		joueur.controle = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		fin.call(ok, q))


func _commencer_action(id: String, libelle: String, duree: float) -> void:
	hud.fermer_menu()
	joueur.controle = false
	_action = {"id": id, "libelle": libelle, "duree": duree, "t": 0.0, "patient": patient}


func _finir_action() -> void:
	var id: String = _action["id"]
	var p: PatientJeu = _action["patient"]
	hud.progression("", 1.0)
	_action = {}
	joueur.controle = true
	if not is_instance_valid(p):
		return
	if id.begins_with("g_"):
		var g := id.substr(2)
		var res := []
		for k in GESTES[g][2]:
			p.constantes.mesurer(k, garde.heure_texte())
			res.append("%s : %s" % [Constantes.NOMS[k], Constantes.texte(k, p.constantes.mesures[k]["valeur"])])
		if g == "scope":
			var m := garde.moniteur_de(p)
			if m:
				m.brancher(true)
		if g == "eva":
			p.dire_eva()
		hud.notifier(p.civilite() + "\n" + "\n".join(res), ThemeHopital.BLEU, 7.0)
	elif id.begins_with("c_"):
		var k := id.substr(2)
		var txt: String = p.patho.get("clinique", {}).get(k, "Normal.")
		if not p.dossier.has("clinique"):
			p.dossier["clinique"] = {}
		p.dossier["clinique"][k] = txt
		hud.notifier("%s — %s :\n%s" % [p.civilite(), CLINIQUE[k][0], txt], ThemeHopital.BLEU, 9.0)
	elif id.begins_with("t_"):
		var t := id.substr(2)
		p.traitements.append(t)
		_effet_traitement(p, t)
		hud.notifier("%s : %s — fait." % [p.civilite(), Pathologies.TRAITEMENTS[t]], ThemeHopital.VERT, 5.0)
	_rafraichir_hud()


## Effets simples des traitements sur les constantes (le détail viendra à l'étape 3).
func _effet_traitement(p: PatientJeu, t: String) -> void:
	var c := p.constantes
	match t:
		"morphine", "paracetamol", "ains":
			c.eva = maxi(c.eva - (4 if t == "morphine" else 2), 0)
		"o2":
			c.cibles["spo2"] = minf(c.cibles.get("spo2", 95.0) + 5.0, 99.0)
		"aerosol":
			c.cibles["spo2"] = minf(c.cibles.get("spo2", 95.0) + 4.0, 98.0)
			c.cibles["fr"] = maxf(c.cibles.get("fr", 16.0) - 8.0, 16.0)
		"g30":
			c.cibles["glycemie"] = 1.2
			c.glycemie = 1.1
			c.glasgow = 15
		"remplissage":
			c.cibles["tas"] = c.cibles.get("tas", 100.0) + 20.0
			c.cibles["fc"] = maxf(c.cibles.get("fc", 100.0) - 15.0, 80.0)


# --- Captures ---------------------------------------------------------------------------------
func poses_capture() -> Array:
	var o := Vector3(7.2, 0, 9)
	return [
		{"nom": "jeu_attente", "position": Vector3(12.0, 1.65, 25.0), "cible": Vector3(4.0, 0.9, 19.0), "fov": 70.0, "avant": "peupler_pour_capture"},
		{"nom": "jeu_attente_proche", "position": Vector3(6.5, 1.5, 23.0), "cible": Vector3(3.0, 0.8, 20.5), "fov": 55.0},
		{"nom": "jeu_dechocage", "position": Vector3(29.0, 1.7, 12.0), "cible": Vector3(24.0, 1.0, 8.0), "fov": 70.0},
		{"nom": "jeu_scope", "position": o + Vector3(2.1, 1.55, 2.2), "cible": o + Vector3(0.6, 1.4, 0.7), "fov": 60.0, "avant": "brancher_pour_capture"},
		{"nom": "jeu_tableau", "position": Vector3(12.0, 1.65, 14.5), "cible": Vector3(4.0, 1.4, 14.5), "fov": 70.0, "avant": "tableau_pour_capture"},
	]


func peupler_pour_capture() -> void:
	garde.arrivees_actives = false
	for i in 7:
		var d := garde.creer_dossier()
		d["posture"] = "assis"
		d["mode"] = "pied"
		var p := garde.ajouter_patient(d)
		garde.asseoir_direct(p)
	var a := garde.generer_arrivee("avc")
	a.tri = 1
	garde.installer(a, "dechoc_1")
	(garde.moniteur_de(a) as Moniteur).brancher(true)


func tableau_pour_capture() -> void:
	hud.dossier.visible = false
	hud.ouvrir_tableau(garde)


func brancher_pour_capture() -> void:
	var m := garde.moniteur_de(patient)
	if m:
		m.brancher(true)
	hud.remplir_dossier(patient)
	hud.dossier.visible = true
