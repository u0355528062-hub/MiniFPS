extends SceneTree
## Génère la bibliothèque de matériaux PBR (assets/materials/*.tres).
## Usage : godot --headless --path . -s res://tools/gen_materiaux.gd
## Les modèles exportés par Blender portent des matériaux NOMMÉS ; scripts/monde/bibliotheque.gd
## remplace chaque matériau par le .tres du même nom.

const TEX := "res://assets/textures/"
const SORTIE := "res://assets/materials/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SORTIE)
	# --- Métaux -----------------------------------------------------------------------------
	_tex("inox", "inox_brosse", Color(1, 1, 1), 1.0, Vector3(1, 1, 1), {"metal": 1.0})
	_simple("inox_poli", Color(0.86, 0.87, 0.88), 0.12, 1.0)
	_simple("chrome", Color(0.92, 0.92, 0.93), 0.05, 1.0)
	_simple("aluminium", Color(0.84, 0.85, 0.86), 0.32, 1.0)
	_tex("aluminium_laque", "plastique_grain", Color(0.90, 0.91, 0.91), 0.0, Vector3(6, 6, 6), {"rug": 0.85})
	_tex("metal_peint_blanc", "plastique_grain", Color(0.92, 0.92, 0.91), 0.0, Vector3(6, 6, 6), {"rug": 0.75})
	_tex("metal_peint_gris", "plastique_grain", Color(0.42, 0.44, 0.46), 0.0, Vector3(6, 6, 6), {"rug": 0.8})
	# --- Plastiques (grain fin, 12 cm par motif) -----------------------------------------------
	var plastiques := {
		"plastique_blanc": Color(0.93, 0.93, 0.92), "plastique_gris_clair": Color(0.80, 0.81, 0.82),
		"plastique_gris": Color(0.58, 0.60, 0.62), "plastique_gris_fonce": Color(0.20, 0.21, 0.22),
		"plastique_noir": Color(0.05, 0.05, 0.055), "plastique_bleu": Color(0.13, 0.42, 0.72),
		"plastique_bleu_nuit": Color(0.10, 0.17, 0.30), "plastique_vert": Color(0.18, 0.62, 0.35),
		"plastique_jaune": Color(0.98, 0.78, 0.05), "plastique_rouge": Color(0.78, 0.10, 0.08),
		"plastique_orange": Color(0.95, 0.45, 0.08),
	}
	for nom in plastiques:
		_tex(nom, "plastique_grain", plastiques[nom], 0.0, Vector3(8, 8, 8))
	_simple("caoutchouc_noir", Color(0.04, 0.04, 0.04), 0.8)
	_simple("caoutchouc_gris", Color(0.25, 0.26, 0.27), 0.8)
	_simple("cable_gris", Color(0.55, 0.57, 0.58), 0.45)
	_simple("cable_bleu", Color(0.15, 0.35, 0.65), 0.45)
	_simple("sac_noir", Color(0.03, 0.03, 0.035), 0.35)
	_simple("brassard", Color(0.10, 0.22, 0.45), 0.75)
	# --- Similicuir et textiles ----------------------------------------------------------------
	_tex("skai_bleu", "skai", Color(0.16, 0.30, 0.52), 0.0, Vector3(4, 4, 4))
	_tex("skai_noir", "skai", Color(0.09, 0.09, 0.10), 0.0, Vector3(4, 4, 4))
	_tex("skai_vert", "skai", Color(0.20, 0.42, 0.38), 0.0, Vector3(4, 4, 4))
	var drap := _tex("tissu_drap", "tissu_serge", Color(0.93, 0.94, 0.95), 0.0, Vector3(6, 6, 6))
	_tex("tissu_oreiller", "tissu_serge", Color(0.95, 0.95, 0.96), 0.0, Vector3(8, 8, 8))
	var rideau := _tex("rideau", "tissu_rideau", Color(1, 1, 1), 0.0, Vector3(0.8, 0.8, 0.8))
	rideau.cull_mode = BaseMaterial3D.CULL_DISABLED
	rideau.backlight_enabled = true
	rideau.backlight = Color(0.35, 0.42, 0.42)
	_sauver(rideau, "rideau")
	var filet := StandardMaterial3D.new()
	filet.albedo_texture = load(TEX + "details/filet.png")
	filet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	filet.alpha_scissor_threshold = 0.5
	filet.cull_mode = BaseMaterial3D.CULL_DISABLED
	filet.uv1_scale = Vector3(4, 4, 4)
	filet.roughness = 0.9
	_sauver(filet, "filet_rideau")
	# --- Papier, cartons, étiquettes -----------------------------------------------------------
	_simple("papier", Color(0.95, 0.95, 0.94), 0.9)
	_simple("carton_bleu", Color(0.25, 0.45, 0.78), 0.75)
	_simple("carton_violet", Color(0.45, 0.30, 0.62), 0.75)
	_simple("carton_vert", Color(0.30, 0.62, 0.40), 0.75)
	_simple("carton_blanc", Color(0.90, 0.90, 0.88), 0.8)
	_simple("gants_bleus", Color(0.45, 0.62, 0.92), 0.55)
	_image("etiquette", "details/etiquette.png", 0.7)
	_image("logo_biorisque", "details/logo_dasri.png", 0.5)
	_image("cadran", "details/cadran.png", 0.3)
	_image("cadran_horloge", "details/horloge.png", 0.4)
	_image("panneau_extincteur", "signaletique/panneau_extincteur.png", 0.5)
	_simple("rouge_extincteur", Color(0.72, 0.05, 0.04), 0.25)
	# --- Étape 2 : accueil, déchocage, imagerie, véhicules ---------------------------------------
	_tex("plan_solide", "plastique_grain", Color(0.95, 0.95, 0.94), 0.0, Vector3(4, 4, 4), {"rug": 0.3})
	_tex("metal_peint_rouge", "plastique_grain", Color(0.70, 0.07, 0.06), 0.0, Vector3(6, 6, 6), {"rug": 0.45})
	_simple("blanc_o2", Color(0.92, 0.92, 0.92), 0.3)
	_tex("plastique_vert_clair", "plastique_grain", Color(0.55, 0.85, 0.60), 0.0, Vector3(8, 8, 8))
	_transparent("tubulure_bleue", Color(0.55, 0.75, 1.0, 0.75), 0.2)
	_simple("platre", Color(0.95, 0.94, 0.90), 0.95)
	_simple("carbone", Color(0.08, 0.08, 0.09), 0.35)
	_emissif("led_bleue", Color(0.3, 0.6, 1.0), 3.0)
	_transparent("verre_teinte", Color(0.12, 0.15, 0.18, 0.75), 0.05)
	_simple("carrosserie_blanche", Color(0.93, 0.93, 0.92), 0.22)
	_simple("carrosserie_rouge", Color(0.70, 0.04, 0.04), 0.22)
	_simple("bande_samu", Color(0.95, 0.45, 0.05), 0.3)
	_simple("bande_pompiers", Color(0.95, 0.95, 0.95), 0.3)
	_image("texte_samu", "signaletique/texte_samu.png", 0.3)
	_image("texte_pompiers", "signaletique/texte_pompiers.png", 0.3)
	_emissif("phare", Color(1.0, 0.98, 0.9), 1.5)
	_emissif("gyrophare", Color(0.15, 0.35, 1.0), 4.0)
	var vit := StandardMaterial3D.new()
	vit.albedo_texture = load(TEX + "signaletique/vitrine_distributeur.png")
	vit.emission_enabled = true
	vit.emission_texture = vit.albedo_texture
	vit.emission_energy_multiplier = 0.8
	vit.roughness = 0.1
	_sauver(vit, "vitrine_distributeur")
	var fr := StandardMaterial3D.new()
	fr.albedo_texture = load(TEX + "signaletique/fronton_distributeur.png")
	fr.emission_enabled = true
	fr.emission_texture = fr.albedo_texture
	fr.emission_energy_multiplier = 1.2
	_sauver(fr, "fronton_distributeur")
	var info := StandardMaterial3D.new()
	info.albedo_color = Color.BLACK
	info.emission_enabled = true
	info.emission_texture = load(TEX + "signaletique/ecran_info.png")
	info.emission_energy_multiplier = 1.3
	info.roughness = 0.15
	_sauver(info, "ecran_info")
	# --- Transparents --------------------------------------------------------------------------
	_transparent("poche_perf", Color(0.93, 0.96, 1.0, 0.28), 0.12)
	_transparent("plastique_transparent", Color(0.92, 0.95, 0.97, 0.30), 0.10)
	_transparent("liquide", Color(0.82, 0.90, 1.0, 0.35), 0.02)
	_transparent("eau", Color(0.75, 0.88, 0.95, 0.40), 0.02)
	_transparent("tubulure", Color(0.95, 0.97, 1.0, 0.55), 0.15)
	_transparent("verre", Color(0.85, 0.92, 0.92, 0.12), 0.03)
	_transparent("verre_depoli", Color(0.90, 0.94, 0.95, 0.55), 0.45)
	# --- Lumineux ------------------------------------------------------------------------------
	_emissif("led_panel", Color(1.0, 0.98, 0.95), 4.0)
	_emissif("led_indirect", Color(1.0, 0.92, 0.80), 3.0)
	_emissif("led_lampe", Color(1.0, 0.98, 0.94), 12.0)
	_emissif("led_alarme", Color(0.2, 0.9, 0.3), 2.0)
	_emissif("ecran_moniteur", Color(0.02, 0.03, 0.04), 1.0)
	_emissif("ecran_pc", Color(0.75, 0.80, 0.88), 1.2)
	# --- Revêtements du bâtiment (UV en mètres) ------------------------------------------------
	_tex("sol_vinyle_gris", "sol_vinyle_gris", Color(1, 1, 1), 0.0, Vector3(0.5, 0.5, 0.5))
	_tex("sol_vinyle_bleu", "sol_vinyle_bleu", Color(1, 1, 1), 0.0, Vector3(0.5, 0.5, 0.5))
	_tex("sol_vinyle_vert", "sol_vinyle_vert", Color(1, 1, 1), 0.0, Vector3(0.5, 0.5, 0.5))
	_tex("mur_blanc", "peinture_mur", Color(0.93, 0.92, 0.89), 0.0, Vector3(0.7, 0.7, 0.7))
	_tex("mur_vert_eau", "peinture_mur", Color(0.70, 0.84, 0.80), 0.0, Vector3(0.7, 0.7, 0.7))
	_tex("mur_bleu", "peinture_mur", Color(0.62, 0.76, 0.86), 0.0, Vector3(0.7, 0.7, 0.7))
	_tex("mur_jaune", "peinture_mur", Color(0.95, 0.86, 0.62), 0.0, Vector3(0.7, 0.7, 0.7))
	_tex("facade", "peinture_mur", Color(0.84, 0.82, 0.78), 0.0, Vector3(0.5, 0.5, 0.5), {"rug": 0.9})
	_tex("plafond", "dalle_plafond", Color(1, 1, 1), 0.0, Vector3(1.0 / 0.6, 1.0 / 0.6, 1.0 / 0.6))
	_tex("protection_murale", "plastique_grain", Color(0.82, 0.84, 0.84), 0.0, Vector3(5, 5, 5), {"rug": 0.7})
	_tex("bois_porte", "bois_stratifie", Color(1, 1, 1), 0.0, Vector3(0.8, 0.8, 0.8))
	_tex("carrelage_blanc", "carrelage_blanc", Color(1, 1, 1), 0.0, Vector3(0.5, 0.5, 0.5))
	_tex("caoutchouc_sol", "caoutchouc_sol", Color(1, 1, 1), 0.0, Vector3(2, 2, 2))
	_tex("beton", "beton", Color(1, 1, 1), 0.0, Vector3(0.3, 0.3, 0.3))
	print("materiaux generes")
	quit()


