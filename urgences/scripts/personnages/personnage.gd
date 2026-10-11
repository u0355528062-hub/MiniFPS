class_name Personnage
extends Node3D
## Un humain (patient ou soignant) : modèle MakeHuman généré, matériaux du jeu (peau à
## diffusion sous-cutanée, cheveux, yeux), animations partagées via AnimationPlayer.
## Aucune animation os par os en GDScript : tout passe par l'AnimationPlayer (moteur natif).
## Le clignement des yeux est une « blend shape » pilotée à basse fréquence.

const DOSSIER := "res://assets/personnages/"

## Identifiant du modèle (assets/personnages/modeles/<id>.glb).
@export var modele := "patient_gerard"
@export var animation_initiale := "attente"
@export var vitesse_animation := 1.0

var skeleton: Skeleton3D
var lecteur: AnimationPlayer
var corps: MeshInstance3D
var _prochain_clignement := 2.0
var _clignement := 0.0
var _idx_clignement := -1
var _expressions := {}

static var _bibliotheque: AnimationLibrary
static var _hauteur_bassin_ref := 0.0
static var _materiaux := {}


func _ready() -> void:
	var ps: PackedScene = load(DOSSIER + "modeles/" + modele + ".glb")
	var m: Node3D = ps.instantiate()
	m.name = "Modele"
	add_child(m)
	skeleton = m.get_node("Squelette/Skeleton3D")
	for c in skeleton.get_children():
		if c is MeshInstance3D:
			_preparer_maillage(c)
	_charger_animations()
	lecteur = AnimationPlayer.new()
	lecteur.name = "Animations"
	m.add_child(lecteur)
	lecteur.root_node = NodePath("..")
	lecteur.add_animation_library("", _bibliotheque)
	lecteur.playback_default_blend_time = 0.35
	# Les positions animées du bassin sont à l'échelle de l'humain neutre.
	var racine := skeleton.find_bone("root")
	if racine >= 0 and _hauteur_bassin_ref > 0.0:
		skeleton.motion_scale = skeleton.get_bone_global_rest(racine).origin.y / _hauteur_bassin_ref
	if animation_initiale != "":
		jouer(animation_initiale)
		lecteur.seek(randf() * 2.0, true)
	_prochain_clignement = randf_range(1.0, 4.0)


static func _charger_animations() -> void:
	if _bibliotheque:
		return
	var n: Node = load(DOSSIER + "animations.glb").instantiate()
	var ap: AnimationPlayer = n.get_node("AnimationPlayer")
	_bibliotheque = ap.get_animation_library("").duplicate(true)
	for nom in _bibliotheque.get_animation_list():
		var a := _bibliotheque.get_animation(nom)
		a.loop_mode = Animation.LOOP_NONE if nom in ["ramasser"] else Animation.LOOP_LINEAR
	var sq: Skeleton3D = n.get_node("Squelette/Skeleton3D")
	var r := sq.find_bone("root")
	_hauteur_bassin_ref = sq.get_bone_global_rest(r).origin.y
	n.free()


## Hauteur du bassin (os « root ») au repos, dans le repère du personnage.
func hauteur_bassin() -> float:
	var r := skeleton.find_bone("root")
	return skeleton.get_bone_global_rest(r).origin.y if r >= 0 else 0.95


func jouer(nom: String, fondu := -1.0, vitesse := 1.0) -> void:
	if lecteur and lecteur.has_animation(nom):
		lecteur.play(nom, fondu, vitesse * vitesse_animation)


func _preparer_maillage(mi: MeshInstance3D) -> void:
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		var nom := mesh.surface_get_material(s).resource_name if mesh.surface_get_material(s) else ""
		var mat := materiau(nom)
		if mat:
			mi.set_surface_override_material(s, mat)
	if mi.name == "Corps":
		corps = mi
		_idx_clignement = mi.find_blend_shape_by_name("clignement")
		for e in ["bouche_ouverte", "douleur", "sourire"]:
			_expressions[e] = mi.find_blend_shape_by_name(e)
	# Ombres : les petites pièces (dents, langue, yeux) n'en projettent pas.
	if mi.name in ["Dents", "Langue", "Yeux"]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Matériau partagé selon le nom donné par le générateur (peau_*, tenue_*, cheveux_*, oeil_*…).
static func materiau(nom: String) -> Material:
	if _materiaux.has(nom):
		return _materiaux[nom]
	var t := DOSSIER + "textures/" + nom + "/"
	var m := StandardMaterial3D.new()
	m.resource_name = nom
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if nom.begins_with("peau_") or nom.begins_with("tenue_") or nom.begins_with("cheveux_"):
		var alb := t + ("albedo.png" if ResourceLoader.exists(t + "albedo.png") else "albedo.jpg")
		m.albedo_texture = load(alb)
		m.normal_enabled = true
		m.normal_texture = load(t + "normal.jpg")
		m.roughness_texture = load(t + "orm.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_enabled = true
		m.ao_texture = m.roughness_texture
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		m.ao_light_affect = 0.3
	if nom.begins_with("peau_"):
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.45
		m.subsurf_scatter_skin_mode = true
		m.subsurf_scatter_transmittance_enabled = true
		m.subsurf_scatter_transmittance_color = Color(0.85, 0.35, 0.25)
		m.subsurf_scatter_transmittance_depth = 0.12
		m.subsurf_scatter_transmittance_boost = 0.15
		m.normal_scale = 0.8
		m.rim_enabled = true
		m.rim = 0.12
		m.rim_tint = 0.6
	elif nom.begins_with("cheveux_"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.anisotropy_enabled = true
		m.anisotropy = 0.7
		m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	elif nom.begins_with("tenue_"):
		m.backlight_enabled = false
	elif nom.begins_with("oeil_"):
		# La cornée (disque bleu de la texture, alpha nul) est découpée ; le globe garde
		# un vernis brillant pour le reflet humide.
		m.albedo_texture = load(t + "albedo.png")
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.roughness = 0.15
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.02
	elif nom == "dents":
		m.albedo_color = Color(0.86, 0.83, 0.76)
		m.roughness = 0.3
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.2
	elif nom == "langue":
		m.albedo_color = Color(0.62, 0.28, 0.28)
		m.roughness = 0.35
	else:
		m.albedo_color = Color(0.7, 0.7, 0.7)
	_materiaux[nom] = m
	return m


## Expression faciale (0..1) : « douleur », « sourire », « bouche_ouverte ».
func expression(nom: String, valeur: float) -> void:
	if corps and _expressions.get(nom, -1) >= 0:
		corps.set_blend_shape_value(_expressions[nom], valeur)


func _process(delta: float) -> void:
	# Clignement des yeux (une blend shape, quelques images toutes les 2 à 6 s).
	if corps == null or _idx_clignement < 0:
		return
	_prochain_clignement -= delta
	if _prochain_clignement <= 0.0:
		_clignement += delta / 0.12
		var v := sin(clampf(_clignement, 0.0, 1.0) * PI)
		corps.set_blend_shape_value(_idx_clignement, v)
		if _clignement >= 1.0:
			_clignement = 0.0
			corps.set_blend_shape_value(_idx_clignement, 0.0)
			_prochain_clignement = randf_range(2.0, 6.0)
