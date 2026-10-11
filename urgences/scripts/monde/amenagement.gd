class_name Amenagement
extends RefCounted
## Aménagement (mobilier, signalétique, luminaires) de chaque type de salle du service.
## Toutes les positions sont données dans le repère de la salle (coin nord-ouest = origine),
## ce qui permet de réutiliser un même aménagement (les 6 box par exemple).

const SOLIDES := ["brancard", "chariot_soins", "lavabo", "chaise", "tabouret", "poubelle_dasri",
	"poubelle_menagere", "pied_perfusion", "lampe_examen", "banque_accueil", "rangee_sieges", "distributeur",
	"chariot_urgence", "respirateur", "table_platre", "table_radio", "scanner", "ambulance_samu", "vsav_pompiers",
	"armoire_murale"]
const SIG := "res://assets/textures/signaletique/"

var mobilier: Node3D        # nœud fusionné ensuite (statique)
var dynamique: Node3D       # moniteurs, etc. (jamais fusionné)
var lumieres: Node3D
var o := Vector3.ZERO       # origine de la salle en cours
var points := {}            # points d'intérêt exportés (places de patients, moniteurs…)


func _init(m: Node3D, d: Node3D, l: Node3D) -> void:
	mobilier = m
	dynamique = d
	lumieres = l


func poser(nom: String, p: Vector3, rot_y := 0.0) -> Node3D:
	var n := Bibliotheque.meuble(nom)
	n.position = o + p
	n.rotation_degrees.y = rot_y
	mobilier.add_child(n)
	if nom in SOLIDES:
		Bibliotheque.ajouter_collision(n)
	return n


func dalle(p: Vector3, energie := 1.2, ombre := false, couleur := Color(1.0, 0.97, 0.93)) -> void:
	var d := Bibliotheque.meuble("plafonnier_led")
	d.position = o + p - Vector3(0, 0.001, 0)
	mobilier.add_child(d)
	var s := SpotLight3D.new()
	s.position = o + p - Vector3(0, 0.03, 0)
	s.rotation_degrees.x = -90.0
	s.light_color = couleur
	s.light_energy = energie
	s.spot_range = 5.0
	s.spot_angle = 75.0
	s.spot_angle_attenuation = 0.9
	s.spot_attenuation = 0.8
	s.shadow_enabled = ombre
	s.light_size = 0.45
	s.light_specular = 0.45
	s.distance_fade_enabled = true
	s.distance_fade_begin = 22.0
	s.distance_fade_length = 6.0
	s.distance_fade_shadow = 14.0
	# Lumière fixe : cuite dans la GI voxel (rebonds sol → plafond gratuits à l'exécution).
	s.light_bake_mode = Light3D.BAKE_STATIC
	lumieres.add_child(s)


## Lumière de rebond : une omni douce près du sol simule la lumière renvoyée par le sol clair
## vers le plafond et le haut des murs (sans ombre ni reflet : coût quasi nul). Elle complète
## la GI voxel et le SSIL, et évite les plafonds noirs dans les grandes salles.
func rebond(taille: Vector2, h: float, energie := 0.22) -> void:
	var l := OmniLight3D.new()
	l.position = o + Vector3(taille.x * 0.5, 0.25, taille.y * 0.5)
	l.omni_range = maxf(taille.x, taille.y) * 0.75 + h
	l.omni_attenuation = 0.6
	l.light_energy = energie
	l.light_color = Color(1.0, 0.97, 0.92)
	l.light_specular = 0.0
	l.shadow_enabled = false
	l.light_bake_mode = Light3D.BAKE_DISABLED
	l.distance_fade_enabled = true
	l.distance_fade_begin = 30.0
	lumieres.add_child(l)


