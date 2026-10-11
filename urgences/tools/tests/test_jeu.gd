extends SceneTree
## Test automatique de la boucle de jeu (sans rendu) : charge la partie, joue les gestes,
## vérifie les mesures et le tri. Toute ligne « SCRIPT ERROR » dans la sortie = échec.

var echecs := 0


func _initialize() -> void:
	_executer.call_deferred()


func verifier(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		print("  ÉCHEC  ", msg)
		echecs += 1


func _executer() -> void:
	var jeu: Node = load("res://scenes/jeu.tscn").instantiate()
	root.add_child(jeu)
	for i in 30:
		await process_frame
	verifier(jeu.patient != null and jeu.patient.personnage.skeleton != null, "patient chargé avec squelette")
	verifier(jeu.patient.personnage.lecteur.is_playing(), "animation du patient en cours : " + jeu.patient.personnage.lecteur.current_animation)
	for g in ["scope", "tension", "temperature", "glycemie", "eva"]:
		jeu._action_menu(g)
		var n := 0
		while not jeu._action.is_empty() and n < 2000:
			await process_frame
			n += 1
	var m: Dictionary = jeu.patient.constantes.mesures
	for k in ["fc", "spo2", "fr", "ta", "temperature", "glycemie", "eva"]:
		verifier(m.has(k), "mesure %s = %s" % [k, str(m.get(k, {}).get("valeur", "?"))])
	verifier(jeu.moniteur.ecran.branche, "scope branché")
	jeu._action_menu("q_antecedents")
	await create_timer(2.0).timeout
	verifier(jeu.patient.dossier.has("connu_antecedents"), "antécédents connus après interrogatoire")
	jeu._attribuer_tri(2)
	verifier(jeu.patient.tri == 2, "tri attribué")
	print("RÉSULTAT : ", "OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs)
	quit(1 if echecs else 0)
