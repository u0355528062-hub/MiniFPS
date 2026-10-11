extends Node3D
## Box d'examen des urgences + un tronçon de couloir (prototype, étape 1).
## Toute la scène est construite par code : coque fusionnée (Batisseur), mobilier (Bibliotheque),
## éclairage (dalles LED, bandeau indirect, lampe d'examen), sonde de reflets et GI voxel.

const H := 2.70          # hauteur sous faux plafond
const LX := 3.6          # largeur du box
const LZ := 4.0          # profondeur du box
const EP := 0.12         # épaisseur des cloisons
const COULOIR := 2.6     # largeur du couloir

var environnement: Environment
var gi: VoxelGI
var sonde: ReflectionProbe
var sonde2: ReflectionProbe
var points_interet := {}  # positions utiles (lit, moniteur…) pour le jeu et les captures


func _ready() -> void:
	_coque()
	_mobilier()
	_eclairage()
	_ambiance()
	Reglages.change.connect(_reglages_changes)
	_reglages_changes()


# ---------------------------------------------------------------------------------------------
func _coque() -> void:
	var b := Batisseur.new()
	# Sols : vinyle vert d'eau dans le box, bleu dans le couloir.
	b.boite(AABB(Vector3(0, -0.1, 0), Vector3(LX, 0.1, LZ)), {"+y": "sol_vinyle_vert"})
	b.boite(AABB(Vector3(-4, -0.1, LZ), Vector3(LX + 8, 0.1, COULOIR)), {"+y": "sol_vinyle_bleu"})
	# Plafonds en dalles 60 x 60.
	b.boite(AABB(Vector3(0, H, 0), Vector3(LX, 0.05, LZ)), {"-y": "plafond"}, false)
	b.boite(AABB(Vector3(-4, H, LZ), Vector3(LX + 8, 0.05, COULOIR)), {"-y": "plafond"}, false)
	# Cloisons du box.
	b.mur(Vector3(0, 0, 0), LX, "x", H, EP, "mur_vert_eau", "mur_blanc")              # fond (tête de lit)
	b.mur(Vector3(0, 0, 0), LZ, "z", H, EP, "mur_blanc", "mur_blanc")                 # gauche
	b.mur(Vector3(LX, 0, 0), LZ, "z", H, EP, "mur_blanc", "mur_blanc")                # droite
	# Façade sur couloir : baie vitrée + porte coulissante (ouverture 1,40 m).
	b.mur(Vector3(0, 0, LZ), LX, "x", H, EP, "mur_blanc", "mur_blanc",
		[{"debut": 0.35, "fin": 1.65, "bas": 0.95, "haut": 2.15}, {"debut": 1.95, "fin": 3.35, "haut": 2.15}])
	# Mur d'en face dans le couloir (avec deux portes d'autres box) et extrémités.
	b.mur(Vector3(-4, 0, LZ + COULOIR), LX + 8, "x", H, EP, "mur_blanc", "mur_jaune",
		[{"debut": 1.2, "fin": 2.4, "haut": 2.1}, {"debut": 8.0, "fin": 9.2, "haut": 2.1}])
	b.mur(Vector3(-4, 0, LZ), COULOIR, "z", H, EP, "mur_blanc", "mur_blanc")
	b.mur(Vector3(LX + 4, 0, LZ), COULOIR, "z", H, EP, "mur_blanc", "mur_blanc")
	# Prolongement de la façade des box dans le couloir (box voisins, fermés).
	b.mur(Vector3(-4, 0, LZ), 4.0, "x", H, EP, "mur_blanc", "mur_blanc", [{"debut": 1.0, "fin": 2.4, "haut": 2.1}])
	b.mur(Vector3(LX, 0, LZ), 4.0, "x", H, EP, "mur_blanc", "mur_blanc", [{"debut": 1.6, "fin": 3.0, "haut": 2.1}])
	# Plinthes à remontée (10 cm) et lisses de protection murale (main courante).
	_plinthes(b)
	b.finir(self, "Coque")
	points_interet["lit"] = Vector3(1.5, 0.75, 1.4)