## Grille de dalles LED couvrant une salle (pas d'environ 2,4 m).
func dalles_grille(taille: Vector2, h: float, energie := 1.1, ombres := 1) -> void:
	rebond(taille, h)
	var nx := maxi(1, int(round(taille.x / 2.4)))
	var nz := maxi(1, int(round(taille.y / 2.4)))
	var n := 0
	for i in nx:
		for j in nz:
			var p := Vector3((i + 0.5) * taille.x / nx, h, (j + 0.5) * taille.y / nz)
			dalle(p, energie, n < ombres)
			n += 1


func affiche(tex: String, p: Vector3, rot_y: float, taille: Vector2, decoupe := false) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = taille
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(tex)
	mat.roughness = 0.35
	if decoupe:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	q.material = mat
	mi.mesh = q
	mi.position = o + p
	mi.rotation_degrees.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mobilier.add_child(mi)


func decalque(tex: String, p: Vector3, taille: Vector3, rot_y := 0.0, opacite := 1.0) -> void:
	var d := Decal.new()
	d.texture_albedo = load(tex)
	d.size = taille
	d.position = o + p
	d.rotation_degrees.y = rot_y
	d.albedo_mix = opacite
	d.upper_fade = 0.1
	d.lower_fade = 0.1
	dynamique.add_child(d)


