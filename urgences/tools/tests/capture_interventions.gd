extends SceneTree
## Série de captures « en situation » : prise en charge en box, examens, arrivée d'ambulance,
## déchocage en arrêt cardiaque, mini-jeux d'intervention, vue de nuit.
## Usage : xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -s res://tools/tests/capture_interventions.gd -- \
##         --sortie /chemin/dossier [--images 14] [--preset ultra] [--taille 1600x900]
## (types non statiques volontairement : les classes du jeu dépendent des autoloads.)

var sortie := "user://captures_interventions"
var images := 14
var preset := "ultra"
var largeur := 1600
var hauteur := 900
var jeu
var cam: Camera3D
var n := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		match args[i]:
			"--sortie": sortie = args[i + 1]; i += 1
			"--images": images = int(args[i + 1]); i += 1
			"--preset": preset = args[i + 1]; i += 1
			"--taille":
				var t: PackedStringArray = args[i + 1].split("x")
				largeur = int(t[0]); hauteur = int(t[1]); i += 1
		i += 1
	_executer.call_deferred()


func _attendre(k: int) -> void:
	for f in k:
		await process_frame


func _vue(position: Vector3, cible: Vector3, fov := 65.0) -> void:
	cam.global_position = position
	cam.look_at(cible, Vector3.UP)
	cam.fov = fov
	cam.make_current()


func _capturer(nom: String, k := -1) -> void:
	await _attendre(images if k < 0 else k)
	n += 1
	var chemin := sortie.path_join("%02d_%s.png" % [n, nom])
	root.get_texture().get_image().save_png(chemin)
	print("CAPTURE ", chemin)


func _collegue(nom: String):
	for co in jeu.garde.collegues:
		if co.nom == nom:
			return co
	return null


## Place un collègue (sans marcher) à `pos`, tourné vers `regard`, animation `anim`.
func _poser_collegue(nom: String, pos: Vector3, regard: Vector3, anim := "parler") -> void:
	var co = _collegue(nom)
	if co == null:
		return
	co.marcheur.arreter()
	co.global_position = Vector3(pos.x, 0, pos.z)
	var d: Vector3 = regard - co.global_position
	co.rotation.y = atan2(d.x, d.z)
	co.personnage.jouer(anim, 0.0)


func _fermer_ui() -> void:
	jeu.hud.fermer_menu()
	jeu.hud.dossier.visible = false
	jeu.hud.resultats.visible = false
	jeu.hud.fermer_tableau()