func _plinthes(b: Batisseur) -> void:
	var e := 0.012
	# Box : périmètre intérieur.
	b.boite(AABB(Vector3(EP * 0.5, 0, EP * 0.5), Vector3(LX - EP, 0.10, e)), {"+z": "protection_murale", "+y": "protection_murale"}, false)
	b.boite(AABB(Vector3(EP * 0.5, 0, EP * 0.5), Vector3(e, 0.10, LZ - EP)), {"+x": "protection_murale", "+y": "protection_murale"}, false)
	b.boite(AABB(Vector3(LX - EP * 0.5 - e, 0, EP * 0.5), Vector3(e, 0.10, LZ - EP)), {"-x": "protection_murale", "+y": "protection_murale"}, false)
	# Lisses de protection (couloir, des deux côtés) : profil 2 x 14 cm à 0,9 m.
	for z in [LZ + EP * 0.5, LZ + COULOIR - EP * 0.5 - 0.03]:
		var face := "+z" if z < LZ + 1.0 else "-z"
		b.boite(AABB(Vector3(-3.9, 0.88, z), Vector3(LX + 7.8, 0.14, 0.03)),
			{face: "protection_murale", "+y": "protection_murale", "-y": "protection_murale"}, false)


# ---------------------------------------------------------------------------------------------
const SOLIDES := ["brancard", "chariot_soins", "lavabo", "chaise", "tabouret", "poubelle_dasri",
	"poubelle_menagere", "pied_perfusion", "lampe_examen"]


func _poser(nom: String, pos: Vector3, rot_y_deg := 0.0, parent: Node3D = self) -> Node3D:
	var n := Bibliotheque.meuble(nom)
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	parent.add_child(n)
	if nom in SOLIDES:
		Bibliotheque.ajouter_collision(n)
	return n