func _tex(nom: String, tex: String, teinte: Color, _metal: float, echelle: Vector3, opts := {}) -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.resource_name = nom
	m.albedo_color = teinte
	m.albedo_texture = load(TEX + tex + "/albedo.jpg")
	m.normal_enabled = true
	m.normal_texture = load(TEX + tex + "/normal.png")
	m.orm_texture = load(TEX + tex + "/orm.jpg")
	m.uv1_scale = echelle
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if opts.has("metal"):
		m.metallic = opts["metal"]
	if opts.has("rug"):
		m.roughness = opts["rug"]
	_sauver(m, nom)
	return m


func _simple(nom: String, c: Color, rug: float, metal := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.albedo_color = c
	m.roughness = rug
	m.metallic = metal
	m.metallic_specular = 0.5
	_sauver(m, nom)


func _image(nom: String, chemin: String, rug: float) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.albedo_texture = load(TEX + chemin)
	m.roughness = rug
	_sauver(m, nom)


func _transparent(nom: String, c: Color, rug: float) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.albedo_color = c
	m.roughness = rug
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS if c.a > 0.5 else BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.metallic_specular = 0.7
	_sauver(m, nom)


func _emissif(nom: String, c: Color, energie: float) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energie
	m.roughness = 0.4
	_sauver(m, nom)


func _sauver(m: Material, nom: String) -> void:
	m.resource_name = nom
	var err := ResourceSaver.save(m, SORTIE + nom + ".tres")
	if err != OK:
		push_error("échec sauvegarde " + nom)
