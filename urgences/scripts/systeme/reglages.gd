extends Node
## Réglages graphiques et de jeu (autoload « Reglages »).
## Quatre préréglages (Bas, Moyen, Élevé, Ultra) + options détaillées, sauvegardés dans
## user://reglages.cfg. Les effets d'environnement (SSAO, SSR…) sont appliqués par les
## scènes via appliquer_environnement() ; le reste est appliqué directement au viewport
## et au RenderingServer.

signal change

const FICHIER := "user://reglages.cfg"

const PRESETS := {
	"bas": {
		"echelle": 0.67, "mise_echelle": "fsr1", "anticrenelage": "fxaa",
		"ombres": 0, "ssao": false, "ssil": false, "ssr": false, "gi": "aucune",
		"brouillard": false, "bloom": true, "profondeur_champ": false, "sss": false,
		"reflets": 0, "detail_lod": 4.0, "distance_vue": 0.6,
	},
	"moyen": {
		"echelle": 0.77, "mise_echelle": "fsr2", "anticrenelage": "taa",
		"ombres": 1, "ssao": true, "ssil": false, "ssr": false, "gi": "voxelgi",
		"brouillard": false, "bloom": true, "profondeur_champ": false, "sss": true,
		"reflets": 1, "detail_lod": 2.0, "distance_vue": 0.8,
	},
	"eleve": {
		"echelle": 0.87, "mise_echelle": "fsr2", "anticrenelage": "taa",
		"ombres": 2, "ssao": true, "ssil": true, "ssr": true, "gi": "voxelgi",
		"brouillard": true, "bloom": true, "profondeur_champ": true, "sss": true,
		"reflets": 2, "detail_lod": 1.0, "distance_vue": 1.0,
	},
	"ultra": {
		"echelle": 1.0, "mise_echelle": "fsr2", "anticrenelage": "taa",
		"ombres": 3, "ssao": true, "ssil": true, "ssr": true, "gi": "voxelgi",
		"brouillard": true, "bloom": true, "profondeur_champ": true, "sss": true,
		"reflets": 3, "detail_lod": 1.0, "distance_vue": 1.0,
	},
}

const NOMS_PRESETS := {"bas": "Bas", "moyen": "Moyen", "eleve": "Élevé", "ultra": "Ultra"}

var preset := "ultra"
var graphismes := {}
## Réglages de jeu (indépendants des graphismes).
var jeu := {
	"sensibilite": 0.0025, "fov": 75.0, "vsync": true, "fps_max": 0,
	"volume_general": 0.9, "volume_ambiance": 0.7, "volume_voix": 1.0,
	"troisieme_personne": false, "afficher_fps": false,
}


func _ready() -> void:
	graphismes = PRESETS["ultra"].duplicate()
	charger()
	appliquer()


func choisir_preset(nom: String) -> void:
	if not PRESETS.has(nom):
		return
	preset = nom
	graphismes = PRESETS[nom].duplicate()
	appliquer()
	sauver()


func regler(cle: String, valeur) -> void:
	if graphismes.has(cle):
		graphismes[cle] = valeur
		preset = "perso"
	elif jeu.has(cle):
		jeu[cle] = valeur
	appliquer()
	sauver()


## Applique tout ce qui ne dépend pas d'une scène particulière.
func appliquer() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var g := graphismes
	# Mise à l'échelle et anticrénelage.
	vp.scaling_3d_scale = clampf(float(g["echelle"]), 0.5, 1.0)
	match String(g["mise_echelle"]):
		"fsr2":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		"fsr1":
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		_:
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	var fsr2 := vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2
	vp.use_taa = String(g["anticrenelage"]) == "taa" and not fsr2
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if String(g["anticrenelage"]) == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	match String(g["anticrenelage"]):
		"msaa2":
			vp.msaa_3d = Viewport.MSAA_2X
		"msaa4":
			vp.msaa_3d = Viewport.MSAA_4X
		_:
			vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.mesh_lod_threshold = float(g["detail_lod"])
	# Ombres : taille d'atlas et filtrage.
	var q := int(g["ombres"])
	var tailles := [1024, 2048, 4096, 4096]
	var filtres := [
		RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	]
	RenderingServer.directional_shadow_atlas_set_size(tailles[q], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(filtres[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(filtres[q])
	vp.positional_shadow_atlas_size = [2048, 4096, 8192, 8192][q]
	# Qualité des effets d'écran.
	RenderingServer.environment_set_ssao_quality(
		RenderingServer.ENV_SSAO_QUALITY_HIGH if q >= 2 else RenderingServer.ENV_SSAO_QUALITY_MEDIUM,
		q < 3, 0.5, 2, 50, 300)
	RenderingServer.environment_set_ssil_quality(
		RenderingServer.ENV_SSIL_QUALITY_HIGH if q >= 3 else RenderingServer.ENV_SSIL_QUALITY_MEDIUM,
		true, 0.5, 4, 50, 300)
	RenderingServer.environment_set_ssr_roughness_quality(
		RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH if q >= 3 else RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW)
	RenderingServer.sub_surface_scattering_set_quality(
		RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_HIGH if g["sss"] else RenderingServer.SUB_SURFACE_SCATTERING_QUALITY_DISABLED)
	RenderingServer.voxel_gi_set_quality(
		RenderingServer.VOXEL_GI_QUALITY_HIGH if q >= 3 else RenderingServer.VOXEL_GI_QUALITY_LOW)
	RenderingServer.environment_set_volumetric_fog_volume_size(96 if q >= 3 else 64, 96 if q >= 3 else 64)
	# Jeu.
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if jeu["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(jeu["fps_max"])
	_appliquer_volumes()
	change.emit()


## Active ou coupe les effets d'un Environment selon les réglages.
## Les valeurs artistiques (intensités, couleurs) restent celles de la scène.
func appliquer_environnement(env: Environment) -> void:
	if env == null:
		return
	var g := graphismes
	env.ssao_enabled = g["ssao"]
	env.ssil_enabled = g["ssil"]
	env.ssr_enabled = g["ssr"]
	env.volumetric_fog_enabled = g["brouillard"]
	env.glow_enabled = g["bloom"]
	env.sdfgi_enabled = String(g["gi"]) == "sdfgi"


## Vrai si les sondes de GI voxel doivent être visibles.
func gi_voxel() -> bool:
	return String(graphismes["gi"]) == "voxelgi"


## Nombre de sondes de reflets en mise à jour « toujours » autorisées (0 = statiques seulement).
func niveau_reflets() -> int:
	return int(graphismes["reflets"])


func _appliquer_volumes() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(jeu["volume_general"]), 0.0001)))


func sauver() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphismes", "preset", preset)
	for k in graphismes:
		cfg.set_value("graphismes", k, graphismes[k])
	for k in jeu:
		cfg.set_value("jeu", k, jeu[k])
	cfg.save(FICHIER)


func charger() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return
	preset = cfg.get_value("graphismes", "preset", "ultra")
	if PRESETS.has(preset):
		graphismes = PRESETS[preset].duplicate()
	for k in graphismes.keys():
		graphismes[k] = cfg.get_value("graphismes", k, graphismes[k])
	for k in jeu.keys():
		jeu[k] = cfg.get_value("jeu", k, jeu[k])