func _mobilier() -> void:
	var m := Node3D.new()
	m.name = "Mobilier"
	add_child(m)
	# Brancard : tête vers le mur du fond (axe X du modèle tourné vers -Z).
	_poser("brancard", Vector3(1.55, 0, 1.40), 90.0, m)
	_poser("bandeau_tete_lit", Vector3(1.55, 1.45, EP * 0.5 + 0.045), 0.0, m)
	var mon := Moniteur.new()
	mon.name = "Moniteur"
	mon.position = Vector3(0.45, 1.72, EP * 0.5 + 0.53)
	mon.rotation_degrees.y = 20.0
	m.add_child(mon)
	points_interet["moniteur"] = mon
	_poser("pied_perfusion", Vector3(2.55, 0, 0.95), -30.0, m)
	_poser("tensiometre_mural", Vector3(2.75, 1.45, EP * 0.5 + 0.0), 0.0, m)
	# Mur gauche : lave-mains, distributeur de gants, poubelles, chariot de soins.
	_poser("lavabo", Vector3(EP * 0.5, 0, 3.05), 90.0, m)
	_poser("distributeur_gants", Vector3(EP * 0.5, 1.45, 2.05), 90.0, m)
	_poser("chariot_soins", Vector3(0.45, 0, 2.05), 90.0, m)
	_poser("poubelle_dasri", Vector3(0.30, 0, 3.65), 60.0, m)
	_poser("poubelle_menagere", Vector3(0.75, 0, 3.72), 20.0, m)
	# Mur droit : armoire vitrée, poste informatique, chaise visiteur.
	_poser("armoire_murale", Vector3(LX - EP * 0.5 - 0.2, 1.75, 2.2), -90.0, m)
	_poser("ordinateur_mural", Vector3(LX - EP * 0.5 - 0.31, 1.35, 3.3), -90.0, m)
	_poser("chaise", Vector3(3.05, 0, 1.0), -110.0, m)
	_poser("tabouret", Vector3(2.3, 0, 2.6), 0.0, m)
	# Lampe d'examen : orientée pour que sa tête (décalée de 0,32 / 0,37 m) vise le thorax.
	var pied_lampe := Vector3(0.75, 0, 2.85)
	var vise := Vector3(1.55, 0, 1.55) - pied_lampe
	var tete_locale := Vector3(0.32, 0, 0.37)
	var lacet := rad_to_deg(tete_locale.signed_angle_to(vise, Vector3.UP))
	_poser("lampe_examen", pied_lampe, lacet, m)
	points_interet["lampe"] = pied_lampe + Vector3(0.32, 1.32, 0.37).rotated(Vector3.UP, deg_to_rad(lacet))
	_poser("horloge", Vector3(LX * 0.5 + 0.3, 2.25, LZ - EP * 0.5), 180.0, m)
	# Rail et rideau d'intimité (côté porte), rideau à moitié tiré.
	_poser("rail_rideau", Vector3(1.8, H - 0.04, 3.55), 0.0, m)
	var rid := _poser("rideau", Vector3(1.85, H - 0.06, 3.55), 0.0, m)
	rid.scale = Vector3(0.75, 1.0, 1.0)
	points_interet["place_patient"] = Vector3(1.55, 0.80, 1.27)
	# Couloir : chaise et brancard en attente, poubelle.
	_poser("brancard", Vector3(-1.6, 0, LZ + COULOIR - 0.55), 0.0, m)
	_poser("chaise", Vector3(5.2, 0, LZ + COULOIR - 0.4), 180.0, m)
	_poser("chaise", Vector3(5.75, 0, LZ + COULOIR - 0.4), 180.0, m)
	_poser("pied_perfusion", Vector3(4.6, 0, LZ + 0.5), 0.0, m)
	_poser("lavabo", Vector3(7.2, 0, LZ + COULOIR - EP * 0.5), 180.0, m)
	# Porte coulissante vitrée du box (entrouverte) et portes des box voisins (fermées).
	_porte_vitree(m, 1.95, 0.55)
	_porte_vitree(m, -3.0, 0.0)
	_porte_vitree(m, LX + 1.6, 0.0)
	# Portes battantes en face (réserve, bureau médical).
	_poser("porte_120", Vector3(-2.2, 0, LZ + COULOIR), 0.0, m)
	_poser("porte_120", Vector3(4.6, 0, LZ + COULOIR), 0.0, m)


## Porte coulissante vitrée de box : ouverture de 1,40 m commençant en x0, vantail décalé de « ouvert ».
func _porte_vitree(parent: Node3D, x0: float, ouvert: float) -> void:
	var verre := Bibliotheque.materiau("verre")
	var alu := Bibliotheque.materiau("aluminium")
	var porte := Node3D.new()
	porte.name = "PorteVitree"
	porte.position = Vector3(x0 + ouvert, 0, LZ + 0.11)
	parent.add_child(porte)
	_bloc(porte, Vector3(0.7, 1.05, 0), Vector3(1.40, 2.10, 0.012), verre)
	for x in [0.0, 1.40]:
		_bloc(porte, Vector3(x, 1.05, 0), Vector3(0.04, 2.10, 0.04), alu)
	_bloc(porte, Vector3(0.7, 2.11, 0), Vector3(1.44, 0.04, 0.04), alu)
	_bloc(porte, Vector3(0.7, 0.02, 0), Vector3(1.44, 0.04, 0.04), alu)
	_bloc(porte, Vector3(0.06, 1.05, 0.03), Vector3(0.025, 0.6, 0.025), alu)  # poignée
	# Bande de vitrophanie dépolie à hauteur d'yeux.
	_bloc(porte, Vector3(0.7, 1.45, 0.008), Vector3(1.36, 0.25, 0.002), Bibliotheque.materiau("verre_depoli"))
	# Rail haut (caisson aluminium) au-dessus de l'ouverture, côté couloir.
	_bloc(parent, Vector3(x0 + 0.7, 2.22, LZ + 0.11), Vector3(2.9, 0.12, 0.06), alu)
	if x0 > 0.0 and x0 < LX:
		# Vitrage fixe de la baie du box joué (allège 0,95 m).
		_bloc(parent, Vector3(1.0, 1.55, LZ), Vector3(1.30, 1.20, 0.012), verre)
		_bloc(parent, Vector3(1.0, 0.96, LZ), Vector3(1.32, 0.03, 0.14), alu)
	else:
		# Box voisin : rideau tiré derrière la vitre (on ne voit pas l'intérieur vide).
		var r := Bibliotheque.meuble("rideau")
		r.position = Vector3(x0 - 0.05, 2.15, LZ - 0.25)
		r.scale = Vector3(0.75, 1.0, 1.0)
		parent.add_child(r)


