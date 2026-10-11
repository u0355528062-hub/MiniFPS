class_name Service
extends Node3D
## Le service des urgences complet (étape 2) : coque générée depuis le Plan, aménagement de
## chaque salle, éclairage, extérieur (parvis, parking, véhicules), ciel et soleil (cycle jour/nuit
## visible par les vitrages), illumination globale par zones, une sonde de reflets par salle.
## Le mobilier de chaque salle est fusionné en un seul maillage par salle (culling par salle).

const ZONES_GI := [
	AABB(Vector3(-0.2, -0.1, 8.8), Vector3(22.0, 2.9, 7.4)),
	AABB(Vector3(21.4, -0.1, 5.8), Vector3(18.8, 3.2, 10.4)),
	AABB(Vector3(-0.2, -0.1, 15.8), Vector3(20.4, 3.4, 10.4)),
	AABB(Vector3(19.8, -0.1, 15.8), Vector3(20.4, 4.2, 12.4)),
]

var plan: Plan
var environnement: Environment
var soleil: DirectionalLight3D
var ciel: ProceduralSkyMaterial
var points := {}
var moniteurs: Array[Moniteur] = []
var sondes: Array[ReflectionProbe] = []
var gis: Array[VoxelGI] = []
var heure := 9.0
var _lumieres_ext: Array[Light3D] = []
var nav: NavigationRegion3D
const VERSION_NAV := 3   # à incrémenter quand le plan ou le mobilier change


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	plan = Plan.new()
	var b := Batisseur.new()
	plan.construire(b)
	var coque := b.finir(self, "Coque")
	(coque.get_node("Geometrie") as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	var t1 := Time.get_ticks_msec()
	_amenager()
	var t2 := Time.get_ticks_msec()
	_exterieur()
	_ambiance()
	_sondes()
	var t3 := Time.get_ticks_msec()
	_navigation()
	print("navigation : %d ms" % (Time.get_ticks_msec() - t3))
	print("service : coque %d ms, aménagement+fusion %d ms, total %d ms" % [t1 - t0, t2 - t1, Time.get_ticks_msec() - t0])
	Reglages.change.connect(_reglages_changes)
	_reglages_changes()
	regler_heure(heure)


func _salle(nom: String) -> Node3D:
	var n := Node3D.new()
	n.name = nom
	add_child(n)
	return n


func _amenager() -> void:
	var dyn := _salle("Dynamique")
	dyn.add_to_group("dynamique")
	var lum := _salle("Eclairage")
	var am := Amenagement.new(null, dyn, lum)
	var salles := {}
	for p in Plan.PIECES:
		var n := _salle("Salle_" + p["id"])
		salles[p["id"]] = n
		am.mobilier = n
		var r: Rect2 = p["r"]
		var org := Vector3(r.position.x, 0, r.position.y)
		match p["id"]:
			"couloir": am.couloir(org, r.size.x, r.size.y)
			"dechocage": moniteurs.append_array(am.dechocage(org, r.size))
			"platre": am.platre(org)
			"radiologie": am.radiologie(org, r.size)
			"hall": am.hall(org, r.size)
			"poste": am.poste_soins(org)
			"tri": am.tri(org)
			"bureau": am.bureau(org)
			"scanner": am.scanner(org, r.size)
			"pupitre": am.pupitre(org)
			"sas": am.sas(org, r.size)
			"reserve": am.reserve(org)
			_:
				if p["id"].begins_with("box_"):
					var num := int(p["id"].substr(4))
					moniteurs.append(am.box(org, num, 0.55 if num == 3 else 0.0))
	points = am.points
	# Géométrie statique fusionnée : un maillage par salle (et un pour tous les luminaires).
	for id in salles:
		Fusion.fusionner(salles[id], "Fusion")
	Fusion.fusionner(lum, "Luminaires")


func _exterieur() -> void:
	var ext := _salle("Exterieur")
	var b := Batisseur.new()
	# Parvis et voirie autour du bâtiment (sans recouvrir les sols intérieurs).
	b.boite(AABB(Vector3(-40, -0.12, 28.2), Vector3(120, 0.1, 50)), {"+y": "beton"}, true)
	b.boite(AABB(Vector3(-40, -0.12, -30), Vector3(39.0, 0.1, 58.2)), {"+y": "beton"}, true)
	b.boite(AABB(Vector3(40.2, -0.12, -30), Vector3(40, 0.1, 58.2)), {"+y": "beton"}, true)
	b.boite(AABB(Vector3(-1, -0.12, -30), Vector3(41.2, 0.1, 35.8)), {"+y": "beton"}, true)
	b.boite(AABB(Vector3(-1, -0.12, 26.0), Vector3(28.0, 0.1, 2.2)), {"+y": "beton"}, true)
	b.boite(AABB(Vector3(37, -0.12, 26.0), Vector3(3.2, 0.1, 2.2)), {"+y": "beton"}, true)
	# Auvent devant l'entrée et bordures de trottoir.
	b.boite(AABB(Vector3(4.0, 3.0, 26.0), Vector3(6.0, 0.2, 3.0)), "beton", false)
	b.boite(AABB(Vector3(-1, -0.02, 29.5), Vector3(28.0, 0.14, 0.3)), "beton", true)
	b.finir(ext, "Sol")
	var v := Bibliotheque.meuble("vsav_pompiers")
	v.position = Vector3(31.5, 0, 33.0)
	v.rotation_degrees.y = 90.0
	ext.add_child(v)
	Bibliotheque.ajouter_collision(v)
	# Lampadaires du parvis (allumés la nuit).
	for x in [2.0, 14.0, 26.0, 38.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(x, 5.5, 31.0)
		l.light_color = Color(1.0, 0.85, 0.6)
		l.omni_range = 14.0
		l.light_energy = 0.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		ext.add_child(l)
		_lumieres_ext.append(l)


func _ambiance() -> void:
	environnement = Environment.new()
	var e := environnement
	ciel = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = ciel
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	# Ambiance neutre faible (intérieur comme extérieur) : la lumière vient des lampes, de la
	# GI voxel et des lumières de rebond. Les sondes de reflets fournissent les reflets.
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.62, 0.65)
	e.ambient_light_energy = 0.12
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 0.9
	e.ssao_intensity = 1.8
	e.ssao_power = 1.4
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
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.005
	e.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	e.volumetric_fog_anisotropy = 0.5
	e.volumetric_fog_length = 32.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.06
	e.adjustment_saturation = 1.04
	var we := WorldEnvironment.new()
	we.environment = e
	we.camera_attributes = CameraAttributesPractical.new()
	add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.name = "Soleil"
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 60.0
	soleil.light_bake_mode = Light3D.BAKE_DYNAMIC
	soleil.light_angular_distance = 0.5
	add_child(soleil)
	for z in ZONES_GI:
		var g := VoxelGI.new()
		g.position = z.get_center()
		g.size = z.size
		g.subdiv = VoxelGI.SUBDIV_256
		add_child(g)
		gis.append(g)


func _sondes() -> void:
	for p in Plan.PIECES:
		var r: Rect2 = p["r"]
		var s := ReflectionProbe.new()
		s.position = Vector3(r.get_center().x, p["h"] * 0.5, r.get_center().y)
		s.size = Vector3(r.size.x, p["h"], r.size.y)
		s.box_projection = true
		s.interior = p["id"] != "sas"
		s.update_mode = ReflectionProbe.UPDATE_ONCE
		# À l'intérieur, l'ambiance du ciel est remplacée par une ambiance neutre très faible.
		s.ambient_mode = ReflectionProbe.AMBIENT_COLOR if s.interior else ReflectionProbe.AMBIENT_ENVIRONMENT
		s.ambient_color = Color(0.5, 0.5, 0.5)
		s.ambient_color_energy = 0.06
		s.max_distance = 30.0
		s.cull_mask = 0xFFFFF
		add_child(s)
		sondes.append(s)


## Maillage de navigation des PNJ, cuit à partir des collisions statiques (murs, mobilier),
## puis mis en cache dans user:// (le calcul n'a lieu qu'au premier lancement).
func _navigation() -> void:
	var carte := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(carte, 0.1)
	NavigationServer3D.map_set_cell_height(carte, 0.05)
	var cache := "user://navigation_v%d.res" % VERSION_NAV
	var nm: NavigationMesh = null
	if ResourceLoader.exists(cache):
		nm = load(cache)
	if nm == null:
		nm = NavigationMesh.new()
		nm.agent_radius = 0.3
		nm.agent_height = 1.7
		nm.agent_max_climb = 0.15
		nm.agent_max_slope = 30.0
		nm.cell_size = 0.1
		nm.cell_height = 0.05
		nm.region_min_size = 4.0
		nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
		nm.filter_baking_aabb = AABB(Vector3(-2, -1, 4), Vector3(44, 5, 32))
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(nm, src, self)
		NavigationServer3D.bake_from_source_geometry_data(nm, src)
		ResourceSaver.save(nm, cache)
	nav = NavigationRegion3D.new()
	nav.name = "Navigation"
	nav.navigation_mesh = nm
	add_child(nav)


## Chemin de navigation entre deux points (liste de points au sol).
func chemin(de: Vector3, a: Vector3) -> PackedVector3Array:
	var carte := get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(carte, de, a, true)


## Heure de la journée (0..24) : course du soleil, couleurs du ciel, lampadaires.
func regler_heure(h: float) -> void:
	heure = fposmod(h, 24.0)
	var jour := clampf((heure - 6.0) / 12.0, 0.0, 1.0)      # 6 h → 18 h
	var elev := sin(jour * PI) * 62.0                      # hauteur du soleil (degrés)
	var nuit := heure < 6.0 or heure > 18.5
	soleil.rotation_degrees = Vector3(-maxf(elev, 2.0), -30.0 - jour * 140.0, 0.0)
	var chaud := clampf(1.0 - elev / 35.0, 0.0, 1.0)
	soleil.light_color = Color(1.0, 0.96, 0.9).lerp(Color(1.0, 0.62, 0.35), chaud)
	soleil.light_energy = 0.0 if nuit else clampf(elev / 20.0, 0.05, 1.3)
	soleil.visible = not nuit
	ciel.sky_top_color = Color(0.22, 0.42, 0.75).lerp(Color(0.02, 0.03, 0.07), 1.0 if nuit else chaud * 0.4)
	ciel.sky_horizon_color = Color(0.65, 0.75, 0.85).lerp(Color(0.9, 0.55, 0.35), chaud * (0.0 if nuit else 1.0))
	if nuit:
		ciel.sky_horizon_color = Color(0.05, 0.06, 0.1)
	ciel.ground_bottom_color = Color(0.12, 0.12, 0.12)
	ciel.ground_horizon_color = ciel.sky_horizon_color.darkened(0.2)
	ciel.sky_energy_multiplier = 0.15 if nuit else 1.0
	for l in _lumieres_ext:
		l.light_energy = 1.6 if (nuit or elev < 6.0) else 0.0


func cuire_gi() -> void:
	for g in gis:
		if g.visible and g.data == null:
			g.bake()
			if g.data:
				g.data.energy = 1.2
				g.data.propagation = 0.75
				g.data.normal_bias = 0.6
				g.data.use_two_bounces = true
	for i in 3:
		await get_tree().process_frame
	for s in sondes:
		s.update_mode = ReflectionProbe.UPDATE_ALWAYS
	for i in 4:
		await get_tree().process_frame
	for s in sondes:
		s.update_mode = ReflectionProbe.UPDATE_ONCE


func _reglages_changes() -> void:
	Reglages.appliquer_environnement(environnement)
	for g in gis:
		g.visible = Reglages.gi_voxel()
	if Reglages.gi_voxel():
		cuire_gi.call_deferred()


func poses_capture() -> Array:
	return [
		{"nom": "s_hall", "position": Vector3(12.5, 1.65, 24.5), "cible": Vector3(4.0, 1.0, 18.0), "fov": 72.0},
		{"nom": "s_accueil", "position": Vector3(7.0, 1.65, 22.0), "cible": Vector3(11.0, 1.1, 18.5), "fov": 65.0},
		{"nom": "s_couloir", "position": Vector3(1.0, 1.65, 14.5), "cible": Vector3(20.0, 1.2, 14.5), "fov": 70.0},
		{"nom": "s_couloir_est", "position": Vector3(38.5, 1.65, 14.5), "cible": Vector3(25.0, 1.2, 14.5), "fov": 70.0},
		{"nom": "s_dechocage", "position": Vector3(29.0, 1.7, 12.0), "cible": Vector3(24.0, 1.0, 7.5), "fov": 72.0},
		{"nom": "s_box3", "position": Vector3(10.2, 1.65, 12.75), "cible": Vector3(8.4, 0.9, 9.8), "fov": 72.0},
		{"nom": "s_sas", "position": Vector3(35.5, 1.8, 26.5), "cible": Vector3(30.0, 1.2, 19.0), "fov": 70.0},
		{"nom": "s_scanner", "position": Vector3(26.0, 1.65, 22.0), "cible": Vector3(23.5, 1.0, 19.0), "fov": 70.0},
		{"nom": "s_exterieur", "position": Vector3(18.0, 1.7, 40.0), "cible": Vector3(12.0, 2.0, 26.0), "fov": 65.0},
		{"nom": "s_radio", "position": Vector3(39.0, 1.65, 12.3), "cible": Vector3(36.0, 1.0, 9.0), "fov": 72.0},
	]