func _executer() -> void:
	DirAccess.make_dir_recursive_absolute(sortie)
	root.size = Vector2i(largeur, hauteur)
	root.get_node("Reglages").choisir_preset(preset)
	jeu = load("res://scenes/jeu.tscn").instantiate()
	root.add_child(jeu)
	await _attendre(3)
	jeu.garde.arrivees_actives = false
	jeu.joueur.controle = false
	cam = Camera3D.new()
	jeu.add_child(cam)
	var g = jeu.garde
	var p = jeu.patient
	var o := Vector3(7.2, 0, 9)
	var lit: Vector3 = jeu.monde.points["box_3"]["place_patient"]

	# --- 1. Box 3 : M. MARTIN, douleur thoracique ---------------------------------------------
	jeu.hud.dossier.visible = false
	g.moniteur_de(p).brancher(true)
	_poser_collegue("Claire", lit + Vector3(-0.85, 0, 0.15), lit, "parler")
	await _vue(Vector3(10.3, 1.65, 12.8), lit + Vector3(-0.3, 0.2, 0), 66.0)
	await _capturer("box3_prise_en_charge", images + 10)
	await _vue(lit + Vector3(0.75, 0.75, 0.55), lit + Vector3(-0.35, 0.45, -0.1), 45.0)
	await _capturer("patient_visage")
	await _vue(o + Vector3(2.1, 1.55, 2.2), o + Vector3(0.6, 1.4, 0.7), 50.0)
	await _capturer("scope_ecg")
	# Menu d'actions au chevet (vue du joueur).
	await _vue(lit + Vector3(1.1, 1.62, 1.5), lit + Vector3(-0.2, 0.3, 0), 72.0)
	jeu._menu_principal()
	await _capturer("menu_actions")
	jeu._action_menu("examens")
	await _capturer("menu_examens", 4)
	jeu._action_menu("traitements")
	await _capturer("menu_traitements", 4)
	_fermer_ui()
	p.repondre("localisation")
	await _capturer("interrogatoire", 8)

	# --- 2. Résultats d'examens ---------------------------------------------------------------
	for ex in ["ecg", "bio"]:
		g.demander_examen(p, ex)
		p.examens[ex]["pret"] = 0.0
	jeu.hud.remplir_dossier(p)
	jeu.hud.dossier.visible = true
	await _capturer("dossier_patient", 6)
	jeu.hud.dossier.visible = false
	jeu.hud.resultats.montrer(p, "ecg")
	jeu.hud.resultats.visible = true
	await _capturer("ecg_12_derivations", 6)
	jeu.hud.resultats.montrer(p, "bio")
	await _capturer("biologie", 6)
	# Radio : une fracture du poignet installée en box 5.
	var fr = g.ajouter_patient(g.creer_dossier("fracture_poignet"))
	g.installer(fr, "box_5")
	g.demander_examen(fr, "radio")
	fr.examens["radio"]["pret"] = 0.0
	jeu.hud.resultats.montrer(fr, "radio")
	await _capturer("radio_poignet", 6)
	_fermer_ui()

	# --- 3. Collègues au travail --------------------------------------------------------------
	_poser_collegue("Julien", lit + Vector3(0.8, 0, 0.35), lit, "parler")
	_poser_collegue("Inès", lit + Vector3(0.9, 0, -0.6), lit, "attente")
	await _vue(Vector3(10.45, 1.7, 12.7), lit + Vector3(-0.1, 0.3, -0.3), 64.0)
	await _capturer("equipe_au_chevet", images + 6)

	# --- 4. Arrivée d'une ambulance (polytraumatisé) -----------------------------------------
	Engine.time_scale = 0.35
	var a = g.generer_arrivee("polytraumatise")
	var cv = null
	for c in jeu.monde.get_children():
		if c.get_script() and c.get_script().resource_path.ends_with("convoi.gd"):
			cv = c
	if cv:
		await _attendre(2)
		await _vue(Vector3(41.0, 1.5, 36.5), Vector3(62.0, 1.4, 41.5), 55.0)
		var t0 := Time.get_ticks_msec()
		while is_instance_valid(cv) and cv.vehicule.global_position.x > 58.0 and Time.get_ticks_msec() - t0 < 60000:
			await process_frame
		await _capturer("ambulance_approche", 2)
		# Depuis l'intérieur du sas, on voit le véhicule se garer, gyrophares allumés.
		await _vue(Vector3(31.0, 1.7, 25.5), Vector3(32.5, 1.3, 33.0), 66.0)
		while is_instance_valid(cv) and cv.vehicule.global_position.distance_to(Vector3(32, 0, 31.5)) > 1.5 and Time.get_ticks_msec() - t0 < 120000:
			await process_frame
		await _capturer("ambulance_gyrophares", 2)
		while is_instance_valid(cv) and cv.brancard == null and Time.get_ticks_msec() - t0 < 150000:
			await process_frame
		await _attendre(6)
		if is_instance_valid(cv) and cv.brancard:
			await _vue(Vector3(34.5, 1.75, 21.0), cv.brancard.global_position + Vector3(0, 0.7, 0), 64.0)
			await _capturer("brancard_secouristes", 2)
			await _attendre(10)
			if is_instance_valid(cv) and cv.brancard:
				await _vue(cv.brancard.global_position + Vector3(2.2, 1.6, -2.4), cv.brancard.global_position + Vector3(0, 0.7, 0), 60.0)
				await _capturer("brancard_gros_plan", 2)
		t0 = Time.get_ticks_msec()
		while is_instance_valid(a) and a.etat == "arrivee" and Time.get_ticks_msec() - t0 < 120000:
			await process_frame
	Engine.time_scale = 1.0

	# --- 5. Déchocage : arrêt cardiaque ---------------------------------------------------
	var dch = g.ajouter_patient(g.creer_dossier("sca_st", {"posture": "allonge", "age": 58, "sexe": "M"}))
	g.installer(dch, "dechoc_1")
	g.moniteur_de(dch).brancher(true)
	dch.declencher_arret(g.heure)
	var ld: Vector3 = jeu.monde.points["dechoc_1"]["place_patient"]
	_poser_collegue("Claire", ld + Vector3(0.75, 0, 0.3), ld, "parler")
	_poser_collegue("Julien", ld + Vector3(-0.8, 0, 0.5), ld, "parler")
	_poser_collegue("Paul", ld + Vector3(0.4, 0, 1.6), ld, "attente")
	await _vue(ld + Vector3(2.6, 1.8, 3.2), ld + Vector3(0, 0.1, -0.3), 66.0)
	await _capturer("dechocage_arret", images + 8)
	await _vue(Vector3(29.0, 1.7, 12.4), Vector3(24.0, 1.0, 8.0), 72.0)
	await _capturer("dechocage_vue_large")
	var md = g.moniteur_de(dch)
	await _vue(md.global_position + md.global_transform.basis.z * 0.9 + Vector3(0, 0.05, 0), md.global_position, 48.0)
	await _capturer("scope_fibrillation", 8)

	# --- 6. Mini-jeux d'intervention (sur la scène) ----------------------------------------
	await _vue(ld + Vector3(1.0, 1.6, 1.3), ld, 68.0)
	var rcp = load("res://scripts/minijeux/mini_rcp.gd").new()
	jeu._lancer_mini(rcp, func(_ok, _q): pass, {"constantes": dch.constantes})
	for i in 10:
		rcp._compression()
		OS.delay_msec(520)
		await process_frame
	await _capturer("rcp_massage", 6)
	rcp._phase = "charge"
	rcp._charge = 0.55
	rcp._dire("Charge en cours… 200 J")
	await _capturer("defibrillateur_charge", 3)
	rcp._phase = "choc"
	rcp._charge = 0.0
	rcp._dire("Chargé ! Écartez-vous… Appuyez sur S pour CHOQUER.")
	await _capturer("defibrillateur_pret", 3)
	rcp._flash = 0.35
	rcp._dire("Choc délivré ! Reprenez immédiatement le massage.")
	await _capturer("defibrillateur_choc", 1)
	rcp.queue_free()
	await _attendre(2)
	var it = load("res://scripts/minijeux/mini_intubation.gd").new()
	jeu._lancer_mini(it, func(_ok, _q): pass)
	it._preox = 0.6
	await _capturer("intubation_preoxygenation", 4)
	it._preox = 1.0
	it._etape = 2
	await _capturer("intubation_laryngoscopie", 4)
	it.queue_free()
	var su = load("res://scripts/minijeux/mini_suture.gd").new()
	jeu._lancer_mini(su, func(_ok, _q): pass)
	await _attendre(2)
	for k in 3:
		for e in 2:
			var ev := InputEventMouseButton.new()
			ev.pressed = true
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.position = su._cibles[k][e] + Vector2(3, 2)
			su._gui_input(ev)
	await _capturer("suture", 4)
	su.queue_free()
	var ja = load("res://scripts/minijeux/mini_jauge.gd").new()
	jeu._lancer_mini(ja, func(_ok, _q): pass)
	await _capturer("voie_veineuse", 4)
	ja.queue_free()
	await _attendre(2)

	# --- 7. Salle d'attente, tableau des patients, vue 3e personne ---------------------------
	jeu.peupler_pour_capture()
	await _vue(Vector3(12.0, 1.65, 25.0), Vector3(4.0, 0.9, 19.0), 70.0)
	await _capturer("salle_attente", images + 6)
	jeu.hud.ouvrir_tableau(g)
	await _capturer("tableau_patients", 4)
	_fermer_ui()
	jeu.joueur.global_position = Vector3(12.0, 0, 14.5)
	jeu.joueur.rotation.y = deg_to_rad(90.0)
	jeu.joueur.basculer_vue()
	jeu.joueur.camera.make_current()
	await _capturer("troisieme_personne_couloir", images)
	jeu.joueur.basculer_vue()

	# --- 8. Orientation et bilan -------------------------------------------------------------
	p.diagnostic = p.patho["diagnostic"]
	for t in ["aspirine", "anticoag", "morphine", "vvp", "o2"]:
		if not t in p.traitements:
			p.traitements.append(t)
	var b = g.orienter(p, "cardiologie")
	jeu.hud.bilan(b)
	cam.make_current()
	await _vue(Vector3(10.3, 1.65, 12.8), lit + Vector3(-0.3, 0.2, 0), 66.0)
	await _capturer("bilan_patient", 6)
	_fermer_ui()

	# --- 9. La nuit : arrivée des pompiers --------------------------------------------------
	jeu.monde.regler_heure(22.5)
	Engine.time_scale = 0.35
	g.generer_arrivee("intoxication_alcool")
	await _vue(Vector3(20.0, 1.7, 41.0), Vector3(14.0, 2.0, 27.0), 66.0)
	await _capturer("nuit_facade", images + 6)
	await _vue(Vector3(31.0, 1.7, 25.5), Vector3(32.5, 1.3, 33.0), 66.0)
	await _capturer("nuit_vehicule_secours", 40)
	Engine.time_scale = 1.0
	print("CAPTURES TERMINÉES : ", n)
	quit()