func _bloc(parent: Node3D, centre: Vector3, taille: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	bm.material = mat
	mi.mesh = bm
	mi.position = centre
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------------------------------
func _eclairage() -> void:
	var l := Node3D.new()
	l.name = "Eclairage"
	add_child(l)
	# Dalles LED du box (2 au-dessus du brancard, 1 côté porte) et du couloir.
	var dalles := [Vector3(1.5, H, 1.2), Vector3(1.5, H, 2.4), Vector3(2.7, H, 3.3)]
	for p in dalles:
		_dalle_led(l, p, 1.3, true)
	for x in [-2.7, -0.3, 2.1, 4.5, 6.9]:
		_dalle_led(l, Vector3(x, H, LZ + COULOIR * 0.5), 1.1, x > -1 and x < 5)
	# Éclairage indirect du bandeau de tête de lit (lumière chaude vers le plafond).
	var ind := OmniLight3D.new()
	ind.position = Vector3(1.55, 1.75, 0.25)
	ind.light_color = Color(1.0, 0.86, 0.68)
	ind.light_energy = 0.35
	ind.omni_range = 2.5
	ind.omni_attenuation = 1.5
	l.add_child(ind)
	# Lampe d'examen braquée sur le thorax du patient.
	var spot := SpotLight3D.new()
	spot.position = points_interet["lampe"] - Vector3(0, 0.03, 0)
	l.add_child(spot)
	spot.look_at(Vector3(1.55, 0.85, 1.45))
	spot.light_color = Color(1.0, 0.97, 0.92)
	spot.light_energy = 3.0
	spot.spot_range = 3.0
	spot.spot_angle = 22.0
	spot.spot_angle_attenuation = 1.6
	spot.shadow_enabled = true
	spot.light_size = 0.12
	spot.light_specular = 0.6


func _dalle_led(parent: Node3D, p: Vector3, energie: float, ombre: bool) -> void:
	var d := Bibliotheque.meuble("plafonnier_led")
	d.position = p - Vector3(0, 0.001, 0)
	parent.add_child(d)
	var s := SpotLight3D.new()
	s.position = p - Vector3(0, 0.03, 0)
	s.rotation_degrees.x = -90.0
	s.light_color = Color(1.0, 0.97, 0.93)
	s.light_energy = energie
	s.spot_range = 5.0
	s.spot_angle = 75.0
	s.spot_angle_attenuation = 0.9
	s.spot_attenuation = 0.8
	s.shadow_enabled = ombre
	s.light_size = 0.45
	s.shadow_blur = 1.2
	s.light_specular = 0.45
	parent.add_child(s)


# ---------------------------------------------------------------------------------------------
func _ambiance() -> void:
	environnement = Environment.new()
	var e := environnement
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.6)
	e.ambient_light_energy = 0.08
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 0.9
	e.ssao_intensity = 1.8
	e.ssao_power = 1.4
	e.ssao_detail = 0.6
	e.ssao_light_affect = 0.15
	e.ssil_enabled = true
	e.ssil_radius = 4.0
	e.ssil_intensity = 0.9
	e.ssr_enabled = true
	e.ssr_max_steps = 96
	e.ssr_fade_in = 0.12
	e.ssr_fade_out = 2.5
	e.ssr_depth_tolerance = 0.25
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 0.9
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.2
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.set_glow_level(0, 0.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.8)
	e.set_glow_level(4, 0.5)
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.006
	e.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	e.volumetric_fog_anisotropy = 0.5
	e.volumetric_fog_length = 24.0
	e.volumetric_fog_ambient_inject = 0.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = e
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = false
	we.camera_attributes = attr
	add_child(we)
	# Sonde de reflets du box (projection en boîte = reflets du sol bien placés).
	sonde = ReflectionProbe.new()
	sonde.position = Vector3(LX * 0.5, H * 0.5, LZ * 0.5)
	sonde.size = Vector3(LX, H, LZ)
	sonde.origin_offset = Vector3(0, 0.2, 0)
	sonde.box_projection = true
	sonde.interior = true
	sonde.enable_shadows = true
	sonde.update_mode = ReflectionProbe.UPDATE_ONCE
	sonde.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(sonde)
	sonde2 = ReflectionProbe.new()
	sonde2.position = Vector3(LX * 0.5, H * 0.5, LZ + COULOIR * 0.5)
	sonde2.size = Vector3(LX + 8, H, COULOIR)
	sonde2.box_projection = true
	sonde2.interior = true
	sonde2.update_mode = ReflectionProbe.UPDATE_ONCE
	sonde2.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	add_child(sonde2)
	# Illumination globale voxel (cuite au chargement).
	gi = VoxelGI.new()
	gi.position = Vector3(LX * 0.5, H * 0.5, (LZ + COULOIR) * 0.5)
	gi.size = Vector3(LX + 8.4, H + 0.3, LZ + COULOIR + 0.4)
	gi.subdiv = VoxelGI.SUBDIV_128
	add_child(gi)