func bloc(p: Vector3, taille: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	bm.material = mat
	mi.mesh = bm
	mi.position = o + p
	mobilier.add_child(mi)


func moniteur(p: Vector3, rot_y: float) -> Moniteur:
	var mon := Moniteur.new()
	mon.position = o + p
	mon.rotation_degrees.y = rot_y
	dynamique.add_child(mon)
	return mon


## Porte coulissante vitrée (box) : ouverture de 1,40 m débutant en x0 (repère de la salle).
func porte_vitree(x0: float, z: float, ouvert: float) -> void:
	var verre := Bibliotheque.materiau("verre")
	var alu := Bibliotheque.materiau("aluminium")
	var px := x0 + ouvert
	bloc(Vector3(px + 0.7, 1.05, z + 0.11), Vector3(1.40, 2.10, 0.012), verre)
	for x in [0.0, 1.40]:
		bloc(Vector3(px + x, 1.05, z + 0.11), Vector3(0.04, 2.10, 0.04), alu)
	bloc(Vector3(px + 0.7, 2.11, z + 0.11), Vector3(1.44, 0.04, 0.04), alu)
	bloc(Vector3(px + 0.7, 0.02, z + 0.11), Vector3(1.44, 0.04, 0.04), alu)
	bloc(Vector3(px + 0.06, 1.05, z + 0.14), Vector3(0.025, 0.6, 0.025), alu)
	bloc(Vector3(px + 0.7, 1.45, z + 0.118), Vector3(1.36, 0.25, 0.002), Bibliotheque.materiau("verre_depoli"))
	bloc(Vector3(x0 + 0.7, 2.22, z + 0.11), Vector3(2.9, 0.12, 0.06), alu)


func vitrage(centre: Vector3, taille: Vector3) -> void:
	bloc(centre, taille, Bibliotheque.materiau("verre"))


# =============================================================================================
## Box d'examen (3,6 × 4 m, façade vitrée au sud). Renvoie le moniteur.
func box(origine: Vector3, numero: int, ouvert := 0.0) -> Moniteur:
	o = origine
	var EP := 0.12
	poser("brancard", Vector3(1.55, 0, 1.40), 90.0)
	poser("bandeau_tete_lit", Vector3(1.55, 1.45, EP * 0.5 + 0.045))
	var mon := moniteur(Vector3(0.45, 1.72, EP * 0.5 + 0.53), 20.0)
	poser("pied_perfusion", Vector3(2.55, 0, 0.95), -30.0)
	poser("tensiometre_mural", Vector3(2.75, 1.45, EP * 0.5))
	poser("lavabo", Vector3(EP * 0.5, 0, 3.05), 90.0)
	poser("distributeur_gants", Vector3(EP * 0.5, 1.45, 2.05), 90.0)
	poser("chariot_soins", Vector3(0.45, 0, 2.05), 90.0)
	poser("poubelle_dasri", Vector3(0.30, 0, 3.65), 60.0)
	poser("poubelle_menagere", Vector3(0.75, 0, 3.72), 20.0)
	poser("armoire_murale", Vector3(3.6 - EP * 0.5 - 0.2, 1.75, 2.2), -90.0)
	poser("ordinateur_mural", Vector3(3.6 - EP * 0.5 - 0.31, 1.35, 3.3), -90.0)
	poser("chaise", Vector3(3.05, 0, 1.0), -110.0)
	poser("tabouret", Vector3(2.3, 0, 2.6))
	var pied := Vector3(0.75, 0, 2.85)
	var lacet := rad_to_deg(Vector3(0.32, 0, 0.37).signed_angle_to(Vector3(1.55, 0, 1.55) - pied, Vector3.UP))
	poser("lampe_examen", pied, lacet)
	poser("rail_rideau", Vector3(1.8, 2.66, 3.55))
	poser("rideau", Vector3(0.12, 2.64, 3.55)).scale = Vector3(0.62, 1.0, 1.0)
	poser("horloge", Vector3(2.1, 2.25, 4.0 - EP * 0.5), 180.0)
	affiche(SIG + "affiche_mains.png", Vector3(EP * 0.5 + 0.004, 1.45, 3.62), 90.0, Vector2(0.30, 0.425))
	affiche(SIG + "box_%d.png" % numero, Vector3(2.65, 2.42, 4.0 + EP * 0.5 + 0.004), 0.0, Vector2(0.42, 0.21), true)
	porte_vitree(1.95, 4.0, ouvert)
	vitrage(Vector3(1.0, 1.55, 4.0), Vector3(1.30, 1.20, 0.012))
	bloc(Vector3(1.0, 0.96, 4.0), Vector3(1.32, 0.03, 0.14), Bibliotheque.materiau("aluminium"))
	decalque(SIG + "traces.png", Vector3(1.8, 0, 2.6), Vector3(2.6, 0.3, 2.4), 37.0 + numero * 20.0, 0.5)
	rebond(Vector2(3.6, 4.0), 2.7, 0.15)
	dalle(Vector3(1.5, 2.7, 1.2), 1.3, true)
	dalle(Vector3(1.5, 2.7, 2.4), 1.3, false)
	dalle(Vector3(2.7, 2.7, 3.3), 1.1, false)
	# Lampe d'examen allumée (spot étroit sur le thorax).
	var spot := SpotLight3D.new()
	spot.position = o + pied + Vector3(0.32, 1.29, 0.37).rotated(Vector3.UP, deg_to_rad(lacet))
	lumieres.add_child(spot)
	spot.look_at(o + Vector3(1.55, 0.85, 1.45))
	spot.light_energy = 2.5
	spot.spot_range = 3.0
	spot.spot_angle = 22.0
	spot.shadow_enabled = numero == 3
	spot.light_size = 0.12
	spot.distance_fade_enabled = true
	spot.distance_fade_begin = 15.0
	points["box_%d" % numero] = {"place_patient": o + Vector3(1.55, 0.80, 1.27), "moniteur": mon,
		"entree": o + Vector3(2.65, 0, 4.6)}
	return mon


func couloir(origine: Vector3, longueur: float, largeur: float) -> void:
	o = origine
	var prot := Bibliotheque.materiau("protection_murale")
	# Lisses de protection (main courante) des deux côtés.
	bloc(Vector3(longueur * 0.5, 0.95, 0.075), Vector3(longueur - 0.2, 0.14, 0.03), prot)
	bloc(Vector3(longueur * 0.5, 0.95, largeur - 0.075), Vector3(longueur - 0.2, 0.14, 0.03), prot)
	for i in int(longueur / 2.4):
		var x := 1.2 + i * 2.4
		dalle(Vector3(x, 2.7, largeur * 0.5), 1.0, i % 4 == 1)
	for k in 4:
		o = origine + Vector3(k * longueur / 4.0, 0, 0)
		rebond(Vector2(longueur / 4.0, largeur), 2.7, 0.18)
	o = origine
	poser("brancard", Vector3(12.6, 0, largeur - 0.55))
	poser("pied_perfusion", Vector3(16.5, 0, 0.5))
	poser("extincteur", Vector3(2.0, 0.85, 0.06), 0.0)
	poser("extincteur", Vector3(26.5, 0.85, largeur - 0.06), 180.0)
	decalque(SIG + "fleche_radiologie.png", Vector3(28.0, 0, largeur * 0.5 - 0.4), Vector3(1.2, 0.3, 0.3), 0.0)
	decalque(SIG + "fleche_dechocage.png", Vector3(20.5, 0, largeur * 0.5 + 0.4), Vector3(1.2, 0.3, 0.3), 0.0)
	decalque(SIG + "fleche_accueil.png", Vector3(10.0, 0, largeur * 0.5), Vector3(1.2, 0.3, 0.3), 180.0)
	decalque(SIG + "traces.png", Vector3(longueur * 0.5, 0, largeur * 0.5), Vector3(longueur, 0.3, largeur - 0.3), 0.0, 0.7)


func dechocage(origine: Vector3, taille: Vector2) -> Array:
	o = origine
	var mons := []
	for k in 2:
		var x := 2.1 + k * 4.2
		poser("brancard", Vector3(x, 0, 2.2), 90.0)
		poser("bandeau_tete_lit", Vector3(x, 1.45, 0.105))
		mons.append(moniteur(Vector3(x - 1.1, 1.75, 0.6), 15.0))
		poser("respirateur", Vector3(x + 1.2, 0, 1.2), -60.0)
		poser("pied_perfusion", Vector3(x - 1.0, 0, 3.4))
		poser("scialytique", Vector3(x, 3.0, 2.3))
		var s := SpotLight3D.new()
		s.position = o + Vector3(x, 2.25, 2.3)
		s.rotation_degrees.x = -90.0
		s.light_energy = 2.0
		s.spot_angle = 28.0
		s.spot_range = 3.0
		s.shadow_enabled = k == 0
		s.light_size = 0.3
		lumieres.add_child(s)
		points["dechoc_%d" % (k + 1)] = {"place_patient": o + Vector3(x, 0.80, 2.07), "moniteur": mons[k]}
	poser("chariot_urgence", Vector3(4.2, 0, 1.0), 0.0)
	poser("lavabo", Vector3(taille.x - 0.06, 0, 5.2), -90.0)
	poser("armoire_murale", Vector3(taille.x - 0.26, 1.75, 2.6), -90.0)
	poser("armoire_murale", Vector3(0.26, 1.75, 4.6), 90.0)
	poser("chariot_soins", Vector3(0.5, 0, 5.6), 90.0)
	poser("poubelle_dasri", Vector3(taille.x - 0.4, 0, 6.5))
	poser("horloge", Vector3(4.2, 2.4, taille.y - 0.06), 180.0)
	dalles_grille(taille, 3.0, 1.3, 2)
	return mons


func platre(origine: Vector3) -> void:
	o = origine
	poser("table_platre", Vector3(2.0, 0, 1.6))
	poser("tabouret", Vector3(1.4, 0, 2.6))
	poser("lavabo", Vector3(0.06, 0, 3.0), 90.0)
	poser("armoire_murale", Vector3(3.74, 1.75, 1.6), -90.0)
	poser("chariot_soins", Vector3(3.4, 0, 3.2), -90.0)
	dalles_grille(Vector2(4, 4), 2.7, 1.2, 1)


func radiologie(origine: Vector3, taille: Vector2) -> void:
	o = origine
	poser("table_radio", Vector3(3.0, 0, 2.8), 0.0)
	bloc(Vector3(3.2, 2.95, 2.8), Vector3(0.12, 0.08, 5.0), Bibliotheque.materiau("aluminium"))
	bloc(Vector3(2.4, 2.95, 2.8), Vector3(0.12, 0.08, 5.0), Bibliotheque.materiau("aluminium"))
	# Détecteur mural (Bucky) et paravent plombé avec vitre.
	bloc(Vector3(0.3, 1.3, 1.2), Vector3(0.12, 1.6, 0.6), Bibliotheque.materiau("metal_peint_blanc"))
	bloc(Vector3(5.2, 1.0, 4.4), Vector3(1.4, 2.0, 0.08), Bibliotheque.materiau("metal_peint_gris"))
	vitrage(Vector3(5.2, 1.6, 4.36), Vector3(0.8, 0.5, 0.02))
	poser("ordinateur_mural", Vector3(5.2, 1.3, 5.2), 180.0)
	dalles_grille(taille, 3.0, 1.1, 1)


func scanner(origine: Vector3, taille: Vector2) -> void:
	o = origine
	poser("scanner", Vector3(3.5, 0, 3.4), 180.0)
	poser("armoire_murale", Vector3(0.26, 1.75, 2.0), 90.0)
	dalles_grille(taille, 3.0, 1.0, 1)


func pupitre(origine: Vector3) -> void:
	o = origine
	poser("banque_accueil", Vector3(3.5, 0, 1.0), 180.0)
	poser("chaise", Vector3(3.0, 0, 1.9), 180.0)
	poser("chaise", Vector3(4.2, 0, 1.9), 170.0)
	dalle(Vector3(2.0, 2.7, 1.25), 0.9, false)
	dalle(Vector3(5.0, 2.7, 1.25), 0.9, false)
	rebond(Vector2(7.0, 2.5), 2.7, 0.15)


func hall(origine: Vector3, taille: Vector2) -> void:
	o = origine
	# Banque d'accueil face à l'entrée, sièges en rangées, distributeur, écran d'information.
	poser("banque_accueil", Vector3(11.2, 0, 3.0), 0.0)
	# Rangées de 4 sièges (pas de 0,56 m) ; on exporte la position et l'orientation de chaque
	# siège pour y asseoir les patients (le modèle de rangée regarde +Z avant rotation).
	var sieges := []
	var rangees := []
	for r in 3:
		for c in 2:
			rangees.append([Vector3(2.0 + c * 3.0, 0, 3.0 + r * 1.8), 180.0])
	rangees.append([Vector3(0.35, 0, 7.5), 90.0])
	for rg in rangees:
		poser("rangee_sieges", rg[0], rg[1])
		var rot := deg_to_rad(rg[1])
		for i in 4:
			var local := Vector3(-0.84 + i * 0.56, 0, 0.0)
			sieges.append({"pos": o + rg[0] + local.rotated(Vector3.UP, rot), "rot": rot})
	points["sieges"] = sieges
	points["accueil"] = o + Vector3(11.2, 0, 3.75)
	points["entree"] = o + Vector3(7.0, 0, taille.y + 2.5)
	poser("distributeur", Vector3(0.55, 0, 1.0), 90.0)
	poser("ecran_tv", Vector3(4.0, 2.2, 0.08), 0.0)
	poser("poubelle_menagere", Vector3(1.2, 0, 0.3))
	poser("extincteur", Vector3(13.94, 0.85, 8.0), -90.0)
	affiche(SIG + "affiche_attente.png", Vector3(7.0, 1.55, 0.065), 0.0, Vector2(0.45, 0.64))
	affiche(SIG + "affiche_avc.png", Vector3(8.0, 1.55, 0.065), 0.0, Vector2(0.45, 0.64))
	affiche(SIG + "affiche_mains.png", Vector3(9.0, 1.55, 0.065), 0.0, Vector2(0.45, 0.64))
	# Entrée : porte automatique coulissante vitrée (deux vantaux entrouverts).
	var verre := Bibliotheque.materiau("verre")
	var alu := Bibliotheque.materiau("aluminium")
	for s in [-1, 1]:
		bloc(Vector3(7.0 + s * 0.85, 1.3, taille.y - 0.02), Vector3(1.1, 2.6, 0.02), verre)
		bloc(Vector3(7.0 + s * 0.85 + s * 0.55, 1.3, taille.y - 0.02), Vector3(0.05, 2.6, 0.06), alu)
	bloc(Vector3(7.0, 2.68, taille.y - 0.02), Vector3(2.4, 0.16, 0.25), alu)
	# Vitrages de la façade (montants tous les 1,25 m).
	for seg in [[0.6, 5.6], [8.4, 13.4]]:
		vitrage(Vector3((seg[0] + seg[1]) * 0.5, 1.625, taille.y), Vector3(seg[1] - seg[0], 2.55, 0.02))
		var n := int((seg[1] - seg[0]) / 1.25)
		for i in n + 1:
			bloc(Vector3(seg[0] + i * (seg[1] - seg[0]) / n, 1.625, taille.y), Vector3(0.06, 2.55, 0.12), alu)
	decalque(SIG + "traces.png", Vector3(7.0, 0, 5.0), Vector3(6.0, 0.3, 9.0), 90.0, 0.6)
	dalles_grille(taille, 3.2, 1.2, 2)


func poste_soins(origine: Vector3) -> void:
	o = origine
	poser("banque_accueil", Vector3(3.0, 0, 1.4), 180.0)
	poser("tabouret", Vector3(2.4, 0, 2.3))
	poser("tabouret", Vector3(3.8, 0, 2.4))
	poser("armoire_murale", Vector3(5.8, 1.75, 2.4), -90.0)
	poser("chariot_soins", Vector3(0.6, 0, 3.4), 90.0)
	dalles_grille(Vector2(6, 4), 2.7, 1.1, 1)


func tri(origine: Vector3) -> void:
	o = origine
	poser("brancard", Vector3(2.4, 0, 2.6), 90.0)
	poser("tensiometre_mural", Vector3(3.44, 1.45, 1.4), -90.0)
	poser("ordinateur_mural", Vector3(0.37, 1.35, 4.6), 90.0)
	poser("chaise", Vector3(1.1, 0, 4.0), 60.0)
	poser("lavabo", Vector3(3.44, 0, 5.2), -90.0)
	poser("chariot_soins", Vector3(0.5, 0, 1.0), 90.0)
	dalles_grille(Vector2(3.5, 6), 2.7, 1.2, 1)
	points["tri"] = {"place_patient": o + Vector3(2.4, 0.80, 2.47)}


func bureau(origine: Vector3) -> void:
	o = origine
	poser("chaise", Vector3(1.2, 0, 3.8), 0.0)
	poser("chaise", Vector3(1.6, 0, 2.5), 160.0)
	bloc(Vector3(1.25, 0.74, 3.2), Vector3(1.4, 0.03, 0.7), Bibliotheque.materiau("bois_porte"))
	poser("armoire_murale", Vector3(2.24, 1.75, 1.2), -90.0)
	dalles_grille(Vector2(2.5, 6), 2.7, 1.0, 0)


func sas(origine: Vector3, taille: Vector2) -> void:
	o = origine
	poser("ambulance_samu", Vector3(4.5, 0, 6.5), 90.0)
	poser("brancard", Vector3(8.5, 0, 3.0), 0.0)
	decalque(SIG + "traces.png", Vector3(5.0, 0, 6.0), Vector3(9.0, 0.3, 11.0), 0.0, 0.8)
	for i in 3:
		for j in 4:
			dalle(Vector3(1.7 + i * 3.3, 4.0, 1.5 + j * 3.0), 1.4, i == 1 and j == 1)
	rebond(taille, 4.0, 0.3)
	points["sas"] = {"arrivee": o + Vector3(5.0, 0, 3.5)}


func reserve(origine: Vector3) -> void:
	o = origine
	for k in 3:
		poser("armoire_murale", Vector3(2.74, 1.0 + (k % 2) * 0.0, 2.0 + k * 2.6), -90.0)
	poser("chariot_soins", Vector3(0.5, 0, 6.0), 90.0)
	dalles_grille(Vector2(3, 10), 2.7, 0.9, 0)
