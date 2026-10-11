extends SceneTree
## Test automatique de la boucle de jeu (sans rendu) : prise en charge complète du patient du
## box 3, arrivée à pied (accueil → tri → salle d'attente), arrivée en ambulance (déchocage),
## résultats d'examens, orientation et score. Toute ligne « SCRIPT ERROR » = échec.

var echecs := 0
var jeu: Node


func _initialize() -> void:
	_executer.call_deferred()


func verifier(cond: bool, msg: String) -> void:
	print("  ok  " if cond else "  ÉCHEC  ", msg)
	if not cond:
		echecs += 1


func attendre_action() -> void:
	var n := 0
	while not jeu._action.is_empty() and n < 3000:
		await process_frame
		n += 1


func attendre(cond: Callable, max_images := 4000) -> bool:
	for i in max_images:
		if cond.call():
			return true
		await physics_frame
	return false


func _executer() -> void:
	jeu = load("res://scenes/jeu.tscn").instantiate()
	root.add_child(jeu)
	for i in 30:
		await process_frame
	var g = jeu.garde
	g.arrivees_actives = false
	var p = jeu.patient
	verifier(p != null and p.personnage.skeleton != null, "patient du box 3 chargé")
	verifier(p.etat == "installe" and p.place == "box_3", "installé en box 3 (%s)" % p.lieu)
	verifier(p.personnage.lecteur.current_animation == "semi_assis", "posture semi-assise")
	# Constantes et examen clinique.
	for gst in ["g_scope", "g_tension", "g_eva", "c_auscultation", "c_aspect"]:
		jeu._action_prefixee(gst)
		await attendre_action()
	verifier(p.constantes.mesures.has("ta") and p.constantes.mesures.has("fc"), "constantes mesurées")
	verifier(p.dossier.get("clinique", {}).has("auscultation"), "auscultation notée au dossier")
	verifier(g.moniteur_de(p).ecran.branche, "scope branché")
	# Examens : demande puis attente du résultat (temps accéléré).
	jeu._action_prefixee("e_ecg")
	verifier(p.examens.has("ecg"), "ECG demandé")
	g.heure += 10.0 * 60.0
	await attendre(func(): return p.examens["ecg"]["resultat"] != "", 200)
	verifier(p.examens["ecg"]["resultat"].contains("Sus-décalage"), "résultat ECG : " + p.examens["ecg"]["resultat"].left(40))
	# Traitements, tri, diagnostic, orientation.
	for t in ["t_aspirine", "t_anticoag", "t_morphine", "t_vvp"]:
		jeu._action_prefixee(t)
		await attendre_action()
	verifier(p.traitements.size() == 4, "4 traitements administrés")
	jeu.patient = p
	jeu._action_prefixee("tri_2")
	jeu._action_prefixee("d_sca_st")
	var score_avant = g.score
	jeu._action_prefixee("o_cardiologie")
	verifier(p.etat == "oriente", "patient orienté (%s)" % p.lieu)
	verifier(g.score > score_avant, "score augmenté : %d" % g.score)
	verifier(not g.occupation.has("box_3"), "box 3 libéré")
	# Arrivée à pied : marche jusqu'à l'accueil.
	var q = g.generer_arrivee("entorse")
	verifier(q.etat == "arrivee", "patient à pied créé à l'entrée")
	var ok = await attendre(func(): return q.etat == "accueil", 3000)
	verifier(ok, "arrivé à l'accueil à pied (%.1f, %.1f)" % [q.global_position.x, q.global_position.z])
	q.tri = 5
	g.envoyer_attente(q)
	ok = await attendre(func(): return not q.en_marche() and q.personnage.lecteur.current_animation.begins_with("assis"), 3000)
	verifier(ok, "assis en salle d'attente (%s)" % q.place)
	# Arrivée en ambulance → déchocage.
	var r = g.generer_arrivee("avc")
	verifier(r.lieu == "Sas ambulances", "arrivée ambulance au sas")
	r.tri = 1
	g.installer(r, "dechoc_1")
	verifier(r.place == "dechoc_1" and r.lieu == "Déchocage 1", "installé au déchocage")
	# Aggravation si non traité.
	g.heure += 90.0 * 60.0
	await attendre(func(): return r.aggrave, 200)
	verifier(r.aggrave, "aggravation de l'AVC non traité")
	print("RÉSULTAT : ", "OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(1 if echecs else 0)