func cuire_gi() -> void:
	if gi == null:
		return
	if gi.data == null:
		gi.bake()
		if gi.data:
			gi.data.energy = 1.2
			gi.data.propagation = 0.75
			gi.data.normal_bias = 0.6
			gi.data.use_two_bounces = true
	# Les sondes de reflets se recalculent une fois la GI prête (sinon l'inox reflète du noir).
	for i in 3:
		await get_tree().process_frame
	rafraichir_sondes()


func rafraichir_sondes() -> void:
	for s in [sonde, sonde2]:
		if s:
			s.position += Vector3(0.0, 0.0001, 0.0)
			await get_tree().process_frame
			s.position -= Vector3(0.0, 0.0001, 0.0)


func _reglages_changes() -> void:
	Reglages.appliquer_environnement(environnement)
	if gi:
		gi.visible = Reglages.gi_voxel()
		if gi.visible:
			cuire_gi.call_deferred()


# --- Captures ---------------------------------------------------------------------------------
func poses_capture() -> Array:
	return [
		{"nom": "box_porte", "position": Vector3(3.0, 1.65, 3.75), "cible": Vector3(1.2, 0.9, 0.8), "fov": 72.0},
		{"nom": "box_lit", "position": Vector3(2.9, 1.5, 2.6), "cible": Vector3(1.4, 0.9, 1.0), "fov": 60.0},
		{"nom": "box_mur_gauche", "position": Vector3(2.6, 1.6, 1.4), "cible": Vector3(0.2, 1.1, 2.7), "fov": 70.0},
		{"nom": "couloir", "position": Vector3(-3.2, 1.65, LZ + 1.2), "cible": Vector3(4.0, 1.2, LZ + 1.5), "fov": 70.0},
		{"nom": "moniteur", "position": Vector3(1.0, 1.6, 1.3), "cible": Vector3(0.45, 1.7, 0.6), "fov": 50.0},
		{"nom": "patient", "position": Vector3(2.3, 1.45, 2.3), "cible": Vector3(1.55, 0.95, 1.2), "fov": 50.0},
		{"nom": "patient_visage", "position": Vector3(1.95, 1.35, 1.75), "cible": Vector3(1.55, 1.15, 1.05), "fov": 35.0},
	]
